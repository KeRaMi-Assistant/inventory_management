-- ─── T3: create_workspace-RPC + workspace_limit_for_plan ─────────────────
--
-- Liefert die zentrale, transaktional sichere Erstellungs-Routine für
-- neue Workspaces. Ersetzt den direkten Client-INSERT (in T1 RLS-blockiert).
--
-- Mitigation (D5, Blocker 4):
--   * Plan-Limit-Lookup über pure SQL-Funktion `workspace_limit_for_plan`.
--   * `create_workspace` als SECURITY DEFINER mit Advisory-Lock pro
--     auth.uid() — verhindert TOCTOU-Race zwischen Limit-Read und INSERT,
--     wenn der gleiche User zwei Calls parallel feuert.
--   * INSERT setzt is_personal=FALSE explizit (nur der Auto-Trigger
--     markiert is_personal=TRUE).
--
-- Sicherheits-Anker:
--   * Funktion läuft mit Definer-Rechten (RLS-Bypass für INSERT auf
--     workspaces + workspace_members), aber prüft auth.uid() selbst.
--   * SET search_path = public, auth — schließt schema-injection-
--     Angriffe (Search-Path-Hijack) aus.
--   * GRANT EXECUTE TO authenticated — anon kann die RPC nicht aufrufen.

-- workspace_limit_for_plan(plan): zentraler Lookup, pure Function.
-- IMMUTABLE → Planner kann das Result cachen.
-- -1 = unbegrenzt. Bei unbekannten Plans: restriktiver Fallback 1.
CREATE OR REPLACE FUNCTION public.workspace_limit_for_plan(_plan TEXT)
RETURNS INTEGER
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE _plan
    WHEN 'free'        THEN 1
    WHEN 'solo'        THEN 1
    WHEN 'solo_pro'    THEN 2
    WHEN 'team'        THEN 5
    WHEN 'business'    THEN 20
    WHEN 'enterprise'  THEN -1
    -- Legacy-Aliase (für DB-Werte, die noch nicht migriert wurden):
    WHEN 'starter'     THEN 1
    WHEN 'pro'         THEN 2
    WHEN 'solo_plus'   THEN 2
    WHEN 'soloplus'    THEN 2
    WHEN 'ultimate'    THEN -1
    ELSE 1
  END;
$$;

GRANT EXECUTE ON FUNCTION public.workspace_limit_for_plan(TEXT) TO authenticated;

COMMENT ON FUNCTION public.workspace_limit_for_plan(TEXT) IS
  'Lookup: max. zulässige Workspaces pro Plan. -1 = unbegrenzt. Synchron mit BillingPlan.workspaceLimit in lib/models/billing_profile.dart.';

-- create_workspace(name): atomar mit Limit-Check + Advisory-Lock.
-- RETURNS public.workspaces (Row-Type) — PostgREST liefert die Zeile mit
-- allen Spalten zurück, inkl. is_personal=FALSE.
CREATE OR REPLACE FUNCTION public.create_workspace(_name TEXT)
RETURNS public.workspaces
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_uid        UUID := auth.uid();
  v_plan       TEXT;
  v_limit      INTEGER;
  v_count      INTEGER;
  v_clean      TEXT;
  v_workspace  public.workspaces%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Race-Mitigation (Blocker 4): serialisiert parallele create_workspace-
  -- Calls desselben Users. Der Lock wird beim TX-Ende automatisch
  -- freigegeben (xact_lock). Andere User sind durch hashtext-Key getrennt
  -- und nicht blockiert.
  PERFORM pg_advisory_xact_lock(hashtext('create_workspace:' || v_uid::text));

  v_clean := btrim(coalesce(_name, ''));
  IF length(v_clean) < 1 OR length(v_clean) > 80 THEN
    RAISE EXCEPTION 'invalid_name';
  END IF;

  SELECT plan INTO v_plan
    FROM public.billing_profiles
   WHERE user_id = v_uid;
  IF v_plan IS NULL THEN
    v_plan := 'free';
  END IF;

  v_limit := public.workspace_limit_for_plan(v_plan);

  SELECT COUNT(*) INTO v_count
    FROM public.workspaces
   WHERE owner_id = v_uid
     AND deleted_at IS NULL;

  IF v_limit >= 0 AND v_count >= v_limit THEN
    RAISE EXCEPTION 'workspace_limit_reached'
      USING HINT = format('plan=%s limit=%s count=%s', v_plan, v_limit, v_count);
  END IF;

  -- is_personal explizit FALSE; Personal-WS wird nur vom Trigger gesetzt.
  INSERT INTO public.workspaces (name, owner_id, is_personal)
       VALUES (v_clean, v_uid, FALSE)
    RETURNING * INTO v_workspace;

  INSERT INTO public.workspace_members (workspace_id, user_id, role, invited_by, joined_at)
       VALUES (v_workspace.id, v_uid, 'owner', v_uid, NOW());

  RETURN v_workspace;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_workspace(TEXT) TO authenticated;

COMMENT ON FUNCTION public.create_workspace(TEXT) IS
  'Erstellt neue Workspace + Owner-Member atomar. Prüft auth.uid() und Plan-Limit aus billing_profiles. Advisory-Lock serialisiert Concurrent-Calls vom selben User. Wirft: not_authenticated | invalid_name | workspace_limit_reached.';
