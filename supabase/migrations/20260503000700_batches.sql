-- Sprint 2 / F: Charge/Batch & MHD-Tracking.
CREATE TABLE IF NOT EXISTS public.inventory_batches (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id       UUID NOT NULL REFERENCES public.inventory_items(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  batch_number  TEXT NOT NULL CHECK (char_length(batch_number) BETWEEN 1 AND 100),
  serial_number TEXT CHECK (serial_number IS NULL OR char_length(serial_number) <= 100),
  mhd           DATE,
  quantity      INT NOT NULL CHECK (quantity > 0),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ
);

ALTER TABLE public.inventory_batches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_owns_batches" ON public.inventory_batches;
CREATE POLICY "user_owns_batches" ON public.inventory_batches
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS batches_item_idx
  ON public.inventory_batches (item_id, mhd)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS batches_user_idx
  ON public.inventory_batches (user_id)
  WHERE deleted_at IS NULL;
