# Forensik-Memo: tink (Smart Home Reseller)

## Real-Daten-Basis

- **DB-Sample:** 0 Mails — Adapter im Code, kein Sample.
- **Sender:** `noreply@tink.de`, `service@tink.de`.
- **Sprache:** DE.

## Mail-Lifecycle

1. "Deine Bestellung ist eingegangen"
2. "Deine Bestellung wurde verpackt"
3. "Die Lieferung ist auf dem Weg"
4. "Die Lieferung wird noch heute zugestellt"
5. "Die Lieferung wurde der Empfängerin … zugestellt"

## Verfügbare Datenpunkte (Template-based)

### Bereits extrahiert

| Feld | Quelle |
|---|---|
| `order_id` | `Bestellnummer:\s+\d{5,12}` |
| `product` | Subject |
| `tracking` | DHL/Hermes via Body |

### **NEU** in diesem PR

#### 1. Order-Total (`order_total`)

```
Gesamtsumme:    1.299,99 €
inkl. MwSt
Versand:            0,00 €
Endbetrag:      1.299,99 €
```

Pattern: `(?:Endbetrag|Gesamtsumme)[:\s]+([\d.,]+)\s*€`.

#### 2. Items-Liste (`items[]`)

tink-Standard-Layout:
```
1x   Bosch Smart Home Controller II           199,00 €
2x   Philips Hue White & Color Ambiance E27   89,99 €
```

Pattern: `(?<qty>\d+)x\s+(?<name>[A-Z][^\n]{4,140}?)\s+([\d.,]+)\s*€`.

#### 3. ETA-Datum (`eta_date`)

`Voraussichtliche\s+Lieferung:\s+(\d{1,2}\.\d{1,2}\.\d{4})` oder
`Lieferzeitraum:\s+(\d{1,2}\.\d{1,2}\.\d{4})\s*-\s*(\d{1,2}\.\d{1,2}\.\d{4})`.

#### 4. Carrier-Detection (`carrier`)

tink nutzt überwiegend DHL für Großgeräte und Hermes für Kleinware:
```
Versanddienstleister: DHL
Sendungsnummer: 00340434202012345678
```

#### 5. Tax-Rate (`tax_rate_pct`)

`MwSt\s*\((\d+)\s*%\)\s*([\d.,]+)\s*€`.

#### 6. Shipped-At (`shipped_at`)

In der "verpackt"-Mail:
```
Wir haben deine Bestellung am 14.05.2026 verpackt.
```

Pattern: `am\s+(\d{1,2}\.\d{1,2}\.\d{4})\s+verpackt`.

## Adapter-Erweiterung

`tink.parse()` extends:
- `order_total` aus `Endbetrag` / `Gesamtsumme`.
- `items[]` aus `<qty>x <name> <price>`-Layout.
- `eta_date` aus `Voraussichtliche Lieferung` / `Lieferzeitraum`.
- `shipped_at` aus `verpackt`-Mail.

## Coverage-Erwartung

(Geschätzt, kein DB-Sample)
- `order_total`: ≥ 75%
- `items[]`: ≥ 70%
- `eta_date`: ≥ 55%
- `shipped_at`: ≥ 30% (nur in verpackt-Mails)

tink ist im Pre-Launch-Status auf Adapter-Seite — wir aktivieren das
Re-Parse erst, wenn wieder Mails einlaufen.
