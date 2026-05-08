# Forensik-Memo: Anker

## Real-Daten-Basis

- **DB-Sample:** 4 Mails, 2 mit `_raw_html`. Eher schlanke Templates.
- **Sender:** `noreply-service@anker.com`, `support@anker.com`,
  `service@de.anker.com`.
- **Sprache:** EN/DE-Hybrid (Anker schickt englische Templates auch
  an deutsche Kunden, Subject lokalisiert).

## Verfügbare Datenpunkte im HTML

### Bereits extrahiert

| Feld | Quelle |
|---|---|
| `order_id` | `R\d{12,15}S?` (z.B. `R030101520991S`) |
| `product` | Item-Block / Subject |
| `tracking` | im Versand-Mail href |

### **NEU** in diesem PR

#### 1. Order-Total (`order_total`)

Pattern: `Order\s+Total:\s+\$?([\d.,]+)` oder
`Gesamtsumme:\s+([\d.,]+)\s*€`. Anker rechnet je nach Region in EUR/USD.

#### 2. Items-Liste (`items[]`)

Item-Block (klassisches Shopify-artiges Layout):
```
Anker Soundcore Liberty 4 NC
Color: Cloud White
Quantity: 1
Price: $99.99
```

Pattern:
```ts
/(?<name>[A-Z][A-Za-z0-9 \-+./]{4,80})\s+(?:Color|Farbe|Variant)[^\n]*\n.*?Quantity[:\s]+(?<qty>\d{1,3}).*?(?:Price|Preis)[:\s]+\$?(?<price>[\d.,]+)/gs
```

#### 3. ETA-Datum (`eta_date`)

Pattern: `Estimated\s+delivery:\s+(\w+\s+\d{1,2},?\s+\d{4})` oder
`Voraussichtliche\s+Lieferung:\s+(\d{1,2}\.\d{1,2}\.\d{4})`.

EN-Datums-Format `Mar 15, 2026` → konvertieren zu ISO-Datum.

#### 4. Shipping-Method (`delivery_method`)

`Shipping Method:\s+(Standard|Express|Priority|Premium)`.

#### 5. Tracking-Carrier-Hinweis (`carrier`)

Anker nutzt typischerweise DHL (DE), USPS (US), DPD (UK). Im Body steht
`Carrier:\s+(DHL|UPS|FedEx|USPS|DPD)` separat zum Tracking-Link.
Wenn vorhanden, überschreibt es die URL-Heuristik.

## Adapter-Erweiterung

`anker.parse()` extends:
- `order_total` aus `Order Total`.
- `items[]` aus EN-Shopify-Layout (Multi-Item-fähig).
- `eta_date` aus `Estimated delivery`.
- `carrier` overrides aus `Carrier:`-Label.

## Coverage-Erwartung

- `order_total`: ≥ 75%
- `items[]`: ≥ 80% (Order-Mails)
- `eta_date`: ≥ 50% (nicht in jeder Mail)

Anker ist eines der "ärmeren" Sample-Sets (nur 2 mit HTML), Patterns
basieren auf öffentlich dokumentierten Anker-Mail-Templates und den
zwei vorhandenen DB-Bodies.
