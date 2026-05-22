-- ─── Epic A-full (Task AF1): Artikelstamm `products` ────────────────────────
--
-- Plan: plans/2026-05-20_warenverwaltung-feature-parity.md
--       Abschnitt "Epic A-full — Artikelstamm (P1)".
--
-- Inhalt dieser Migration:
--   1. NEU: Tabelle `products` (wiederverwendbarer Stammkatalog-Artikel) —
--      Standard-4-Policy-RLS, Touch-Trigger, Indexe (inkl. partial-UNIQUE
--      auf lower(sku)), FK-Cross-Workspace-Trigger für `category_id` und
--      `default_supplier_id`.
--
-- RLS-Pattern strikt nach 20260504000500_data_workspace_scope.sql /
-- 20260521222920_categories_supplier_extension.sql (B1): `workspace_id
-- NOT NULL` + FK, `user_id` als Erfasser-Spalte, Policies über
-- `is_workspace_member` (read) und `has_workspace_role(...,
-- ['owner','admin','member'])` (write). Audit-Spalten + Touch-Trigger
-- wie bei `product_categories` (`touch_row` pflegt updated_at/updated_by/
-- version). EAN-CHECK-Stil übernommen aus 20260503000500_inventory_ean.sql
-- (`ean IS NULL OR ean ~ '...'` — der CHECK gilt nur für non-NULL Werte).

-- ─── 1. Tabelle products ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.products (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id        UUID NOT NULL
                        REFERENCES public.workspaces(id) ON DELETE CASCADE,
  user_id             UUID NOT NULL REFERENCES auth.users(id),
  name                TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 200),
  sku                 TEXT,
  ean                 TEXT
                        CHECK (ean IS NULL
                               OR ean ~ '^\d{8}$|^\d{12}$|^\d{13}$|^\d{14}$'),
  category_id         UUID REFERENCES public.product_categories(id)
                        ON DELETE SET NULL,
  default_supplier_id UUID REFERENCES public.suppliers(id)
                        ON DELETE SET NULL,
  unit                TEXT NOT NULL DEFAULT 'Stk',
  default_cost_price  NUMERIC(12,2),
  default_sale_price  NUMERIC(12,2),
  min_stock           INTEGER NOT NULL DEFAULT 0,
  tax_rate            NUMERIC(5,2),
  note                TEXT,
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  is_demo             BOOLEAN NOT NULL DEFAULT FALSE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by          UUID REFERENCES auth.users(id),
  version             INT NOT NULL DEFAULT 1,
  deleted_at          TIMESTAMPTZ
);

-- ── RLS: Default-Deny + 4 explizite Workspace-Policies ──────────────────────
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS products_ws_read   ON public.products;
DROP POLICY IF EXISTS products_ws_insert ON public.products;
DROP POLICY IF EXISTS products_ws_update ON public.products;
DROP POLICY IF EXISTS products_ws_delete ON public.products;

CREATE POLICY products_ws_read   ON public.products FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY products_ws_insert ON public.products FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY products_ws_update ON public.products FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY products_ws_delete ON public.products FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));

-- ── Touch-Trigger (updated_at/updated_by/version) — Pattern wie B1 ───────────
DROP TRIGGER IF EXISTS trg_touch_products ON public.products;
CREATE TRIGGER trg_touch_products
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.touch_row();

-- ── Indexe: workspace_id, Kategorie-Filter, eindeutige SKU pro Workspace ─────
CREATE INDEX IF NOT EXISTS products_workspace_idx
  ON public.products (workspace_id);
CREATE INDEX IF NOT EXISTS products_workspace_category_idx
  ON public.products (workspace_id, category_id);

-- Partial-Index auf Demo-Rows: hält Bulk-Delete des Wipe-Buttons schnell
-- (Pattern: 20260511000000_demo_data_columns.sql).
CREATE INDEX IF NOT EXISTS products_demo_idx
  ON public.products(workspace_id) WHERE is_demo;

-- Partial-UNIQUE: Artikelnummer (case-insensitiv) eindeutig pro Workspace,
-- nur für gesetzte SKU und nicht soft-gelöschte Rows.
CREATE UNIQUE INDEX IF NOT EXISTS products_workspace_sku_uidx
  ON public.products (workspace_id, lower(sku))
  WHERE sku IS NOT NULL AND deleted_at IS NULL;

-- ── FK-Cross-Workspace-Trigger für category_id + default_supplier_id ────────
-- Ein reiner FK erlaubt Cross-Workspace-Referenzen. Dieser Trigger erzwingt
-- DB-seitig, dass die referenzierte Kategorie bzw. der Lieferant im SELBEN
-- Workspace liegt — greift auch beim Service-Role-Pfad (Demo-Seed,
-- Migrationen). Ein Trigger deckt beide FK-Spalten ab.
CREATE OR REPLACE FUNCTION public.assert_product_fks_same_workspace()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.category_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.product_categories r
    WHERE r.id = NEW.category_id
      AND r.workspace_id = NEW.workspace_id
  ) THEN
    RAISE EXCEPTION 'cross-workspace reference rejected for category_id';
  END IF;

  IF NEW.default_supplier_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.suppliers r
    WHERE r.id = NEW.default_supplier_id
      AND r.workspace_id = NEW.workspace_id
  ) THEN
    RAISE EXCEPTION 'cross-workspace reference rejected for default_supplier_id';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS products_fks_ws_check ON public.products;
CREATE TRIGGER products_fks_ws_check
  BEFORE INSERT OR UPDATE OF category_id, default_supplier_id
  ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.assert_product_fks_same_workspace();

-- ─── DOWN-Migration (kommentiert, Repo-Konvention wie B1 / 20260509000300) ───
-- Reine CREATE-TABLE-Migration → vollständig reversibel.
-- Zum Zurückrollen den folgenden Block ausführen:
--
-- BEGIN;
--   DROP TRIGGER IF EXISTS products_fks_ws_check ON public.products;
--   DROP TRIGGER IF EXISTS trg_touch_products    ON public.products;
--   DROP FUNCTION IF EXISTS public.assert_product_fks_same_workspace();
--   DROP TABLE IF EXISTS public.products;
-- COMMIT;
