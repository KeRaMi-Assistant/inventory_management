-- ─── Initial schema for inventory management cloud backend ─────────────────
--
-- Apply via Supabase Dashboard SQL editor, supabase CLI (`supabase db push`),
-- or psql against the project's direct connection string.
--
-- All tables are scoped per auth.users.id via user_id + Row Level Security.

-- ─── deals ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.deals (
  id              BIGSERIAL PRIMARY KEY,
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product         TEXT NOT NULL,
  quantity        INTEGER NOT NULL DEFAULT 1,
  shipping_type   TEXT NOT NULL CHECK (shipping_type IN ('Reship', 'Dropship')),
  shop            TEXT NOT NULL,
  order_date      TIMESTAMPTZ NOT NULL,
  ek_netto        NUMERIC(12,2),
  ek_brutto       NUMERIC(12,2),
  vk              NUMERIC(12,2),
  buyer           TEXT,
  ticket_number   TEXT,
  ticket_url      TEXT,
  tracking        TEXT,
  arrival_date    TIMESTAMPTZ,
  status          TEXT NOT NULL DEFAULT 'Bestellt'
                  CHECK (status IN ('Bestellt','Unterwegs','Angekommen','Rechnung gestellt','Done')),
  beleg           TEXT NOT NULL DEFAULT 'Nein' CHECK (beleg IN ('Ja','Nein')),
  lexware         TEXT,
  note            TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS deals_user_id_idx ON public.deals(user_id);
CREATE INDEX IF NOT EXISTS deals_user_order_date_idx ON public.deals(user_id, order_date DESC);
ALTER TABLE public.deals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_owns_deals" ON public.deals;
CREATE POLICY "user_owns_deals" ON public.deals
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ─── buyers ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.buyers (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name                TEXT NOT NULL,
  row_fill_color      BIGINT NOT NULL,
  buyer_cell_color    BIGINT NOT NULL,
  font_color          BIGINT NOT NULL,
  sort_order          INTEGER NOT NULL DEFAULT 0,
  active              BOOLEAN NOT NULL DEFAULT TRUE,
  discord_server_ids  JSONB NOT NULL DEFAULT '[]',
  payment_status      TEXT NOT NULL DEFAULT 'OK',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS buyers_user_id_idx ON public.buyers(user_id);
ALTER TABLE public.buyers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_owns_buyers" ON public.buyers;
CREATE POLICY "user_owns_buyers" ON public.buyers
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ─── shops ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.shops (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  region      TEXT NOT NULL DEFAULT 'DE',
  channel     TEXT NOT NULL DEFAULT '',
  url         TEXT,
  active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS shops_user_id_idx ON public.shops(user_id);
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_owns_shops" ON public.shops;
CREATE POLICY "user_owns_shops" ON public.shops
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ─── inventory_items ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.inventory_items (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  sku             TEXT,
  quantity        INTEGER NOT NULL DEFAULT 0,
  min_stock       INTEGER NOT NULL DEFAULT 0,
  location        TEXT,
  cost_price      NUMERIC(12,2),
  arrival_date    TIMESTAMPTZ,
  deal_id         BIGINT REFERENCES public.deals(id) ON DELETE SET NULL,
  ticket_number   TEXT,
  ticket_url      TEXT,
  note            TEXT,
  status          TEXT NOT NULL DEFAULT 'Im Lager'
                  CHECK (status IN ('Im Lager','Reserviert','Versandt','Verkauft')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS inventory_items_user_id_idx ON public.inventory_items(user_id);
CREATE INDEX IF NOT EXISTS inventory_items_user_deal_idx ON public.inventory_items(user_id, deal_id);
ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_owns_inventory" ON public.inventory_items;
CREATE POLICY "user_owns_inventory" ON public.inventory_items
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ─── inventory_movements ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.inventory_movements (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  item_id         UUID NOT NULL REFERENCES public.inventory_items(id) ON DELETE CASCADE,
  date            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  quantity_change INTEGER NOT NULL,
  reason          TEXT NOT NULL,
  deal_id         BIGINT REFERENCES public.deals(id) ON DELETE SET NULL,
  ticket_number   TEXT,
  note            TEXT
);
CREATE INDEX IF NOT EXISTS inventory_movements_user_id_idx ON public.inventory_movements(user_id);
CREATE INDEX IF NOT EXISTS inventory_movements_user_item_idx ON public.inventory_movements(user_id, item_id);
ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_owns_movements" ON public.inventory_movements;
CREATE POLICY "user_owns_movements" ON public.inventory_movements
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ─── activity_log ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.activity_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  type        TEXT NOT NULL,
  message     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS activity_log_user_date_idx ON public.activity_log(user_id, date DESC);
ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_owns_activity" ON public.activity_log;
CREATE POLICY "user_owns_activity" ON public.activity_log
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ─── app_settings (optional, for theme/columns/etc.) ───────────────────────
CREATE TABLE IF NOT EXISTS public.app_settings (
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  key         TEXT NOT NULL,
  value       TEXT NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, key)
);
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_owns_settings" ON public.app_settings;
CREATE POLICY "user_owns_settings" ON public.app_settings
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
