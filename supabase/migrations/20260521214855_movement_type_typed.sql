-- ─── Epic A-lite: getypte Buchungsarten auf inventory_movements ──────────
--
-- Plan: plans/2026-05-20_warenverwaltung-feature-parity.md
--       Abschnitt „Epic A-lite — getypte Buchungsarten (P0)".
--
-- Heute trägt jede inventory_movements-Row nur einen Freitext-`reason`
-- (z. B. 'Einbuchung', 'Ausbuchung', 'Einbuchung via Deal') — nicht
-- auswertbar. Diese Migration ergänzt zwei additive Spalten:
--
--   1) movement_type — getypte, auswertbare Buchungsart (CHECK-Enum).
--   2) unit_cost     — Einstandspreis der Buchung (nullable, für L9).
--
-- `reason` bleibt unverändert als optionale Detail-Notiz erhalten.
--
-- WICHTIG — inventory_movements bleibt append-only (Committee-Finding 5):
--   * KEINE neue Tabelle.
--   * KEINE UPDATE-/DELETE-Policy — die bestehende 2-Policy-RLS
--     (inventory_movements_ws_read + inventory_movements_ws_insert,
--     definiert in 20260504000500_data_workspace_scope.sql:346-353)
--     bleibt unverändert.
--   * KEINE updated_at/deleted_at/Touch-Trigger — die Tabelle ist ein
--     unveränderliches Audit-Journal (siehe auch
--     20260503000000_audit_columns.sql:57).
--   * Korrekturen laufen über Gegenbuchungen, nie über UPDATE/DELETE.
--
-- Der Backfill weiter unten läuft als Migration mit Service-Role
-- (RLS-Bypass) — das ist der einzige zulässige Weg, bestehende Rows
-- nachträglich zu typisieren, ohne die Insert-only-Policy zu verletzen.

-- ── 1) Spalte movement_type ──────────────────────────────────────────────
-- NOT NULL mit DEFAULT 'correction' — bestehende Rows bekommen sofort den
-- sicheren Default, der Backfill verfeinert ihn anschließend heuristisch.
ALTER TABLE public.inventory_movements
  ADD COLUMN IF NOT EXISTS movement_type TEXT NOT NULL DEFAULT 'correction'
    CHECK (movement_type IN
      ('goods_in','goods_out','correction','stocktake','transfer','sale'));

COMMENT ON COLUMN public.inventory_movements.movement_type IS
  'Getypte Buchungsart (Epic A-lite). reason bleibt als Freitext-Notiz.';

-- ── 2) Spalte unit_cost ──────────────────────────────────────────────────
-- Nullable: Einstandspreis der Buchung. Grundlage für die spätere
-- Einstandspreis-Bewertung (Plan-Lücke L9).
ALTER TABLE public.inventory_movements
  ADD COLUMN IF NOT EXISTS unit_cost NUMERIC(12,2);

COMMENT ON COLUMN public.inventory_movements.unit_cost IS
  'Einstandspreis der Buchung (nullable). Basis für Bestandsbewertung (L9).';

-- ── 3) Backfill bestehender Rows (Service-Role, RLS-Bypass) ──────────────
-- Heuristik aus dem Freitext-`reason`. Reale reason-Strings (verifiziert in
-- lib/providers/inventory_provider.dart und lib/screens/inventory_screen.dart):
--   * addInventoryItem      → 'Einbuchung'
--   * updateInventoryItem   → 'Einbuchung' (delta>0) / 'Ausbuchung' (delta<0)
--   * checkInDeal           → 'Einbuchung via Deal'
--   * adjustStock           → Freitext, vorbefüllt mit l10n inventoryReasonStockIn
--     ('Einbuchung' DE / 'Stock-in' EN) bzw. inventoryReasonSale
--     ('Verkauf' DE / 'Sale' EN) — User kann den Text frei überschreiben.
--
-- Reihenfolge der UPDATEs: spezifischer (sale) vor generischer (goods_out),
-- damit eine Verkaufs-Buchung nicht vorzeitig als goods_out klassifiziert
-- wird. Jeder Treffer schreibt nur Rows, die noch auf dem DEFAULT
-- 'correction' stehen — dadurch ist die Migration idempotent und ein
-- zweiter Lauf trifft 0 zusätzliche Rows.

-- 3a) Verkauf → 'sale' (vor goods_out, da "Verkauf"/"Sale" spezifischer ist).
UPDATE public.inventory_movements
   SET movement_type = 'sale'
 WHERE movement_type = 'correction'
   AND quantity_change < 0
   AND (reason ILIKE '%verkauf%' OR reason ILIKE '%sale%');

-- 3b) Wareneingang → 'goods_in'.
UPDATE public.inventory_movements
   SET movement_type = 'goods_in'
 WHERE movement_type = 'correction'
   AND quantity_change > 0
   AND (reason ILIKE 'Einbuchung%'
        OR reason ILIKE '%wareneingang%'
        OR reason ILIKE '%eingebucht%'
        OR reason ILIKE 'stock-in%'
        OR reason ILIKE 'stock in%');

-- 3c) Warenausgang → 'goods_out'.
UPDATE public.inventory_movements
   SET movement_type = 'goods_out'
 WHERE movement_type = 'correction'
   AND quantity_change < 0
   AND (reason ILIKE 'Ausbuchung%'
        OR reason ILIKE '%warenausgang%'
        OR reason ILIKE '%ausgebucht%'
        OR reason ILIKE 'stock-out%'
        OR reason ILIKE 'stock out%');

-- 3d) Alles Übrige bleibt auf dem DEFAULT 'correction' — kein UPDATE nötig.

-- ─────────────────────────────────────────────────────────────────────────
-- DOWN-Migration (manuell, bei Bedarf — keine separate Datei, Repo-Konvention
-- dokumentiert Down als kommentierten Block, siehe z. B.
-- 20260509000300_archive_triggers.sql).
--
-- ACHTUNG — DATENVERLUST-RELEVANT: Der DROP von movement_type wirft die
-- per Backfill gewonnene Typisierungs-Information unwiederbringlich weg.
-- Ein erneutes Up kann sie nur noch grob aus `reason` rekonstruieren;
-- manuell gesetzte Typen (z. B. künftige 'stocktake'/'transfer'-Buchungen,
-- deren reason die Heuristik nicht erkennt) gehen verloren.
--
--   ALTER TABLE public.inventory_movements DROP COLUMN IF EXISTS unit_cost;
--   ALTER TABLE public.inventory_movements DROP COLUMN IF EXISTS movement_type;
-- ─────────────────────────────────────────────────────────────────────────
