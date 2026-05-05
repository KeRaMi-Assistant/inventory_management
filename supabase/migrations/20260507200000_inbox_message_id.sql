-- Sprint 6 Follow-up: Mail-Header für Deep-Links + Status pro Suggestion.
--
-- 1. `message_id` (RFC822 Message-ID) auf parsed_messages und
--    pending_deal_suggestions, damit das UI z. B. einen Gmail-Suchlink
--    `rfc822msgid:...` bauen kann ("Mail in Gmail öffnen").
-- 2. `status` auf pending_deal_suggestions: erkannter Versand-Status
--    (ordered/shipped/delivered/cancelled/refunded), damit das UI die
--    Card direkt mit "Unterwegs" / "Angekommen" badgen kann ohne extra-
--    Parse beim Anzeigen.

ALTER TABLE public.parsed_messages
  ADD COLUMN IF NOT EXISTS message_id TEXT;

ALTER TABLE public.pending_deal_suggestions
  ADD COLUMN IF NOT EXISTS message_id TEXT;

ALTER TABLE public.pending_deal_suggestions
  ADD COLUMN IF NOT EXISTS status TEXT
  CHECK (status IS NULL OR status IN
    ('ordered','shipped','delivered','cancelled','refunded'));

CREATE INDEX IF NOT EXISTS parsed_messages_message_id_idx
  ON public.parsed_messages(message_id) WHERE message_id IS NOT NULL;
