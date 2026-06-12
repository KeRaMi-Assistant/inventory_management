-- Mail-Retention-Staffel (Stakeholder-Direktive 2026-06-11):
-- Inbox-Verlauf pro Plan jetzt 0 / 0 / 0 / 14 / 30 / 30 Tage
-- (free/solo/soloPro ohne Postfach · team 14 · business+enterprise 30).
--
-- DB-Retention folgt der Regel "max Plan-Tage + 10 Puffer" (Muster aus
-- 20260507700000_inbox_retention_100.sql): max ist jetzt 30 → 40 Tage.
-- Spart Storage gegenüber den bisherigen 100 Tagen; der Repository-Query-
-- Cap (lib/services/supabase_repository.dart `_inboxVisibilityDays = 30`)
-- bleibt damit konsistent gedeckt.
--
-- Hinweis: Beim ersten Cleanup-Lauf nach dem Deploy werden Bestands-Mails
-- älter als 40 Tage gelöscht — gewollt (Pre-Launch, Stakeholder-Entscheid;
-- sichtbar waren ohnehin nur die letzten 30 Tage).

CREATE OR REPLACE FUNCTION public.cleanup_inbox_history()
RETURNS VOID LANGUAGE sql AS $$
  DELETE FROM public.parsed_messages
   WHERE created_at < NOW() - INTERVAL '40 days';

  DELETE FROM public.pending_deal_suggestions
   WHERE created_at < NOW() - INTERVAL '40 days'
     AND resolved_at IS NULL;
$$;
