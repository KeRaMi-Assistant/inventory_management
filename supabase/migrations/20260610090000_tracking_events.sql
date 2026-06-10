-- Paket 1 (plans/2026-06-10_state_of_the_art_tracking_roadmap.md §Paket 1):
-- Klarna-Style Tracking-Event-Timeline + ETA + adaptive Poll-Infrastruktur.
--
--   1) tracking_events: vollständige Carrier-Event-Historie pro Deal.
--      Bisher wurde nur der LETZTE Event-Text in deals.live_status_last_event
--      persistiert — die Carrier-APIs (DHL Parcel-DE) liefern aber den
--      kompletten Event-Verlauf, der ab jetzt idempotent upserted wird.
--   2) deals.live_eta: geschätztes Zustellfenster (Carrier-API oder Mail-ETA).
--   3) deals.last_polled_at: wann zuletzt ERFOLGREICH gepollt wurde —
--      getrennt von live_status_updated_at (= letzter Status-WECHSEL).
--      Grundlage für die adaptive Poll-Frequenz (out_for_delivery stündlich,
--      in_transit alle 4h, pending 2×/Tag).
--   4) workspace_carrier_credentials: Tages-Quota-Zähler (DHL: 1.000
--      Queries/Tag hartes Limit, wir kappen bei 900 — Lesson PR #115).
--   5) notifications_sent.ref_kind um 'tracking_status' erweitern
--      (Status-Wechsel-Push aus tracking-poll, Dedup pro Deal+Status).

