-- ─── T1: Workspaces RLS-Split — INSERT-Pfad RLS-deny (Blocker 2) ─────────
--
-- Vorgeschichte:
--   * 20260504000200_workspaces.sql:94 setzt `workspaces_owner_write FOR ALL`
--     mit USING/WITH CHECK = owner_id=auth.uid().
--   * Das deckt auch INSERT ab: ein Client kann mit eigenem owner_id eine
--     neue Workspace-Zeile direkt einfügen — der Plan-Limit-Check in der
--     kommenden create_workspace-RPC (T3) wäre umgehbar.
--
-- Mitigation (D6):
--   * `workspaces_owner_write` droppen.
--   * Stattdessen zwei explizite Policies für UPDATE und DELETE.
--   * KEINE INSERT-Policy für `authenticated`. Damit ist direkter Client-
--     INSERT auf workspaces RLS-deny.
--
-- INSERT-Pfade bleiben:
--   (1) Trigger provision_personal_workspace (SECURITY DEFINER, bypassed RLS).
--   (2) Künftige RPC create_workspace (SECURITY DEFINER, kommt in T3).
--
-- SELECT-Policy (workspaces_member_read) aus 20260504000300_workspace_rls_fix.sql
-- bleibt unverändert — Member dürfen weiter lesen.

DROP POLICY IF EXISTS workspaces_owner_write ON public.workspaces;

CREATE POLICY workspaces_owner_update ON public.workspaces
  FOR UPDATE
  USING  (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY workspaces_owner_delete ON public.workspaces
  FOR DELETE
  USING  (owner_id = auth.uid());

-- KEINE INSERT-Policy für authenticated. INSERT geht nur via:
--   1) Trigger provision_personal_workspace (SECURITY DEFINER)
--   2) RPC create_workspace (SECURITY DEFINER, kommt in 20260520000200)
COMMENT ON TABLE public.workspaces IS
  'Workspaces. INSERT nur via SECURITY DEFINER (provision_personal_workspace-Trigger + create_workspace-RPC). UPDATE/DELETE nur durch Owner. SELECT durch Members.';
