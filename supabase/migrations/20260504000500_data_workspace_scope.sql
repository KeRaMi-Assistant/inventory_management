-- ─── Daten-Tabellen auf workspace_id umstellen ───────────────────────────
--
-- Bisher waren alle Daten per `user_id` gescoped. Damit ein Team gemeinsam
-- auf denselben Datenbestand zugreifen kann, hängen wir ab jetzt jede Zeile
-- an eine `workspace_id` und prüfen Mitgliedschaft via Helper-Funktionen
-- (`is_workspace_member`, `has_workspace_role`) aus der RLS-Fix-Migration.
--
-- Strategie:
--   1. workspace_id-Spalte (nullable) anlegen + FK auf workspaces(id).
--   2. Backfill: jede Zeile bekommt die ÄLTESTE Workspace-ID des eigenen
--      `user_id` (= Personal-Workspace, weil der per Trigger zuerst angelegt
--      wird). Spalten ohne user_id (movements, batches, comments) erben
--      über den Parent.
--   3. NOT NULL setzen + Index.
--   4. Alte `user_owns_*`-Policies droppen, neue Workspace-Policies
--      anlegen (read = jedes Mitglied; write = owner/admin/member).
--
-- `user_id` bleibt als "Erfasser-Spalte" erhalten (für Audit/Trail-Anzeige).
-- Wir prüfen sie nur nicht mehr in RLS.

-- ─── 1. Spalten anlegen ──────────────────────────────────────────────────
ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS workspace_id UUID
  REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE public.buyers
  ADD COLUMN IF NOT EXISTS workspace_id UUID
  REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE public.shops
  ADD COLUMN IF NOT EXISTS workspace_id UUID
  REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE public.suppliers
  ADD COLUMN IF NOT EXISTS workspace_id UUID
  REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS workspace_id UUID
  REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE public.inventory_movements
  ADD COLUMN IF NOT EXISTS workspace_id UUID
  REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE public.inventory_batches
  ADD COLUMN IF NOT EXISTS workspace_id UUID
  REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE public.activity_log
  ADD COLUMN IF NOT EXISTS workspace_id UUID
  REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE public.deal_comments
  ADD COLUMN IF NOT EXISTS workspace_id UUID
  REFERENCES public.workspaces(id) ON DELETE CASCADE;

-- ─── 2. Backfill ─────────────────────────────────────────────────────────
-- CTE liefert für jede user_id die ID des ältesten Workspaces, den sie
-- besitzt — das ist konstruktionsbedingt der Personal-Workspace.
WITH user_personal AS (
  SELECT owner_id AS user_id, id AS ws_id
  FROM (
    SELECT owner_id, id,
           ROW_NUMBER() OVER (PARTITION BY owner_id ORDER BY created_at ASC) AS rn
    FROM public.workspaces
    WHERE deleted_at IS NULL
  ) ranked
  WHERE rn = 1
)
UPDATE public.deals d
   SET workspace_id = up.ws_id
  FROM user_personal up
 WHERE d.user_id = up.user_id
   AND d.workspace_id IS NULL;

WITH user_personal AS (
  SELECT owner_id AS user_id, id AS ws_id
  FROM (
    SELECT owner_id, id,
           ROW_NUMBER() OVER (PARTITION BY owner_id ORDER BY created_at ASC) AS rn
    FROM public.workspaces
    WHERE deleted_at IS NULL
  ) ranked
  WHERE rn = 1
)
UPDATE public.buyers b
   SET workspace_id = up.ws_id
  FROM user_personal up
 WHERE b.user_id = up.user_id
   AND b.workspace_id IS NULL;

WITH user_personal AS (
  SELECT owner_id AS user_id, id AS ws_id
  FROM (
    SELECT owner_id, id,
           ROW_NUMBER() OVER (PARTITION BY owner_id ORDER BY created_at ASC) AS rn
    FROM public.workspaces
    WHERE deleted_at IS NULL
  ) ranked
  WHERE rn = 1
)
UPDATE public.shops s
   SET workspace_id = up.ws_id
  FROM user_personal up
 WHERE s.user_id = up.user_id
   AND s.workspace_id IS NULL;

