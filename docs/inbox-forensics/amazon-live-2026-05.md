# Amazon Live-Tracking-Forensik (2026-05)

**Status:** Live-Coverage 97.9 % — vorher 0 %.

## TL;DR

PR #37 hat den Amazon-HTML-Adapter mit Carrier-Patterns für DHL, UPS,
Chronopost, SEUR, DPD, Amazon Logistics gebaut. Synthetische Fixtures
waren grün, **live aber 0 Tracking-Treffer**. Der Bug: Amazon wrappt
in echten Versandbestätigungen jede Tracking-URL in einen Click-Tracker
`amazon.<tld>/gp/f.html?C=…&U=<URL-encoded shiptrack-URL>`. Die
Carrier-URL-Parameter (`piececode`, `trackingId`, `orderingShipmentId`)
stehen damit **doppelt URL-encoded** im `href`. Die alten Regexes haben
nur gegen den raw String gematcht und die `%26param%3Dvalue`-Form
übersehen.

Außerdem: echte Amazon-Mails enthalten **keine** DHL/UPS/etc.-Carrier-
Codes — die Versandbestätigungen referenzieren ausschließlich Amazons
eigene `shiptrack/view.html`-Seite mit `orderingShipmentId` als
Tracking-Anker.

## Was wurde geprüft

Forensik via Supabase MCP gegen die Live-Dev-DB
(`parsed_messages.parsed_payload._raw_html`, Test-Workspace,
2026-02 bis 2026-05-08):

| Metrik | Wert |
|---|---|
| Amazon-Mails total | 109 |
| davon mit `_raw_html` | 79 |
| mit Versand-Subject (versandt/dispatched/spedito/expédié/enviado) | 48 |
| **vorher** mit `tracking` | **0** |
| URLs mit `track.amazon.<tld>/<code>` | 0 |
| URLs mit Strong-Pattern (1Z/TBA/JJD) | 0 |
| URLs mit `piececode` (DHL) | 0 |
| URLs mit `progress-tracker` | 0 |
| URLs mit `orderingShipmentId%3D[0-9]+` (URL-encoded) | 47 |

→ 47/48 = **97,9 % Coverage** abdeckbar mit einer einzigen neuen
Pattern-Erweiterung. Die letzte Mail ohne Tracking ist eine
Lieferungs-Aktualisierung ohne Shiptrack-Link.

## Was vorher fehlte

1. **`href`-URL-Cap zu klein.** Der Regex `href\s*=\s*["']([^"']{8,400})["']`
   hat URLs auf 400 Zeichen begrenzt. Amazon-Click-Tracker-URLs sind
   real 600–1200 Zeichen lang (Click-Token + URL-encoded Ziel-URL).
   → URLs wurden komplett verworfen, bevor irgendein Pattern matchte.
2. **Keine URL-Decoding-Schicht.** Selbst wenn die URL mitgeholt wurde,
   stand das Ziel als `…&U=https%3A%2F%2Fbusiness.amazon.de%2F…
   %26orderingShipmentId%3D106121425175302%26…`. `[?&]…=…` hat aber
   gegen `%26…%3D…` nicht gematcht — die `%`-Form war für die Regex
   ein anderer Buchstabe.
3. **`orderingShipmentId` war nicht im Pattern-Katalog.** PR #37 hat
   `[?&]packageId=…` aufgenommen, aber `packageId` ist in real-Mails
   typischerweise `1` oder `2` (Sequenznummer pro Versand-Splitt) und
   damit als Tracking wertlos. Der eigentliche Anker `orderingShipmentId`
   (12–18-stellige Amazon-Logistics-Internal-ID) fehlte.

## Was jetzt extrahiert wird

In `supabase/functions/_shared/inbox_adapters.ts`:

```ts
// 1) URL-Cap auf 2000 erhöht.
const hrefRe = /href\s*=\s*["']([^"']{8,2000})["']/gi

// 2) Pro href: gegen RAW + decoded(URL) matchen.
let decoded = url
if (url.includes('%')) {
  try { decoded = decodeURIComponent(url) } catch { /* ignore */ }
}
const candidates = decoded === url ? [url] : [url, decoded]

// 3) Neuer Pattern für Amazon-Logistics-Shipment-ID.
{ re: /[?&]orderingShipmentId=([0-9]{8,20})/i, carrier: 'Amazon Logistics' }
```

