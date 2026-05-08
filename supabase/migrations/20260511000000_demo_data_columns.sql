-- ─── Demo-Daten-Markierung + Onboarding-Status ───────────────────────────
--
-- Zweck:
--   * `is_demo BOOLEAN`-Spalte auf allen Daten-Tabellen, die der Onboarding-
--     Demo-Loader füllt. Erlaubt einen sauberen Rollback ("Demo-Daten löschen")
--     ohne dass User-Eigene Einträge gelöscht werden.
--   * `onboarded_at` auf `workspaces`, damit der Auth-Gate erkennt, ob ein
--     User den Onboarding-Flow schon durchlaufen hat.
--
-- RLS bleibt unverändert: bestehende Workspace-Policies decken die neuen
-- Spalten implizit mit ab — Mitglieder dürfen lesen/schreiben, Nicht-Mitglieder
-- werden bereits per `is_workspace_member`/`has_workspace_role` blockiert.

-- ─── 1. is_demo-Spalten anlegen ──────────────────────────────────────────
ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS is_demo BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.buyers
  ADD COLUMN IF NOT EXISTS is_demo BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.shops
  ADD COLUMN IF NOT EXISTS is_demo BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.suppliers
  ADD COLUMN IF NOT EXISTS is_demo BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS is_demo BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.activity_log
  ADD COLUMN IF NOT EXISTS is_demo BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS is_demo BOOLEAN NOT NULL DEFAULT FALSE;

-- Partial-Indexe nur auf den Demo-Rows: hält das Bulk-Delete des Wipe-Buttons
-- schnell, ohne reguläre Workloads aufzublähen.
CREATE INDEX IF NOT EXISTS deals_demo_idx
  ON public.deals(workspace_id) WHERE is_demo;
CREATE INDEX IF NOT EXISTS buyers_demo_idx
  ON public.buyers(workspace_id) WHERE is_demo;
CREATE INDEX IF NOT EXISTS shops_demo_idx
  ON public.shops(workspace_id) WHERE is_demo;
CREATE INDEX IF NOT EXISTS suppliers_demo_idx
  ON public.suppliers(workspace_id) WHERE is_demo;
CREATE INDEX IF NOT EXISTS inventory_items_demo_idx
  ON public.inventory_items(workspace_id) WHERE is_demo;
CREATE INDEX IF NOT EXISTS activity_log_demo_idx
  ON public.activity_log(workspace_id) WHERE is_demo;
CREATE INDEX IF NOT EXISTS tickets_demo_idx
  ON public.tickets(workspace_id) WHERE is_demo;

-- ─── 2. onboarded_at auf workspaces ──────────────────────────────────────
ALTER TABLE public.workspaces
  ADD COLUMN IF NOT EXISTS onboarded_at TIMESTAMPTZ;

COMMENT ON COLUMN public.workspaces.onboarded_at IS
  'Zeitstempel, an dem der Owner den Onboarding-Flow beendet hat. NULL = noch nicht durchlaufen.';

-- Backfill: alle bereits existierenden Workspaces gelten als onboarded —
-- sie wurden vor Einführung des Flows angelegt. Pre-Launch ist das
-- risikofrei. Neue Workspaces (Trigger `provision_personal_workspace`)
-- bekommen weiterhin NULL und triggern dadurch den First-Time-Flow.
UPDATE public.workspaces
   SET onboarded_at = created_at
 WHERE onboarded_at IS NULL;
