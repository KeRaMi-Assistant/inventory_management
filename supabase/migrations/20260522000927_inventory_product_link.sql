-- ─── Epic A-full (Task AF2): Produkt-Verknüpfung für Bestand & Buchungen ────
--
-- Plan: plans/2026-05-20_warenverwaltung-feature-parity.md
--       Abschnitt "Epic A-full — Artikelstamm (P1)":
--         * "GEÄNDERT: inventory_items wird (additiv) zur Bestands-Row"
--           (Committee-Finding 2: product_id ist DAUERHAFT NULLABLE).
--         * "GEÄNDERT: inventory_movements — Produkt-Verknüpfung".
--
-- Inhalt dieser Migration (rein additiv):
--   1. inventory_items: NEUE Spalte product_id (FK → products, ON DELETE
--      SET NULL, DAUERHAFT NULLABLE) + NEUE Spalte warehouse_id (nur UUID,
--      OHNE FK — Tabelle warehouses kommt erst Epic D / Task D1).
--   2. inventory_movements: NEUE Spalte product_id (FK → products, ON DELETE
--      SET NULL, nullable) + Index (workspace_id, product_id).
--   3. FK-Cross-Workspace-Trigger für inventory_items.product_id und
--      inventory_movements.product_id — Stil exakt nach AF1
--      (20260522000609_products_catalog.sql) / B1
--      (20260521222920_categories_supplier_extension.sql):
--      SECURITY DEFINER, SET search_path = public, pg_temp, EXISTS-Check.
--
-- WICHTIG — Committee-Finding 2 (product_id dauerhaft nullable):
--   * KEIN NOT-NULL-Constraint auf product_id (weder jetzt noch später).
--   * KEIN Backfill bestehender Rows. Bestehende inventory_items ohne
--     verknüpftes Produkt funktionieren unverändert weiter; nur neue
--     Wareneingänge / PO-Receipts verlinken auf ein Produkt.
--   * Begründung: Pre-Launch = keine echten Daten — ein Backfill wäre
--     verschwendete Komplexität und Risiko ohne Nutzen.
--
-- WICHTIG — Committee-Finding 5 (inventory_movements bleibt append-only):
--   * inventory_movements behält seine 2-Policy-RLS (read + insert,
--     definiert in 20260504000500_data_workspace_scope.sql:346-353).
--     Diese Migration ändert KEINE Policy.
--   * KEINE updated_at/deleted_at/Touch-Trigger auf inventory_movements —
--     die Tabelle ist ein unveränderliches Audit-Journal.
--   * Der FK-Cross-Workspace-Trigger unten ist ein reiner BEFORE-INSERT-OR-
--     UPDATE-Validierungs-Trigger (RAISE EXCEPTION bei Verletzung) — er
--     mutiert keine Daten und verletzt den append-only-Charakter nicht.

-- ─── 1. inventory_items: product_id + warehouse_id ──────────────────────────

