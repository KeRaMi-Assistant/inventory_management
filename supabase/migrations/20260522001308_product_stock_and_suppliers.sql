-- ─── Epic A-full (Task AF3): Bestands-View + Artikel-Lieferanten-Zuordnung ──
--
-- Plan: plans/2026-05-20_warenverwaltung-feature-parity.md
--       Abschnitt "Epic A-full — Artikelstamm (P1)":
--         * "NEU: DB-View product_stock" (Committee-Finding 9).
--       Abschnitt "Epic B — Kategorien + Lieferanten-Erweiterung":
--         * "NEU: Tabelle product_suppliers (Artikel-Lieferanten-Zuordnung
--           n:m)". Laut Plan-Hinweis "Epic-Abhaengigkeit" referenziert
--           product_suppliers die products-Tabelle und wird daher im
--           A-full-Cluster mitgezogen.
--
-- Inhalt dieser Migration (rein additiv):
--   1. NEU: View public.product_stock — die EINZIGE Bestands-Wahrheit fuer
--      Low-Stock-Alerts (D4) und Produkt-Detail-Aggregation. Aggregiert
--      inventory_items.quantity pro (workspace_id, product_id, warehouse_id).
--      Explizit security_invoker = true, damit die inventory_items_ws_read-
--      RLS-Policy des aufrufenden Users greift (NICHT Definer-Rechte).
--   2. NEU: Tabelle public.product_suppliers — Artikel-Lieferanten-Zuordnung
--      n:m. Standard-4-Policy-RLS, Touch-Trigger, Indexe, zwei partial-
--      UNIQUE-Indexe, FK-Cross-Workspace-Trigger fuer product_id UND
--      supplier_id (Pflicht — Kind-/Verknuepfungstabelle, Finding 6).
--
-- RLS-Pattern strikt nach 20260504000500_data_workspace_scope.sql /
-- 20260522000609_products_catalog.sql (AF1) /
-- 20260521222920_categories_supplier_extension.sql (B1): `workspace_id
-- NOT NULL` + FK, `user_id` als Erfasser-Spalte, Policies ueber
-- `is_workspace_member` (read) und `has_workspace_role(...,
-- ['owner','admin','member'])` (write). Audit-Spalten + Touch-Trigger
-- (`touch_row` pflegt updated_at/updated_by/version).

-- ─── 1. View product_stock ──────────────────────────────────────────────────
--
-- security_invoker = true ist PFLICHT: Ohne dieses Attribut laeuft die View
-- mit den Rechten ihres Eigentuemers (Definer) und wuerde die RLS der
-- zugrunde liegenden inventory_items umgehen. Mit security_invoker = true
-- greift die inventory_items_ws_read-Policy des aufrufenden Users — die View
-- erbt damit die Workspace-Isolation implizit.
-- security_invoker auf Views verlangt PostgreSQL 15+ (Supabase liegt aktuell
-- darueber — PG 15 ist seit Supabase-Standard verfuegbar).
--
-- Aggregations-Achse: pro (workspace_id, product_id, warehouse_id) — liefert
-- den Bestand pro Lager. Gesamtbestand pro Produkt = Summe darueber
-- (GROUP BY workspace_id, product_id). Nicht-verknuepfte Bestands-Rows
-- (product_id IS NULL) fallen bewusst raus — sie haben kein Produkt-
-- Mindestbestand-Ziel.
DROP VIEW IF EXISTS public.product_stock;
CREATE VIEW public.product_stock
WITH (security_invoker = true) AS
SELECT
  i.workspace_id,
  i.product_id,
  i.warehouse_id,
  SUM(i.quantity) AS qty_in_warehouse
FROM public.inventory_items i
WHERE i.deleted_at IS NULL
  AND i.product_id IS NOT NULL
GROUP BY i.workspace_id, i.product_id, i.warehouse_id;

COMMENT ON VIEW public.product_stock IS
  'Aggregierter Lagerbestand pro (workspace_id, product_id, warehouse_id) '
  'aus inventory_items (Epic A-full, Committee-Finding 9). Einzige Bestands-'
  'Wahrheit fuer Low-Stock-Alerts und Produkt-Detail. security_invoker=true '
  '-> erbt die inventory_items_ws_read-RLS des aufrufenden Users.';

-- ─── 2. Tabelle product_suppliers ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.product_suppliers (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id   UUID NOT NULL
                   REFERENCES public.workspaces(id) ON DELETE CASCADE,
  user_id        UUID NOT NULL REFERENCES auth.users(id),
  product_id     UUID NOT NULL
                   REFERENCES public.products(id) ON DELETE CASCADE,
  supplier_id    UUID NOT NULL
                   REFERENCES public.suppliers(id) ON DELETE CASCADE,
  supplier_sku   TEXT,
  supplier_price NUMERIC(12,2),
  is_preferred   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by     UUID REFERENCES auth.users(id),
  version        INT NOT NULL DEFAULT 1,
  deleted_at     TIMESTAMPTZ
);

