-- ─── Daten-Integrität: CHECK-Constraints ─────────────────────────────────
--
-- Verhindert offensichtliche Müll-Werte (negative Mengen/Preise, leere
-- Bewegungen, etc.) auf DB-Ebene — als zweite Verteidigungslinie zusätzlich
-- zur Client-Validierung.
--
-- Hinweis zu Produktion: bestehende Zeilen, die die Bedingungen verletzen,
-- lassen sich vor dem ALTER mit einem SELECT prüfen. Bei diesem App-Stand
-- sollten keine fehlerhaften Zeilen existieren.

ALTER TABLE public.deals
  DROP CONSTRAINT IF EXISTS deals_qty_positive,
  ADD  CONSTRAINT deals_qty_positive CHECK (quantity > 0);

ALTER TABLE public.deals
  DROP CONSTRAINT IF EXISTS deals_ek_netto_nonneg,
  ADD  CONSTRAINT deals_ek_netto_nonneg CHECK (ek_netto IS NULL OR ek_netto >= 0);

ALTER TABLE public.deals
  DROP CONSTRAINT IF EXISTS deals_ek_brutto_nonneg,
  ADD  CONSTRAINT deals_ek_brutto_nonneg CHECK (ek_brutto IS NULL OR ek_brutto >= 0);

ALTER TABLE public.deals
  DROP CONSTRAINT IF EXISTS deals_vk_nonneg,
  ADD  CONSTRAINT deals_vk_nonneg CHECK (vk IS NULL OR vk >= 0);

ALTER TABLE public.inventory_items
  DROP CONSTRAINT IF EXISTS inv_qty_nonneg,
  ADD  CONSTRAINT inv_qty_nonneg CHECK (quantity >= 0);

ALTER TABLE public.inventory_items
  DROP CONSTRAINT IF EXISTS inv_min_nonneg,
  ADD  CONSTRAINT inv_min_nonneg CHECK (min_stock >= 0);

ALTER TABLE public.inventory_items
  DROP CONSTRAINT IF EXISTS inv_cost_nonneg,
  ADD  CONSTRAINT inv_cost_nonneg CHECK (cost_price IS NULL OR cost_price >= 0);

ALTER TABLE public.inventory_movements
  DROP CONSTRAINT IF EXISTS mov_qty_nonzero,
  ADD  CONSTRAINT mov_qty_nonzero CHECK (quantity_change <> 0);

-- Optional: tax_id-Format für Buyer prüfen (nur wenn nicht NULL).
-- Wird hier noch nicht eingebaut, da Spalte erst in Sprint 2 kommt.
