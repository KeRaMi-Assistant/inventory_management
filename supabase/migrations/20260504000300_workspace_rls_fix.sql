-- ─── Fix RLS-Rekursion auf workspace_members ─────────────────────────────
--
-- Die Policies aus 20260504000200 referenzieren `workspace_members` aus
-- einer Policy auf `workspace_members` heraus → Postgres erkennt das als
-- "infinite recursion" (42P17). Lösung: ein SECURITY DEFINER-Helper, der
-- RLS umgeht und für die Mitgliedschaftsprüfung benutzt wird.

CREATE OR REPLACE FUNCTION public.is_workspace_member(_ws uuid, _uid uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.workspace_members
    WHERE workspace_id = _ws AND user_id = _uid
  );
$$;

CREATE OR REPLACE FUNCTION public.has_workspace_role(_ws uuid, _uid uuid, _roles text[])
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.workspace_members
    WHERE workspace_id = _ws AND user_id = _uid AND role = ANY(_roles)
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_workspace_member(uuid, uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.has_workspace_role(uuid, uuid, text[]) TO anon, authenticated;

-- ── Policies neu aufbauen ──────────────────────────────────────────────

-- workspaces: bleibt gleich, aber Member-Check via Helper
DROP POLICY IF EXISTS workspaces_member_read ON public.workspaces;
CREATE POLICY workspaces_member_read ON public.workspaces
  FOR SELECT USING (
    deleted_at IS NULL AND (
      owner_id = auth.uid()
      OR public.is_workspace_member(id, auth.uid())
    )
  );

-- workspace_members
DROP POLICY IF EXISTS members_self_read ON public.workspace_members;
CREATE POLICY members_self_read ON public.workspace_members
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.is_workspace_member(workspace_id, auth.uid())
  );

DROP POLICY IF EXISTS members_owner_write ON public.workspace_members;
CREATE POLICY members_owner_write ON public.workspace_members
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.workspaces w
      WHERE w.id = workspace_id AND w.owner_id = auth.uid()
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.workspaces w
      WHERE w.id = workspace_id AND w.owner_id = auth.uid()
    )
  );

-- workspace_invites: nur Owner/Admin schreiben & sehen, sowie der eingeladene User
DROP POLICY IF EXISTS invites_owner_admin ON public.workspace_invites;
CREATE POLICY invites_owner_admin ON public.workspace_invites
  FOR ALL USING (
    public.has_workspace_role(workspace_id, auth.uid(), ARRAY['owner','admin'])
  ) WITH CHECK (
    public.has_workspace_role(workspace_id, auth.uid(), ARRAY['owner','admin'])
  );

-- audit_log: alle Mitglieder dürfen lesen
DROP POLICY IF EXISTS audit_member_read ON public.audit_log;
CREATE POLICY audit_member_read ON public.audit_log
  FOR SELECT USING (
    public.is_workspace_member(workspace_id, auth.uid())
  );