-- ── RLS: Default-Deny + 4 explizite Workspace-Policies ──────────────────────
ALTER TABLE public.product_suppliers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS product_suppliers_ws_read   ON public.product_suppliers;
DROP POLICY IF EXISTS product_suppliers_ws_insert ON public.product_suppliers;
DROP POLICY IF EXISTS product_suppliers_ws_update ON public.product_suppliers;
DROP POLICY IF EXISTS product_suppliers_ws_delete ON public.product_suppliers;

CREATE POLICY product_suppliers_ws_read   ON public.product_suppliers FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY product_suppliers_ws_insert ON public.product_suppliers FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY product_suppliers_ws_update ON public.product_suppliers FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY product_suppliers_ws_delete ON public.product_suppliers FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));

-- ── Touch-Trigger (updated_at/updated_by/version) — Pattern wie products ─────
DROP TRIGGER IF EXISTS trg_touch_product_suppliers ON public.product_suppliers;
CREATE TRIGGER trg_touch_product_suppliers
  BEFORE UPDATE ON public.product_suppliers
  FOR EACH ROW EXECUTE FUNCTION public.touch_row();

-- ── Indexe: FK-Filter (workspace_id, product_id) ────────────────────────────
CREATE INDEX IF NOT EXISTS product_suppliers_workspace_product_idx
  ON public.product_suppliers (workspace_id, product_id);

-- Partial-UNIQUE: dieselbe Lieferanten-Zuordnung darf pro Produkt nur einmal
-- existieren — nur fuer nicht soft-geloeschte Rows.
CREATE UNIQUE INDEX IF NOT EXISTS product_suppliers_product_supplier_uidx
  ON public.product_suppliers (workspace_id, product_id, supplier_id)
  WHERE deleted_at IS NULL;

-- Partial-UNIQUE: nur EIN bevorzugter Lieferant pro Produkt
-- (Committee-Empfehlung 5) — nur fuer is_preferred und nicht soft-geloeschte
-- Rows.
CREATE UNIQUE INDEX IF NOT EXISTS product_suppliers_preferred_uidx
  ON public.product_suppliers (workspace_id, product_id)
  WHERE is_preferred AND deleted_at IS NULL;

-- ── FK-Cross-Workspace-Trigger fuer product_id + supplier_id ────────────────
-- Pflicht (Committee-Finding 6) — product_suppliers ist eine Kind-/
-- Verknuepfungstabelle. Ein reiner FK erlaubt Cross-Workspace-Referenzen.
-- Dieser Trigger erzwingt DB-seitig, dass das referenzierte Produkt UND der
-- Lieferant im SELBEN Workspace liegen — greift auch beim Service-Role-Pfad
-- (Demo-Seed, Migrationen). Stil exakt nach AF1 / B1: SECURITY DEFINER,
-- SET search_path = public, pg_temp, EXISTS-Check. Ein Trigger deckt beide
-- FK-Spalten ab.
CREATE OR REPLACE FUNCTION public.assert_product_supplier_fks_same_workspace()
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

DROP TRIGGER IF EXISTS product_suppliers_fks_ws_check ON public.product_suppliers;
CREATE TRIGGER product_suppliers_fks_ws_check
  BEFORE INSERT OR UPDATE OF product_id, supplier_id
  ON public.product_suppliers
  FOR EACH ROW EXECUTE FUNCTION
    public.assert_product_supplier_fks_same_workspace();

-- ─── DOWN-Migration (kommentiert, Repo-Konvention wie AF1 / AF2 / B1) ───────
-- Reine CREATE-VIEW-/CREATE-TABLE-Migration → vollstaendig reversibel.
-- product_suppliers ist ungefuellt (kein Backfill) → DROP TABLE ist
-- datenverlustfrei. Zum Zurueckrollen den folgenden Block ausfuehren:
--
-- BEGIN;
--   -- 2) product_suppliers: Trigger, Funktion, Indexe, Tabelle
--   DROP TRIGGER IF EXISTS product_suppliers_fks_ws_check
--     ON public.product_suppliers;
--   DROP TRIGGER IF EXISTS trg_touch_product_suppliers
--     ON public.product_suppliers;
--   DROP FUNCTION IF EXISTS
--     public.assert_product_supplier_fks_same_workspace();
--   DROP TABLE IF EXISTS public.product_suppliers;
--
--   -- 1) product_stock-View
--   DROP VIEW IF EXISTS public.product_stock;
-- COMMIT;
