-- Paket 2 (plans/2026-06-10_state_of_the_art_tracking_roadmap.md):
-- deals.carrier-CHECK um 'gls' + 'ups' erweitern.
--
-- GLS: neuer Detection-Scope (PcComponentes & Co. versenden via GLS).
--   GLS ist DETECTION-ONLY wie amazon — der offene GLS-Tracking-Endpoint
--   wurde 2026 hinter eine API-Registrierung gelegt (verifiziert 2026-06-10:
--   api.gls-group.eu/...rstt001 → 303 Redirect auf "Register API Access").
--   Live-Status bleibt mail-getrieben; die UI bietet den Deep-Link zur
--   GLS-Paketverfolgung (lib/utils/carrier_links.dart).
-- UPS: Poll-Adapter existiert im Code (tracking_adapters.ts), war aber im
--   CHECK nicht zugelassen — die Carrier-Registry (carriers.ts) dokumentiert
--   ihn als key-required/disabled. Aufnahme hier macht den CHECK zur
--   Obermenge aller Registry-Carrier (eine kanonische Menge, Audit-Fix
--   "Carrier 3-fach inkonsistent").
--
-- Constraint-Name: Postgres vergibt für den Inline-CHECK aus
-- 20260603074312_deals_carrier_column.sql den Auto-Namen `deals_carrier_check`.

ALTER TABLE public.deals
  DROP CONSTRAINT IF EXISTS deals_carrier_check;

ALTER TABLE public.deals
  ADD CONSTRAINT deals_carrier_check
  CHECK (carrier IS NULL OR carrier IN ('dhl','amazon','dpd','gls','ups'));

COMMENT ON COLUMN public.deals.carrier IS
  'Erkannter Carrier (lowercase): dhl|amazon|dpd|gls|ups. amazon+gls='
  'detection-only (kein Poll). Gesetzt von der algorithmischen Detection '
  '(tracking_detection.ts) bzw. manuell.';
