-- Detection-Ausbau 2026-06-11: deals.carrier-CHECK um 'hermes' erweitern.
--
-- UPS-1Z- und Hermes-14-Detection sind neu (tracking_detection.ts);
-- 'ups' ist seit 20260610150000 bereits im CHECK, 'hermes' fehlt noch.
-- Hermes ist detection-only (kein Poll-Adapter, carriers.ts) — der Wert
-- dient Deep-Link + mail-getriebenem Status. Neue Menge bleibt strikte
-- Obermenge der alten → kein Bestandsrow kann verletzen.

ALTER TABLE public.deals
  DROP CONSTRAINT IF EXISTS deals_carrier_check;

ALTER TABLE public.deals
  ADD CONSTRAINT deals_carrier_check
  CHECK (carrier IS NULL OR carrier IN ('dhl','amazon','dpd','gls','ups','hermes'));

COMMENT ON COLUMN public.deals.carrier IS
  'Erkannter Carrier (lowercase): dhl|amazon|dpd|gls|ups|hermes. '
  'amazon+gls+hermes=detection-only (kein Poll). Gesetzt von der '
  'algorithmischen Detection (tracking_detection.ts) bzw. manuell.';
