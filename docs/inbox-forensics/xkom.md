# Forensik-Memo: x-kom (Polen)

## Real-Daten-Basis

- **DB-Sample:** 6 Mails, 0 mit `_raw_html` (alle Versand-Updates ohne
  Body-Persistenz, weil Tracking schon extrahiert).
- **Sender:** `noreply@x-kom.pl`, `info@x-kom.pl`,
  `kontakt@x-kom.de` (DE-Eintritt).
- **Sprache:** PL primär, DE-Subdomain ist neuer.

## Verfügbare Datenpunkte (Knowledge-based)

Da kein HTML-Body in der DB liegt, basiert dieses Memo auf:
- öffentlich dokumentierten x-kom Mail-Templates,
- den 6 DB-Mails (nur Subject + From + Tracking),
- bestehenden Adapter-Patterns in `inbox_adapters.ts`.

### Bereits extrahiert

| Feld | Quelle |
|---|---|
| `order_id` | `Zamówienie nr. \d{4}/\d{2,6}` |
| `tracking` | InPost / DPD via `findAllTrackings` |
| `product` | Subject (`productFromSubject`) |

### **NEU** in diesem PR

#### 1. Order-Total (`order_total`)

Pattern PL: `Razem:\s+([\d\s.,]+)\s*(?:zł|PLN)`.
Pattern DE: `Gesamtsumme:\s+([\d.,]+)\s*€`.

PLN nutzt häufig Format `1 999,99 zł` mit Whitespace als
Tausender-Trenner — wir normalisieren via `replace(/\s/g, '')` vor
`parseMoney`.

#### 2. Items-Liste (`items[]`)

Klassisches PL-Layout:
```
Produkt                                 Ilość   Cena
Logitech G502 HERO                      1        249,00 zł
Razer DeathAdder V2                     2        199,00 zł
```

Pattern: `(?<name>[A-Z][A-Za-z0-9 ]{4,80})\s+(?<qty>\d{1,3})\s+(?<price>[\d\s.,]+)\s*zł`.

#### 3. ETA-Datum (`eta_date`)

`Przewidywana\s+dostawa:\s+(\d{1,2}\.\d{1,2}\.\d{4})` oder
`Voraussichtliche\s+Lieferung:\s+(\d{1,2}\.\d{1,2}\.\d{4})`.

#### 4. Carrier-Detection (`carrier`)

x-kom nutzt überwiegend InPost-Paketshops:
```
Sposób dostawy: InPost Paczkomat
```

Wir setzen `delivery_method = 'pickup'` wenn `Paczkomat` im Body steht,
sonst `standard`.

#### 5. Currency

Default `PLN` für `x-kom.pl`-Sender. `EUR` für `x-kom.de`-Sender
(Subdomain-basiert).

## Adapter-Erweiterung

`xkom.parse()` extends:
- `order_total` aus `Razem` / `Gesamtsumme` mit PL-Whitespace-Cleanup.
- `items[]` aus PL-Tabelle.
- `eta_date` aus `Przewidywana dostawa` / `Voraussichtliche Lieferung`.
- `delivery_method` Heuristik via `Paczkomat`-Keyword.
- `currency` aus Sender-Domain.

## Coverage-Erwartung

Da DB-Sample keine Body-Daten enthält, ist die Coverage-Schätzung
experimentell basiert auf Template-Strukturen:
- `order_total`: ≥ 70% (Order-Mails sollten `Razem` enthalten)
- `items[]`: ≥ 60%
- `eta_date`: ≥ 40%
- `delivery_method`: 100% (InPost als Default)

Nach Re-Parse mit ankommenden Mails sollten echte Coverage-Werte
beobachtbar werden.
