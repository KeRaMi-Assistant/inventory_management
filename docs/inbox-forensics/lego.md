# Forensik-Memo: LEGO

## Real-Daten-Basis

- **DB-Sample:** 0 Mails — Adapter ist im Code, aber keine Mail seit
  dem letzten Bootstrap. Memo basiert auf öffentlich dokumentierten
  LEGO-Mail-Templates und den existierenden Adapter-Pattern.
- **Sender:**
  - `order-acknowledged@m.lego.com` (Bestelleingang)
  - `DoNotReply@lego.com` (Bestellinfo + Rechnung als PDF)
  - `Noreply@t.crm.lego.com` (Versand-Updates)
- **Order-ID-Format:** `T<8-12 Ziffern>(-E\d)?`, z.B. `T492568051-E9`.

## Verfügbare Datenpunkte (Template-based)

### Bereits extrahiert

| Feld | Quelle |
|---|---|
| `order_id` | `\bT\d{8,12}(?:-E\d)?\b` |
| `product` | Subject (Body-Pattern unsicher ohne Sample) |
| `tracking` | URL-Pattern in Versand-Mail |

### **NEU** in diesem PR

#### 1. Order-Total (`order_total`)

LEGO-Standard-Templates zeigen:
```
Order Total:    €299.95
Bestellsumme:   299,95 €
```

Pattern: `(?:Order\s+Total|Bestellsumme|Gesamtsumme)\s*[:€]\s*([\d.,]+)\s*€?`.

#### 2. Items-Liste (`items[]`)

LEGO-Order-Confirmations listen Items als:
```
LEGO® Star Wars™ The Razor Crest 75331    1   €519.99
LEGO® Technic Lamborghini Sián 42115      1   €379.99
```

Pattern: `(?<name>LEGO[®\s][A-Za-z0-9®™ ]{4,140})\s+(?<qty>\d{1,3})\s+€([\d.,]+)`.

LEGO-Variante: jedes Item-Set hat einen Set-Code (`75331`) der wie eine
Tracking-Nr aussehen kann — wir filtern Set-Codes aus dem Tracking-
Match raus, weil die nicht in `findAllTrackings` matchen (zu kurz).

#### 3. ETA-Datum (`eta_date`)

```
Estimated delivery: March 15-17, 2026
Voraussichtliche Lieferung: 15.03.2026 - 17.03.2026
```

Pattern: `(?:Estimated\s+delivery|Voraussichtliche\s+Lieferung)[\s:]+(\w+\s+\d{1,2}|\d{1,2}\.\d{1,2}\.\d{4})`.

#### 4. VIP-Status (`metadata.vip_member`)

LEGO sendet VIP-Member-Bestätigungen mit dem Hinweis
`VIP Member earned: 250 points` — wir speichern als Metadata, nicht in
Top-Level-Schema.

#### 5. Tax-Rate (`tax_rate_pct`)

```
Sub-total:     €260.83
VAT (19%):      €49.56
Order Total:   €310.39
```

Pattern: `VAT\s*\((\d+)%\)|MwSt\s*\((\d+)\s*%\)`.

#### 6. Shipping-Method (`delivery_method`)

`Shipping:\s+Standard|Express|Click & Collect`.

## Adapter-Erweiterung

`lego.parse()` extends:
- `order_total` aus EN/DE-Pattern.
- `items[]` aus LEGO-Set-Format.
- `eta_date` aus EN-Datum oder DE-Datum.
- `tax_rate_pct` aus VAT-Block.

## Coverage-Erwartung

Schätzung (kein DB-Sample):
- `order_total`: ≥ 80% (jede Confirmation hat Total)
- `items[]`: ≥ 75%
- `eta_date`: ≥ 60% (Lieferzusage variiert)
- `tax_rate_pct`: ≥ 70%

LEGO-Adapter wird re-aktiviert, sobald wieder Mails einlaufen.
