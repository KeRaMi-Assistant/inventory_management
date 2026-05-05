-- Sprint 6 Follow-up: Mehrere Tracking-Nummern pro Suggestion.
--
-- Eine Bestellung kann in mehrere Pakete gesplittet werden, jedes mit
-- eigener Sendungsnummer (oder gar verschiedenen Carriern). Die alte
-- `tracking TEXT`-Spalte bleibt als "primary tracking" für Kompatibilität
-- (Repository-Methoden, Edge-Function-Update auf Deal-Tracking),
-- daneben kommt `trackings TEXT[]` mit der vollen, deduplizierten Liste.

ALTER TABLE public.pending_deal_suggestions
  ADD COLUMN IF NOT EXISTS trackings TEXT[];

-- Backfill: bestehende Single-Werte in Array hochziehen.
UPDATE public.pending_deal_suggestions
   SET trackings = ARRAY[tracking]
 WHERE tracking IS NOT NULL
   AND (trackings IS NULL OR cardinality(trackings) = 0);
