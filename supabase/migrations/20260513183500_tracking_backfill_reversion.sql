-- T6 (Plan 2026-05-13_strict_tracking_extraction.md): Backfill-Reversion.
-- Markiert alle parsed_messages mit Amazon-orderingShipmentId-Werten als
-- tracking_needs_review (für Re-Parse). Reset tracking_confidence auf 'none'
-- wenn nur orderingShipmentId-Werte erkannt wurden.
--
-- Strategie: parsed_messages hat bisher keine tracking_confidence-Spalte.
-- Diese Migration:
--   1) fügt tracking_confidence + tracking_needs_review hinzu (idempotent),
--   2) markiert orderingShipmentId-only-Rows / pure-numerische Trackings als
--      review-bedürftig + setzt tracking_confidence='none'.
--
-- Hinweis: parsed_messages persistiert Tracking ausschließlich in
-- parsed_payload (JSONB). Wir lassen den JSONB-Inhalt unverändert (für
-- Forensik / Re-Parse-Input) und steuern die Re-Klassifizierung über die
-- neuen Spalten.

-- 1) Add columns to parsed_messages (idempotent)
ALTER TABLE public.parsed_messages
  ADD COLUMN IF NOT EXISTS tracking_confidence text
    CHECK (tracking_confidence IN ('strong', 'medium', 'weak', 'none'));

ALTER TABLE public.parsed_messages
  ADD COLUMN IF NOT EXISTS tracking_needs_review boolean
    NOT NULL DEFAULT false;

-- 2) Identify orderingShipmentId-only rows and reset.
-- A row is suspect when:
--   parsed_payload->>'tracking' IS NOT NULL/non-empty
--   AND (
--     the tracking value is pure-numeric 8-20 digits (typical shipment-id),
--     OR the carrier was tagged as 'amazon-shipment-id'
--   )
-- We only touch rows that have not been (re-)classified yet
-- (tracking_confidence IS NULL) and never override 'manual' (defensive,
-- even though parsed_messages does not have manual entries today).
UPDATE public.parsed_messages
SET tracking_needs_review = true,
    tracking_confidence = 'none'
WHERE (parsed_payload->>'tracking') IS NOT NULL
  AND (parsed_payload->>'tracking') <> ''
  AND (
    (parsed_payload->>'tracking') ~ '^\d{8,20}$'
    OR (parsed_payload->>'tracking_carrier') = 'amazon-shipment-id'
  )
  AND tracking_confidence IS NULL
  AND COALESCE(tracking_confidence, '') <> 'manual';

-- 3) Index for re-parse filter (workspace-scoped, partial)
CREATE INDEX IF NOT EXISTS parsed_messages_needs_tracking_review_idx
  ON public.parsed_messages (workspace_id, tracking_needs_review)
  WHERE tracking_needs_review = true;

-- 4) Comments
COMMENT ON COLUMN public.parsed_messages.tracking_confidence IS
  'T6/2026-05-13: confidence of last tracking extraction. Default null = not yet (re-)classified.';
COMMENT ON COLUMN public.parsed_messages.tracking_needs_review IS
  'T6/2026-05-13: true when prior extraction produced suspect tracking (e.g. orderingShipmentId-only).';