WITH user_personal AS (
  SELECT owner_id AS user_id, id AS ws_id
  FROM (
    SELECT owner_id, id,
           ROW_NUMBER() OVER (PARTITION BY owner_id ORDER BY created_at ASC) AS rn
    FROM public.workspaces
    WHERE deleted_at IS NULL
  ) ranked
  WHERE rn = 1
)
UPDATE public.suppliers su
   SET workspace_id = up.ws_id
  FROM user_personal up
 WHERE su.user_id = up.user_id
   AND su.workspace_id IS NULL;

WITH user_personal AS (
  SELECT owner_id AS user_id, id AS ws_id
  FROM (
    SELECT owner_id, id,
           ROW_NUMBER() OVER (PARTITION BY owner_id ORDER BY created_at ASC) AS rn
    FROM public.workspaces
    WHERE deleted_at IS NULL
  ) ranked
  WHERE rn = 1
)
UPDATE public.inventory_items i
   SET workspace_id = up.ws_id
  FROM user_personal up
 WHERE i.user_id = up.user_id
   AND i.workspace_id IS NULL;

WITH user_personal AS (
  SELECT owner_id AS user_id, id AS ws_id
  FROM (
    SELECT owner_id, id,
           ROW_NUMBER() OVER (PARTITION BY owner_id ORDER BY created_at ASC) AS rn
    FROM public.workspaces
    WHERE deleted_at IS NULL
  ) ranked
  WHERE rn = 1
)
UPDATE public.inventory_movements m
   SET workspace_id = up.ws_id
  FROM user_personal up
 WHERE m.user_id = up.user_id
   AND m.workspace_id IS NULL;

WITH user_personal AS (
  SELECT owner_id AS user_id, id AS ws_id
  FROM (
    SELECT owner_id, id,
           ROW_NUMBER() OVER (PARTITION BY owner_id ORDER BY created_at ASC) AS rn
    FROM public.workspaces
    WHERE deleted_at IS NULL
  ) ranked
  WHERE rn = 1
)
UPDATE public.inventory_batches ba
   SET workspace_id = up.ws_id
  FROM user_personal up
 WHERE ba.user_id = up.user_id
   AND ba.workspace_id IS NULL;

WITH user_personal AS (
  SELECT owner_id AS user_id, id AS ws_id
  FROM (
    SELECT owner_id, id,
           ROW_NUMBER() OVER (PARTITION BY owner_id ORDER BY created_at ASC) AS rn
    FROM public.workspaces
    WHERE deleted_at IS NULL
  ) ranked
  WHERE rn = 1
)
UPDATE public.activity_log a
   SET workspace_id = up.ws_id
  FROM user_personal up
 WHERE a.user_id = up.user_id
   AND a.workspace_id IS NULL;

WITH user_personal AS (
  SELECT owner_id AS user_id, id AS ws_id
  FROM (
    SELECT owner_id, id,
           ROW_NUMBER() OVER (PARTITION BY owner_id ORDER BY created_at ASC) AS rn
    FROM public.workspaces
    WHERE deleted_at IS NULL
  ) ranked
  WHERE rn = 1
)
UPDATE public.deal_comments dc
   SET workspace_id = up.ws_id
  FROM user_personal up
 WHERE dc.user_id = up.user_id
   AND dc.workspace_id IS NULL;

-- ─── 3. NOT NULL + Indexe ────────────────────────────────────────────────
ALTER TABLE public.deals              ALTER COLUMN workspace_id SET NOT NULL;
ALTER TABLE public.buyers             ALTER COLUMN workspace_id SET NOT NULL;
ALTER TABLE public.shops              ALTER COLUMN workspace_id SET NOT NULL;
ALTER TABLE public.suppliers          ALTER COLUMN workspace_id SET NOT NULL;
ALTER TABLE public.inventory_items    ALTER COLUMN workspace_id SET NOT NULL;
ALTER TABLE public.inventory_movements ALTER COLUMN workspace_id SET NOT NULL;
ALTER TABLE public.inventory_batches  ALTER COLUMN workspace_id SET NOT NULL;
ALTER TABLE public.activity_log       ALTER COLUMN workspace_id SET NOT NULL;
ALTER TABLE public.deal_comments      ALTER COLUMN workspace_id SET NOT NULL;

