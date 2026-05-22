-- ─── Epic C (Task C1): Bestellwesen — purchase_orders + purchase_order_items ─
--
-- Plan: plans/2026-05-20_warenverwaltung-feature-parity.md
--       Abschnitt "Epic C — Bestellwesen".
--
-- Inhalt dieser Migration (rein additiv):
--   1. NEU: Tabelle public.purchase_orders — Bestell-Kopf. Standard-4-Policy-
--      RLS, Touch-Trigger, Indexe (inkl. partial-UNIQUE auf order_number),
--      FK-Cross-Workspace-Trigger für supplier_id.
--   2. NEU: Tabelle public.purchase_order_items — Bestell-Positionen
--      (Kind-Tabelle). Standard-4-Policy-RLS, Touch-Trigger, Indexe,
--      FK-Cross-Workspace-Trigger für product_id UND purchase_order_id
--      (Pflicht — Kind-Tabelle, Committee-Finding 6).
--   3. NEU: Status-Trigger auf purchase_order_items — pflegt
--      purchase_orders.status (partially_received / received) automatisch
--      beim Wareneingang. Stil analog 20260509000300_archive_triggers.sql.
--
-- RLS-Pattern strikt nach 20260504000500_data_workspace_scope.sql /
-- 20260522000609_products_catalog.sql (AF1) /
-- 20260522001308_product_stock_and_suppliers.sql (AF3): `workspace_id
-- NOT NULL` + FK, `user_id` als Erfasser-Spalte, Policies über
-- `is_workspace_member` (read) und `has_workspace_role(...,
-- ['owner','admin','member'])` (write). Audit-Spalten + Touch-Trigger
-- (`touch_row` pflegt updated_at/updated_by/version).
--
-- PO-Wareneingang ist serverseitig atomar gedacht (Committee-Finding 12):
-- quantity_received wird via `SET quantity_received = quantity_received + :x`
-- in einem einzigen UPDATE inkrementiert (kein Read-modify-write im Client).
-- Der Status-Trigger unten feuert auf genau dieses UPDATE.

-- ─── 1. Tabelle purchase_orders ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.purchase_orders (
  id            BIGSERIAL PRIMARY KEY,
  workspace_id  UUID NOT NULL
                  REFERENCES public.workspaces(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id),
  supplier_id   UUID NOT NULL
                  REFERENCES public.suppliers(id) ON DELETE RESTRICT,
  order_number  TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'draft'
                  CHECK (status IN ('draft','ordered','partially_received',
                                    'received','cancelled')),
  order_date    TIMESTAMPTZ,
  expected_date TIMESTAMPTZ,
  note          TEXT,
  total_net     NUMERIC(12,2),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by    UUID REFERENCES auth.users(id),
  version       INT NOT NULL DEFAULT 1,
  deleted_at    TIMESTAMPTZ
);

-- ── RLS: Default-Deny + 4 explizite Workspace-Policies ──────────────────────
ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS purchase_orders_ws_read   ON public.purchase_orders;
DROP POLICY IF EXISTS purchase_orders_ws_insert ON public.purchase_orders;
DROP POLICY IF EXISTS purchase_orders_ws_update ON public.purchase_orders;
DROP POLICY IF EXISTS purchase_orders_ws_delete ON public.purchase_orders;

CREATE POLICY purchase_orders_ws_read   ON public.purchase_orders FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY purchase_orders_ws_insert ON public.purchase_orders FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY purchase_orders_ws_update ON public.purchase_orders FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY purchase_orders_ws_delete ON public.purchase_orders FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));

-- ── Touch-Trigger (updated_at/updated_by/version) — Pattern wie AF1/AF3 ──────
DROP TRIGGER IF EXISTS trg_touch_purchase_orders ON public.purchase_orders;
CREATE TRIGGER trg_touch_purchase_orders
  BEFORE UPDATE ON public.purchase_orders
  FOR EACH ROW EXECUTE FUNCTION public.touch_row();

-- ── Indexe: workspace_id, Status-Filter ─────────────────────────────────────
CREATE INDEX IF NOT EXISTS purchase_orders_workspace_idx
  ON public.purchase_orders (workspace_id);
CREATE INDEX IF NOT EXISTS purchase_orders_workspace_status_idx
  ON public.purchase_orders (workspace_id, status);

-- Partial-UNIQUE: Bestellnummer eindeutig pro Workspace, nur für nicht
-- soft-gelöschte Rows.
CREATE UNIQUE INDEX IF NOT EXISTS purchase_orders_workspace_order_number_uidx
  ON public.purchase_orders (workspace_id, order_number)
  WHERE deleted_at IS NULL;

