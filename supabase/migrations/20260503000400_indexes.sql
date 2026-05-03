-- ─── Performance-Indexe ───────────────────────────────────────────────────
--
-- Ergänzt häufige Filter-/Sortier-Pfade. Die initial-schema-Migration legt
-- bereits user_id-Indexe an; hier kommen kombinierte Indexe für typische
-- Queries dazu.

CREATE INDEX IF NOT EXISTS deals_user_status_idx
  ON public.deals(user_id, status);

CREATE INDEX IF NOT EXISTS deals_user_buyer_idx
  ON public.deals(user_id, buyer);

CREATE INDEX IF NOT EXISTS deals_user_ticket_idx
  ON public.deals(user_id, ticket_number) WHERE ticket_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS inventory_items_user_qty_idx
  ON public.inventory_items(user_id, quantity);

CREATE INDEX IF NOT EXISTS inventory_movements_item_date_idx
  ON public.inventory_movements(item_id, date DESC);
