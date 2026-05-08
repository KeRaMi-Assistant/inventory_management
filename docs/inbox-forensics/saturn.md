# Forensik-Memo: Saturn

## Real-Daten-Basis

- **DB-Sample:** 5 Mails, 3 mit `_raw_html`. Alle Order-Confirmations.
- **Sender:** `noreply@saturn.de`, `service@saturn.de`.
- **Sprache:** DE.
- **Konzern-Beziehung:** Saturn ist Schwester-Marke von MediaMarkt
  (Ceconomy AG) — Mail-Templates sind nahezu identisch zu
  MediaMarkt, nur Branding (Logo, Farben) abweichend.

## Verfügbare Datenpunkte im HTML

### Bereits extrahiert

| Feld | Quelle |
|---|---|
| `order_id` | `Bestellnummer: \d{6,15}` |
| `product` | Article-Table (`productFromArticleTable`) |
| `tracking` | Versand-Mail (Sendungsnummer-Block) |

### **NEU** in diesem PR

#### 1. ETA-Datum (`eta_date`)

Pattern wie MediaMarkt:
```
Lieferung bis Donnerstag, 12.03.2026
```

Saturn nutzt zusätzlich für Marktplatz-Items:
```
Voraussichtlicher Liefertermin: 14.03.2026 — 18.03.2026
```
→ wir nehmen das frühere Datum.

#### 2. Order-Total (`order_total`)

Pattern: `Gesamtsumme:\s*inkl\.\s*MwSt\s+([\d.,]+)\s*Euro` (identisch zu
MediaMarkt). Verfügbar in 1/3 Real-Samples (Order-Mails).

Auch: `Gesamtbetrag\s+([\d.,]+)\s*€` (kürzere Saturn-Mails).

#### 3. Items-Liste (`items[]`)

Article-Table identisch zu MediaMarkt-Format:
```
Anzahl  Artikelnummer und Beschreibung   Lieferung   Einzelpreis   Summe
1       3145678 SONY KD-65X95L OLED TV   Lieferung … 1.499,00 €    1.499,00 €
```

#### 4. Shipping-Address-Country (`shipping_address_country`)

`Lieferanschrift\s*:.*\s+(DE|AT|CH|NL|ES|HU|PL)\s` — wie MediaMarkt.

#### 5. Payment-Method (`payment_method`)

Beispiele: `PayPal`, `Klarna`, `Kreditkarte`, `Vorkasse`.

## Adapter-Erweiterung

Saturn-Adapter teilt sich Helper-Funktionen mit MediaMarkt
(`extractEtaDate`, `extractOrderTotal`, `extractItems`).

## Coverage-Erwartung

- `eta_date`: ≥ 90% in Order-Mails (Article-Table immer da).
- `order_total`: ≥ 65% (Versand-Mails ohne Total).
- `items[]`: ≥ 80%.

Pattern-Inheritance reduziert Wartungsaufwand: jede Saturn-Verbesserung
profitiert MediaMarkt automatisch und umgekehrt.