CREATE INDEX IF NOT EXISTS deals_workspace_idx
  ON public.deals(workspace_id);
CREATE INDEX IF NOT EXISTS buyers_workspace_idx
  ON public.buyers(workspace_id);
CREATE INDEX IF NOT EXISTS shops_workspace_idx
  ON public.shops(workspace_id);
CREATE INDEX IF NOT EXISTS suppliers_workspace_idx
  ON public.suppliers(workspace_id);
CREATE INDEX IF NOT EXISTS inventory_items_workspace_idx
  ON public.inventory_items(workspace_id);
CREATE INDEX IF NOT EXISTS inventory_movements_workspace_idx
  ON public.inventory_movements(workspace_id);
CREATE INDEX IF NOT EXISTS inventory_batches_workspace_idx
  ON public.inventory_batches(workspace_id);
CREATE INDEX IF NOT EXISTS activity_log_workspace_date_idx
  ON public.activity_log(workspace_id, date DESC);
CREATE INDEX IF NOT EXISTS deal_comments_workspace_idx
  ON public.deal_comments(workspace_id);

-- ─── 4. RLS-Policies neu ─────────────────────────────────────────────────
-- Alte User-Scoped-Policies droppen
DROP POLICY IF EXISTS "user_owns_deals"          ON public.deals;
DROP POLICY IF EXISTS "user_owns_buyers"         ON public.buyers;
DROP POLICY IF EXISTS "user_owns_shops"          ON public.shops;
DROP POLICY IF EXISTS "user_owns_suppliers"      ON public.suppliers;
DROP POLICY IF EXISTS "user_owns_inventory"      ON public.inventory_items;
DROP POLICY IF EXISTS "user_owns_movements"     ON public.inventory_movements;
DROP POLICY IF EXISTS "user_owns_batches"       ON public.inventory_batches;
DROP POLICY IF EXISTS "user_owns_activity"      ON public.activity_log;
DROP POLICY IF EXISTS "user_owns_deal_comments" ON public.deal_comments;

-- Helper: Macro-artige Policy-Definition pro Tabelle.
-- read  = jedes Mitglied (auch viewer)
-- write = owner/admin/member (viewer ausgeschlossen)

-- ── deals ───────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS deals_ws_read   ON public.deals;
DROP POLICY IF EXISTS deals_ws_insert ON public.deals;
DROP POLICY IF EXISTS deals_ws_update ON public.deals;
DROP POLICY IF EXISTS deals_ws_delete ON public.deals;
CREATE POLICY deals_ws_read   ON public.deals FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY deals_ws_insert ON public.deals FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY deals_ws_update ON public.deals FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY deals_ws_delete ON public.deals FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));

-- ── buyers ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS buyers_ws_read   ON public.buyers;
DROP POLICY IF EXISTS buyers_ws_insert ON public.buyers;
DROP POLICY IF EXISTS buyers_ws_update ON public.buyers;
DROP POLICY IF EXISTS buyers_ws_delete ON public.buyers;
CREATE POLICY buyers_ws_read   ON public.buyers FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY buyers_ws_insert ON public.buyers FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY buyers_ws_update ON public.buyers FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY buyers_ws_delete ON public.buyers FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));

-- ── shops ───────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS shops_ws_read   ON public.shops;
DROP POLICY IF EXISTS shops_ws_insert ON public.shops;
DROP POLICY IF EXISTS shops_ws_update ON public.shops;
DROP POLICY IF EXISTS shops_ws_delete ON public.shops;
CREATE POLICY shops_ws_read   ON public.shops FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY shops_ws_insert ON public.shops FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY shops_ws_update ON public.shops FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY shops_ws_delete ON public.shops FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));