-- ── FK-Cross-Workspace-Trigger für supplier_id ──────────────────────────────
-- Ein reiner FK erlaubt Cross-Workspace-Referenzen. Dieser Trigger erzwingt
-- DB-seitig, dass der referenzierte Lieferant im SELBEN Workspace liegt —
-- greift auch beim Service-Role-Pfad (Demo-Seed, Migrationen). Stil exakt
-- nach AF1 / AF3: SECURITY DEFINER, SET search_path = public, pg_temp.
CREATE OR REPLACE FUNCTION public.assert_purchase_order_fks_same_workspace()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.supplier_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.suppliers r
    WHERE r.id = NEW.supplier_id
      AND r.workspace_id = NEW.workspace_id
  ) THEN
    RAISE EXCEPTION 'cross-workspace reference rejected for supplier_id';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS purchase_orders_fks_ws_check ON public.purchase_orders;
CREATE TRIGGER purchase_orders_fks_ws_check
  BEFORE INSERT OR UPDATE OF supplier_id
  ON public.purchase_orders
  FOR EACH ROW EXECUTE FUNCTION
    public.assert_purchase_order_fks_same_workspace();

-- ─── 2. Tabelle purchase_order_items ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.purchase_order_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id      UUID NOT NULL
                      REFERENCES public.workspaces(id) ON DELETE CASCADE,
  purchase_order_id BIGINT NOT NULL
                      REFERENCES public.purchase_orders(id) ON DELETE CASCADE,
  product_id        UUID NOT NULL
                      REFERENCES public.products(id) ON DELETE RESTRICT,
  quantity_ordered  INTEGER NOT NULL CHECK (quantity_ordered > 0),
  quantity_received INTEGER NOT NULL DEFAULT 0
                      CHECK (quantity_received >= 0),
  unit_price        NUMERIC(12,2),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by        UUID REFERENCES auth.users(id),
  version           INT NOT NULL DEFAULT 1,
  deleted_at        TIMESTAMPTZ
);

-- ── RLS: Default-Deny + 4 explizite Workspace-Policies ──────────────────────
-- purchase_order_items filtert über die EIGENE workspace_id-Spalte (nicht
-- über den Parent), konsistent mit inventory_movements / product_suppliers.
ALTER TABLE public.purchase_order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS purchase_order_items_ws_read   ON public.purchase_order_items;
DROP POLICY IF EXISTS purchase_order_items_ws_insert ON public.purchase_order_items;
DROP POLICY IF EXISTS purchase_order_items_ws_update ON public.purchase_order_items;
DROP POLICY IF EXISTS purchase_order_items_ws_delete ON public.purchase_order_items;

CREATE POLICY purchase_order_items_ws_read   ON public.purchase_order_items FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY purchase_order_items_ws_insert ON public.purchase_order_items FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY purchase_order_items_ws_update ON public.purchase_order_items FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY purchase_order_items_ws_delete ON public.purchase_order_items FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));

-- ── Touch-Trigger (updated_at/updated_by/version) — Pattern wie AF1/AF3 ──────
DROP TRIGGER IF EXISTS trg_touch_purchase_order_items ON public.purchase_order_items;
CREATE TRIGGER trg_touch_purchase_order_items
  BEFORE UPDATE ON public.purchase_order_items
  FOR EACH ROW EXECUTE FUNCTION public.touch_row();

-- ── Indexe: FK-Filter für Parent-Join und Produkt-Filter ────────────────────
CREATE INDEX IF NOT EXISTS purchase_order_items_workspace_po_idx
  ON public.purchase_order_items (workspace_id, purchase_order_id);
CREATE INDEX IF NOT EXISTS purchase_order_items_workspace_product_idx
  ON public.purchase_order_items (workspace_id, product_id);

-- ── FK-Cross-Workspace-Trigger für product_id + purchase_order_id ───────────
-- Pflicht (Committee-Finding 6) — purchase_order_items ist eine Kind-Tabelle.
-- Ein reiner FK erlaubt Cross-Workspace-Referenzen. Dieser Trigger erzwingt
-- DB-seitig, dass die referenzierte Bestellung UND das Produkt im SELBEN
-- Workspace liegen. Ein Trigger deckt beide FK-Spalten ab.
CREATE OR REPLACE FUNCTION public.assert_purchase_order_item_fks_same_workspace()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.purchase_order_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.purchase_orders r
    WHERE r.id = NEW.purchase_order_id
      AND r.workspace_id = NEW.workspace_id
  ) THEN
    RAISE EXCEPTION 'cross-workspace reference rejected for purchase_order_id';
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

DROP TRIGGER IF EXISTS purchase_order_items_fks_ws_check ON public.purchase_order_items;
CREATE TRIGGER purchase_order_items_fks_ws_check
  BEFORE INSERT OR UPDATE OF product_id, purchase_order_id
  ON public.purchase_order_items
  FOR EACH ROW EXECUTE FUNCTION
    public.assert_purchase_order_item_fks_same_workspace();

