-- ─── Invite-Annahme: RLS für Invitees + accept_workspace_invite RPC ──────
--
-- Bisher konnte nur der Owner/Admin Invites einer Workspace lesen
-- (`invites_owner_admin`). Der Eingeladene selbst hatte keine Möglichkeit,
-- die offenen Einladungen zu sehen oder anzunehmen — was den ganzen
-- Invite-Flow nutzlos machte.
--
-- Hier:
--   1. zusätzliche SELECT-Policy "invites_self_email_read", die den
--      Eingeladenen die eigenen offenen Einladungen sehen lässt.
--   2. SECURITY-DEFINER-Funktion `accept_workspace_invite(token)`, die
--      sauber prüft (Email-Match, nicht abgelaufen, noch nicht angenommen)
--      und dann atomisch in `workspace_members` einträgt + Invite als
--      accepted markiert.

-- ── 1. Policy: Eingeladener sieht eigene offene Invites ─────────────────
DROP POLICY IF EXISTS invites_self_email_read ON public.workspace_invites;
CREATE POLICY invites_self_email_read ON public.workspace_invites
  FOR SELECT USING (
    accepted_at IS NULL
    AND expires_at > NOW()
    AND lower(email) = lower(coalesce(
      (auth.jwt() -> 'email')::text,
      ''
    ))
  );

-- Note: `auth.jwt() -> 'email'` liefert die Email als JSONB-Wert (mit
-- Quotes drumrum); daher mit `->>` als Text rauslesen wäre sauberer.
-- Variante mit ->>:
DROP POLICY IF EXISTS invites_self_email_read ON public.workspace_invites;
CREATE POLICY invites_self_email_read ON public.workspace_invites
  FOR SELECT USING (
    accepted_at IS NULL
    AND expires_at > NOW()
    AND lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- ── 2. RPC: Invite annehmen ─────────────────────────────────────────────
-- Wird vom Client aufgerufen, sobald der User auf "Beitreten" tippt.
-- Returns workspace_id bei Erfolg, raised exception bei Fehler.
CREATE OR REPLACE FUNCTION public.accept_workspace_invite(_invite_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_invite public.workspace_invites%ROWTYPE;
  v_user_email text;
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  v_user_email := lower(coalesce(auth.jwt() ->> 'email', ''));
  IF v_user_email = '' THEN
    RAISE EXCEPTION 'no_email_in_token';
  END IF;

  SELECT * INTO v_invite
  FROM public.workspace_invites
  WHERE id = _invite_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invite_not_found';
  END IF;

  IF v_invite.accepted_at IS NOT NULL THEN
    RAISE EXCEPTION 'invite_already_accepted';
  END IF;

  IF v_invite.expires_at < NOW() THEN
    RAISE EXCEPTION 'invite_expired';
  END IF;

  IF lower(v_invite.email) <> v_user_email THEN
    RAISE EXCEPTION 'invite_email_mismatch';
  END IF;

  -- Idempotent: falls Member-Eintrag schon existiert (Race), upserten.
  INSERT INTO public.workspace_members
    (workspace_id, user_id, role, invited_by, joined_at)
  VALUES
    (v_invite.workspace_id, v_user_id, v_invite.role,
     v_invite.invited_by, NOW())
  ON CONFLICT (workspace_id, user_id) DO UPDATE
    SET role = EXCLUDED.role;

  UPDATE public.workspace_invites
  SET accepted_at = NOW()
  WHERE id = v_invite.id;

  RETURN v_invite.workspace_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_workspace_invite(uuid)
  TO authenticated;

-- Optional: Cleanup-Funktion zum Ablehnen (entfernt die Einladung)
CREATE OR REPLACE FUNCTION public.decline_workspace_invite(_invite_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_invite public.workspace_invites%ROWTYPE;
  v_user_email text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  v_user_email := lower(coalesce(auth.jwt() ->> 'email', ''));

  SELECT * INTO v_invite
  FROM public.workspace_invites
  WHERE id = _invite_id;

  IF NOT FOUND THEN RETURN FALSE; END IF;
  IF v_invite.accepted_at IS NOT NULL THEN RETURN FALSE; END IF;
  IF lower(v_invite.email) <> v_user_email THEN
    RAISE EXCEPTION 'invite_email_mismatch';
  END IF;

  DELETE FROM public.workspace_invites WHERE id = v_invite.id;
  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.decline_workspace_invite(uuid)
  TO authenticated;
