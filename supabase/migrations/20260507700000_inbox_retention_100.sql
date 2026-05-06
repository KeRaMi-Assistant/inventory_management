-- Sprint 6 Follow-up: Inbox-Retention an reduzierte Plan-Tage angepasst.
--
-- Pläne sind jetzt 0 / 7 / 14 / 30 / 90 Tage. Damit der Ultimate-Plan
-- 90 Tage zuverlässig laden kann, halten wir 100 Tage in der DB
-- (= max Plan + 10 Tage Puffer). Vorher 200 Tage war für 180 ausgelegt.

CREATE OR REPLACE FUNCTION public.cleanup_inbox_history()
RETURNS VOID LANGUAGE sql AS $$
  DELETE FROM public.parsed_messages
   WHERE created_at < NOW() - INTERVAL '100 days';

  DELETE FROM public.pending_deal_suggestions
   WHERE created_at < NOW() - INTERVAL '100 days'
     AND resolved_at IS NULL;
$$;
