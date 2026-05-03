-- Sprint 2 / G: Steuersatz & Währung pro Deal.
ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS tax_rate NUMERIC(5,4),
  ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'EUR';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'deals_tax_rate_range'
  ) THEN
    ALTER TABLE public.deals
      ADD CONSTRAINT deals_tax_rate_range
      CHECK (tax_rate IS NULL OR (tax_rate >= 0 AND tax_rate <= 1));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'deals_currency_iso'
  ) THEN
    ALTER TABLE public.deals
      ADD CONSTRAINT deals_currency_iso
      CHECK (char_length(currency) = 3);
  END IF;
END$$;
