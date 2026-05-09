-- Backfill: Amazon-Logistics-Tracking-Nrn aus dem orderingShipmentId-
-- URL-Parameter, der in jeder Amazon-Versandbestätigung steht.
--
-- Hintergrund (siehe docs/inbox-forensics/amazon-live-2026-05.md):
--   PR #37 hat einen HTML-Adapter mit DHL/UPS/Chronopost/SEUR/DPD-
--   Patterns gebaut, aber echte Amazon-Versandbestätigungen wrappen
--   jede Tracking-URL in einen `amazon.<tld>/gp/f.html?C=…&U=<URL-
--   encoded shiptrack-URL>`-Redirect. Die einzige stabile Tracking-
--   Information ist `orderingShipmentId` (Amazon-Logistics-interne
--   Shipment-ID, 12–18 stellig).
--
--   Live-Forensik im Test-Workspace: 47 von 79 Amazon-Mails mit HTML
--   enthielten orderingShipmentId — bisher null davon ein Tracking
--   gespeichert.
--
-- Diese Migration ist idempotent: läuft sie zweimal, wird der zweite
-- Lauf nichts ändern (jsonb_set überschreibt mit demselben Wert; der
-- WHERE-Filter `tracking IS NULL` greift dann ohnehin nicht mehr).
WITH extracted AS (
  SELECT pm.id,
         (regexp_match(
            pm.parsed_payload->>'_raw_html',
            'orderingShipmentId(?:%3D|=)([0-9]{8,20})',
            'i'
         ))[1] AS shipment_id
  FROM public.parsed_messages pm
  WHERE pm.shop_key ILIKE 'amazon%'
    AND pm.parsed_payload->>'_raw_html' IS NOT NULL
    AND pm.parsed_payload->>'tracking' IS NULL
    AND pm.parsed_payload->>'status' IN ('shipped', 'delivered')
)
UPDATE public.parsed_messages pm
SET parsed_payload = jsonb_set(
       jsonb_set(
         jsonb_set(
           pm.parsed_payload,
           '{tracking}',
           to_jsonb(e.shipment_id)
         ),
         '{trackings}',
         jsonb_build_array(e.shipment_id)
       ),
       '{carrier}',
       '"Amazon Logistics"'::jsonb
     )
FROM extracted e
WHERE pm.id = e.id
  AND e.shipment_id IS NOT NULL;

-- pending_deal_suggestions ebenfalls patchen (sonst zeigt der Inbox-
-- Suggestion-Tab kein Tracking, obwohl das parsed_message es jetzt hat).
UPDATE public.pending_deal_suggestions pds
SET tracking = (pm.parsed_payload->>'tracking'),
    trackings = ARRAY[pm.parsed_payload->>'tracking'],
    carrier = 'Amazon Logistics'
FROM public.parsed_messages pm
WHERE pds.parsed_message_id = pm.id
  AND pm.shop_key ILIKE 'amazon%'
  AND pm.parsed_payload->>'tracking' IS NOT NULL
  AND pm.parsed_payload->>'carrier' = 'Amazon Logistics'
  AND pds.tracking IS NULL;

-- Bestehende Deals, die per order_id zur jetzt-gefixten Mail matchen,
-- bekommen das Tracking auf den Deal selbst gesetzt — sonst sieht der
-- User in der Deal-Liste weiterhin "Kein Tracking", obwohl die Inbox
-- es längst hat. Konservativ: nur wenn deal.tracking aktuell NULL.
UPDATE public.deals d
SET tracking = pm.parsed_payload->>'tracking'
FROM public.parsed_messages pm
WHERE d.workspace_id = pm.workspace_id
  AND d.ticket_number = (pm.parsed_payload->>'order_id')
  AND d.deleted_at IS NULL
  AND d.tracking IS NULL
  AND pm.shop_key ILIKE 'amazon%'
  AND pm.parsed_payload->>'tracking' IS NOT NULL
  AND pm.parsed_payload->>'carrier' = 'Amazon Logistics';
