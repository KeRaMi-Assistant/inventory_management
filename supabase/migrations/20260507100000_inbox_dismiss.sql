-- Sprint 6 Follow-up: parsed_messages um 'dismissed'-Status erweitern.
--
-- Erlaubt dem User, Mails aktiv zu verwerfen ("Spam", "interessiert mich
-- nicht"). Solche Zeilen bleiben in der DB (für Audit + Dedup), erscheinen
-- aber nicht mehr im Inbox-UI.

ALTER TABLE public.parsed_messages
  DROP CONSTRAINT IF EXISTS parsed_messages_status_check;

ALTER TABLE public.parsed_messages
  ADD CONSTRAINT parsed_messages_status_check
  CHECK (status IN (
    'pending',
    'matched',
    'suggested',
    'unclassified',
    'failed',
    'dismissed'
  ));
