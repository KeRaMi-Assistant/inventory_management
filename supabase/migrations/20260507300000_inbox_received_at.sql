-- Sprint 6 Follow-up: Mail-Empfangszeit auf Suggestions zugänglich machen.
--
-- `pending_deal_suggestions.created_at` zeigt, wann WIR die Suggestion
-- inserted haben. Das UI braucht aber das Mail-Datum (Empfangszeitpunkt
-- aus dem IMAP-Envelope) — sonst sieht eine 5 Tage alte Mail aus, als
-- wäre sie heute reingekommen, sobald der Cron sie zum ersten Mal pollt.

ALTER TABLE public.pending_deal_suggestions
  ADD COLUMN IF NOT EXISTS received_at TIMESTAMPTZ;

-- Backfill: wo received_at fehlt, nehmen wir created_at als Annäherung.
UPDATE public.pending_deal_suggestions
   SET received_at = created_at
 WHERE received_at IS NULL;

CREATE INDEX IF NOT EXISTS pending_deal_suggestions_received_idx
  ON public.pending_deal_suggestions(received_at DESC)
  WHERE resolved_at IS NULL;
