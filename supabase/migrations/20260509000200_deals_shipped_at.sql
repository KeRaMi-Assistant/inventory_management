-- ─── deals.shipped_at: Versand-Zeitpunkt explizit tracken ────────────────
--
-- Bisher hat die App den Versand-Status nur implizit aus
-- `status = 'Versendet'` und der `arrival_date` abgeleitet. Für den neuen
-- Carrier-Polling-Flow (siehe edge function `carrier-poll`) brauchen wir
-- einen separaten Zeitstempel, der den TATSÄCHLICHEN Versand-Moment
-- markiert — unabhängig vom angekündigten Liefertermin.
--
-- NULL = noch nicht versendet (oder unbekannt). Sobald die Carrier-API
-- "shipped" bestätigt, schreibt der Adapter hier rein.

ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS shipped_at TIMESTAMPTZ;

-- Index für die zwei häufigsten Filter:
--   1) "alle versendeten Deals dieses Workspaces" (status-Reports)
--   2) "shipped_at IS NULL" — Carrier-Poll braucht offene Sendungen
-- Workspace-Prefix ist Pflicht, weil RLS pro Workspace scoped — der
-- Planner kann den Index dann ohne Tenant-Scan nutzen.
CREATE INDEX IF NOT EXISTS deals_shipped_at_idx
  ON public.deals(workspace_id, shipped_at);

-- ─── Backfill (best-effort) ──────────────────────────────────────────────
--
-- Für historische Deals existiert kein echter Versand-Zeitpunkt — wir
-- haben nur das `arrival_date` (Liefertermin). Annahme:
--   shipped_at ≈ arrival_date - 2 Tage
-- Das ist ein heuristischer Default für DHL/Hermes-Standard-Versand und
-- bewusst eine Näherung, KEIN exakter Wert. Sobald der Carrier-Adapter
-- echte Tracking-Events liefert, überschreibt er diese Schätzung.
--
-- Nur Deals mit `status = 'Done'` UND `arrival_date IS NOT NULL` werden
-- gefüllt — andere Stati (Bestellt/Versendet/Storniert) bleiben NULL,
-- weil die Heuristik dort nicht greift.
UPDATE public.deals
   SET shipped_at = arrival_date - INTERVAL '2 days'
 WHERE status = 'Done'
   AND arrival_date IS NOT NULL
   AND shipped_at IS NULL;
