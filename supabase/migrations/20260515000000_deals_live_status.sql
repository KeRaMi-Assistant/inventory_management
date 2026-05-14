-- Live-Status-Spalten für deals (Klarna-style live tracking visibility).
-- Source: tracking-poll Edge-Function (pg_cron alle 4h).
-- Carrier-übergreifende Statuswerte aus _shared/tracking_adapters.ts TrackingDeliveryStatus.

ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS live_status text
    CHECK (live_status IN ('pending', 'in_transit', 'out_for_delivery', 'delivered', 'exception', 'expired'));

ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS live_status_last_event text;

ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS live_status_updated_at timestamptz;

-- Index für Filter "alle mit aktivem live_status"
CREATE INDEX IF NOT EXISTS deals_live_status_idx
  ON public.deals (workspace_id, live_status)
  WHERE live_status IS NOT NULL AND live_status != 'delivered';

-- Comment
COMMENT ON COLUMN public.deals.live_status IS
  '2026-05-15: Carrier-übergreifender Live-Status (vom tracking-poll geschrieben). NULL bei Deals ohne Tracking oder vor erstem Poll.';
COMMENT ON COLUMN public.deals.live_status_last_event IS
  '2026-05-15: Letzter bekannter Carrier-Event-Text ("Zugestellt", "In Zustellung").';
COMMENT ON COLUMN public.deals.live_status_updated_at IS
  '2026-05-15: Wann wurde live_status zuletzt aktualisiert (tracking-poll-Tick).';
