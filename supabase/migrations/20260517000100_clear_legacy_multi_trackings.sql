-- Plan-Ref: plans/2026-05-16_dhl_api_only_tracking_detection.md §D4b
--
-- One-shot Cleanup nach dem Refactor "Tracking-Detection ausschließlich
-- via DHL-API". Vor dem Refactor hat die alte Pattern-Heuristik in
-- `inbox_adapters.ts` pro Mail mehrere Multi-Tracking-Kandidaten
-- (Bestellnr, Kundennr, echte Tracking-Nr) als "strong" persistiert.
-- Die UI in `lib/screens/inbox_screen.dart:1114-1126` rendert pro
-- Tracking eine Pill — Resultat: bis zu 4+ Pills pro Suggestion,
-- obwohl maximal eine echt ist.
--
-- Nach dem Refactor schreibt die Pipeline pro Mail höchstens 1 Tracking
-- in `trackings[]` (DHL-API-validiert) oder gar keines. Damit der User
-- nicht in einem hybriden Zustand auf alte Multi-Pill-Suggestions
-- starrt, setzen wir diese hier hart zurück:
--   * trackings              → leeres Array
--   * tracking               → NULL
--   * tracking_confidence    → 'none'
--   * tracking_needs_review  → true   (User-Hinweis: bitte Re-Parse)
--
-- Anschließend triggert der User in Settings → "Sendungsnummern neu
-- prüfen" (existierender Re-Parse-Pfad, siehe
-- `triggerReparseTracking` in lib/services/supabase_repository.dart),
-- und die neue DHL-API-Pipeline schreibt saubere Single-Pill-Resultate.
--
-- SCOPE-WAHL:
--   * Nur pending Suggestions (resolved_at IS NULL) — bereits
--     akzeptierte/abgelehnte Suggestions bleiben unangetastet
--     (Audit-Spur). Im Schema heißt das Feld `resolved_at` (siehe
--     20260507000000_inbox.sql:141), Plan-Text §D4b nennt
--     `user_accepted_at` — das ist Plan-Drift, Schema gewinnt.
--   * Nur Rows mit echtem Multi-Array (array_length > 1). Single-
--     Tracking-Suggestions bleiben, da sie eh nur 1 Pill rendern.
--
-- IDEMPOTENZ:
--   `trackings` ist TEXT[] (siehe 20260507400000_inbox_trackings_array.sql:10).
--   Nach diesem UPDATE haben alle gematchten Rows trackings='{}' (länge 0)
--   → array_length('{}', 1) ist NULL, nicht > 1 → zweiter Run matcht
--   nichts mehr. Migration ist gefahrlos mehrfach ausführbar.
--
-- SCHEMA-VORBEDINGUNG:
--   `pending_deal_suggestions.tracking_needs_review` existiert bisher
--   nicht — siehe 20260513183000_strict_tracking_schema.sql, das die
--   Spalte nur an `deals` + `parsed_messages` setzt. Damit dieses
--   UPDATE läuft und damit die UI/Pipeline künftig auch auf
--   Suggestion-Level einen Review-Flag hat, fügen wir die Spalte hier
--   idempotent hinzu (NOT NULL DEFAULT FALSE, analog zu deals).

ALTER TABLE public.pending_deal_suggestions
  ADD COLUMN IF NOT EXISTS tracking_needs_review BOOLEAN
    NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.pending_deal_suggestions.tracking_needs_review IS
  'Plan 2026-05-16 §D4b: true, wenn die alte Pattern-Heuristik Multi-Tracking-Pollution gespeichert hatte und die neue DHL-API-Pipeline noch nicht drüber lief. UI zeigt Hinweis "Re-Parse auslösen".';

UPDATE public.pending_deal_suggestions
   SET trackings             = ARRAY[]::TEXT[],
       tracking              = NULL,
       tracking_confidence   = 'none',
       tracking_needs_review = TRUE
 WHERE resolved_at IS NULL
   AND trackings IS NOT NULL
   AND array_length(trackings, 1) > 1;
