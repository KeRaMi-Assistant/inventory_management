-- Sprint 2 / D: EAN/GTIN für Lagerartikel.
ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS ean TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'inventory_items_ean_format'
  ) THEN
    ALTER TABLE public.inventory_items
      ADD CONSTRAINT inventory_items_ean_format
      CHECK (ean IS NULL OR ean ~ '^\d{8}$|^\d{12}$|^\d{13}$|^\d{14}$');
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS inventory_items_ean_idx
  ON public.inventory_items (user_id, ean)
  WHERE ean IS NOT NULL AND deleted_at IS NULL;
