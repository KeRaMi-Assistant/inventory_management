# Forensik-Memo: Dell (Direct-Shop)

## Real-Daten-Basis

- **DB-Sample:** 4 Mails (alle als `unclassified` — kein Adapter
  vorhanden, deshalb kein HTML in `parsed_payload._raw_html`).
- **Sender:** `order@dell.com`, `noreply@order.dell.com`,
  `customercare@dell.com`.
- **Sprache:** EN/DE — Dell schickt englische Bestellbestätigungen
  und deutsche Versand-Updates.

## Mail-Lifecycle (Public Knowledge)

1. "Order Confirmation: <Product>" — direkt nach Kauf.
2. "Your Dell Order is Being Processed" — 1–3 Tage später.
3. "Your Dell Order has Shipped" — Versand-Update mit Tracking.
4. "Your Dell Order has been Delivered" — Zustellung.
5. "Order Cancellation Confirmation".

## Verfügbare Datenpunkte (Template-based)

### Order-ID-Format

Dell-Order-IDs sind 9-stellige numerische Codes mit "Order Number" oder
"Bestellnummer":
```
Order Number: 123456789
Bestellnummer: 123456789
```

Pattern: `(?:Order\s+(?:Number|#)|Bestellnummer)\s*[:#]?\s*(\d{8,10})`.

### Tracking

Dell nutzt UPS, FedEx oder DHL:
```
Tracking Number: 1Z999AA10123456784
Carrier: UPS
```

### Order-Total (`order_total`)

```
Order Total:        $1,299.99
Bestellsumme:       1.299,99 €
```

### Items (`items[]`)

```
Dell XPS 15 9530 Laptop                1     $1,499.99
Dell Pro Wireless Mouse                1       $24.99
```

### Tax-Rate (`tax_rate_pct`)

```
VAT (19%):           247.20 €
Sales Tax (8.875%):   $115.41
```

### ETA-Datum (`eta_date`)

```
Estimated Delivery: March 15-17, 2026
Voraussichtliche Lieferung: 15.03.2026
```

### Configuration-Code (`metadata.dell_config_code`)

Dell-Spezifikum: jede Bestellung hat einen `Dell Configuration Code`
(8-stellig alphanumerisch), der die genaue Hardware-Konfiguration
identifiziert. Wir speichern ihn als Metadata, weil das Service-Team
ihn manchmal für Support-Anfragen referenziert.

## Adapter-Implementation (Neu)

```ts
const dell: Adapter = {
  key: 'dell',
  label: 'Dell',
  matches: (ctx) => /(@|\.)(?:[a-z.]+\.)?dell\.com\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => {
    // order_id, tracking, items, order_total, eta_date, tax_rate_pct, …
  }
}
```

## Coverage-Erwartung

(Schätzung; kein DB-Body-Sample)
- `order_id`: ≥ 95%
- `tracking`: ≥ 80% (Versand-Mails)
- `order_total`: ≥ 70%
- `items[]`: ≥ 60%
- `eta_date`: ≥ 50%

Mit dem neuen Adapter werden die 4 bestehenden `unclassified`-Mails
beim nächsten Re-Parse-Run einen `shop_key='dell'` bekommen, ihr
HTML wird ab dem nächsten Inbox-Poll gespeichert (für die ohne
Tracking-Match).
