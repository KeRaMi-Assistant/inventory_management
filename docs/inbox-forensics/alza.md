# Forensik-Memo: Alza (CZ/SK/DE/AT/HU/UK)

## Real-Daten-Basis

- **DB-Sample:** 2 Mails (`unclassified`). Sender: `noreply@alza.de`,
  `info@alza.de`.

## Mail-Lifecycle (Template-based)

1. "Order confirmation - Alza.de (Order #X)"
2. "Your order has been shipped - Alza.de"
3. "Delivery scheduled - Alza.de"
4. "Order cancelled - Alza.de"

## Verfügbare Datenpunkte

### Order-ID

Alza-Order-IDs sind 12-stellig numerisch:
```
Order Number: 102456789012
Bestellnummer: 102456789012
```

Pattern: `(?:Order\s+(?:Number|#)|Bestellnummer)\s*[:#]?\s*(\d{10,14})`.

### Tracking

DPD oder Tschechische Post (CZ) — `findAllTrackings` deckt DPD.
CZ-Post-Tracking:
```
Sledovací číslo: RR123456789CZ
```

Pattern: `\b(RR\d{9}CZ|CD\d{9}CZ)\b`.

### Order-Total

```
Order total:        499.00 €
Celkem k úhradě:   12.499 Kč
```

CZ-Format mit Whitespace als Tausender-Trenner und `Kč`. Currency CZK
für `alza.cz`-Endpoints, EUR für `alza.de`/`alza.at`, GBP für
`alza.co.uk`.

### Items

```
Pos.   Description                         Qty   Price
1      Logitech MX Master 3S                1    109.00 €
2      Samsung 980 Pro 1TB SSD              1     99.00 €
```

### ETA-Datum

```
Estimated delivery: March 18-22, 2026
Voraussichtliche Lieferung: 18.03.2026
```

### Tax-Rate

```
VAT (21%):    87.00 €
```

CZ default 21%, AT 20%, DE 19%, UK 20%, HU 27%.

## Adapter-Implementation (Neu)

```ts
const alza: Adapter = {
  key: 'alza',
  label: 'Alza',
  matches: (ctx) => /(@|\.)alza\.(de|cz|sk|at|hu|co\.uk)\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => { /* ... */ }
}
```

Currency-Detection via Sender-Domain:
- `.cz` → `CZK`
- `.de`/`.at` → `EUR`
- `.co.uk` → `GBP`
- `.hu` → `HUF`

## Coverage-Erwartung

- `order_id`: ≥ 90%
- `tracking`: ≥ 70%
- `order_total`: ≥ 80%
- `items[]`: ≥ 50%
