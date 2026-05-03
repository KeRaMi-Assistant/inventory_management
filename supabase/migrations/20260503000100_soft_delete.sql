-- ─── Soft-Delete: deleted_at + RLS-Anpassung ─────────────────────────────
--
-- Statt Datensätze physisch zu löschen, markieren wir sie via deleted_at.
-- Die Anwendung filtert in SELECTs auf "deleted_at IS NULL" (Standard) und
-- bietet einen Papierkorb-View für deleted_at IS NOT NULL.
--
-- RLS-Policies bleiben "user_id basiert" — die Sichtbarkeitsfilterung passiert
-- im App-Layer, damit Admin-/Restore-Workflows weiterhin auf Soft-Deleted
-- zugreifen können.

ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS deals_active_idx
  ON public.deals(user_id) WHERE deleted_at IS NULL;

ALTER TABLE public.buyers
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS buyers_active_idx
  ON public.buyers(user_id) WHERE deleted_at IS NULL;

ALTER TABLE public.shops
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS shops_active_idx
  ON public.shops(user_id) WHERE deleted_at IS NULL;

ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS inventory_items_active_idx
  ON public.inventory_items(user_id) WHERE deleted_at IS NULL;
