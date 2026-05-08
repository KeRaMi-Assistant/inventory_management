# Forensik-Memo: Amazon (DE/COM/UK/FR/IT/ES)

## Real-Daten-Basis

- **DB-Sample:** 109 Mails, 79 mit `_raw_html` (60 KB Cap pro Row).
- **Sender:** `auto-confirm@amazon.de`, `shipment-tracking@amazon.de`,
  `shipment-tracking@business.amazon.de`, `auto-confirm@business.amazon.de`.
- **Sprachen:** überwiegend DE; Subset `.com`/`.co.uk` EN, `.fr` FR,
  `.it` IT, `.es` ES.
- **Mail-Lifecycle:**
  - "Wir haben deine Bestellung erhalten" / "Your Amazon order #..."
  - "Deine Amazon-Bestellung mit „<Produkt>" wurde versandt!"
  - "Lieferung deiner Amazon-Bestellung verzögert sich"
  - "Deine Amazon-Bestellung wurde zugestellt"
  - "Stornierung der Bestellung deine Amazon-Bestellung #..."

## Verfügbare Datenpunkte im HTML

### Bereits extrahiert (Stand vor diesem PR)

| Feld | Quelle | Pattern |
|---|---|---|
| `order_id` | Body + URL | `\b(\d{3}-\d{7}-\d{7})\b` |
| `product` | Title-Attribut + Body | `productFromSubject` + `Item(s):` |
| `tracking` | href im "Sendung verfolgen"-Button | `track.amazon.de/tracking/TBA…` |
| `carrier` | URL-Pattern + Body | TBA → Amazon Logistics, 1Z → UPS |
| `total` (teilweise) | "Order Total"/"Gesamtbetrag" | `Gesamtbetrag\s*[:\s]+([^\n]{1,40})` |
| `status` | Subject + Body | `detectShipStatus` |

### **NEU** in diesem PR — verfügbar im HTML, aber bisher nicht extrahiert

#### 1. ETA-Datum (`eta_date`)

Pattern A — Wochentag + Tag + Monat (DE):
```
Zustellung:
Dienstag, 5 Mai
```

Pattern B — embedded Unix-Timestamp im Track-URL:
```
…&latestArrivalDate=1778004000&…
```
→ `new Date(1778004000 * 1000).toISOString().slice(0, 10)` = `2026-05-05`.

In 43 von 79 HTML-Bodies (~54%) verfügbar (entweder Pattern A oder B).

#### 2. Shipped-At-Timestamp (`shipped_at`)

Eingebettet im Tracking-URL als Query-Param:
```
…&shipmentDate=1777885378&orderingShipmentId=109611089925302&…
```
→ `2026-05-04T09:02:58.000Z`.

In 27 von 79 (~34%) Versand-Mails gegeben (alle, die einen
Tracking-Button haben).

#### 3. Order-Total (`order_total.amount` + `currency`)

Pattern explicit:
```
Gesamtbetrag der Bestellung:        EUR 124,44
```

Verfügbar in 46 von 79 (~58%). In Versand-Mails als Recap, in
Bestellbestätigungen mehrfach (Zwischensumme, Versand, Total).

#### 4. Items-Liste (`items[]`)

Strukturierter Block pro Artikel (rio_asin_card):
```
Samsung 870 EVO SATA III 2,5 Zoll SS...
Verkauft von: Amazon EU S.a.r.L.
EUR 124,44
```

Pattern: nach `<title>Amazon.de Customer Service</title>` kommt erst
Hero-Headline, dann ein wiederholter Block:
```
<a … title="<PRODUKT>" …>
…
Verkauft von: <SELLER>
…
EUR <PREIS>
```

Pro Mail typischerweise 1–4 Items. Multi-Item-Detection funktioniert
über mehrfaches `title="Samsung … "`-Match in der Block-Reihenfolge.

#### 5. Seller (`seller`)

Pattern: `Verkauft von:\s+([^,\n.]{1,60})` (DE)
oder `Sold by:\s+([^,\n.]{1,60})` (EN, .com).

Beispiele aus Real-Daten: `Amazon EU S.a.r.L.`, `Invision Technik
(Deutschland)`, `Labelident`, `MUNBYNUK`. In 65/79 (~82%) verfügbar.

Wichtig für Marketplace-vs-direkt-Unterscheidung: wenn `seller` nicht
"Amazon EU" ist → Marketplace-Verkäufer.

#### 6. Delivery-Method (`delivery_method`)

Pattern in Versand-Mails:
- `Die Sendung wurde mit Amazon Logistics versandt.` → `partner`
- `Versand durch Amazon` → `standard`
- `Premium Versand` / `Prime Express` → `express`

Im Subject auch: `Same-Day Lieferung von …` → `express`.

#### 7. Cancellation-Reason (`cancellation_reason`)

In Storno-Mails (bisher noch nicht in Sample-DB), aus öffentlich
dokumentierten Templates:
```
Wir haben deine Bestellung gemäß deiner Anfrage storniert.
Grund: Änderung der Lieferadresse
```

Pattern: `Grund\s*[:\s]+([^.]{4,120})`. Robust gegen verschiedene
Ursachen (Aus Versehen bestellt, Falsche Adresse, ...).

## Adapter-Erweiterung

Implementiert in `supabase/functions/_shared/inbox_adapters.ts`:
`amazon.parse()` schreibt in `parsedExtras`:

- `eta_date` aus `latestArrivalDate`-URL-Param oder `Zustellung:`-Block.
- `shipped_at` aus `shipmentDate`-URL-Param.
- `order_total` aus `Gesamtbetrag`/`Order Total` mit Currency-Detection.
- `items[]` aus repeated `title=`-Blocks + `EUR \d+,\d+`.
- `seller` aus erstem `Verkauft von:`-Treffer.
- `delivery_method` aus Carrier-Hinweis.

## Coverage-Erwartung

Pro Versand-Mail (n=27 in Sample):
- `tracking`: ≥ 90% (war schon stark)
- `eta_date`: ≥ 70% (Unix-Timestamp + Block)
- `shipped_at`: ≥ 80% (Unix-Timestamp im URL)
- `order_total`: ≥ 70% (Gesamtbetrag-Block)
- `seller`: ≥ 80% (Verkauft-von-Block)

Nach Re-Parse aller 79 Bodies sollten ≥ 50/79 mindestens 4 neue Felder
populiert haben.
