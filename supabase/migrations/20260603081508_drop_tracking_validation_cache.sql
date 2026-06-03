-- T6 (Plan 2026-06-03_tracking_algorithmic_rebuild.md §4 / §5b, Critique C2-#6):
-- public.tracking_validation_cache droppen.
--
-- Warum: Die Tabelle war der Persistenz-Layer für enrichWithDhlValidation
-- (Live-DHL-API-Probe als DETECTION-Gate). T3 hat diese Verflechtung
-- entfernt — Detection ist jetzt rein algorithmisch (tracking_detection.ts:
-- Pattern + Checksum + Anchor + Reject), ohne API-Call. Damit hat der
-- Cache keine Leser/Schreiber mehr → toter Code.
--
-- Vorgänger-Migrationen (20260517000000 anlegend, 20260523210530 +
-- 20260523223802 Cache-Resets) laufen beim db reset NACH wie vor zuerst
-- (frühere Timestamps), arbeiten gegen die noch existierende Tabelle und
-- bleiben damit gültig — dieser DROP läuft mit späterem Timestamp danach.
--
-- Pre-Launch safe (keine echten Nutzer); IF EXISTS für Idempotenz.
-- CASCADE nicht nötig: an der Tabelle hängen nur ein Index + Comments,
-- keine FKs/Views.

DROP TABLE IF EXISTS public.tracking_validation_cache;
