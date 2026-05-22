-- ─── Epic D (Task D1): Mehrlager — Tabelle `warehouses` + FK-Nachzug ────────
--
-- Plan: plans/2026-05-20_warenverwaltung-feature-parity.md
--       Abschnitt "Epic D — Mehrlager + Alerts":
--         * "NEU: Tabelle warehouses".
--         * "RLS-Policy-Skizze" + "FK-Cross-Workspace-Trigger-Skizze".
--
-- Inhalt dieser Migration (rein additiv):
--   1. NEU: Tabelle public.warehouses (strukturierte Lagerorte) —
--      Standard-4-Policy-RLS, Touch-Trigger, Index (workspace_id),
--      partial-UNIQUE "nur ein Default-Lager pro Workspace".
--   2. inventory_items.warehouse_id: FK-Constraint NACHZIEHEN. Die Spalte
--      wurde in AF2 (20260522000927_inventory_product_link.sql) bewusst als
--      reine UUID-Spalte OHNE FK angelegt — die Tabelle warehouses existierte
--      damals noch nicht. Hier kommt der FK auf warehouses(id) ON DELETE
--      SET NULL, der Index (workspace_id, warehouse_id) und der in AF2
--      aufgeschobene FK-Cross-Workspace-Trigger.
--
-- RLS-Pattern strikt nach 20260504000500_data_workspace_scope.sql /
-- 20260522000609_products_catalog.sql (AF1) /
-- 20260522001308_product_stock_and_suppliers.sql (AF3): `workspace_id
-- NOT NULL` + FK, `user_id` als Erfasser-Spalte, Policies über
-- `is_workspace_member` (read) und `has_workspace_role(...,
-- ['owner','admin','member'])` (write). Audit-Spalten + Touch-Trigger
-- (`touch_row` pflegt updated_at/updated_by/version).
--
-- HINWEIS Default-Lager: Es gibt KEINEN DB-Trigger, der ein Default-Lager
-- "Hauptlager" anlegt — das macht die App beim ersten Workspace-Touch
-- (Plan: "App-seitig, nicht per DB-Trigger — vermeidet komplexe Migration").
-- Die DB stellt nur die partial-UNIQUE sicher: maximal EIN Default pro
-- Workspace.

-- ─── 1. Tabelle warehouses ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.warehouses (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  UUID NOT NULL
                  REFERENCES public.workspaces(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id),
  name          TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  address       TEXT,
  is_default    BOOLEAN NOT NULL DEFAULT FALSE,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by    UUID REFERENCES auth.users(id),
  version       INT NOT NULL DEFAULT 1,
  deleted_at    TIMESTAMPTZ
);

-- ── RLS: Default-Deny + 4 explizite Workspace-Policies ──────────────────────
ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS warehouses_ws_read   ON public.warehouses;
DROP POLICY IF EXISTS warehouses_ws_insert ON public.warehouses;
DROP POLICY IF EXISTS warehouses_ws_update ON public.warehouses;
DROP POLICY IF EXISTS warehouses_ws_delete ON public.warehouses;

CREATE POLICY warehouses_ws_read   ON public.warehouses FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY warehouses_ws_insert ON public.warehouses FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY warehouses_ws_update ON public.warehouses FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY warehouses_ws_delete ON public.warehouses FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));

-- ── Touch-Trigger (updated_at/updated_by/version) — Pattern wie AF1/AF3 ──────
DROP TRIGGER IF EXISTS trg_touch_warehouses ON public.warehouses;
CREATE TRIGGER trg_touch_warehouses
  BEFORE UPDATE ON public.warehouses
  FOR EACH ROW EXECUTE FUNCTION public.touch_row();

-- ── Indexe ──────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS warehouses_workspace_idx
  ON public.warehouses (workspace_id);

-- Partial-UNIQUE: nur EIN Default-Lager pro Workspace (Committee-Empfehlung 5)
-- — nur für is_default und nicht soft-gelöschte Rows.
CREATE UNIQUE INDEX IF NOT EXISTS warehouses_workspace_default_uidx
  ON public.warehouses (workspace_id)
  WHERE is_default AND deleted_at IS NULL;

COMMENT ON TABLE public.warehouses IS
  'Strukturierte Lagerorte pro Workspace (Epic D). Ein Default-Lager pro '
  'Workspace via partial-UNIQUE warehouses_workspace_default_uidx. '
  'inventory_items.location bleibt als Freitext-Lagerplatz INNERHALB '
  'eines Lagers erhalten.';