-- ── suppliers ───────────────────────────────────────────────────────────
DROP POLICY IF EXISTS suppliers_ws_read   ON public.suppliers;
DROP POLICY IF EXISTS suppliers_ws_insert ON public.suppliers;
DROP POLICY IF EXISTS suppliers_ws_update ON public.suppliers;
DROP POLICY IF EXISTS suppliers_ws_delete ON public.suppliers;
CREATE POLICY suppliers_ws_read   ON public.suppliers FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY suppliers_ws_insert ON public.suppliers FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY suppliers_ws_update ON public.suppliers FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY suppliers_ws_delete ON public.suppliers FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));

-- ── inventory_items ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS inventory_items_ws_read   ON public.inventory_items;
DROP POLICY IF EXISTS inventory_items_ws_insert ON public.inventory_items;
DROP POLICY IF EXISTS inventory_items_ws_update ON public.inventory_items;
DROP POLICY IF EXISTS inventory_items_ws_delete ON public.inventory_items;
CREATE POLICY inventory_items_ws_read   ON public.inventory_items FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY inventory_items_ws_insert ON public.inventory_items FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY inventory_items_ws_update ON public.inventory_items FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY inventory_items_ws_delete ON public.inventory_items FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));

-- ── inventory_movements ─────────────────────────────────────────────────
DROP POLICY IF EXISTS inventory_movements_ws_read   ON public.inventory_movements;
DROP POLICY IF EXISTS inventory_movements_ws_insert ON public.inventory_movements;
CREATE POLICY inventory_movements_ws_read   ON public.inventory_movements FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY inventory_movements_ws_insert ON public.inventory_movements FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));

-- ── inventory_batches ───────────────────────────────────────────────────
DROP POLICY IF EXISTS inventory_batches_ws_read   ON public.inventory_batches;
DROP POLICY IF EXISTS inventory_batches_ws_insert ON public.inventory_batches;
DROP POLICY IF EXISTS inventory_batches_ws_update ON public.inventory_batches;
DROP POLICY IF EXISTS inventory_batches_ws_delete ON public.inventory_batches;
CREATE POLICY inventory_batches_ws_read   ON public.inventory_batches FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY inventory_batches_ws_insert ON public.inventory_batches FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY inventory_batches_ws_update ON public.inventory_batches FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY inventory_batches_ws_delete ON public.inventory_batches FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));

-- ── activity_log ────────────────────────────────────────────────────────
DROP POLICY IF EXISTS activity_log_ws_read   ON public.activity_log;
DROP POLICY IF EXISTS activity_log_ws_insert ON public.activity_log;
DROP POLICY IF EXISTS activity_log_ws_delete ON public.activity_log;
CREATE POLICY activity_log_ws_read   ON public.activity_log FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY activity_log_ws_insert ON public.activity_log FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY activity_log_ws_delete ON public.activity_log FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));

-- ── deal_comments ───────────────────────────────────────────────────────
DROP POLICY IF EXISTS deal_comments_ws_read   ON public.deal_comments;
DROP POLICY IF EXISTS deal_comments_ws_insert ON public.deal_comments;
DROP POLICY IF EXISTS deal_comments_ws_update ON public.deal_comments;
DROP POLICY IF EXISTS deal_comments_ws_delete ON public.deal_comments;
CREATE POLICY deal_comments_ws_read   ON public.deal_comments FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY deal_comments_ws_insert ON public.deal_comments FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY deal_comments_ws_update ON public.deal_comments FOR UPDATE
  USING (
    user_id = auth.uid()
    AND public.has_workspace_role(workspace_id, auth.uid(),
        ARRAY['owner','admin','member'])
  )
  WITH CHECK (
    user_id = auth.uid()
    AND public.has_workspace_role(workspace_id, auth.uid(),
        ARRAY['owner','admin','member'])
  );
CREATE POLICY deal_comments_ws_delete ON public.deal_comments FOR DELETE
  USING (
    user_id = auth.uid()
    OR public.has_workspace_role(workspace_id, auth.uid(),
       ARRAY['owner','admin'])
  );