-- ── 1. tracking_events ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tracking_events (
  id           BIGSERIAL PRIMARY KEY,
  deal_id      BIGINT NOT NULL REFERENCES public.deals(id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  -- Tracking-Nummer, zu der die Events gehören. Teil des Dedup-Keys, damit
  -- ein Tracking-Wechsel am Deal (Korrektur) eine frische Timeline beginnt
  -- und Multi-Parcel-Deals (trackings[]) später getrennt darstellbar sind.
  tracking     TEXT NOT NULL,
  carrier      TEXT,
  occurred_at  TIMESTAMPTZ NOT NULL,
  -- Normalisierter Status zum Zeitpunkt des Events. NULL = Carrier-Code
  -- nicht zuordenbar ('unknown' wird nie persistiert).
  status       TEXT CHECK (status IN
                 ('pending','in_transit','out_for_delivery','delivered','exception')),
  raw_code     TEXT,
  -- NOT NULL DEFAULT '' statt nullable: description ist Teil des
  -- Dedup-UNIQUE-Keys, und UNIQUE behandelt NULLs als distinct → Duplikate.
  -- KONTRAKT: der einzige Writer (tracking-poll) kürzt description auf
  -- 500 Zeichen VOR dem Upsert — der UNIQUE-Key operiert damit effektiv
  -- auf dem gekürzten Wert. Andere Writer müssen dieselbe Kürzung anwenden.
  description  TEXT NOT NULL DEFAULT '',
  location     TEXT,
  source       TEXT NOT NULL DEFAULT 'poll' CHECK (source IN ('poll','mail','manual')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Dedup: tracking-poll upserted bei jedem Lauf den kompletten Event-Array
  -- (ON CONFLICT DO NOTHING) — ohne den Key würde die Tabelle pro Poll wachsen.
  CONSTRAINT tracking_events_dedup UNIQUE (deal_id, tracking, occurred_at, description)
);

CREATE INDEX IF NOT EXISTS tracking_events_deal_idx
  ON public.tracking_events (deal_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS tracking_events_ws_idx
  ON public.tracking_events (workspace_id);

ALTER TABLE public.tracking_events ENABLE ROW LEVEL SECURITY;

-- read: jedes Workspace-Mitglied (Muster: 20260504000500_data_workspace_scope).
-- Writes: KEINE Policies für authenticated → default-deny. Schreiben darf nur
-- die tracking-poll-Edge-Function (Service-Role, bypassed RLS).
DROP POLICY IF EXISTS tracking_events_ws_read ON public.tracking_events;
CREATE POLICY tracking_events_ws_read ON public.tracking_events FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));

COMMENT ON TABLE public.tracking_events IS
  '2026-06-10: Carrier-Event-Historie pro Deal (Klarna-Style-Timeline). '
  'Geschrieben ausschließlich vom tracking-poll (Service-Role); Clients lesen '
  'workspace-scoped via RLS.';

-- ── 2. deals: ETA + last_polled_at ───────────────────────────────────────
ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS live_eta timestamptz;
ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS last_polled_at timestamptz;

COMMENT ON COLUMN public.deals.live_eta IS
  '2026-06-10: Geschätztes Zustelldatum/-fenster-Start. Quelle: Carrier-API '
  '(tracking-poll) oder Versand-Mail (etaDate). NULL = keine Prognose bekannt.';
COMMENT ON COLUMN public.deals.last_polled_at IS
  '2026-06-10: Letzter ERFOLGREICHER Carrier-Poll (auch ohne Status-Wechsel). '
  'Getrennt von live_status_updated_at (= letzter Status-/Event-Wechsel). '
  'Steuert die adaptive Poll-Frequenz + den 30s-Retrack-Cooldown.';

-- ── 3. Tages-Quota-Zähler pro Workspace×Carrier ─────────────────────────
ALTER TABLE public.workspace_carrier_credentials
  ADD COLUMN IF NOT EXISTS daily_call_count integer NOT NULL DEFAULT 0;
ALTER TABLE public.workspace_carrier_credentials
  ADD COLUMN IF NOT EXISTS daily_call_date date;

COMMENT ON COLUMN public.workspace_carrier_credentials.daily_call_count IS
  '2026-06-10: Anzahl Carrier-API-Calls am daily_call_date (UTC). Harter '
  'Guard gegen Quota-Riss bei adaptivem Polling (DHL: 1.000/Tag → Cap 900).';

-- ── 3b. Atomarer Quota-Bump (Review-Finding: Lost-Update-Race) ───────────
-- Parallele tracking-poll-Läufe (stündlicher Sweep + Event-Trigger-Polls)
-- dürfen sich die Tageszähler nicht gegenseitig überschreiben. Ein
-- Read-Modify-Write im Edge-Function-Code wäre nicht atomar — dieser RPC
-- macht das Increment in EINEM Statement (row-level lock durch UPDATE).
-- Datums-Rollover: anderes Datum → Zähler startet bei _calls.
CREATE OR REPLACE FUNCTION public.bump_carrier_daily_calls(
  _workspace_id uuid,
  _carrier_id   text,
  _calls        integer,
  _today        date,
  _last_error   text DEFAULT NULL
)
RETURNS void
LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.workspace_carrier_credentials
     SET daily_call_count = CASE
           WHEN daily_call_date = _today THEN daily_call_count + GREATEST(_calls, 0)
           ELSE GREATEST(_calls, 0)
         END,
         daily_call_date = _today,
         last_polled_at  = now(),
         last_error      = _last_error
   WHERE workspace_id = _workspace_id
     AND carrier_id   = _carrier_id;
$$;

-- Nur das Backend (Service-Role) darf den Zähler bumpen — Supabase-Default-
-- Grants für anon/authenticated explizit entfernen (pg_default_acl-Klasse,
-- gleiche Härtung wie public._edge_config in 20260603081506).
REVOKE EXECUTE ON FUNCTION public.bump_carrier_daily_calls(uuid, text, integer, date, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.bump_carrier_daily_calls(uuid, text, integer, date, text) FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.bump_carrier_daily_calls(uuid, text, integer, date, text) TO service_role;

-- ── 4. notifications_sent: ref_kind 'tracking_status' ───────────────────
-- ALT: CHECK (ref_kind IN ('mhd','delivery','payment','low_stock'))
-- (Constraint-Name verifiziert in 20260522015347_low_stock_notification_kind.sql)
ALTER TABLE public.notifications_sent
  DROP CONSTRAINT notifications_sent_ref_kind_check;
ALTER TABLE public.notifications_sent
  ADD CONSTRAINT notifications_sent_ref_kind_check
  CHECK (ref_kind IN ('mhd', 'delivery', 'payment', 'low_stock', 'tracking_status'));
