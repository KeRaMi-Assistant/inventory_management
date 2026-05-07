---
slug: fix-mail-tracking-update-adapter
priority: 1
plan: true
test_scenario: smoke-inbox
---

## Symptom
User-Inbox zeigt "Aktualisiert (0)" obwohl 42 Vorschläge + 53 Unklassifizierte
da sind. Erwartung: Versand-Mails sollten existierende Deals updaten
(Status `Bestellt` → `Unterwegs`, mit Tracking-Nummer + Carrier).

## Diagnose-Schritte

1. Prüfe `parsed_messages`-Tabelle in Supabase: wie viele Rows haben
   `status='matched'`? Sollten ≈ #VersandMails sein.
2. Prüfe die Adapter in `supabase/functions/_shared/inbox_adapters/`:
   gibt es Versand-/Tracking-Update-Branches? Oder nur
   Bestellbestätigungs-Parser?
3. Prüfe `inbox-parse` Edge Function: matched Order-IDs gegen existing
   `deals.shop_order_id` UND aktualisiert Deal-Status korrekt?

## Was zu tun ist

Pro Top-8-Shop (Amazon DE/COM/FR/IT/ES/UK, eBay, Zalando, Nike/SNKRS,
Adidas/Confirmed, StockX, Otto, About You):

1. Versand-Mail-Pattern erkennen (deutsche + englische Subject-Lines wie
   "Versandbestätigung", "Your order has shipped", "Wurde versendet" etc.)
2. Tracking-Nummer extrahieren (`<tracking>` aus Body — oft via Carrier-
   Domain-Match `<tracking-number>` neben `dhl.de`, `ups.com`, etc.)
3. `inbox-parse` Update-Branch:
   - Wenn Mail = Versand-Update UND `parsed_messages.shop_order_id` matched
     existing `deals.shop_order_id` für gleichen Workspace:
     - `deals.status` auf `Unterwegs` setzen (falls aktuell `Bestellt`)
     - `deals.tracking_number` setzen (falls leer)
     - `deals.carrier_id` setzen via Carrier-Detection
     - `parsed_messages.status` = `'matched'`
     - Activity-Log-Eintrag

Plus: Ankunft-Mails ("Lieferung zugestellt") → `deals.arrival_date`,
`deals.status` auf `Angekommen`.

## Tests

- `test/services/inbox_match_service_test.dart` (neu/erweitert): pro
  Shop 1× Bestellbestätigung + 1× Versand-Update + 1× Storno mit
  Mock-Mail-Body, prüfe dass Adapter-Output korrekt.
- `flutter test` 70+ grün.

## Akzeptanz

- In der App-Inbox: nach erneutem Polling steht "Aktualisiert (>0)".
- Mind. 1 existing Deal hat nach Test seinen Status auf `Unterwegs`
  geändert (in der Demo-DB sichtbar).
- `smoke-inbox` Visual-Test passed.

## Hinweis

Du arbeitest auf opus ohne Budget-Cap. Gründlich, nicht schnell.
Edge-Function-Code in `supabase/functions/_shared/inbox_adapters/`
+ `supabase/functions/inbox-parse/index.ts`. Kein `supabase db push`
gegen Prod.
