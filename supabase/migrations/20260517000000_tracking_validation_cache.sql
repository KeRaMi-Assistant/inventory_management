-- Plan-Ref: plans/2026-05-16_dhl_api_only_tracking_detection.md §D4
--
-- Globaler Validation-Cache für DHL-API-Probe-Calls.
--
-- WARUM GLOBAL (kein workspace_id im PK)?
--   Eine Tracking-Nummer ist objektiv "valide DHL-Sendung" oder nicht —
--   das ist kein workspace-spezifischer Fakt. Cross-Workspace-Reuse spart
--   massiv API-Calls (DHL Free-Tier: 1 Call / 5s, 250 Calls / Tag).
--   `first_seen_workspace_id` bleibt als Audit-Spur erhalten, ist aber
--   nicht Teil der Identity.
--
-- WARUM RLS ENABLED ABER OHNE POLICIES?
--   Default-Deny-Pattern, identisch zu `workspace_carrier_credentials`
--   (siehe 20260508000000_workspace_carrier_credentials.sql:69-71) und
--   `mailbox_credentials` (siehe 20260507000000_inbox.sql:92-93).
--   Nur `service_role` (Edge-Function `tracking-validation` /
--   `inbox-parse-runner`) darf schreiben/lesen. RLS ohne Policies
--   blockiert alle authenticated/anon-Zugriffe hart.
--
-- TTL-LOGIK (Edge-Function-Semantik, NICHT im SQL):
--   * result_state='valid'   → 7 Tage  (Tracking-Nrn werden nicht ungültig)
--   * result_state='invalid' → 30 Tage (False-Positives sind dauerhaft)
--   * result_state='unknown' → 1 Stunde (DHL 429/5xx → schnell retry)
--   Wrapper-Code in `tracking_validation.ts` prüft `last_checked_at` vs
--   `now()` vor jedem Re-Use und entscheidet pro `result_state` neu.
--   Reaper-Job kann später (nicht in diesem PR) über pg_cron alte Rows
--   anhand des `last_checked_at`-Index löschen.

CREATE TABLE IF NOT EXISTS public.tracking_validation_cache (
  tracking_norm            TEXT        NOT NULL PRIMARY KEY,
  is_valid                 BOOLEAN     NOT NULL,
  result_state             TEXT        NOT NULL
                           CHECK (result_state IN ('valid', 'invalid', 'unknown')),
  status_raw               JSONB,
  first_seen_workspace_id  UUID        REFERENCES public.workspaces(id) ON DELETE SET NULL,
  last_checked_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index für TTL-Cleanup-Job (älteste Rows zuerst scannen).
CREATE INDEX IF NOT EXISTS tracking_validation_cache_last_checked_idx
  ON public.tracking_validation_cache (last_checked_at);

-- Default-Deny: RLS an, KEINE Policies → nur service_role hat Zugriff.
-- Identisches Pattern wie workspace_carrier_credentials + mailbox_credentials.
ALTER TABLE public.tracking_validation_cache ENABLE ROW LEVEL SECURITY;

-- Kommentare für DBA / Audit-Tools.
COMMENT ON TABLE public.tracking_validation_cache IS
  'Plan 2026-05-16 §D4: globaler Cache für DHL-API-Validation-Ergebnisse. PK global (kein workspace_id), da Validität objektiv. Service-role-only (RLS enabled, no policies). TTL-Logik in Edge-Function tracking_validation.ts.';
COMMENT ON COLUMN public.tracking_validation_cache.tracking_norm IS
  'Normalisierte Tracking-Nr: uppercase + alle whitespace-Zeichen entfernt. Primärschlüssel.';
COMMENT ON COLUMN public.tracking_validation_cache.result_state IS
  'valid = DHL-API hat Shipment bestätigt; invalid = DHL-API explizit 404/leer; unknown = transient (429/5xx), 1h-TTL.';
COMMENT ON COLUMN public.tracking_validation_cache.status_raw IS
  'Letztes API-Response-Payload (debug + forensisch). NULL für unknown-State.';
COMMENT ON COLUMN public.tracking_validation_cache.first_seen_workspace_id IS
  'Audit-only: welcher Workspace hat den Cache-Eintrag erstmals geschrieben. NICHT Teil der Identity.';
COMMENT ON COLUMN public.tracking_validation_cache.last_checked_at IS
  'Letzter DHL-API-Probe-Call. Edge-Function prüft TTL gegen now() pro result_state.';