-- ─── 3. Status-Trigger: Wareneingang pflegt purchase_orders.status ──────────
--
-- Wenn quantity_received einer Position verändert wird (Wareneingang gebucht),
-- leitet die DB den Bestell-Status automatisch ab:
--
--   alle Positionen quantity_received >= quantity_ordered  → 'received'
--   mind. eine Position quantity_received > 0, aber nicht
--     alle voll                                            → 'partially_received'
--
-- Defensiv: Der Status wird NUR umgesetzt, wenn die PO aktuell in 'ordered'
-- oder 'partially_received' steht. Damit gilt:
--   * Eine 'draft'-PO (noch nicht bestellt) springt durch einen
--     Wareneingang nicht plötzlich auf 'received'.
--   * Eine 'cancelled'-PO ist final und wird nie überschrieben.
--
-- Soft-deleted Positionen (deleted_at IS NOT NULL) werden bei der
-- Aggregation ausgeschlossen — sie sollen den Abschluss nicht blockieren
-- und nicht fälschlich als "offen" zählen.
--
-- SECURITY DEFINER + festes search_path: Der Trigger muss purchase_orders
-- schreiben dürfen, auch wenn der auslösende User dort nur eine engere
-- Policy hat. search_path auf public, pg_temp gepinnt (Standard-Härtung,
-- analog 20260509000300_archive_triggers.sql).
CREATE OR REPLACE FUNCTION public.tg_purchase_order_status_from_items()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_po_id       BIGINT;
  v_status      TEXT;
  v_total       INT;
  v_full        INT;
  v_any_partial INT;
  v_new_status  TEXT;
BEGIN
  v_po_id := NEW.purchase_order_id;
  IF v_po_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Aktuellen Status der PO laden. Nur 'ordered'/'partially_received'
  -- werden automatisch fortgeschrieben — 'draft' und 'cancelled' (sowie
  -- ein bereits gesetztes 'received') bleiben unangetastet.
  SELECT status INTO v_status
    FROM public.purchase_orders
   WHERE id = v_po_id;

  IF v_status IS NULL
     OR v_status NOT IN ('ordered','partially_received') THEN
    RETURN NEW;
  END IF;

  -- Positionen aggregieren — soft-deleted Items ausgeschlossen.
  SELECT COUNT(*),
         COUNT(*) FILTER (WHERE quantity_received >= quantity_ordered),
         COUNT(*) FILTER (WHERE quantity_received > 0)
    INTO v_total, v_full, v_any_partial
    FROM public.purchase_order_items
   WHERE purchase_order_id = v_po_id
     AND deleted_at IS NULL;

  -- Keine (aktiven) Positionen → kein automatischer Statuswechsel.
  IF v_total = 0 THEN
    RETURN NEW;
  END IF;

  IF v_full = v_total THEN
    v_new_status := 'received';
  ELSIF v_any_partial > 0 THEN
    v_new_status := 'partially_received';
  ELSE
    RETURN NEW;  -- noch nichts empfangen → Status bleibt.
  END IF;

  -- Nur schreiben, wenn sich der Status tatsächlich ändert (vermeidet
  -- unnötige Touch-Trigger-Läufe). Das WHERE auf den Quell-Status schützt
  -- zusätzlich gegen Races mit einem parallelen Cancel/Reopen.
  UPDATE public.purchase_orders
     SET status = v_new_status
   WHERE id = v_po_id
     AND status IN ('ordered','partially_received')
     AND status IS DISTINCT FROM v_new_status;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS purchase_order_items_status_trg
  ON public.purchase_order_items;
CREATE TRIGGER purchase_order_items_status_trg
  AFTER INSERT OR UPDATE OF quantity_received
  ON public.purchase_order_items
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_purchase_order_status_from_items();

-- ─── DOWN-Migration (kommentiert, Repo-Konvention wie AF1 / AF3) ────────────
-- Reine CREATE-TABLE-Migration → vollständig reversibel. Beide Tabellen
-- sind ungefüllt (kein Backfill) → DROP TABLE ist datenverlustfrei.
-- Zum Zurückrollen den folgenden Block ausführen:
--
-- BEGIN;
--   -- 3) Status-Trigger + Funktion
--   DROP TRIGGER IF EXISTS purchase_order_items_status_trg
--     ON public.purchase_order_items;
--   DROP FUNCTION IF EXISTS public.tg_purchase_order_status_from_items();
--
--   -- 2) purchase_order_items: Trigger, Funktion, Tabelle
--   --    (Indexe + Policies fallen mit DROP TABLE weg)
--   DROP TRIGGER IF EXISTS purchase_order_items_fks_ws_check
--     ON public.purchase_order_items;
--   DROP TRIGGER IF EXISTS trg_touch_purchase_order_items
--     ON public.purchase_order_items;
--   DROP FUNCTION IF EXISTS
--     public.assert_purchase_order_item_fks_same_workspace();
--   DROP TABLE IF EXISTS public.purchase_order_items;
--
--   -- 1) purchase_orders: Trigger, Funktion, Tabelle
--   DROP TRIGGER IF EXISTS purchase_orders_fks_ws_check
--     ON public.purchase_orders;
--   DROP TRIGGER IF EXISTS trg_touch_purchase_orders
--     ON public.purchase_orders;
--   DROP FUNCTION IF EXISTS
--     public.assert_purchase_order_fks_same_workspace();
--   DROP TABLE IF EXISTS public.purchase_orders;
-- COMMIT;
