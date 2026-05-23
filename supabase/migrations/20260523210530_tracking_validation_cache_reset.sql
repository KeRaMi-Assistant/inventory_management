-- Plan-Ref: Folge zu PR #103 (DHL-Adapter Migration auf Parcel-DE).
--
-- Hintergrund:
--   Nach dem Switch von "Shipment Tracking – Unified" auf
--   "Parcel DE Tracking (Post & Parcel Germany)" können
--   Tracking-Nummern, die unter der alten API als `invalid` (404)
--   gecached wurden, unter der neuen API durchaus gültig sein —
--   z.B. weil Unified manche DHL-Geschäftskunden-Pakete nicht kannte,
--   Parcel-DE aber schon. `invalid`-Cache hat eine TTL von 30 Tagen
--   (siehe 20260517000000_tracking_validation_cache.sql §TTL-LOGIK),
--   würde also Validierungs-Fails bis ~21. Juni 2026 weiter "invalid"
--   cachen — User-Frust und falsche "Tracking nicht erkannt"-Hinweise
--   in der UI.
--
-- Fix:
--   Einmaliger Cache-Cleanup: alle `invalid`- und `unknown`-Rows mit
--   `last_checked_at < 2026-05-22T00:00:00Z` löschen (Datum des
--   API-Switches). `valid`-Rows BLEIBEN — sie sind objektive
--   "Tracking-Nr existiert"-Fakten, die API-unabhängig sind.
--   Worst-Case-Konsequenz: nächster Inbox-Poll re-validiert ~1-2k
--   Trackings gegen die neue API. Bei 1 Call/5s SPIKE_ARREST = ~80 min,
--   bei 10M/day Quota völlig unproblematisch.
--
-- Idempotenz:
--   DELETE-Statement ist idempotent (zweiter Run löscht nichts mehr,
--   weil last_checked_at nach API-Switch in der Zukunft liegt).

DELETE FROM public.tracking_validation_cache
 WHERE result_state IN ('invalid', 'unknown')
   AND last_checked_at < '2026-05-22T00:00:00Z';

COMMENT ON TABLE public.tracking_validation_cache IS
  'DHL Tracking-API-Validation-Cache. Reset 2026-05-23 nach Switch '
  'auf Parcel-DE-API (PR #103) — alte invalid/unknown-Rows gelöscht.';
