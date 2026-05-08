# Forensik-Memo: eBay

## Real-Daten-Basis

- **DB-Sample:** 3 Mails (`unclassified`). Sender:
  `members@ebay.com`, `members@reply.ebay.de`, `info@ebay.com`.

## Mail-Lifecycle

1. "Bestellbestätigung — <Verkäufer>"
2. "Versandbestätigung — <Verkäufer>"
3. "Lieferbestätigung — <Verkäufer>"
4. "Stornoanfrage — <Verkäufer>"

eBay-Mails sind Verkäufer-zentrisch — der Verkäufer (Marketplace-
Seller) ist ein wichtiges Datenpunkt-Feld.

## Verfügbare Datenpunkte

### Order-ID

eBay nutzt zwei Formate parallel:
- `Item Number: 123456789012` (12-stellig)
- `Order ID: 17-12345-67890` (mit Bindestrichen)

Pattern: `(?:Item\s+(?:Number|#)|Order\s+ID|Bestellnummer)\s*[:#]?\s*([A-Z0-9-]{8,30})`.

### Verkäufer (`seller`) — kritisch für eBay

```
Sold by: john_doe_2024 (4,237 ★)
Verkauft von: john_doe_2024 (4.237 ★)
```

Pattern: `(?:Sold\s+by|Verkauft\s+von)\s*[:\s]+([\w_\-]+)`.
Reputation-Score (Sterne) speichern wir NICHT — könnte Privacy-
Implikationen haben für den Verkäufer.

### Tracking

eBay schickt selten Tracking direkt — der Verkäufer schickt es. Wenn
vorhanden, kommt es via `Sendungsnummer`-Block.

### Order-Total

```
Total:        $499.99
Gesamt:       499,99 €
```

Inklusive Versand und Steuer (eBay aggregiert).

### Items

```
Apple iPhone 15 Pro 256GB Used                 1   $799.00
```

Meist nur 1 Item pro Mail (eBay aggregiert per Verkäufer in einer
Mail; Multi-Verkäufer = Multi-Mail).

### ETA-Datum

```
Estimated delivery: March 12-15, 2026
```

### Item-Condition (`metadata.condition`)

eBay-Spezifikum: jeder Item hat einen Condition-Status:
```
Condition: Used (good)
Zustand: Gebraucht (gut)
Condition: New
Zustand: Neuwertig
```

Pattern: `(?:Condition|Zustand)\s*[:]\s*([^.]{4,40})`. Speichern als
Metadata, weil das Inventory-Tracking interessieren könnte (Used vs
New ist preisbestimmend).

## Adapter-Implementation (Neu)

```ts
const ebay: Adapter = {
  key: 'ebay',
  label: 'eBay',
  matches: (ctx) => /(@|\.)(?:[a-z0-9.]+\.)?ebay\.(com|de|co\.uk|fr|it|es|nl)\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => { /* ... */ }
}
```

## Coverage-Erwartung

- `order_id`: ≥ 90%
- `seller`: ≥ 95% (eBay-zentrisch)
- `order_total`: ≥ 85%
- `tracking`: ≥ 40% (Verkäufer-abhängig)
- `condition`: ≥ 80%
