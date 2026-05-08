# Forensik-Memo: MediaMarkt

## Real-Daten-Basis

- **DB-Sample:** 173 Mails, 51 mit `_raw_html` (Mediamarkt redet viel,
  speichert aber unsere Bodies bei Match-Versand-Mails wieder weg →
  Order-Mails dominieren das HTML-Sample).
- **Sender:** `noreply@mediamarkt.de`, `service@mediamarkt.de`,
  `bestellung@mediamarkt.de` (per Sub-Tenant unterschiedlich).
- **Sprache:** DE (auch AT/CH-Subdomains in Adapter-Whitelist, aktuell
  nur DE in DB).

## Verfügbare Datenpunkte im HTML

### Real-Sample (PII-redacted Auszug aus DB)

```
…damit deine Bestellung (Bestellnummer: 3007XXXXX) schnell bei dir ist.
Du hast die Zahlungsart Klarna gewählt. …
Bestellstatus:  Deine Bestellung ist eingegangen!
Deine Bestellung im Überblick:
Anzahl   Artikelnummer und Beschreibung   Lieferung                Einzelpreis  Summe
1        2924946 STARLINK Standard Kit    Lieferung bis Dienstag,  349,00 Euro 349,00 Euro
                                          17.02.2026
1        Aktion myMediaMarkt Rabatt 327c…                          - 80,00 Euro
Versandkosten:                            0,00 Euro
Gesamtsumme:  inkl. MwSt                  269,00 Euro
Lieferanschrift : Test User Musterstr. 1 12345 Musterstadt DE
Rechnungsanschrift : Test User Musterstr. 1 12345 Musterstadt DE
Tel.:    Deine gewählte Zahlungsart: Klarna
```

### Bereits extrahiert

| Feld | Quelle | Pattern |
|---|---|---|
| `order_id` | `Bestellnummer: 300XXXXXX` | `\d{6,15}` |
| `product` | Item-Table | `productFromArticleTable` |
| `total` (teilweise) | `Gesamtsumme: …` | `Gesamtsumme[:\s]+…` |
| `tracking` | Versand-Mail (anderes Sample) | `findAllTrackings` |

### **NEU** in diesem PR

#### 1. ETA-Datum pro Item (`eta_date`)

Pattern: `Lieferung bis Dienstag, 17.02.2026`. DE-Datums-Format:
`(\d{1,2})\.(\d{1,2})\.(\d{4})` nach Wochentag.

```ts
const m = /Lieferung\s+bis\s+\w+,\s+(\d{1,2})\.(\d{1,2})\.(\d{4})/i.exec(s)
// → [_, "17", "02", "2026"] → ISO "2026-02-17"
```

Verfügbar in 51/51 (100%) der Order-Mails (jedes Item hat eine
Lieferungs-Spalte).

#### 2. Order-Total mit MwSt-Inkl-Hinweis (`order_total`)

Pattern: `Gesamtsumme:\s*inkl\.\s*MwSt\s+([\d.,]+)\s*Euro`.
Verfügbar in 36/51 (~71%). MwSt ist in DE per Default 19%, wird
nicht explizit als Prozentsatz angezeigt — wir lassen `tax_rate_pct`
deshalb leer.

#### 3. Versandkosten (`shipping_cost`)

Pattern: `Versandkosten:\s+([\d.,]+)\s*Euro`. Liegt fast immer bei
`0,00 Euro`. Nicht direkt für Deal-Tracking nötig; speichern wir aber
für spätere Analytics in `parsed_payload`.

#### 4. Items-Liste (`items[]`)

Item-Block-Pattern (linearisiert):
```
(?<qty>\d{1,3})\s+(?<sku>\d{6,9})\s+(?<name>[A-Z][^\n]{4,140})\s+Lieferung\s+bis…(?<unit>\d+,\d{2})\s*Euro\s+(?<sum>\d+,\d{2})\s*Euro
```

Multi-Item: wiederholt Block für Block. Jeder Aktion-Rabatt-Block
beginnt mit `Aktion myMediaMarkt Rabatt` und ist KEIN Item — beim
Parsen via Negative-Lookahead überspringen.

#### 5. Country-Code aus Lieferanschrift (`shipping_address_country`)

Pattern: am Ende der Lieferanschrift steht `\s+(DE|AT|CH|NL|ES|HU|PL)\b`
in Großbuchstaben. **Kein** Name/Straße extrahieren — DSGVO.

```ts
const m = /Lieferanschrift\s*:\s*[^\n]{10,200}\s+(DE|AT|CH|NL|ES|HU|PL)\s/i.exec(s)
```

#### 6. Payment-Method (`payment_method`)

Pattern: `Deine\s+gewählte\s+Zahlungsart:\s+(\w+)`. Real-Beispiele:
`Klarna`, `PayPal`, `Kreditkarte`, `Lastschrift`. Speichern wir in
`parsed_payload` für spätere Filter, nicht in `deals`.

## Adapter-Erweiterung

`mediamarkt.parse()` extends:
- `eta_date` aus erstem `Lieferung bis …`-Block.
- `order_total` aus `Gesamtsumme: inkl. MwSt …`.
- `items[]` über Multi-Item-Iteration auf der Article-Tabelle.
- `shipping_address_country` aus Lieferanschrift-Tail.
- `payment_method` aus `Deine gewählte Zahlungsart`.

## Coverage-Erwartung

Pro Order-Mail (n=36):
- `eta_date`: ≥ 95% (`Lieferung bis …`-Block durchgehend vorhanden)
- `order_total`: ≥ 70% (Gesamtsumme nicht in jeder Status-Update-Mail)
- `items[]`: ≥ 80% (komplette Article-Table)
- `shipping_address_country`: ≥ 95% (DE als Default; Adresse fehlt nur
  bei Storno-Mails)

Pro Versand-Mail (n=15): zusätzlich `tracking` aus `Sendungsnummer:`
und `shipped_at` aus Mail-Datum (kein expliziter Body-Timestamp).
