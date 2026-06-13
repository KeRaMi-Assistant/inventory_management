-- Multi-Parcel-Support (Roadmap 2026-06-10 §2.6, Backlog 02-multi-parcel-deals):
-- Ein Deal kann mehrere Sendungsnummern tragen (gesplittete Bestellungen).
-- Bisher existierte `trackings TEXT[]` nur auf pending_deal_suggestions
-- (20260507400000) — beim Suggestion-Accept ging alles außer der ersten
-- Nummer verloren.
--
-- PRIMARY-KONZEPT: `deals.tracking` bleibt die führende Nummer — sie
-- bestimmt live_status/live_eta/Push/Retrack-Cooldown. `trackings[]`
-- enthält ALLE Nummern (inkl. Primary); Sekundär-Pakete liefern nur
-- Events in tracking_events (deren Dedup-Key trägt die Nummer bereits:
-- UNIQUE(deal_id, tracking, occurred_at, description), 20260610090000).

ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS trackings TEXT[];

-- Backfill: bestehende Single-Tracking-Deals bekommen ein 1-Element-Array.
-- Idempotent (Pattern 20260507400000): mehrfaches Anwenden ist sicher.
UPDATE public.deals
   SET trackings = ARRAY[tracking]
 WHERE tracking IS NOT NULL
   AND (trackings IS NULL OR cardinality(trackings) = 0);

-- GIN-Index für Array-Containment-Lookups: der dpd-push-Webhook und
-- findMatchingDeal (inbox_parse_runner) suchen Deals per
-- `trackings @> ARRAY[nummer]` — ohne Index wäre das ein Seq-Scan.
CREATE INDEX IF NOT EXISTS deals_trackings_gin
  ON public.deals USING gin (trackings);

COMMENT ON COLUMN public.deals.trackings IS
  '2026-06-12 Multi-Parcel: alle Sendungsnummern des Deals (inkl. Primary '
  'deals.tracking). Nur das Primary steuert live_status/Push/Cooldown; '
  'Sekundäre schreiben ausschließlich tracking_events (Timeline pro Nummer).';
