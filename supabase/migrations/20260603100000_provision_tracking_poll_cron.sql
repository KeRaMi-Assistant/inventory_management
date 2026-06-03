-- Provisioning für den Tracking-Poll (Plan 2026-06-03 §7 Schritt B+C).
--
-- Idempotent + db-reset-safe + ENV-PORTABEL: extrahiert CRON_SECRET und die
-- Base-Function-URL SERVER-SEITIG aus bestehenden pg_cron-Jobs
-- (send-notifications-daily / inbox-poll-5min), sodass KEIN Secret und keine
-- projekt-spezifische URL als Literal im Git landen.
--
-- Erledigt, was sonst manuell in der SQL-Console liefe:
--   * vault.create_secret('edge_cron_secret', <CRON_SECRET>)   (für den
--     Event-Trigger deals_enqueue_tracking_poll + _edge_config('cron_secret'))
--   * private.edge_config('tracking_poll_url', <base>/tracking-poll)
--   * cron.schedule('tracking-poll-daily', '0 11,12 * * *', …)  → 13:00 Europe/
--     Berlin via In-Function-Hour-Guard (mode=daily-sweep, target 13).
--
-- Auf einem frischen lokalen `db reset` existieren die Quell-Cron-Jobs nicht →
-- der Block überspringt sauber per NOTICE (kein Fehler, db reset bleibt grün).
-- Privileg: läuft als Migrations-Rolle (db push), die — wie
-- 20260516000000_carrier_master_key_bootstrap.sql — vault.create_secret darf.

DO $$
DECLARE
  s    text;   -- CRON_SECRET (64-hex)
  base text;   -- https://<ref>.functions.supabase.co
  v_url text;
  cmd  text;
BEGIN
  -- 1) CRON_SECRET aus einem verify_jwt=false-Cron-Job (send-notifications).
  BEGIN
    SELECT (regexp_match(command, 'Bearer ([a-f0-9]{64})'))[1]
      INTO s
      FROM cron.job
     WHERE jobname = 'send-notifications-daily'
     LIMIT 1;
  EXCEPTION WHEN OTHERS THEN s := NULL;
  END;

  -- 2) Base-Function-URL aus irgendeinem Edge-Fn-Cron-Job (projekt-portabel).
  BEGIN
    SELECT (regexp_match(command, '(https://[a-z0-9]+\.functions\.supabase\.co)/'))[1]
      INTO base
      FROM cron.job
     WHERE command ~ 'functions\.supabase\.co'
     LIMIT 1;
  EXCEPTION WHEN OTHERS THEN base := NULL;
  END;

  IF s IS NULL OR base IS NULL THEN
    RAISE NOTICE 'tracking-poll provisioning übersprungen (keine Quell-Cron-Jobs gefunden — manuell setzen lt. SETUP §7).';
    RETURN;
  END IF;

  v_url := base || '/tracking-poll';

  -- 3) Vault-Secret (create oder update).
  IF EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'edge_cron_secret') THEN
    PERFORM vault.update_secret(
      (SELECT id FROM vault.secrets WHERE name = 'edge_cron_secret'), s);
  ELSE
    PERFORM vault.create_secret(
      s, 'edge_cron_secret',
      'tracking-poll Event-Trigger + Daily-Cron (Plan 2026-06-03)');
  END IF;

  -- 4) edge_config-URL-Row (nicht-sensibel, table-Fallback erlaubt).
  INSERT INTO private.edge_config(key, value)
  VALUES ('tracking_poll_url', v_url)
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();

  -- 5) Daily-Cron 13:00 Europe/Berlin: feuert 11:00 + 12:00 UTC, die Function
  --    self-gated via berlinHourNow()==13 (DST-sicher → genau 1 Sweep/Tag).
  BEGIN PERFORM cron.unschedule('tracking-poll-4h');   EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN PERFORM cron.unschedule('tracking-poll-daily'); EXCEPTION WHEN OTHERS THEN NULL; END;

  cmd := format(
    $f$SELECT net.http_post(
        url := %L,
        headers := jsonb_build_object('Authorization', 'Bearer %s', 'Content-Type', 'application/json'),
        body := jsonb_build_object('mode','daily-sweep','target_berlin_hours', jsonb_build_array(13)),
        timeout_milliseconds := 110000);$f$,
    v_url, s);

  PERFORM cron.schedule('tracking-poll-daily', '0 11,12 * * *', cmd);

  RAISE NOTICE 'tracking-poll provisioniert: vault edge_cron_secret gesetzt, edge_config URL + tracking-poll-daily Cron (0 11,12 * * *).';
END $$;
