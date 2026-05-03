-- Sprint 2 / E: Lieferanten-Tabelle.
CREATE TABLE IF NOT EXISTS public.suppliers (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name         TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  contact_name TEXT,
  email        TEXT CHECK (email IS NULL OR email ~ '^[^@]+@[^@]+\.[^@]+$'),
  phone        TEXT,
  website      TEXT,
  note         TEXT CHECK (note IS NULL OR char_length(note) <= 2000),
  active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by   UUID REFERENCES auth.users(id),
  version      INT NOT NULL DEFAULT 1,
  deleted_at   TIMESTAMPTZ
);

ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_owns_suppliers" ON public.suppliers;
CREATE POLICY "user_owns_suppliers" ON public.suppliers
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE UNIQUE INDEX IF NOT EXISTS suppliers_user_name_uidx
  ON public.suppliers (user_id, lower(name))
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS suppliers_active_idx
  ON public.suppliers (user_id)
  WHERE deleted_at IS NULL;

DROP TRIGGER IF EXISTS trg_touch_suppliers ON public.suppliers;
CREATE TRIGGER trg_touch_suppliers
  BEFORE UPDATE ON public.suppliers
  FOR EACH ROW EXECUTE FUNCTION public.touch_row();

-- Lieferanten-Verknüpfung an Lagerartikel.
ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS supplier_id UUID
    REFERENCES public.suppliers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS inventory_items_supplier_idx
  ON public.inventory_items (user_id, supplier_id)
  WHERE supplier_id IS NOT NULL AND deleted_at IS NULL;
