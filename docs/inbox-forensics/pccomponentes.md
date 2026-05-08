# Forensik-Memo: PcComponentes (ES/DE/FR/IT/PT)

## Real-Daten-Basis

- **DB-Sample:** 6 Mails, 4 mit `_raw_html`.
- **Sender:** `noreply@pccomponentes.com`, `pedidos@pccomponentes.com`,
  `noreply@pccomponentes.de`.
- **Sprache:** Multi-Lang. Real-DB hat DE-Mails (PCComponentes hat
  Deutschland-Localization). Original-ES + EN-Templates sind ähnlich.
- **Hervorhebung:** PCComponentes liefert die **dichteste** Daten in
  allen 7 ausgewerteten Shops — Tax-Rate, Total, Items, Seller,
  Quantity sind in 4/4 Bodies enthalten (100% Coverage in Sample).

## Verfügbare Datenpunkte im HTML

### Bereits extrahiert

| Feld | Quelle |
|---|---|
| `order_id` | `Bestellnummer: \d{8,18}` |
| `product` | `productFromPcComponentesLine` (Bestelldetails-Block) |
| `total` | `Gesamtbetrag/Zwischensumme/Total` |
| `tracking` | (selten in Body, kommt eher per Versand-Update) |

### **NEU** in diesem PR

#### 1. ETA-Datum (`eta_date`)

Real-Sample-Pattern (DE-Localization):
```
Lieferung zwischen Dienstag, 3 März und Donnerstag, 5 März
```

Wir parsen das frühere Datum (Dienstag, 3 März → ISO-Datum mit aktuellem
Jahr; bei Jahreswechsel Edge-Case auf nächstes Jahr fallback).

#### 2. Tax-Rate (`tax_rate_pct`)

PCComponentes ist der einzige Shop in unserem Sample, der den
Steuer-Satz **explizit als Prozentsatz** anzeigt:
```
Zwischensumme:    400,00 €
IVA (21%):         84,00 €
Gesamtbetrag:     484,00 €
```

Pattern: `(?:IVA|MwSt|VAT|TVA)\s*\(?(\d{1,2})\s*%\)?`

DE-Lokalisierung nutzt `MwSt (19%)`, ES `IVA (21%)`, FR `TVA (20%)`,
IT `IVA (22%)`, PT `IVA (23%)`.

#### 3. Order-Total + Subtotal (`order_total`, `subtotal`)

Pattern: `Gesamtbetrag:\s*([\d.,]+)\s*(€|EUR)`. PCComponentes formatiert
mit Komma-Dezimal in DE/ES/IT/FR/PT. Alle 4 Sample-Bodies haben Total.

#### 4. Items-Liste (`items[]`)

Layout (linearisiert):
```
Bestelldetails Produkt   Stk.  Preis
              Samsung 990 PRO M.2 …  Einheiten: 4
              404,80 €     1.619,20 €
```

Item-Struktur: `<name>` + `Einheiten: N` + Preis pro Einheit + Summe
pro Item. Mehrere Items hintereinander = mehrere Bestelldetails-Blöcke.

#### 5. Seller (`seller`)

`Verkauft von:\s+([^,\n.]{1,60})` (DE-Variante) oder
`Vendido por:\s+([^,\n.]{1,60})` (ES). Beispiele: `PcComponentes`,
`Marketplace-Verkäufer XYZ`.

#### 6. Shipping-Method (`delivery_method`)

`Lieferart:\s*Standard|Express|Pickup` oder
`Modalidad de envío:\s*Estándar|Express`.

#### 7. Cancellation-Reason

In Storno-Mails (kein Real-Sample in DB):
```
Tu pedido ha sido cancelado.
Motivo: Cambio de dirección de entrega
```

Pattern: `Motivo:\s+([^.]{4,120})` oder DE `Grund:\s+…`.

## Adapter-Erweiterung

`pccomponentes.parse()` extends:
- `eta_date` aus `Lieferung zwischen Wochentag, T Monat …`.
- `tax_rate_pct` aus `IVA/MwSt/VAT (\d+%)`.
- `order_total` aus Gesamtbetrag.
- `items[]` über Bestelldetails-Multi-Block-Iteration mit Einheiten.
- `seller` aus `Verkauft von / Vendido por`.

## Coverage-Erwartung

Pro Order-Mail (n=4 in Sample):
- `tax_rate_pct`: 100% (jede Mail zeigt explizit IVA/MwSt %)
- `order_total`: 100%
- `items[]`: 100%
- `eta_date`: ≥ 75% (Liefer-Range nicht in jeder Mail)
- `seller`: 100%
