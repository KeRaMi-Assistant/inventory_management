-- ─── Öffentliche Verkaufs-Profile pro Workspace ─────────────────────────
--
-- Jeder Workspace darf opt-in eine öffentliche Read-only-Seite unter
-- `/u/<handle>` betreiben. Der Handle ist global eindeutig, lowercase,
-- und besteht aus a-z/0-9/-. Items werden NUR sichtbar, wenn:
--   * Workspace.public_profile_enabled = true
--   * inventory_items.is_public          = true
--   * inventory_items.status             = 'Im Lager'
-- Sichtbar gemacht werden NUR explizit kuratierte Felder
-- (kein cost_price, keine note, kein supplier_id, kein deal_id).

-- ─── 1. Spalten ──────────────────────────────────────────────────────────
ALTER TABLE public.workspaces
  ADD COLUMN IF NOT EXISTS handle TEXT,
  ADD COLUMN IF NOT EXISTS public_profile_enabled BOOLEAN NOT NULL DEFAULT FALSE;

-- Handle: lowercase, 3-32 Zeichen, [a-z0-9-], nicht mit "-" beginnen/enden.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'workspaces_handle_format'
  ) THEN
    ALTER TABLE public.workspaces
      ADD CONSTRAINT workspaces_handle_format
      CHECK (
        handle IS NULL
        OR handle ~ '^[a-z0-9](?:[a-z0-9-]{1,30}[a-z0-9])?$'
      );
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS workspaces_handle_unique
  ON public.workspaces (handle)
  WHERE handle IS NOT NULL AND deleted_at IS NULL;

ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS public_price NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS public_description TEXT;

-- Constraints: Beschreibung max 500 Zeichen, Preis nicht negativ.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'inventory_items_public_description_len'
  ) THEN
    ALTER TABLE public.inventory_items
      ADD CONSTRAINT inventory_items_public_description_len
      CHECK (public_description IS NULL OR length(public_description) <= 500);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'inventory_items_public_price_nonneg'
  ) THEN
    ALTER TABLE public.inventory_items
      ADD CONSTRAINT inventory_items_public_price_nonneg
      CHECK (public_price IS NULL OR public_price >= 0);
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS inventory_items_public_idx
  ON public.inventory_items (workspace_id)
  WHERE is_public = TRUE;

-- ─── 2. Public-RPC: get_public_profile(handle) ───────────────────────────
-- SECURITY DEFINER lässt anonyme User über exakt diese Funktion auf
-- exakt diese Felder zugreifen — RLS bleibt für direkte Tabellen-Calls
-- sonst zu (siehe Schritt 3).
CREATE OR REPLACE FUNCTION public.get_public_profile(handle_in TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  ws       RECORD;
  result   JSONB;
BEGIN
  IF handle_in IS NULL OR length(handle_in) < 3 THEN
    RETURN NULL;
  END IF;

  SELECT id, handle, name
    INTO ws
    FROM public.workspaces
   WHERE lower(handle) = lower(handle_in)
     AND public_profile_enabled = TRUE
     AND deleted_at IS NULL
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT jsonb_build_object(
           'workspace', jsonb_build_object(
             'handle', ws.handle,
             'name',   ws.name
           ),
           'items', COALESCE(jsonb_agg(
             jsonb_build_object(
               'id',                 i.id,
               'name',               i.name,
               'public_description', i.public_description,
               'public_price',       i.public_price,
               'attachment_paths',   i.attachment_paths,
               'quantity',           i.quantity
             )
             ORDER BY i.created_at DESC
           ) FILTER (WHERE i.id IS NOT NULL), '[]'::jsonb)
         )
    INTO result
    FROM public.inventory_items i
   WHERE i.workspace_id = ws.id
     AND i.is_public    = TRUE
     AND i.status       = 'Im Lager'
     AND i.quantity     > 0;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_profile(TEXT) TO anon, authenticated;

-- ─── 3. Storage-RLS: Anon darf öffentliche Item-Bilder lesen ─────────────
-- Bestehende auth-only-Policy bleibt; zusätzlich erlaubt die neue Policy
-- READ für jede Datei, deren Pfad in attachment_paths eines public-Items
-- in einem öffentlich aktivierten Workspace steht. Anon sieht damit nur
-- explizit freigegebene Bilder, keine privaten.
DROP POLICY IF EXISTS "attachments_public_select" ON storage.objects;
CREATE POLICY "attachments_public_select" ON storage.objects
  FOR SELECT
  TO anon, authenticated
  USING (
    bucket_id = 'attachments'
    AND EXISTS (
      SELECT 1
        FROM public.inventory_items i
        JOIN public.workspaces w ON w.id = i.workspace_id
       WHERE i.is_public = TRUE
         AND w.public_profile_enabled = TRUE
         AND w.deleted_at IS NULL
         AND storage.objects.name = ANY (i.attachment_paths)
    )
  );

-- Bilder werden client-seitig via createSignedUrl(path, 3600) abgerufen.
-- Der Bucket bleibt privat; die obige Policy lässt nur Pfade signieren,
-- die einem öffentlich freigegebenen Item gehören.
