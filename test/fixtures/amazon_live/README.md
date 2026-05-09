# Amazon Live Fixtures

Synthetic-aber-realistische HTML-Fixtures, die das **echte Live-Mail-Format**
abbilden, das die App bei Amazon-Versandbestätigungen tatsächlich bekommt.

## Hintergrund

PR #37 hat den Amazon-HTML-Adapter implementiert mit synthetischen
Fixtures (`test/fixtures/amazon_*.html`), die echte Carrier-Tracking-
Nummern enthielten (DHL `0034…`, UPS `1Z…`, Chronopost `XJ…`, …).

Live zeigte sich aber: **echte Amazon-Versandbestätigungen enthalten
diese Tracking-Nummern überhaupt nicht.** Stattdessen wrappt Amazon
jede Tracking-URL in einen `amazon.<tld>/gp/f.html?C=…&U=<URL-encoded
shiptrack-URL>`-Redirect. Die einzige Tracking-Information ist der
`orderingShipmentId`-Parameter (Amazon-interne Shipment-ID, 12–15 stellig).

## Datenquelle

Forensik via Supabase MCP gegen die Live-Dev-DB
(`parsed_messages.parsed_payload._raw_html`, May 2026, Test-Workspace):
- 47 von 48 Versand-Subject-Mails enthielten `orderingShipmentId`
- 0 enthielten DHL/UPS/Chronopost/SEUR/DPD-Tracking-Codes

→ Re-Realisierung: `orderingShipmentId` ist das einzige stabile
  Tracking-Anker für Amazon-Logistics-Sendungen, das aus dem Mail-Body
  extrahierbar ist.

## PII-Redaction

Die Fixtures hier sind **nicht** Bytecopies der Live-Mails. Sie
übernehmen das Strukturmuster (URL-Wrap, Tag-Hierarchie) aber mit
synthetischen IDs:

- Order-IDs: Format `XXX-NNNNNNN-NNNNNNN`, randomisiert.
- Shipment-IDs: 12–15-stellige Random-Zahlen.
- C/K/M/R/H/AddressID-Tokens: Platzhalter-Strings.
- Empfänger-Namen, Adressen, vollständige E-Mail-Adressen: NICHT
  enthalten.

Wer eine echte Live-Mail debuggen will, geht über MCP-SQL-Queries gegen
`parsed_messages.parsed_payload._raw_html` — die HTMLs liegen dort
ohnehin (read-only, RLS-geschützt).
