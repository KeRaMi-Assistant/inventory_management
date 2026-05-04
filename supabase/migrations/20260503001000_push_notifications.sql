-- Sprint 4 / S-Tier: Push-Notifications via FCM HTTP v1.
-- Tabellen: fcm_tokens (Geräte-Tokens), notification_preferences (User-Toggles),
-- notifications_sent (Dedup-Tracking, damit jede Warnung nur einmal raus geht).

-- ── 1. fcm_tokens ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token        TEXT NOT NULL UNIQUE,
  platform     TEXT NOT NULL CHECK (platform IN ('ios','android','web','macos')),
  device_label TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS fcm_tokens_user_id_idx ON public.fcm_tokens(user_id);

ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fcm_tokens_owner" ON public.fcm_tokens;
CREATE POLICY "fcm_tokens_owner" ON public.fcm_tokens
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── 2. notification_preferences ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  mhd_warning_enabled  BOOLEAN NOT NULL DEFAULT true,
  mhd_warning_days     INTEGER NOT NULL DEFAULT 14
                        CHECK (mhd_warning_days BETWEEN 0 AND 365),
  delivery_enabled     BOOLEAN NOT NULL DEFAULT true,
  payment_enabled      BOOLEAN NOT NULL DEFAULT true,
  payment_overdue_days INTEGER NOT NULL DEFAULT 7
                        CHECK (payment_overdue_days BETWEEN 0 AND 365),
  quiet_hours_start    TIME NOT NULL DEFAULT '22:00',
  quiet_hours_end      TIME NOT NULL DEFAULT '08:00',
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notification_preferences_owner" ON public.notification_preferences;
CREATE POLICY "notification_preferences_owner" ON public.notification_preferences
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── 3. notifications_sent (Dedup-Log) ───────────────────────────────────────
-- ref_kind ∈ {'mhd','delivery','payment'}, ref_id ist die jeweilige
-- batch_id / deal_id / deal_id. PRIMARY KEY garantiert "max. einmal".
CREATE TABLE IF NOT EXISTS public.notifications_sent (
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ref_kind   TEXT NOT NULL CHECK (ref_kind IN ('mhd','delivery','payment')),
  ref_id     TEXT NOT NULL,
  sent_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, ref_kind, ref_id)
);

CREATE INDEX IF NOT EXISTS notifications_sent_user_kind_idx
  ON public.notifications_sent(user_id, ref_kind);

ALTER TABLE public.notifications_sent ENABLE ROW LEVEL SECURITY;

-- Nur Service-Role schreibt; User dürfen ihre eigenen Einträge lesen
-- (z.B. um in der UI "schon benachrichtigt" anzuzeigen).
DROP POLICY IF EXISTS "notifications_sent_owner_read" ON public.notifications_sent;
CREATE POLICY "notifications_sent_owner_read" ON public.notifications_sent
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);
