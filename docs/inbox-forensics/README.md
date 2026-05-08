# Inbox Forensics — Cross-Shop HTML-Body Datapoints

Diese Memos dokumentieren, welche Daten in den HTML-Bodies der eingehenden
Shop-Mails verfügbar sind, welche der Adapter bereits extrahiert und
welche Patterns für noch fehlende Felder verwendet werden können.

## Forensik-Ablauf

1. **Sample-Pull (read-only):** `parsed_messages.parsed_payload->>'_raw_html'`
   wird über Supabase-MCP abgefragt. HTML wird mit `<style>`+Tag-Strip
   linearisiert.
2. **PII-Redaction PFLICHT** für jede committete Fixture:
   - Empfänger-Name → `Test User` o.ä.
   - Adresse → `Musterstraße 1, 12345 Musterstadt, DE`
   - Email → `customer@example.test`
   - Order-ID → erste 4 Zeichen behalten (`306-XXXX-XXXX`).
3. **Pattern-Memo** pro Shop: was ist da, was fehlt, welcher Regex/Selector.
4. **Adapter-Erweiterung** (siehe `supabase/functions/_shared/inbox_adapters.ts`).
5. **Live-Verifikation** über MCP-Coverage-Queries nach Re-Parse.

## Coverage-Übersicht (Stand 2026-05-08)

| Shop | DB-Mails | mit HTML | Forensik | Adapter | Neue Felder |
|---|---|---|---|---|---|
| amazon | 109 | 79 | ✅ Real-Daten | ✅ Erweitert | tracking, eta, shipped_at, total, items, seller |
| mediamarkt | 173 | 51 | ✅ Real-Daten | ✅ Erweitert | tracking, eta, total, items |
| kaufland | 8 | 5 | ✅ Real-Daten | ✅ Erweitert | total, items, eta |
| pccomponentes | 6 | 4 | ✅ Real-Daten | ✅ Erweitert | tax_rate, total, items, eta |
| saturn | 5 | 3 | ✅ Real-Daten | ✅ Erweitert | total, items, eta |
| anker | 4 | 2 | ✅ Real-Daten | ✅ Erweitert | total, items |
| euronics | 4 | 1 | ✅ Real-Daten | ✅ Erweitert | total, items |
| xkom | 6 | 0 | ⚠️ Adapter-only | ✅ Erweitert | total, items |
| lego | 0 | 0 | ⚠️ Adapter-only | ✅ Erweitert | total, items |
| tink | 0 | 0 | ⚠️ Adapter-only | ✅ Erweitert | total, items |
| dell | 4 | 0 | ⚠️ Neu (nur From) | ✅ Neu | from-only Initialerkennung |
| galaxus | 2 | 0 | ⚠️ Neu (nur From) | ✅ Neu | from-only Initialerkennung |
| alza | 2 | 0 | ⚠️ Neu (nur From) | ✅ Neu | from-only Initialerkennung |
| ebay | 3 | 0 | ⚠️ Neu (nur From) | ✅ Neu | from-only Initialerkennung |
| xxxlutz | 3 | 0 | ⚠️ Neu (nur From) | ✅ Neu | from-only Initialerkennung |

## Generic Datapoint Schema (`parsed_payload`)

Jeder Adapter darf in `parsed_payload` zusätzlich folgende Felder
populieren (alle optional, `undefined` wenn HTML kein Datum liefert):

```ts
interface ParsedOrderExtras {
  /// ISO 8601 `YYYY-MM-DD`. Frühster im HTML genannter Liefertermin.
  eta_date?: string
  /// ISO 8601 `YYYY-MM-DDTHH:mm:ssZ`. Wenn die Versand-Mail explizit
  /// "versandt am ..." enthält oder ein Unix-Timestamp im Tracking-URL
  /// steckt (z.B. Amazon: `&shipmentDate=1777885378`).
  shipped_at?: string
  /// Bestellsumme inkl. MwSt.
  order_total?: { amount: number; currency: string }
  /// MwSt-Satz in Prozent. PCComponentes / spanische Shops zeigen ihn
  /// regelmäßig: "IVA (21%)".
  tax_rate_pct?: number
  /// Ländercode der Versandadresse (kein Name, keine Straße — DSGVO).
  shipping_address_country?: string
  /// Item-Liste für Multi-Article-Bestellungen.
  items?: Array<{
    product: string
    quantity: number
    unit_price?: number
    currency?: string
  }>
  /// Zustellart wenn angegeben (Amazon: "Versand mit Amazon Logistics").
  delivery_method?: 'standard' | 'express' | 'pickup' | 'partner'
  /// Storno-Grund — selten, aber Amazon/MediaMarkt liefern ihn manchmal
  /// in Storno-Bestätigungen.
  cancellation_reason?: string
  /// Verkäufer/Marketplace-Seller (Amazon/Kaufland-Marketplace).
  seller?: string
}
```

Diese Felder sind alle additiv — bestehende Konsumenten in `inbox-poll`,
`inbox-parse-runner` und der Flutter-App lesen weiterhin nur die
existierenden Top-Level-Keys (`tracking`, `order_id`, `total`, ...).
