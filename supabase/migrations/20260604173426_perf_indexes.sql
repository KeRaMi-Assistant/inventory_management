-- ─── Performance-Indexe: Hot-Query-Coverage (Audit Quick-Win) ────────────
--
-- Audit-Findings:
--   1. Die tägliche tracking-poll-Query (offene Deals pro Workspace) hat
--      keinen passenden Index — sie filtert workspace_id + status +
--      arrival_date IS NULL + tracking IS NOT NULL und sortiert nach
--      order_date. Der vorhandene deals_workspace_idx (nur workspace_id)
--      deckt nur den ersten Filter.
--   2. Die Soft-Delete-„Active"-Indexe aus 20260503000100_soft_delete.sql
--      (und suppliers_active_idx aus 20260503000600) sind auf `user_id`
--      gekeyed. Seit der Workspace-Umstellung (20260504000500) filtern ALLE
--      List-Queries aber `workspace_id` + `deleted_at IS NULL` — die alten
--      user_id-Indexe sind damit für die Hot-Path-List-Queries tot.
--
-- Diese Migration ergänzt NUR die fehlenden, query-genauen Indexe.
-- Sie löscht KEINE alten user_id-Indexe (separates Risiko → Followup, siehe
-- Kommentar am Dateiende). Alle CREATE INDEX sind idempotent
-- (IF NOT EXISTS).

-- ── 1. tracking-poll Daily-Query (Edge Function tracking-poll/index.ts) ──
-- Query (pollWorkspace, ~Z.286-299):
--   FROM deals
--   WHERE workspace_id = ?
--     AND status = 'Unterwegs'
--     AND arrival_date IS NULL
--     AND tracking IS NOT NULL
--   ORDER BY order_date ASC
-- Partial Composite Index: das WHERE-Prädikat (status/arrival_date/tracking)
-- ist im Partial-Filter, workspace_id + order_date im Index-Key → der Index
-- liefert die Rows pre-sortiert und pre-gefiltert.
CREATE INDEX IF NOT EXISTS deals_open_tracking_idx
  ON public.deals (workspace_id, order_date)
  WHERE status = 'Unterwegs'
    AND arrival_date IS NULL
    AND tracking IS NOT NULL;

-- ── 2. Workspace-scoped Active-Indexe für die loadAll-Hot-Queries ────────
-- Ersetzen funktional die toten user_id-`*_active_idx`. Jede Query stammt aus
-- SupabaseRepository.loadAll (lib/services/supabase_repository.dart, ~Z.215):
--   .eq('workspace_id', ws).filter('deleted_at', 'is', null)

-- deals: .eq('workspace_id', ws).filter('deleted_at','is',null).order('id')
CREATE INDEX IF NOT EXISTS deals_ws_active_idx
  ON public.deals (workspace_id)
  WHERE deleted_at IS NULL;

-- buyers: .eq('workspace_id', ws).filter('deleted_at','is',null)
--         .order('sort_order')
CREATE INDEX IF NOT EXISTS buyers_ws_active_idx
  ON public.buyers (workspace_id)
  WHERE deleted_at IS NULL;

-- shops: .eq('workspace_id', ws).filter('deleted_at','is',null).order('name')
CREATE INDEX IF NOT EXISTS shops_ws_active_idx
  ON public.shops (workspace_id)
  WHERE deleted_at IS NULL;

-- inventory_items: .eq('workspace_id', ws).filter('deleted_at','is',null)
--                  .order('created_at')
CREATE INDEX IF NOT EXISTS inventory_items_ws_active_idx
  ON public.inventory_items (workspace_id)
  WHERE deleted_at IS NULL;

-- suppliers: .eq('workspace_id', ws).filter('deleted_at','is',null)
--            .order('name')
CREATE INDEX IF NOT EXISTS suppliers_ws_active_idx
  ON public.suppliers (workspace_id)
  WHERE deleted_at IS NULL;

-- ─── Followup (NICHT in dieser Migration) ────────────────────────────────
-- Die folgenden user_id-gekeyten Soft-Delete-Indexe sind für die
-- Workspace-List-Queries tot und sollten in einer SEPARATEN Migration
-- (nach Verifikation, dass keine user_id-basierte Query mehr darauf
-- angewiesen ist) per DROP INDEX entfernt werden:
--   - deals_active_idx            (20260503000100_soft_delete.sql)
--   - buyers_active_idx           (20260503000100_soft_delete.sql)
--   - shops_active_idx            (20260503000100_soft_delete.sql)
--   - inventory_items_active_idx  (20260503000100_soft_delete.sql)
--   - suppliers_active_idx        (20260503000600_suppliers.sql)
-- Bewusst hier NICHT gedroppt: DROP INDEX ist destruktiv und braucht
-- explizite Plan-Bestätigung (CLAUDE.md: keine destruktiven Migrations
-- ohne Freigabe).
