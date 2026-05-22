-- ─── Epic E (Task E1): Inventur — stocktakes + stocktake_items ───────────────
--
-- Plan: plans/2026-05-20_warenverwaltung-feature-parity.md
--       Abschnitt "Epic E — Inventur".
--
-- Inhalt dieser Migration (rein additiv):
--   1. NEU: Tabelle public.stocktakes — Inventur-Session (Kopf). BIGSERIAL-PK,
--      Standard-4-Policy-RLS, Touch-Trigger, Indexe (workspace_id +
--      Status-Filter), FK-Cross-Workspace-Trigger für warehouse_id.
--   2. NEU: Tabelle public.stocktake_items — Zähl-Positionen (Kind-Tabelle).
--      UUID-PK, Standard-4-Policy-RLS, Touch-Trigger, Indexe,
--      FK-Cross-Workspace-Trigger für product_id UND stocktake_id
--      (Pflicht — Kind-Tabelle, Committee-Finding 6).
--
-- RLS-Pattern strikt nach 20260504000500_data_workspace_scope.sql /
-- 20260522010918_purchase_orders.sql (C1): `workspace_id NOT NULL` + FK,
-- `user_id` als Erfasser-Spalte, Policies über `is_workspace_member` (read)
-- und `has_workspace_role(...,['owner','admin','member'])` (write).
-- Audit-Spalten + Touch-Trigger (`touch_row` pflegt updated_at/updated_by/
-- version).
--
-- Hinweis zu stocktake_items: Der Plan listet für diese Kind-Tabelle nur
-- created_at/updated_at — KEIN deleted_at. Das wird hier exakt befolgt.
-- updated_by/version werden ergänzt, weil der gemeinsame touch_row-Trigger
-- diese Spalten pflegt (Pattern wie C1.purchase_order_items).
--
-- Beim Schließen einer Inventur erzeugt die App pro Differenz eine
-- inventory_movements-Row mit movement_type='stocktake' (append-only,
-- siehe Querschnitt im Plan) — das ist NICHT Teil dieser Migration.

-- ─── 1. Tabelle stocktakes ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.stocktakes (
  id            BIGSERIAL PRIMARY KEY,
  workspace_id  UUID NOT NULL
                  REFERENCES public.workspaces(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id),
  warehouse_id  UUID
                  REFERENCES public.warehouses(id) ON DELETE SET NULL,
  status        TEXT NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open','counting','closed','cancelled')),
  title         TEXT,
  started_at    TIMESTAMPTZ,
  closed_at     TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by    UUID REFERENCES auth.users(id),
  version       INT NOT NULL DEFAULT 1,
  deleted_at    TIMESTAMPTZ
);

-- ── RLS: Default-Deny + 4 explizite Workspace-Policies ──────────────────────
ALTER TABLE public.stocktakes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS stocktakes_ws_read   ON public.stocktakes;
DROP POLICY IF EXISTS stocktakes_ws_insert ON public.stocktakes;
DROP POLICY IF EXISTS stocktakes_ws_update ON public.stocktakes;
DROP POLICY IF EXISTS stocktakes_ws_delete ON public.stocktakes;

CREATE POLICY stocktakes_ws_read   ON public.stocktakes FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY stocktakes_ws_insert ON public.stocktakes FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY stocktakes_ws_update ON public.stocktakes FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY stocktakes_ws_delete ON public.stocktakes FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));

-- ── Touch-Trigger (updated_at/updated_by/version) — Pattern wie C1 ───────────
DROP TRIGGER IF EXISTS trg_touch_stocktakes ON public.stocktakes;
CREATE TRIGGER trg_touch_stocktakes
  BEFORE UPDATE ON public.stocktakes
  FOR EACH ROW EXECUTE FUNCTION public.touch_row();

-- ── Indexe: workspace_id, Status-Filter ─────────────────────────────────────
CREATE INDEX IF NOT EXISTS stocktakes_workspace_idx
  ON public.stocktakes (workspace_id);
CREATE INDEX IF NOT EXISTS stocktakes_workspace_status_idx
  ON public.stocktakes (workspace_id, status);

-- ── FK-Cross-Workspace-Trigger für warehouse_id ─────────────────────────────
-- Ein reiner FK erlaubt Cross-Workspace-Referenzen. Dieser Trigger erzwingt
-- DB-seitig, dass das referenzierte Lager im SELBEN Workspace liegt — greift
-- auch beim Service-Role-Pfad (Demo-Seed, Migrationen). Stil exakt nach C1:
-- SECURITY DEFINER, SET search_path = public, pg_temp.
CREATE OR REPLACE FUNCTION public.assert_stocktake_fks_same_workspace()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.warehouse_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.warehouses r
    WHERE r.id = NEW.warehouse_id
      AND r.workspace_id = NEW.workspace_id
  ) THEN
    RAISE EXCEPTION 'cross-workspace reference rejected for warehouse_id';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS stocktakes_fks_ws_check ON public.stocktakes;
CREATE TRIGGER stocktakes_fks_ws_check
  BEFORE INSERT OR UPDATE OF warehouse_id
  ON public.stocktakes
  FOR EACH ROW EXECUTE FUNCTION
    public.assert_stocktake_fks_same_workspace();

