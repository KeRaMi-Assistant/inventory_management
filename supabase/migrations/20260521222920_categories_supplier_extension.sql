-- ─── Epic B (Task B1): Kategorien + Lieferanten-Erweiterung ─────────────────
--
-- Plan: plans/2026-05-20_warenverwaltung-feature-parity.md
--       Abschnitt "Epic B — Kategorien + Lieferanten-Erweiterung".
--
-- Inhalt dieser Migration:
--   1. NEU: Tabelle `product_categories` (hierarchische Warengruppen) —
--      Standard-4-Policy-RLS, Touch-Trigger, Indexe, FK-Cross-Workspace-
--      Trigger für die self-referenzielle `parent_id`.
--   2. GEÄNDERT: `suppliers` bekommt 9 neue (nullable) Kreditoren-
--      Stammdaten-Spalten — kein Backfill nötig.
--
-- RLS-Pattern strikt nach 20260504000500_data_workspace_scope.sql:
-- `workspace_id NOT NULL` + FK, `user_id` als Erfasser-Spalte, Policies
-- über `is_workspace_member` (read) und `has_workspace_role(...,
-- ['owner','admin','member'])` (write). Audit-Spalten + Touch-Trigger
-- wie bei `suppliers` (`touch_row` pflegt updated_at/updated_by/version).

-- ─── 1. Tabelle product_categories ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.product_categories (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL
                 REFERENCES public.workspaces(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES auth.users(id),
  name         TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  parent_id    UUID REFERENCES public.product_categories(id) ON DELETE SET NULL,
  sort_order   INTEGER NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by   UUID REFERENCES auth.users(id),
  version      INT NOT NULL DEFAULT 1,
  deleted_at   TIMESTAMPTZ
);

-- ── RLS: Default-Deny + 4 explizite Workspace-Policies ──────────────────────
ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS product_categories_ws_read   ON public.product_categories;
DROP POLICY IF EXISTS product_categories_ws_insert ON public.product_categories;
DROP POLICY IF EXISTS product_categories_ws_update ON public.product_categories;
DROP POLICY IF EXISTS product_categories_ws_delete ON public.product_categories;

CREATE POLICY product_categories_ws_read   ON public.product_categories FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY product_categories_ws_insert ON public.product_categories FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY product_categories_ws_update ON public.product_categories FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY product_categories_ws_delete ON public.product_categories FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));

-- ── Touch-Trigger (updated_at/updated_by/version) — Pattern wie suppliers ────
DROP TRIGGER IF EXISTS trg_touch_product_categories ON public.product_categories;
CREATE TRIGGER trg_touch_product_categories
  BEFORE UPDATE ON public.product_categories
  FOR EACH ROW EXECUTE FUNCTION public.touch_row();

-- ── Indexe: workspace_id + häufig gefilterte Hierarchie-Spalte ──────────────
CREATE INDEX IF NOT EXISTS product_categories_workspace_idx
  ON public.product_categories (workspace_id);
CREATE INDEX IF NOT EXISTS product_categories_workspace_parent_idx
  ON public.product_categories (workspace_id, parent_id);

-- ── FK-Cross-Workspace-Trigger für parent_id (self-referenziell) ────────────
-- Ein reiner FK erlaubt Cross-Workspace-Referenzen. Dieser Trigger erzwingt
-- DB-seitig, dass die referenzierte Eltern-Kategorie im SELBEN Workspace
-- liegt — greift auch beim Service-Role-Pfad (Demo-Seed, Migrationen).
CREATE OR REPLACE FUNCTION public.assert_category_parent_same_workspace()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.parent_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.product_categories r
    WHERE r.id = NEW.parent_id
      AND r.workspace_id = NEW.workspace_id
  ) THEN
    RAISE EXCEPTION 'cross-workspace reference rejected for parent_id';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS product_categories_parent_id_ws_check
  ON public.product_categories;
CREATE TRIGGER product_categories_parent_id_ws_check
  BEFORE INSERT OR UPDATE OF parent_id ON public.product_categories
  FOR EACH ROW EXECUTE FUNCTION public.assert_category_parent_same_workspace();

-- ─── 2. suppliers — erweiterte Kreditoren-Stammdaten ────────────────────────
-- Alle Spalten nullable, kein Backfill (Pre-Launch, keine echten Daten).
ALTER TABLE public.suppliers
  ADD COLUMN IF NOT EXISTS address_street     TEXT,
  ADD COLUMN IF NOT EXISTS address_zip        TEXT,
  ADD COLUMN IF NOT EXISTS address_city       TEXT,
  ADD COLUMN IF NOT EXISTS address_country    TEXT DEFAULT 'DE',
  ADD COLUMN IF NOT EXISTS vat_id             TEXT,
  ADD COLUMN IF NOT EXISTS customer_number    TEXT,
  ADD COLUMN IF NOT EXISTS payment_terms_days INTEGER,
  ADD COLUMN IF NOT EXISTS lead_time_days     INTEGER,
  ADD COLUMN IF NOT EXISTS min_order_value    NUMERIC(12,2);

-- ─── DOWN-Migration (kommentiert, Repo-Konvention wie 20260509000300) ───────
-- Reine CREATE-TABLE-/ADD-COLUMN-Migration → vollständig reversibel.
-- Zum Zurückrollen den folgenden Block ausführen:
--
-- BEGIN;
--   -- 2. suppliers: neue Spalten entfernen
--   ALTER TABLE public.suppliers
--     DROP COLUMN IF EXISTS address_street,
--     DROP COLUMN IF EXISTS address_zip,
--     DROP COLUMN IF EXISTS address_city,
--     DROP COLUMN IF EXISTS address_country,
--     DROP COLUMN IF EXISTS vat_id,
--     DROP COLUMN IF EXISTS customer_number,
--     DROP COLUMN IF EXISTS payment_terms_days,
--     DROP COLUMN IF EXISTS lead_time_days,
--     DROP COLUMN IF EXISTS min_order_value;
--
--   -- 1. product_categories: Trigger, Funktion, Tabelle entfernen
--   DROP TRIGGER IF EXISTS product_categories_parent_id_ws_check
--     ON public.product_categories;
--   DROP TRIGGER IF EXISTS trg_touch_product_categories
--     ON public.product_categories;
--   DROP FUNCTION IF EXISTS public.assert_category_parent_same_workspace();
--   DROP TABLE IF EXISTS public.product_categories;
-- COMMIT;