Das Pattern matcht jetzt:

- Raw URL: `…&U=…%26orderingShipmentId%3D106121425175302%26…`
  → kein Treffer auf RAW (URL-encoded).
- Nach `decodeURIComponent`: `…&U=…&orderingShipmentId=106121425175302&…`
  → Treffer, capturt `106121425175302`, Carrier `Amazon Logistics`.

Side-Effect: `packageId` wurde aus dem generischen Last-Resort-Pattern
entfernt (`packageId=1` / `packageId=2` als Tracking ist Müll).

## Live-Coverage nach dem Fix

```sql
-- Verifikation per MCP, 2026-05-09
SELECT count(*) FILTER (
  WHERE parsed_payload->>'tracking' IS NOT NULL
) AS amazon_mails_mit_tracking
FROM parsed_messages
WHERE shop_key ILIKE 'amazon%';
```

| Vorher | Nachher |
|---|---|
| 0 | **48** (47 Amazon Logistics + 1 Sonderfall) |

Coverage über alle Versand-Subject-Mails: **97,9 %** (47/48).

`pending_deal_suggestions` wurden parallel gepatcht — der Inbox-Tab
zeigt jetzt Tracking-Chips auf den Suggestion-Cards.

## Bekannte Lücken

1. **`deals.tracking` bleibt zunächst NULL.** Die existierenden
   Demo-Deals haben `ticket_number` der Form `TK-DEMO-*`, nicht
   `XXX-NNNNNNN-NNNNNNN`. Das Backfill-`UPDATE deals` aus der Migration
   findet daher kein Match. Sobald der User per Inbox-UI eine
   Suggestion akzeptiert oder einen Deal mit echter Amazon-Order-ID
   anlegt, wird der nächste Inbox-Poll-Lauf das Tracking auf den
   Deal pflegen (siehe `inbox_parse_runner.ts → applyUpdateToDeal`).

2. **HTML-Cap 60 KB.** `parsed_payload._raw_html` ist auf 60 000 Bytes
   begrenzt. In den 79 untersuchten Mails liegt der `orderingShipmentId`
   immer in den ersten ~35 KB — sicher innerhalb des Caps. Sollte
   Amazon das Layout ändern und Tracking-Buttons hinten ans Mail-Ende
   schieben, könnte das Cap zur Falle werden. Monitoring-Punkt:
   bei plötzlichem Coverage-Drop diesen Cap überprüfen.

3. **Kein Status-Polling.** `orderingShipmentId` ist eine Amazon-
   interne ID; es gibt keine öffentliche API, an die `tracking-poll`
   sie schicken könnte. Das Status-Update von "Unterwegs" → "Angekommen"
   passiert daher nur, wenn Amazon eine Zustell-Mail schickt, die der
   Adapter dann auf `status='delivered'` setzt. Das funktioniert in
   den 7 "Zugestellt:"-Mails (alle korrekt klassifiziert).

## Live-Fixtures

5 PII-redacted Fixtures in `test/fixtures/amazon_live/` bilden das
echte Live-Format ab:

| Datei | Domain | Order-ID | Shipment-ID |
|---|---|---|---|
| `amazon_de_live_redirect_wrap_01.html` | amazon.de | 306-4234293-3555528 | 106121425175302 |
| `amazon_de_live_redirect_wrap_02.html` | amazon.de | 306-5580998-3956325 | 108834567890123 |
| `amazon_it_live_redirect_wrap.html` | amazon.it | 404-5127739-1289903 | 109555111222333 |
| `amazon_es_live_redirect_wrap.html` | amazon.es | 405-4447968-7281969 | 110123456789012 |
| `amazon_fr_live_redirect_wrap.html` | amazon.fr | 402-4004849-1316335 | 111777888999000 |

Tests in `supabase/functions/_shared/amazon_live_test.ts` —
6 grün, alle 5 Fixtures liefern korrekt `Amazon Logistics` + Shipment-ID.

## Migrations

- `supabase/migrations/20260512000000_backfill_amazon_logistics_tracking.sql`
  — idempotent, setzt parsed_messages.tracking + pending_deal_suggestions
  + (sobald Match existiert) deals.tracking. Lokal via `supabase db
  reset` getestet, live via `supabase db query --linked -f <file>`
  ausgeführt.
