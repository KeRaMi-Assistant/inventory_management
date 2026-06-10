-- Paket 1.5 (plans/2026-06-10_state_of_the_art_tracking_roadmap.md):
-- Adaptive Poll-Frequenz — Cron von 1×/Tag (13:00 Berlin) auf stündlich.
--
-- Die Frequenz-Logik liegt IN der Edge-Function (mode='adaptive-sweep'):
--   * out_for_delivery  → jede Stunde
--   * in_transit        → alle ~4 h
--   * pending/exception → 2×/Tag
--   * delivered/expired → nie
--   * Quiet-Hours: Berlin 22–05 Uhr wird serverseitig geskippt
--   * Tages-Quota-Guard: daily_call_count ≤ 900 pro Workspace×Carrier
--
-- ENV-PORTABEL wie 20260603100000_provision_tracking_poll_cron.sql: Secret +
-- URL werden aus dem bestehenden tracking-poll-daily-Job (Fallback: beliebiger
-- Edge-Fn-Job) extrahiert — kein Secret-Literal im Git. Auf frischem lokalen
-- `db reset` existieren keine Quell-Jobs → NOTICE + Skip, Reset bleibt grün.

DO $$
DECLARE
  s     text;   -- CRON_SECRET (64-hex)
  v_url text;   -- https://<ref>.functions.supabase.co/tracking-poll
  base  text;
  cmd   text;
BEGIN
  -- 1) Secret + URL bevorzugt aus dem bisherigen tracking-poll-daily-Job.
  BEGIN
    SELECT (regexp_match(command, 'Bearer ([a-f0-9]{64})'))[1],
           (regexp_match(command, '(https://[a-z0-9]+\.functions\.supabase\.co/tracking-poll)'))[1]
      INTO s, v_url
      FROM cron.job
     WHERE jobname = 'tracking-poll-daily'
     LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    s := NULL; v_url := NULL;
  END;

  -- 2) Fallback: aus irgendeinem Edge-Fn-Cron-Job extrahieren (wie #113).
  IF s IS NULL OR v_url IS NULL THEN
    BEGIN
      SELECT (regexp_match(command, 'Bearer ([a-f0-9]{64})'))[1]
        INTO s
        FROM cron.job
       WHERE jobname = 'send-notifications-daily'
       LIMIT 1;
      SELECT (regexp_match(command, '(https://[a-z0-9]+\.functions\.supabase\.co)/'))[1]
        INTO base
        FROM cron.job
       WHERE command ~ 'functions\.supabase\.co'
       LIMIT 1;
      IF base IS NOT NULL THEN
        v_url := base || '/tracking-poll';
      END IF;
    EXCEPTION WHEN OTHERS THEN
      s := NULL; v_url := NULL;
    END;
  END IF;

  IF s IS NULL OR v_url IS NULL THEN
    RAISE NOTICE 'tracking-poll adaptive-cron übersprungen (keine Quell-Cron-Jobs — lokaler Stack oder manuelles Setup nötig).';
    RETURN;
  END IF;

  -- 3) Alten Daily-Job ablösen, stündlichen adaptive-sweep schedulen.
  --    Minute 7 statt 0: entzerrt von anderen Voll-Stunden-Jobs.
  BEGIN PERFORM cron.unschedule('tracking-poll-daily');    EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN PERFORM cron.unschedule('tracking-poll-adaptive'); EXCEPTION WHEN OTHERS THEN NULL; END;

  cmd := format(
    $f$SELECT net.http_post(
        url := %L,
        headers := jsonb_build_object('Authorization', 'Bearer %s', 'Content-Type', 'application/json'),
        body := jsonb_build_object('mode','adaptive-sweep'),
        timeout_milliseconds := 110000);$f$,
    v_url, s);

  PERFORM cron.schedule('tracking-poll-adaptive', '7 * * * *', cmd);

  RAISE NOTICE 'tracking-poll-adaptive provisioniert (stündlich, In-Function-Gating + Quiet-Hours + Quota-Guard).';
END $$;
