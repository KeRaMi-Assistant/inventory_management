-- ─── T2: workspaces.is_personal — explizite Personal-Workspace-Markierung ─
--
-- Vorgeschichte:
--   * 20260504000200_workspaces.sql legt pro neuem auth.users-Row einen
--     "Personal" Workspace an (Trigger provision_personal_workspace).
--   * Bisher gibt es keine harte Spalte, die den Personal-WS markiert; UI
--     erkennt ihn heuristisch über `created_at=MIN(per owner)`. Das ist
--     nicht stabil, sobald ein User mehrere Workspaces hat (Multi-WS).
--
-- Mitigation (D3, R3):
--   * Neue Spalte `is_personal BOOLEAN NOT NULL DEFAULT FALSE`.
--   * Backfill: pro owner_id wird der älteste Workspace als is_personal=TRUE
--     markiert. ROW_NUMBER() ist stabil und idempotent.
--   * Trigger provision_personal_workspace wird so erweitert, dass künftige
--     Auto-Provisionings is_personal=TRUE setzen.
--
-- Wichtig: Das `CREATE TRIGGER trg_provision_personal_workspace`-Statement
-- aus 20260504000200_workspaces.sql:177-180 bleibt unverändert — wir
-- ersetzen nur die Function-Definition via `CREATE OR REPLACE FUNCTION`.

ALTER TABLE public.workspaces
  ADD COLUMN IF NOT EXISTS is_personal BOOLEAN NOT NULL DEFAULT FALSE;

-- Backfill: älteste Workspace pro owner_id ist die Personal-WS.
-- Idempotent: setzt is_personal nur, wo es noch FALSE ist. Beim zweiten
-- Lauf trifft die WHERE-Klausel keine Zeile mehr.
WITH ranked AS (
  SELECT
    id,
    owner_id,
    ROW_NUMBER() OVER (PARTITION BY owner_id ORDER BY created_at ASC) AS rn
  FROM public.workspaces
  WHERE deleted_at IS NULL
)
UPDATE public.workspaces w
   SET is_personal = TRUE
  FROM ranked r
 WHERE w.id = r.id
   AND r.rn = 1
   AND w.is_personal = FALSE;

-- Trigger-Function aktualisieren: setzt is_personal = TRUE bei der
-- Auto-Provision. Signatur + Trigger-Definition aus 20260504000200_workspaces.sql
-- bleiben kompatibel (RETURNS TRIGGER, SECURITY DEFINER, AFTER INSERT ON
-- auth.users). search_path wird explizit gesetzt — Best-Practice gegen
-- Search-Path-Injection in SECURITY DEFINER Functions.
CREATE OR REPLACE FUNCTION public.provision_personal_workspace()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_ws_id UUID;
BEGIN
  INSERT INTO public.workspaces (name, owner_id, is_personal)
       VALUES ('Personal', NEW.id, TRUE)
    RETURNING id INTO v_ws_id;

  INSERT INTO public.workspace_members (workspace_id, user_id, role, invited_by, joined_at)
       VALUES (v_ws_id, NEW.id, 'owner', NEW.id, NOW());

  RETURN NEW;
END;
$$;

COMMENT ON COLUMN public.workspaces.is_personal IS
  'TRUE = Auto-Provisioned Personal Workspace (1 pro User). Bei Rename via UI muss Confirm-Dialog erscheinen. Niemals direkt durch Client setzbar (RLS deny auf INSERT, create_workspace-RPC setzt FALSE).';