-- ─── 2. Tabelle stocktake_items ─────────────────────────────────────────────
-- Kein deleted_at (Plan-Vorgabe für diese Kind-Tabelle). updated_by/version
-- werden für den gemeinsamen touch_row-Trigger ergänzt.
CREATE TABLE IF NOT EXISTS public.stocktake_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  UUID NOT NULL
                  REFERENCES public.workspaces(id) ON DELETE CASCADE,
  stocktake_id  BIGINT NOT NULL
                  REFERENCES public.stocktakes(id) ON DELETE CASCADE,
  product_id    UUID NOT NULL
                  REFERENCES public.products(id) ON DELETE RESTRICT,
  expected_qty  INTEGER NOT NULL,
  counted_qty   INTEGER,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by    UUID REFERENCES auth.users(id),
  version       INT NOT NULL DEFAULT 1
);

-- ── RLS: Default-Deny + 4 explizite Workspace-Policies ──────────────────────
-- stocktake_items filtert über die EIGENE workspace_id-Spalte (nicht über den
-- Parent), konsistent mit purchase_order_items / inventory_movements.
ALTER TABLE public.stocktake_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS stocktake_items_ws_read   ON public.stocktake_items;
DROP POLICY IF EXISTS stocktake_items_ws_insert ON public.stocktake_items;
DROP POLICY IF EXISTS stocktake_items_ws_update ON public.stocktake_items;
DROP POLICY IF EXISTS stocktake_items_ws_delete ON public.stocktake_items;

CREATE POLICY stocktake_items_ws_read   ON public.stocktake_items FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY stocktake_items_ws_insert ON public.stocktake_items FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY stocktake_items_ws_update ON public.stocktake_items FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY stocktake_items_ws_delete ON public.stocktake_items FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));

-- ── Touch-Trigger (updated_at/updated_by/version) — Pattern wie C1 ───────────
DROP TRIGGER IF EXISTS trg_touch_stocktake_items ON public.stocktake_items;
CREATE TRIGGER trg_touch_stocktake_items
  BEFORE UPDATE ON public.stocktake_items
  FOR EACH ROW EXECUTE FUNCTION public.touch_row();

-- ── Indexe: FK-Filter für Parent-Join und Produkt-Filter ────────────────────
CREATE INDEX IF NOT EXISTS stocktake_items_workspace_stocktake_idx
  ON public.stocktake_items (workspace_id, stocktake_id);
CREATE INDEX IF NOT EXISTS stocktake_items_workspace_product_idx
  ON public.stocktake_items (workspace_id, product_id);

-- ── FK-Cross-Workspace-Trigger für product_id + stocktake_id ────────────────
-- Pflicht (Committee-Finding 6) — stocktake_items ist eine Kind-Tabelle.
-- Ein reiner FK erlaubt Cross-Workspace-Referenzen. Dieser Trigger erzwingt
-- DB-seitig, dass die referenzierte Inventur-Session UND das Produkt im
-- SELBEN Workspace liegen. Ein Trigger deckt beide FK-Spalten ab.
CREATE OR REPLACE FUNCTION public.assert_stocktake_item_fks_same_workspace()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.stocktake_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.stocktakes r
    WHERE r.id = NEW.stocktake_id
      AND r.workspace_id = NEW.workspace_id
  ) THEN
    RAISE EXCEPTION 'cross-workspace reference rejected for stocktake_id';
  END IF;

  IF NEW.product_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.products r
    WHERE r.id = NEW.product_id
      AND r.workspace_id = NEW.workspace_id
  ) THEN
    RAISE EXCEPTION 'cross-workspace reference rejected for product_id';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS stocktake_items_fks_ws_check ON public.stocktake_items;
CREATE TRIGGER stocktake_items_fks_ws_check
  BEFORE INSERT OR UPDATE OF product_id, stocktake_id
  ON public.stocktake_items
  FOR EACH ROW EXECUTE FUNCTION
    public.assert_stocktake_item_fks_same_workspace();

-- ─── DOWN-Migration (kommentiert, Repo-Konvention wie C1) ───────────────────
-- Reine CREATE-TABLE-Migration → vollständig reversibel. Beide Tabellen sind
-- ungefüllt (kein Backfill) → DROP TABLE ist datenverlustfrei.
-- Zum Zurückrollen den folgenden Block ausführen:
--
-- BEGIN;
--   -- 2) stocktake_items: Trigger, Funktion, Tabelle
--   --    (Indexe + Policies fallen mit DROP TABLE weg)
--   DROP TRIGGER IF EXISTS stocktake_items_fks_ws_check
--     ON public.stocktake_items;
--   DROP TRIGGER IF EXISTS trg_touch_stocktake_items
--     ON public.stocktake_items;
--   DROP FUNCTION IF EXISTS
--     public.assert_stocktake_item_fks_same_workspace();
--   DROP TABLE IF EXISTS public.stocktake_items;
--
--   -- 1) stocktakes: Trigger, Funktion, Tabelle
--   DROP TRIGGER IF EXISTS stocktakes_fks_ws_check
--     ON public.stocktakes;
--   DROP TRIGGER IF EXISTS trg_touch_stocktakes
--     ON public.stocktakes;
--   DROP FUNCTION IF EXISTS
--     public.assert_stocktake_fks_same_workspace();
--   DROP TABLE IF EXISTS public.stocktakes;
-- COMMIT;
