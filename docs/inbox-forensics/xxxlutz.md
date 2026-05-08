# Forensik-Memo: XXXLutz (DE/AT — Marketplace + Hauptshop)

## Real-Daten-Basis

- **DB-Sample:** 3 Mails (`unclassified`). Sender:
  `noreply@marktplatz.xxxlutz.de`, `noreply@marketplace.xxxlgroup.com`.

## Mail-Lifecycle

1. "Bestellung eingegangen — XXXLutz"
2. "Versandbestätigung — XXXLutz"
3. "Lieferung erfolgt — XXXLutz"
4. "Bestellung storniert — XXXLutz"

XXXLutz ist primär Möbel/Wohnen — Lieferungen sind häufig
Sperrgut-Versand (Speditionsdienst, kein Standard-Paket-Carrier).

## Verfügbare Datenpunkte

### Order-ID

`(?:Auftrags?nummer|Bestellnummer)\s*[:#]?\s*([A-Z0-9]{6,15})` —
Format `MP\d{8}` für Marktplatz, `XXL\d{6}` für Hauptshop.

### Carrier — Speditionen

XXXLutz nutzt für Großmöbel Spezial-Speditionen:
```
Versand durch: Schenker
Versand durch: Hellmann Worldwide Logistics
Versand durch: DHL Sperrgut
```

Wir setzen `delivery_method='partner'` und speichern
`carrier='Schenker'/'DHL Sperrgut'/...` direkt — diese Carrier sind in
unserer `tracking_adapters.ts`-Map nicht alle bekannt; Tracking-Status
muss manuell vom User abgefragt werden.

### Order-Total

```
Gesamtsumme:    1.299,00 €
inkl. MwSt
```

### Items

```
Pos.   Bezeichnung                        Menge   Einzelpreis    Gesamt
1      MOEMAX Sofa Lyon 3-Sitzer          1      999,00 €       999,00 €
2      Schmutzfänger-Matte (Service)      1       99,00 €        99,00 €
```

### ETA-Datum

```
Voraussichtlicher Liefertermin: 15.05.2026
Voraussichtlicher Liefertermin: KW 22 (Mai 2026)
```

KW-Pattern (Kalenderwoche) → Wir speichern als Range-Start (Montag der
KW). Pattern: `KW\s+(\d{1,2})\s+\((\w+)\s+(\d{4})\)`.

### Tax-Rate

```
MwSt 19%:        207,40 €
```

### Sperrgut-Hinweis (`metadata.bulk_delivery`)

```
Bitte beachten: Der Artikel ist sperrgutpflichtig. Die Spedition
kontaktiert Sie 1-2 Tage vor Lieferung zur Terminvereinbarung.
```

Wir setzen `metadata.bulk_delivery = true`, weil der User wissen will,
dass er telefonisch erreichbar sein muss.

## Adapter-Implementation (Neu)

```ts
const xxxlutz: Adapter = {
  key: 'xxxlutz',
  label: 'XXXLutz',
  matches: (ctx) => /(@|\.)(?:[a-z.]+\.)?(?:xxxlutz|xxxlgroup)\.(de|at|com|cz|sk|pl|hu)\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => { /* ... */ }
}
```

Carrier-Override: wenn `Versand durch: Schenker/Hellmann` im Body, dann
`carrier='Schenker'` (Display) und `delivery_method='partner'`.

## Coverage-Erwartung

- `order_id`: ≥ 90%
- `order_total`: ≥ 75%
- `items[]`: ≥ 60%
- `eta_date`: ≥ 70%
- `delivery_method='partner'` (Spedition): ≥ 50%
