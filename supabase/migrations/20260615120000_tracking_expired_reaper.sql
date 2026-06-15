-- Tracking-Expired-Reaper (Backlog 02-tracking-poll-reaper-and-loop-tests):
-- `live_status='expired'` ist seit 20260515000000 im CHECK-Enum definiert,
-- wurde aber von KEINEM Code je geschrieben (toter Wert). `isDuePoll`
-- (tracking-poll) liest ihn nur: ein 'expired'-Deal wird im adaptiven Sweep
-- nicht mehr gepollt.
--
-- Problem (verschärft durch Multi-Parcel 20260612100000): ein dauerhaft
-- verlorenes Paket — insb. ein Sekundär-Paket, das die Aggregat-Completion
-- nie erreichen lässt — hält den Deal für immer in 'Unterwegs' und wird
-- endlos auf in_transit-Kadenz (~4h, 6×/Tag) gepollt. Nur durch das
-- Tages-Quota-Cap (900/Workspace×Carrier) gebremst.
--
-- Dieser Reaper ist der ERSTE Writer von 'expired'. Zwei Arme:
--   A) Genuinely lost (nie zugestellt): live_status → 'expired'. Der adaptive
--      Sweep überspringt den Deal danach (isDuePoll=false). Ein MANUELLER
--      Retrack im Deal-Detail pollt weiterhin (gewollt: User-Override).
--   B) Multi-Parcel-Patt (Primary zugestellt, aber nach 90 Tagen immer noch
--      'Unterwegs', weil ein Sekundär-Paket nie ankam): Deal als angekommen
--      schließen (status='Angekommen', arrival_date), das verlorene Sekundär
--      aufgeben — der User hat sein Hauptpaket längst erhalten.
--
-- Schwelle 90 Tage: EU-Versand dauert real 4-6 Wochen; 90 Tage deckt
-- Extremfälle (Zoll, Rücksendung) + Puffer. Amazon-Deals (carrier='amazon',
-- nie gepollt, live_status='pending' geseedet) werden in Arm A bewusst
-- AUSGENOMMEN — sie verbrauchen kein Poll-Quota und ihr Status kommt nur per
-- Mail.

-- ─── Reaper-Funktion ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.reap_expired_tracking()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Arm A: genuinely lost → 'expired' + Activity-Log.
  WITH expired AS (
    UPDATE public.deals
       SET live_status = 'expired',
           live_status_updated_at = now()
     WHERE status = 'Unterwegs'
       AND arrival_date IS NULL
       AND deleted_at IS NULL
       AND tracking IS NOT NULL
       AND live_status IS DISTINCT FROM 'expired'
       AND live_status IS DISTINCT FROM 'delivered'   -- delivered → Arm B
       AND (carrier IS NULL OR carrier <> 'amazon')   -- Amazon nie pollen/expiren
       AND COALESCE(shipped_at, order_date) < now() - interval '90 days'
       -- Stagnations-Guard: kein Status-WECHSEL seit ≥14 Tagen (ein echtes
       -- Paket bewegt sich; Zoll-Freigabe o.ä. schützt der 14-Tage-Puffer).
       AND (live_status_updated_at IS NULL
            OR live_status_updated_at < now() - interval '14 days')
    RETURNING id, workspace_id, user_id, product
  )
  INSERT INTO public.activity_log (workspace_id, user_id, type, message, date)
  SELECT workspace_id, user_id, 'tracking_expired',
         'Sendung "' || product || '" als veraltet markiert (keine '
         || 'Zustellung seit ≥90 Tagen) — automatischer Re-Track gestoppt.',
         now()
    FROM expired;

  -- Arm B: Multi-Parcel-Patt (Primary zugestellt, Deal hängt) → schließen.
  WITH completed AS (
    UPDATE public.deals
       SET status = 'Angekommen',
           arrival_date = COALESCE(live_status_updated_at, now())
     WHERE status = 'Unterwegs'
       AND arrival_date IS NULL
       AND deleted_at IS NULL
       AND live_status = 'delivered'
       AND COALESCE(shipped_at, order_date) < now() - interval '90 days'
    RETURNING id, workspace_id, user_id, product
  )
  INSERT INTO public.activity_log (workspace_id, user_id, type, message, date)
  SELECT workspace_id, user_id, 'tracking_delivered',
         'Sendung "' || product || '" abgeschlossen — Hauptpaket zugestellt, '
         || 'verbleibendes Paket nach ≥90 Tagen aufgegeben.',
         now()
    FROM completed;
END;
$$;

-- Kein Client-RPC: nur der pg_cron-Job (als postgres/owner) ruft die Funktion.
REVOKE EXECUTE ON FUNCTION public.reap_expired_tracking() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.reap_expired_tracking() FROM anon, authenticated;

-- ─── Täglicher pg_cron-Job ───────────────────────────────────────────────
-- Täglich 04:30 UTC (eigener Slot nach cleanup_inbox_history 03:15). Ein
-- 90-Tage-Reaper hat keine Eile → täglich reicht. Idempotent: erst
-- unschedule, dann neu schedulen.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'tracking_expired_reaper_daily') THEN
    PERFORM cron.unschedule('tracking_expired_reaper_daily');
  END IF;
  PERFORM cron.schedule(
    'tracking_expired_reaper_daily',
    '30 4 * * *',
    $job$ SELECT public.reap_expired_tracking(); $job$
  );
EXCEPTION WHEN OTHERS THEN
  -- pg_cron nicht verfügbar (z.B. lokaler Stack) → still NOTICE.
  RAISE NOTICE 'pg_cron nicht verfügbar, tracking_expired_reaper_daily nicht eingeplant: %', SQLERRM;
END
$$;
