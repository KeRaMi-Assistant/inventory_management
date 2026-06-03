-- Backfill carrier='dhl' für bestehende Deals mit DE-Prefix-Tracking
-- (DE + 10–14 Ziffern, Amazon-Logistics-DE / DHL-National).
--
-- Hintergrund (2026-06-03): Der ursprüngliche Carrier-Backfill
-- (20260603081509) kannte das DE-Prefix-Format noch nicht (es war im
-- Tracking-Rebuild versehentlich mit `dhl-de-prefix` gelöscht worden). Real
-- haben aber ~30 Deals dieses Format (`DE5455…`, 12 Zeichen) → carrier blieb
-- NULL → Poller-Fallback. Mit dem wiederhergestellten DE-Pattern wird das
-- Format jetzt erkannt; dieser Backfill setzt carrier für die Bestands-Deals.
--
-- Abgrenzung: DE+9 (USt-IdNr) und DE+20 (IBAN) sind durch die Längen-Range
-- 10–14 ausgeschlossen. Idempotent (nur WHERE carrier IS NULL).

UPDATE public.deals
SET carrier = 'dhl'
WHERE carrier IS NULL
  AND tracking ~ '^DE[0-9]{10,14}$';
