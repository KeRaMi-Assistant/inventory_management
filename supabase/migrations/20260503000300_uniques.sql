-- ─── Unique-Constraints: doppelte Stammdaten verhindern ──────────────────
--
-- Pro Nutzer dürfen Shop- und Käufername nicht doppelt vorkommen. SKUs in
-- inventory_items werden ebenfalls pro Nutzer eindeutig erzwungen — aber nur
-- wenn gesetzt (NULL bleibt erlaubt).
--
-- Soft-Delete-Awareness: WHERE-Klausel sorgt dafür, dass gelöschte Datensätze
-- die Eindeutigkeit nicht blockieren (so können Namen wiederverwendet werden).

CREATE UNIQUE INDEX IF NOT EXISTS shops_user_name_unique
  ON public.shops (user_id, lower(name))
  WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS buyers_user_name_unique
  ON public.buyers (user_id, lower(name))
  WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS inventory_items_user_sku_unique
  ON public.inventory_items (user_id, lower(sku))
  WHERE sku IS NOT NULL AND deleted_at IS NULL;

-- product/order_date sind bereits NOT NULL (siehe initial schema).
-- inventory_items.name explizit NOT NULL setzen, falls in alten Schemata
-- nullable gewesen wäre.
ALTER TABLE public.inventory_items
  ALTER COLUMN name SET NOT NULL;
