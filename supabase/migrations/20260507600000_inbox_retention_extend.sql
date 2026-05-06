-- Sprint 6 Follow-up: DB-Retention an die neue Plan-Struktur anpassen.
--
-- Das Sichtbarkeitsfenster der Inbox skaliert ab jetzt mit dem Plan-Tier
-- (Ultimate: 180 Tage). Wenn der Cleanup-Cron weiterhin nach 30 Tagen
-- löscht, ist nach 30 Tagen schlicht keine Mail mehr in der DB —
-- höhere Pläne hätten dann nichts zu zeigen, auch wenn die Client-
-- seitige Sichtbarkeit das Fenster zulässt.
--
-- Wir setzen die Retention auf 200 Tage (= max Plan + 20 Tage Puffer
-- für Wechsel/Backups). pgcron-Schedule bleibt täglich um 03:15.

CREATE OR REPLACE FUNCTION public.cleanup_inbox_history()
RETURNS VOID LANGUAGE sql AS $$
  DELETE FROM public.parsed_messages
   WHERE created_at < NOW() - INTERVAL '200 days';

  DELETE FROM public.pending_deal_suggestions
   WHERE created_at < NOW() - INTERVAL '200 days'
     AND resolved_at IS NULL;
$$;
