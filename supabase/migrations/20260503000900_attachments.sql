-- Sprint 4 / S-Tier: Foto-Anhänge für Items & Deals (max. 5 pro Entität).
-- Speichert nur die Object-Pfade als TEXT[]. Tatsächliche Bytes leben in
-- Supabase Storage Bucket "attachments" mit RLS pro user_id-Prefix.

-- ── 1. Spalten ──────────────────────────────────────────────────────────────
ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS attachment_paths TEXT[] NOT NULL DEFAULT '{}';

ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS attachment_paths TEXT[] NOT NULL DEFAULT '{}';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'deals_attachment_paths_max'
  ) THEN
    ALTER TABLE public.deals
      ADD CONSTRAINT deals_attachment_paths_max
      CHECK (array_length(attachment_paths, 1) IS NULL
             OR array_length(attachment_paths, 1) <= 5);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'inventory_items_attachment_paths_max'
  ) THEN
    ALTER TABLE public.inventory_items
      ADD CONSTRAINT inventory_items_attachment_paths_max
      CHECK (array_length(attachment_paths, 1) IS NULL
             OR array_length(attachment_paths, 1) <= 5);
  END IF;
END$$;

-- ── 2. Storage-Bucket ───────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'attachments',
  'attachments',
  false,
  10485760, -- 10 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
ON CONFLICT (id) DO UPDATE
  SET file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types,
      public = EXCLUDED.public;

-- ── 3. Storage-RLS: User darf nur "<auth.uid()>/..."-Pfade managen ──────────
DROP POLICY IF EXISTS "attachments_owner_select" ON storage.objects;
CREATE POLICY "attachments_owner_select" ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "attachments_owner_insert" ON storage.objects;
CREATE POLICY "attachments_owner_insert" ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "attachments_owner_update" ON storage.objects;
CREATE POLICY "attachments_owner_update" ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "attachments_owner_delete" ON storage.objects;
CREATE POLICY "attachments_owner_delete" ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
