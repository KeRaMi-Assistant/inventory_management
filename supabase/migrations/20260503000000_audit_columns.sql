-- ─── Audit-Spalten: updated_at, updated_by, version ──────────────────────
--
-- Fügt für alle Business-Tabellen Felder zum Tracking der letzten Änderung
-- + Versions-Counter für Optimistic Locking hinzu. Ein Trigger pflegt die
-- Felder automatisch bei jedem UPDATE.

-- Hilfsfunktion (idempotent): aktualisiert updated_at, updated_by, version.
CREATE OR REPLACE FUNCTION public.touch_row()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  NEW.updated_by := auth.uid();
  NEW.version    := COALESCE(OLD.version, 0) + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Spalten + Trigger pro Tabelle.
-- Konvention: zuerst Spalten anlegen, dann Trigger neu erstellen.

-- ── deals ─────────────────────────────────────────────────────────────────
ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;
DROP TRIGGER IF EXISTS trg_touch_deals ON public.deals;
CREATE TRIGGER trg_touch_deals BEFORE UPDATE ON public.deals
  FOR EACH ROW EXECUTE FUNCTION public.touch_row();

-- ── buyers ────────────────────────────────────────────────────────────────
ALTER TABLE public.buyers
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;
DROP TRIGGER IF EXISTS trg_touch_buyers ON public.buyers;
CREATE TRIGGER trg_touch_buyers BEFORE UPDATE ON public.buyers
  FOR EACH ROW EXECUTE FUNCTION public.touch_row();

-- ── shops ─────────────────────────────────────────────────────────────────
ALTER TABLE public.shops
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;
DROP TRIGGER IF EXISTS trg_touch_shops ON public.shops;
CREATE TRIGGER trg_touch_shops BEFORE UPDATE ON public.shops
  FOR EACH ROW EXECUTE FUNCTION public.touch_row();

-- ── inventory_items ───────────────────────────────────────────────────────
ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;
DROP TRIGGER IF EXISTS trg_touch_inventory_items ON public.inventory_items;
CREATE TRIGGER trg_touch_inventory_items BEFORE UPDATE ON public.inventory_items
  FOR EACH ROW EXECUTE FUNCTION public.touch_row();

-- inventory_movements bewusst NICHT versioniert — sind unveränderlicher
-- Audit-Stream (write-once).