-- ─── 2. inventory_items.warehouse_id: FK + Index + Cross-Workspace-Trigger ───
-- Die Spalte warehouse_id existiert bereits aus AF2
-- (20260522000927_inventory_product_link.sql) als reine UUID-Spalte OHNE FK,
-- mit dem Kommentar "FK folgt in D1". Jetzt wird der FK nachgezogen.

-- FK auf warehouses(id) ON DELETE SET NULL — ein gelöschtes Lager blockiert
-- keine Bestands-Rows, die Bestands-Row verliert nur die Lager-Zuordnung.
ALTER TABLE public.inventory_items
  ADD CONSTRAINT inventory_items_warehouse_id_fkey
    FOREIGN KEY (warehouse_id) REFERENCES public.warehouses(id)
    ON DELETE SET NULL;

COMMENT ON COLUMN public.inventory_items.warehouse_id IS
  'Optionale Lager-Zuordnung (Epic D). FK auf warehouses(id) ON DELETE '
  'SET NULL — in D1 nachgezogen. Cross-Workspace-Schutz über '
  'inventory_items_warehouse_id_ws_check.';

-- Index für den Lager-Filter (Bestand pro Lager / product_stock-View-Achse).
CREATE INDEX IF NOT EXISTS inventory_items_workspace_warehouse_idx
  ON public.inventory_items (workspace_id, warehouse_id);

-- ── FK-Cross-Workspace-Trigger für inventory_items.warehouse_id ─────────────
-- In AF2 bewusst aufgeschoben ("kommt in D1"), da warehouses damals noch
-- nicht existierte. Ein reiner FK erlaubt Cross-Workspace-Referenzen; dieser
-- Trigger erzwingt DB-seitig, dass das referenzierte Lager im SELBEN
-- Workspace liegt — greift auch beim Service-Role-Pfad (Demo-Seed,
-- Migrationen). Stil exakt nach AF2/AF3: SECURITY DEFINER,
-- SET search_path = public, pg_temp, EXISTS-Check, sonst RAISE EXCEPTION.
--
-- BEWUSST eigener Trigger statt Erweiterung des bestehenden
-- inventory_items_product_id_ws_check (AF2): der product-Trigger feuert nur
-- BEFORE INSERT OR UPDATE OF product_id. Ein separater warehouse-Trigger
-- mit OF warehouse_id feuert ausschließlich bei warehouse_id-Änderungen.
-- Beide haben disjunkte UPDATE-OF-Spalten — kein doppeltes Feuern bei einem
-- reinen warehouse_id-Update, und ein reines product_id-Update triggert
-- nicht unnötig die warehouse-Prüfung.
CREATE OR REPLACE FUNCTION public.assert_inventory_item_warehouse_same_workspace()
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

DROP TRIGGER IF EXISTS inventory_items_warehouse_id_ws_check
  ON public.inventory_items;
CREATE TRIGGER inventory_items_warehouse_id_ws_check
  BEFORE INSERT OR UPDATE OF warehouse_id ON public.inventory_items
  FOR EACH ROW EXECUTE FUNCTION
    public.assert_inventory_item_warehouse_same_workspace();

-- ─── DOWN-Migration (kommentiert, Repo-Konvention wie AF1 / AF2 / AF3) ───────
-- Reine CREATE-TABLE-/ADD-CONSTRAINT-/Trigger-Migration → vollständig
-- reversibel. warehouses ist ungefüllt (kein Backfill); inventory_items
-- .warehouse_id bleibt nach dem Down als reine UUID-Spalte ohne FK erhalten
-- (Zustand nach AF2). Zum Zurückrollen den folgenden Block ausführen:
--
-- BEGIN;
--   -- 2) inventory_items.warehouse_id: Trigger, Funktion, Index, FK
--   DROP TRIGGER IF EXISTS inventory_items_warehouse_id_ws_check
--     ON public.inventory_items;
--   DROP FUNCTION IF EXISTS
--     public.assert_inventory_item_warehouse_same_workspace();
--   DROP INDEX IF EXISTS public.inventory_items_workspace_warehouse_idx;
--   ALTER TABLE public.inventory_items
--     DROP CONSTRAINT IF EXISTS inventory_items_warehouse_id_fkey;
--
--   -- 1) warehouses: Trigger, Indexe, Tabelle (Policies droppen mit der
--   --    Tabelle, die Funktion touch_row ist geteilt → bleibt erhalten)
--   DROP TRIGGER IF EXISTS trg_touch_warehouses ON public.warehouses;
--   DROP TABLE IF EXISTS public.warehouses;
-- COMMIT;
