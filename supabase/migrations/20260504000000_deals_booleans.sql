-- ─── Convert deals.shipping_type and deals.beleg from TEXT to BOOLEAN ─────
--
-- Sprint 4 cleanup:
--   * shipping_type ('Reship'|'Dropship') → is_dropship BOOLEAN
--   * beleg         ('Ja'|'Nein')         → has_receipt BOOLEAN
--
-- Code reads both column variants during the rollout (legacy fallback in
-- Deal.fromSupabase), so the migration is non-breaking even if the app is
-- still on an older build for a moment.

-- ── is_dropship ──────────────────────────────────────────────────────────
ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS is_dropship BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE public.deals
SET    is_dropship = (shipping_type = 'Dropship')
WHERE  shipping_type IS NOT NULL;

ALTER TABLE public.deals
  DROP CONSTRAINT IF EXISTS deals_shipping_type_check;

ALTER TABLE public.deals
  ALTER COLUMN shipping_type DROP NOT NULL;

-- Old column left in place for one release as a safety net.
-- Drop it in a follow-up migration once all clients are on the new build:
--   ALTER TABLE public.deals DROP COLUMN shipping_type;

-- ── has_receipt ──────────────────────────────────────────────────────────
ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS has_receipt BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE public.deals
SET    has_receipt = (beleg = 'Ja')
WHERE  beleg IS NOT NULL;

ALTER TABLE public.deals
  DROP CONSTRAINT IF EXISTS deals_beleg_check;

ALTER TABLE public.deals
  ALTER COLUMN beleg DROP NOT NULL;

-- Drop in follow-up migration:
--   ALTER TABLE public.deals DROP COLUMN beleg;
