-- T5/R6 (Plan 2026-06-03_tracking_algorithmic_rebuild.md §4 / §3.3 / R6):
-- pg_net-Response/Request-Reaper.
--
-- Warum (Security-Finding, Council-Fix): der Event-Trigger
-- (deals_enqueue_tracking_poll) ruft net.http_post mit
-- 'Authorization: Bearer <CRON_SECRET>' auf. pg_net protokolliert
-- Requests + Responses in net._http_request / net._http_response — die
-- Request-Zeile enthält den CRON_SECRET-Header IM KLARTEXT. Beide Tabellen
-- wachsen zudem unbegrenzt. Darum ein enger STÜNDLICHER Reaper ('7 * * * *'),
-- der Rows älter als 24h aus BEIDEN Tabellen löscht (Plan: idealerweise <1h; 24h
-- als konservativer Default, damit Smoke-Verifikation post-deploy noch die
-- letzte Response sehen kann).
--
-- Idempotenz: cron.unschedule + cron.schedule im DO-Block; EXCEPTION WHEN
-- OTHERS → NOTICE, falls pg_cron/pg_net auf dem lokalen Stack nicht
-- verfügbar sind (supabase db reset bleibt grün).

-- ─── Reaper-Funktion ─────────────────────────────────────────────────────
-- Löscht alte pg_net-Telemetrie aus BEIDEN Tabellen. In BEGIN/EXCEPTION
-- gewrappt, weil net._http_request/_http_response auf einem pg_net-losen
-- Stack nicht existieren → undefined_table; dann no-op statt Fehler.
CREATE OR REPLACE FUNCTION public.reap_net_http_telemetry()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, net, extensions
AS $$
BEGIN
  BEGIN
    DELETE FROM net._http_response WHERE created < now() - interval '24 hours';
  EXCEPTION WHEN undefined_table THEN
    RAISE NOTICE 'net._http_response nicht vorhanden (pg_net fehlt) — skip.';
  END;
  BEGIN
    DELETE FROM net._http_request WHERE created < now() - interval '24 hours';
  EXCEPTION WHEN undefined_table THEN
    RAISE NOTICE 'net._http_request nicht vorhanden (pg_net fehlt) — skip.';
  END;
END;
$$;

-- Kein Client-RPC-Aufruf: nur der pg_cron-Job (läuft als postgres/owner) ruft
-- die Funktion. PUBLIC + die expliziten Supabase-Default-Grants revoken.
REVOKE EXECUTE ON FUNCTION public.reap_net_http_telemetry() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.reap_net_http_telemetry() FROM anon, authenticated;

-- ─── Stündlicher pg_cron-Job ─────────────────────────────────────────────
-- Stündlich (statt täglich), damit der CRON_SECRET-Klartext-Header maximal
-- ~1-25h in net._http_request überlebt. Idempotent: erst unschedule, dann
-- neu schedulen.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'net_http_reaper_hourly') THEN
    PERFORM cron.unschedule('net_http_reaper_hourly');
  END IF;
  PERFORM cron.schedule(
    'net_http_reaper_hourly',
    '7 * * * *',
    $job$ SELECT public.reap_net_http_telemetry(); $job$
  );
EXCEPTION WHEN OTHERS THEN
  -- pg_cron nicht verfügbar (z.B. lokale Tests) → still NOTICE.
  RAISE NOTICE 'pg_cron nicht verfügbar, net_http_reaper_hourly nicht eingeplant: %', SQLERRM;
END
$$;
