-- T1 (Plan 2026-06-03_tracking_algorithmic_rebuild.md §3.1 / §4 / §5b):
-- deals.carrier-Spalte für die algorithmische Tracking-Detection.
--
-- Zweck: Der Poller (tracking-poll) liest deal.carrier als PRIMÄRE
-- Carrier-Präferenz (ADAPTERS[deal.carrier] ?? detectAdapter(tracking)) und
-- skippt amazon (detection-only, kein Live-Status-Poll). Detection schreibt
-- den Wert künftig lowercase aus tracking_detection.ts.
--
-- Lowercase-CHECK (Pflicht, Council-Fix §2.8): Bestandscode emittiert teils
-- 'DHL'/'DPD' (uppercase, z.B. inbox_parse_runner.ts:298, inbox_adapters.ts:713).
-- Der CHECK akzeptiert AUSSCHLIESSLICH lowercase ('dhl','amazon','dpd') — die
-- Normalisierung auf lowercase passiert in T3 (.toLowerCase()-Guard vor jedem
-- deals.carrier-Write). Ein uppercase-Write würde hier eine check_violation
-- werfen und den Deal-Write rollbacken (gewolltes Fail-Loud-Verhalten).
--
-- RLS-Hinweis: public.deals trägt bereits workspace-scoped Policies
-- (deals_ws_read/insert/update/delete via is_workspace_member /
-- has_workspace_role aus 20260504000500_data_workspace_scope.sql).
-- PG-RLS arbeitet auf Row-Granularität, nicht auf Column-Granularität — eine
-- neu hinzugefügte Spalte erbt diese Policies automatisch. KEINE neuen Policies
-- nötig (verifiziert: grep "CREATE POLICY deals_ws" -> nur 20260504000500).
--
-- IF NOT EXISTS für Idempotenz (supabase db reset / Re-Run safe).

ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS carrier text
  CHECK (carrier IS NULL OR carrier IN ('dhl','amazon','dpd'));

COMMENT ON COLUMN public.deals.carrier IS
  'Erkannter Carrier (lowercase): dhl|amazon|dpd. amazon=detection-only (kein Poll). Gesetzt von der algorithmischen Detection (tracking_detection.ts).';
