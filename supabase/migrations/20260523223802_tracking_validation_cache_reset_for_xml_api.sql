-- Plan-Ref: Folge zu PR #103/#106/#107 — DHL-Adapter auf Parcel-DE-XML-API
-- umgestellt (Public Query mit ?xml=<request/>).
--
-- Hintergrund:
--   PRs #103 + #106 + #107 nutzten das JSON-Probing-Format mit
--   `?trackingNumber=...`-Query. Das gab gegen die echte Parcel-DE-API
--   401/403 zurück (siehe Stakeholder-Screenshot: „Letzter Fehler:
--   DHL-API-Key nicht autorisiert"). Grund: die Parcel-DE-Tracking-API
--   erwartet stattdessen einen XML-Payload als `?xml=<request/>`-Query
--   (Public Query, kein Geschäftskunden-Login nötig).
--
--   Während dieser Übergangsphase wurden alle Probe-Calls als
--   `auth_error` (resultState='unknown', TTL 1h) gecached.
--   Damit nach dem Switch auf die XML-API nicht die nächste Stunde
--   gewartet werden muss, bis sich die unknown-Caches re-validieren,
--   räumen wir explizit auf.
--
-- Fix:
--   Alle Rows mit `result_state IN ('unknown', 'invalid')` und
--   `last_checked_at >= 2026-05-22T00:00:00Z` (Datum des ersten
--   API-Switch-PR #103) löschen. Damit erzwingen wir Re-Validation
--   gegen die neue XML-API beim nächsten tracking-poll-Tick.
--
--   `valid`-Rows bleiben — sie sind API-unabhängige Fakten („Tracking-
--   Nr existiert"), die durch den API-Wechsel nicht falsch werden.
--
-- Idempotenz:
--   DELETE ist idempotent (zweiter Run löscht nichts mehr, weil
--   `last_checked_at` nach Cache-Refresh älter als jetzt wird; vor
--   allem aber wechselt der State von 'unknown' auf 'valid'/'invalid').

DELETE FROM public.tracking_validation_cache
 WHERE result_state IN ('unknown', 'invalid')
   AND last_checked_at >= '2026-05-22T00:00:00Z';