-- product_id: DAUERHAFT NULLABLE FK auf den Artikelstamm. ON DELETE SET NULL,
-- damit ein gelöschtes Produkt keine Bestands-Rows blockiert. KEIN Backfill.
ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS product_id UUID
    REFERENCES public.products(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.inventory_items.product_id IS
  'Optionale Verknuepfung zum Artikelstamm products (Epic A-full). '
  'DAUERHAFT NULLABLE — kein NOT-NULL, kein Backfill (Committee-Finding 2). '
  'Nicht-verknuepfte Rows nutzen weiterhin name/sku/ean direkt.';

-- warehouse_id: nullable. Die Tabelle public.warehouses existiert NOCH NICHT
-- (sie wird erst in Epic D / Task D1 angelegt). Daher hier bewusst eine reine
-- UUID-Spalte OHNE FK-Constraint. Der FK auf warehouses(id) UND der
-- zugehoerige FK-Cross-Workspace-Trigger werden in der D1-Migration
-- nachgezogen.
ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS warehouse_id UUID;

COMMENT ON COLUMN public.inventory_items.warehouse_id IS
  'Optionale Lager-Zuordnung (Epic D). NOCH OHNE FK — Tabelle warehouses '
  'existiert erst ab Epic D. FK auf warehouses(id) ON DELETE SET NULL und '
  'FK-Cross-Workspace-Trigger werden in der D1-Migration ergaenzt.';

-- ─── 2. inventory_movements: product_id + Index ─────────────────────────────

-- product_id: nullable FK auf den Artikelstamm, parallel zum bestehenden
-- item_id — fuer katalogweite Buchungs-Auswertung (Produkt-Detail-History).
ALTER TABLE public.inventory_movements
  ADD COLUMN IF NOT EXISTS product_id UUID
    REFERENCES public.products(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.inventory_movements.product_id IS
  'Optionale Verknuepfung zum Artikelstamm products (Epic A-full), parallel '
  'zu item_id. Fuer katalogweite Auswertung. Nullable, kein Backfill.';

-- Index fuer die Produkt-Detail-Movement-History: Filter nach
-- (workspace_id, product_id).
CREATE INDEX IF NOT EXISTS inventory_movements_workspace_product_idx
  ON public.inventory_movements (workspace_id, product_id);

-- ─── 3. FK-Cross-Workspace-Trigger ──────────────────────────────────────────
-- Ein reiner FK erlaubt Cross-Workspace-Referenzen. Diese Trigger erzwingen
-- DB-seitig, dass das referenzierte Produkt im SELBEN Workspace liegt —
-- greifen auch beim Service-Role-Pfad (Demo-Seed, Migrationen).
-- Stil exakt nach AF1 / B1: SECURITY DEFINER, SET search_path = public,
-- pg_temp, EXISTS-Check gegen products.workspace_id, sonst RAISE EXCEPTION.

-- ── 3a) inventory_items.product_id ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.assert_inventory_item_product_same_workspace()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
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

-- Eigener, klar benannter Trigger. Die bestehende
-- inventory_check_ticket_archive_trg (20260509000300_archive_triggers.sql)
-- ist AFTER UPDATE — kein Timing-Konflikt mit diesem BEFORE-Trigger.
DROP TRIGGER IF EXISTS inventory_items_product_id_ws_check
  ON public.inventory_items;
CREATE TRIGGER inventory_items_product_id_ws_check
  BEFORE INSERT OR UPDATE OF product_id ON public.inventory_items
  FOR EACH ROW EXECUTE FUNCTION
    public.assert_inventory_item_product_same_workspace();

-- HINWEIS: Fuer inventory_items.warehouse_id gibt es JETZT bewusst NOCH
-- KEINEN FK-Cross-Workspace-Trigger — die Tabelle warehouses existiert erst
-- ab Epic D. Der Trigger wird zusammen mit dem FK in der D1-Migration
-- nachgezogen.

-- ── 3b) inventory_movements.product_id ──────────────────────────────────────
-- Reiner BEFORE-Validierungs-Trigger (RAISE EXCEPTION) — mutiert keine
-- Daten, verletzt den append-only-Charakter von inventory_movements nicht.
CREATE OR REPLACE FUNCTION public.assert_movement_product_same_workspace()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
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

DROP TRIGGER IF EXISTS inventory_movements_product_id_ws_check
  ON public.inventory_movements;
CREATE TRIGGER inventory_movements_product_id_ws_check
  BEFORE INSERT OR UPDATE OF product_id ON public.inventory_movements
  FOR EACH ROW EXECUTE FUNCTION
    public.assert_movement_product_same_workspace();

-- ─── DOWN-Migration (kommentiert, Repo-Konvention wie AF1 / B1) ─────────────
-- Reine ADD-COLUMN-/Trigger-Migration → vollstaendig reversibel.
-- product_id ist nullable und ungefuellt (kein Backfill) → DROP COLUMN
-- ist datenverlustfrei. Zum Zurueckrollen den folgenden Block ausfuehren:
--
-- BEGIN;
--   -- 3b) inventory_movements.product_id-Trigger
--   DROP TRIGGER IF EXISTS inventory_movements_product_id_ws_check
--     ON public.inventory_movements;
--   DROP FUNCTION IF EXISTS public.assert_movement_product_same_workspace();
--
--   -- 3a) inventory_items.product_id-Trigger
--   DROP TRIGGER IF EXISTS inventory_items_product_id_ws_check
--     ON public.inventory_items;
--   DROP FUNCTION IF EXISTS
--     public.assert_inventory_item_product_same_workspace();
--
--   -- 2) inventory_movements: Index + Spalte
--   DROP INDEX IF EXISTS public.inventory_movements_workspace_product_idx;
--   ALTER TABLE public.inventory_movements DROP COLUMN IF EXISTS product_id;
--
--   -- 1) inventory_items: Spalten
--   ALTER TABLE public.inventory_items DROP COLUMN IF EXISTS warehouse_id;
--   ALTER TABLE public.inventory_items DROP COLUMN IF EXISTS product_id;
-- COMMIT;
