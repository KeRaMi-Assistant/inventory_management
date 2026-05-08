# Forensik-Memo: Galaxus (CH/DE)

## Real-Daten-Basis

- **DB-Sample:** 2 Mails — `unclassified`. Sender:
  `noreply@notifications.galaxus.de`. Kein Adapter, deshalb kein
  Body-Persistenz.

## Mail-Lifecycle

1. "Bestellbestätigung Nr. <ORDER>"
2. "Versandbestätigung — Bestellung <ORDER>"
3. "Lieferbestätigung — Bestellung <ORDER>"
4. "Stornierung — Bestellung <ORDER>"

Galaxus betreibt sowohl `galaxus.de` (DE) als auch `galaxus.ch` (CH);
Mails kommen einheitlich von `notifications.galaxus.de`.

## Verfügbare Datenpunkte (Template-based)

### Order-ID-Format

`(?:Bestellung|Order)\s+(?:Nr\.?|#)?\s*(\d{8,12})` — typischerweise
9–10-stellig numerisch.

### Tracking

Galaxus nutzt für CH die Schweizer Post (`Track & Trace`-Pattern), für
DE überwiegend DHL/DPD. Pattern wird via `findAllTrackings` abgedeckt;
zusätzlich CH-Post-spezifisch:
```
Sendungs-Nummer: 99.00.123456.00012345
```

Pattern: `\b(\d{2}\.\d{2}\.\d{6}\.\d{8})\b` für CH-Post.

### Order-Total (`order_total`)

```
Endbetrag inkl. MwSt:    1'299.00 CHF
Endbetrag inkl. MwSt:    1.299,00 €
```

CH-Format mit Apostroph als Tausender-Trenner. Pattern muss beide
Formate akzeptieren.

### Items (`items[]`)

```
1   Apple iPhone 15 Pro 256 GB Titan Schwarz   1'199.00 CHF
1   Anker Powerbank 20000mAh                       49.95 CHF
```

### Currency

`CHF` für Galaxus.ch (default für Mails an CH-Empfänger), `EUR` für
Galaxus.de. Heuristik via Body-Suchstring (`CHF` vs `€`).

### ETA-Datum (`eta_date`)

```
Voraussichtlicher Versand: 17. März 2026
Voraussichtliche Lieferung: 18.-21. März 2026
```

DE-Wort-Format `17. März` → manuelles Monats-Mapping nötig
(`März → 03`).

### Lieferart (`delivery_method`)

```
Versandart: Post Standard
Versandart: Post PRIORITY (CH)
Versandart: Selbstabholung Filiale Zürich
```

## Adapter-Implementation (Neu)

```ts
const galaxus: Adapter = {
  key: 'galaxus',
  label: 'Galaxus',
  matches: (ctx) => /(@|\.)(?:[a-z.]+\.)?galaxus\.(de|ch|com)\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => { /* ... */ }
}
```

## Coverage-Erwartung

- `order_id`: ≥ 95%
- `order_total`: ≥ 80%
- `items[]`: ≥ 60%
- `eta_date`: ≥ 70%
