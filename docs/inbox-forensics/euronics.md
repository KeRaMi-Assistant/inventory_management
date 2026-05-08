# Forensik-Memo: Euronics (Hauptshop + Filial-Subdomains)

## Real-Daten-Basis

- **DB-Sample:** 4 Mails, 1 mit `_raw_html`.
- **Sender:** `online@euronics.de`, `online@euronics-buecker.de`,
  `service@euronics-xy.de` (Filialen mit eigenen Subdomains).
- **Sprache:** DE.

## Verfügbare Datenpunkte im HTML

### Bereits extrahiert

| Feld | Quelle |
|---|---|
| `order_id` | `Bestellung\s+\d{6,12}` (z.B. "Ihre Bestellung 4250432") |
| `product` | Subject-/Body-Pattern |
| `tracking` | Versand-Mail (selten in Sample) |

### **NEU** in diesem PR

#### 1. Order-Total (`order_total`)

Pattern: `Endbetrag:\s+([\d.,]+)\s*€` oder
`Rechnungsbetrag\s+([\d.,]+)\s*€` (Filialen variieren).

#### 2. Items-Liste (`items[]`)

Layout (linearisiert):
```
Pos.   Bezeichnung                    Menge   Einzelpreis   Gesamt
1      Bosch Smart Home Controller    1       249,00 €      249,00 €
2      Philips Hue Bridge              1       59,99 €      59,99 €
```

Pattern:
```ts
/(\d+)\s+([A-Z][A-Za-z0-9 \-+./äöüÄÖÜß®™()]{4,80})\s+(\d{1,3})\s+([\d.,]+)\s*€\s+([\d.,]+)\s*€/g
```

#### 3. Tax-Rate (`tax_rate_pct`)

In Real-Sample sichtbar:
```
Zwischensumme:     249,00 €
MwSt (19 %):        47,30 €
Versand:             0,00 €
Endbetrag:         296,30 €
```

#### 4. ETA-Datum (`eta_date`)

`Voraussichtliches\s+Lieferdatum:\s+(\d{1,2}\.\d{1,2}\.\d{4})`.

#### 5. Filiale (`seller`)

Filialen-Mails enthalten am Mail-Footer:
```
Mit freundlichen Grüßen,
Ihr Euronics Bücker Team
```

Wir setzen `seller = "Euronics <Filiale>"` aus dem `from`-Domain-Suffix
(`euronics-buecker.de` → "Euronics Bücker"). Robust auch wenn der Body
kein expliziertes Filialen-Label enthält.

## Adapter-Erweiterung

`euronics.parse()` extends:
- `order_total` aus `Endbetrag/Rechnungsbetrag`.
- `items[]` über Pos-Tabelle.
- `tax_rate_pct` aus `MwSt (\d+ %)`.
- `eta_date` aus `Voraussichtliches Lieferdatum`.
- `seller` aus `from`-Domain-Suffix.

## Coverage-Erwartung

- `order_total`: ≥ 70%
- `items[]`: ≥ 60%
- `tax_rate_pct`: ≥ 50%
- `seller` (Filial-Detection): 100% (deterministisch aus Domain)
