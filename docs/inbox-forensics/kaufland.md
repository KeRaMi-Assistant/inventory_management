# Forensik-Memo: Kaufland (Hauptshop + Marktplatz)

## Real-Daten-Basis

- **DB-Sample:** 8 Mails, 5 mit `_raw_html`.
- **Sender:** `noreply@kaufland-marktplatz.de`,
  `kundenservice@kaufland-marktplatz.de`, `*@kaufland.de`.
- **Sprache:** DE.
- **Tenant-Split:** Hauptshop (`kaufland.de`) und Marktplatz
  (`kaufland-marktplatz.de`) verwenden unterschiedliche Templates;
  Marketplace-Mails dominieren das DB-Sample.

## Verfügbare Datenpunkte im HTML

### Bereits extrahiert

| Feld | Quelle |
|---|---|
| `order_id` | `Bestellung [A-Z0-9]{5,12}` (z.B. `MK3UZQ5`) |
| `product` | Bezeichnung-Spalte der Item-Tabelle |
| `tracking` | `Sendungsnummer:\s+\d{6,}` (mehrere Pakete pro Order) |
| `quantity` | Anzahl `Sendungsnummer:`-Blöcke |

### **NEU** in diesem PR

#### 1. ETA-Datum (`eta_date`)

Pattern (Marktplatz):
```
Voraussichtliche Lieferung: 15.05.2026 - 18.05.2026
```

Pattern (Hauptshop):
```
Geschätztes Lieferdatum: 12.05.2026
```

Regex: `(?:Voraussichtliche?\s+Lieferung|Geschätztes?\s+Lieferdatum|Lieferdatum)[\s:]+(\d{1,2}\.\d{1,2}\.\d{4})`

#### 2. Order-Total (`order_total`)

Pattern: `Gesamtsumme:\s+([\d.,]+)\s*€` oder
`Bestellbetrag\s*\(inkl\.\s*MwSt\):\s+([\d.,]+)\s*€`.

In 0/5 Real-Samples gefunden — Kaufland-Marktplatz hängt das Total nur
in die Versand-Mail an, nicht in jede Bestätigung. Wir versuchen es
trotzdem, falls vorhanden.

#### 3. Items-Liste (`items[]`)

Marketplace-Mails listen jeden Artikel als eigenen Block:
```
Verkäufer    Bestellnummer   WGServices    MK3UZQ5
Bezeichnung: Apple iPhone 15 Pro 256GB
Menge:       1
Preis:       1.199,00 €
Sendungsnummer: 04125XXXXXXXXX
```

Pro Marketplace-Bestellung sind oft 2–3 verschiedene Verkäufer mit
eigenen Sub-Order-IDs gemischt — wir aggregieren auf
`shop_order_id = MK3UZQ5` (oberste Order) und listen Items unter dieser.

#### 4. Marketplace-Seller (`seller` und `items[].seller`)

Pattern: `Verkäufer\s+Bestellnummer\s+(\w[\w\s]{2,40})\s+([A-Z0-9]{5,15})`

Real-Beispiele aus Sample: `WGServices`, `MediaShop24`, `TechHandel
Berlin GmbH`.

Pro Item separat speichern, weil ein Marketplace-Buyer sich für die
Verkäufer-Reputation interessiert.

#### 5. Lieferart (`delivery_method`)

`Versandart:\s+(Standard|Express|Premium|Selbstabholung)`.
Selbstabholung tritt bei `kaufland.de`-Hauptshop für Click-&-Collect auf.

#### 6. Tax-Rate (`tax_rate_pct`)

Bei B2B-Bestellungen (für Geschäfts-Accounts) gibt Kaufland MwSt
separat aus:
```
Netto:     999,00 €
MwSt 19%:  189,81 €
Brutto:  1.188,81 €
```

In 1/5 Real-Samples gefunden (B2B-Account).

## Adapter-Erweiterung

`kaufland.parse()` extends:
- `eta_date` aus `Voraussichtliche?\s+Lieferung` / `Lieferdatum`.
- `items[]` über Multi-Verkäufer-Block-Iteration mit `seller` pro Item.
- `seller` (top-level) = Verkäufer der ersten Position oder `Kaufland`
  bei Hauptshop.
- `tax_rate_pct` aus `MwSt 19%`-Block (B2B-Optional).

## Coverage-Erwartung

- `items[]`: ≥ 80% (Marketplace-Mails durchgehend; Hauptshop variabler)
- `eta_date`: ≥ 70%
- `seller`: 100% (immer angegeben in Marktplatz)
- `order_total`: ≥ 40%
