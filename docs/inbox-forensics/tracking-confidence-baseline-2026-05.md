# Tracking Confidence Baseline — Mai 2026

> **Status:** T1-Forensik-Baseline (Plan `2026-05-13_strict_tracking_extraction.md`)
> Erstellt: 2026-05-13 · Quelle: Fixture-Scan + Code-Analyse `inbox_adapters.ts`
> Versioniert unter `docs/inbox-forensics/`. Kein PII — alle Empfänger-/Adressdaten anonymisiert.
> Dient als Falsifikationsquelle für T2b-Validatoren + T13-Fixture-Generierung.

---

## Inhaltsverzeichnis

- [Sektion A — Sample-Liste](#a--sample-liste)
- [Sektion B — Falsch-Positive (heute)](#b--falsch-positive-heute)
- [Sektion C — Falsch-Negative (zu eng)](#c--falsch-negative-zu-eng)
- [Sektion D — Carrier-Coverage-Matrix](#d--carrier-coverage-matrix)
- [Sektion E — Validatoren-Erwartung](#e--validatoren-erwartung)

---

## A — Sample-Liste

Alle Tracking-Werte stammen aus den Fixture-Files unter `test/fixtures/` und `test/fixtures/forensics/` sowie den Test-Cases in `inbox_adapters_test.ts`, `amazon_html_test.ts`, `amazon_live_test.ts`. Synthethische Stand-Ins sind mit `[synth]` markiert und basieren auf den Pattern-Definitionen in `inbox_adapters.ts` L100–116.

**Legende Confidence (Plan §1 Ziel):**
- `strong` = Pattern + Anchor + (wenn möglich) valide Checksum
- `medium` = kein Anchor oder kein Checksum
- `weak` = reines Kontext-Match ohne Format-Eindeutigkeit
- `none` = REJECT greift oder kein Match

**Legende Source:**
- `strong-pattern` = trifft `STRONG_TRACKING_PATTERNS`
- `context-anchor` = trifft `CONTEXT_TRACKING_RE` (Keyword im Sentence-Window)
- `html-carrier-url` = extrahiert aus Carrier-spezifischem `href`-Parameter
- `html-generic-url` = generischer `trk`/`tracking_number`-URL-Param
- `amazon-shipment-id` = `orderingShipmentId` aus Amazon-Redirect-URL

---

### A.1 Echte Samples aus Fixtures

| # | Tracking-Wert | Quell-Domäne | Aktuell extrahiert via | Erwartete Confidence (Plan) | Erwarteter Adapter-Pfad | Negativ-Check (REJECT?) |
|---|---|---|---|---|---|---|
| 1 | `TBA987654321098` | Amazon Logistics | `STRONG_TRACKING_PATTERNS[1]` L102 `TBA\d{9,14}` | `strong` | `strong-pattern` → `html-carrier-url` als Duplikat | Nein — TBA-Prefix eindeutig |
| 2 | `TBA456789012345` | Amazon Logistics (IT) | `STRONG_TRACKING_PATTERNS[1]` | `strong` | `strong-pattern` | Nein |
| 3 | `1Z999AA10123456784` | UPS | `STRONG_TRACKING_PATTERNS[0]` L101 `1Z[A-Z0-9]{16}` | `strong` | `strong-pattern` | Nein — 1Z-Prefix eindeutig |
| 4 | `1Z999AA10987654321` | UPS | `STRONG_TRACKING_PATTERNS[0]` | `strong` | `strong-pattern` | Nein |
| 5 | `1Z999AA10123456111` | UPS (eBay fixture) | `STRONG_TRACKING_PATTERNS[0]` | `strong` | `strong-pattern` | Nein |
| 6 | `JJD012345678901234` | DHL (LEGO test) | `STRONG_TRACKING_PATTERNS[2]` L103 `JJD\d{10,18}` | `strong` | `strong-pattern` | Nein — JJD-Prefix eindeutig |
| 7 | `00340434202012345678` | DHL (MediaMarkt, via `Sendungsnummer:` Text) | `STRONG_TRACKING_PATTERNS[4]` L105 `\d{20,22}` | `strong` nach Plan (braucht Anchor) | `strong-pattern` + `context-anchor` | **KRITISCH**: heute kein Anchor nötig → nach Plan wird Anchor Pflicht |
| 8 | `00340434202023456789` | DHL (Saturn) | `STRONG_TRACKING_PATTERNS[4]` | `strong` nach Plan (braucht Anchor + Checksum via jkeen) | `strong-pattern` + `context-anchor` | Nein wenn Anchor vorh. |
| 9 | `00340434202098765432` | DHL (LEGO) | `STRONG_TRACKING_PATTERNS[4]` | `strong` nach Plan | `strong-pattern` + `context-anchor` | Nein wenn Anchor vorh. |
| 10 | `00340434202012345001` | DHL (Tink) | `STRONG_TRACKING_PATTERNS[4]` | `strong` nach Plan | `strong-pattern` + `context-anchor` | Nein wenn Anchor vorh. |
| 11 | `04125123456789` | DHL (Kaufland, 14-stellig) | `CONTEXT_TRACKING_RE` nach Keyword `Sendungsnummer:` | `strong` (Anchor vorhanden, URL-Duplikat bestätigt) | `context-anchor` + `html-carrier-url` (nolp.dhl.de/?idc=) | Nein — 14-stellig, DHL-Format |
| 12 | `12345678901234` | InPost (xkom) | `CONTEXT_TRACKING_RE` nach `Sendungsnummer:` | `medium` (kein eindeutiges Format; Checksum fehlt) | `context-anchor` | **PRÜFEN**: `\d{14}` ist mehrdeutig (DHL 14 vs. InPost 14 vs. DPD 14) |
| 13 | `DE5455279839` | Amazon Logistics (IT live) | `STRONG_TRACKING_PATTERNS[5]` L115 `DE\d{8,14}` | `strong` (Anchor aus Plain-Text "tracking number is:") | `context-anchor` gewinnt gegen `orderingShipmentId` | Nein — `DE`+Digits, ≥10 Stellen |
| 14 | `106121425175302` | Amazon Logistics (DE live 01) | `html-carrier-url` `orderingShipmentId` L236 | `medium` nach Plan (intern, kein echter Carrier-Track) | `amazon-shipment-id` | Nein wenn als `medium` eingestuft |
| 15 | `108834567890123` | Amazon Logistics (DE live 02) | `html-carrier-url` `orderingShipmentId` | `medium` | `amazon-shipment-id` | Nein |
| 16 | `109727463192302` | Amazon Logistics (IT live, Falsch-Positiv-Fall) | `orderingShipmentId` HTML-Fallback (vor Fix) | `medium` — soll NICHT `primary` werden | `amazon-shipment-id` — muss hinter Plain-Text DE-Tracking | Nein, aber Priorisierungs-Fehler |
| 17 | `110123456789012` | Amazon Logistics (ES live) | `orderingShipmentId` | `medium` | `amazon-shipment-id` | Nein |
| 18 | `111777888999000` | Amazon Logistics (FR live) | `orderingShipmentId` | `medium` | `amazon-shipment-id` | Nein |
| 19 | `XJ123456789FR` | Chronopost (Amazon FR fixture) | `html-carrier-url` `chronopost.fr/?listeNumerosLT=` L252 | `strong` (URL-Carrier-Anker) | `html-carrier-url` | Nein — `[A-Z]{2}\d{9}[A-Z]{2}` = S10-Format |
| 20 | `14001122334455` | SEUR (Amazon ES fixture) | `html-carrier-url` `seur.com/?segOnLine=` L254 | `strong` (URL-Carrier-Anker) | `html-carrier-url` | Nein |
| 21 | `PCK1234567890ES` | SEUR (pccomponentes shipped) | `html-carrier-url` `seur.com/?segOnLine=` | `strong` | `html-carrier-url` | Nein |
| 22 | `15501234567890` | DPD (Amazon UK fixture) | `html-carrier-url` `dpd.track/parcels/` L246 | `strong` (URL-Carrier-Anker) | `html-carrier-url` | Nein |
| 23 | `RR123456789CZ` | DPD (Alza) | `CONTEXT_TRACKING_RE` nach `Sendungsnummer:` | `strong` (Anchor vorh.) | `context-anchor` | Nein — S10-Format |

---

### A.2 Synthetische Stand-Ins (nach Pattern-Struktur, kein echter Workspace)

> Diese Samples werden benötigt, weil keine echten Carrier-Trackings für GLS, Hermes, FedEx, Royal Mail, USPS, Canada Post in den Fixture-Files vorhanden sind.

| # | Tracking-Wert | Carrier | Pattern-Basis | Erwartete Confidence (Plan) | Erwarteter Adapter-Pfad | Checksum-Typ |
|---|---|---|---|---|---|---|
| 24 | `JJD01234567890123456` | DHL (JJD lang) | `JJD\d{10,18}` L103 | `strong` (Anchor Pflicht nach Plan) | `strong-pattern` | jkeen Mod-10 |
| 25 | `1Z12345E0291980793` | UPS | `1Z[A-Z0-9]{16}` L101 | `strong` | `strong-pattern` | UPS Mod-10 (spec) |
| 26 | `JJD00099991400800` | DHL (JJD kurz 17) | `JJD\d{10,18}` | `strong` | `strong-pattern` | jkeen |
| 27 | `LX123456789DE` | DHL (S10 DE) | `[A-Z]{2}\d{9}DE` L104 | `strong` | `strong-pattern` | S10 Mod-11 |
| 28 | `RX987654321DE` | Deutsche Post (S10) | `[A-Z]{2}\d{9}DE` L104 | `strong` | `strong-pattern` | S10 Mod-11 |
| 29 | `1234567890123456789012` | DHL (22-stellig) | `\d{20,22}` L105 | `strong` nach Plan (Anchor + Checksum Pflicht) | `strong-pattern` + `context-anchor` | jkeen DHL |
| 30 | `12345678` | GLS (8-stellig) | URL-Pattern `gls-pakete.de/?match=` L248 | `strong` (nur via URL) | `html-carrier-url` | proprietär |
| 31 | `123456789012` | GLS (12-stellig) | URL-Pattern | `strong` (nur via URL) | `html-carrier-url` | proprietär |
| 32 | `H12345678` | Hermes/evri | URL-Pattern `hermesworld/?Barcode=` L250 | `strong` (nur via URL) | `html-carrier-url` | keiner bekannt |
| 33 | `7489044985` | FedEx (10-stellig) [synth] | kein STRONG-Pattern vorhanden | `none` heute, `weak` nach Anchor-Ausbau | kein Pfad — FedEx fehlt | FedEx Mod-10 |
| 34 | `123456789012` | FedEx (12-stellig) [synth] | kein Pattern | `none` | — | FedEx Mod-10 |
| 35 | `JD014600004621907466` | Royal Mail (JD-Prefix) [synth] | kein STRONG-Pattern | `none` heute | — | S10 |
| 36 | `9400111899223420133141` | USPS (22-stellig) [synth] | `\d{20,22}` würde fälschlich matchen | **PROBLEM**: trifft DHL-Pattern | `strong-pattern` fälschlicherweise | kein Validator |
| 37 | `1Z999AA10123456784` | UPS mit Spaces (`1Z 999 AA1 0123456784`) [synth] | `STRONG_TRACKING_PATTERNS[0]` **HEUTE NEIN** | `none` heute (Spaces) → `strong` nach Whitespace-Normalisierung | Braucht T3c-Fix | UPS Mod-10 |
| 38 | `JJD 012 345 678 901 234` | DHL JJD mit Spaces [synth] | **HEUTE NEIN** | `none` heute → `strong` nach T3c | T3c-Fix nötig | jkeen |
| 39 | `00 340 434 202 098 765 432` | DHL 20-stellig mit Spaces [synth] | **HEUTE NEIN** | `none` heute → `strong` nach T3c | T3c-Fix nötig | jkeen |
| 40 | `1ZX12345` | UPS zu kurz (8 Zeichen) [synth] | kein Match (16 folgende Zeichen nötig) | `none` | kein Pfad | — |

---

## B — Falsch-Positive (heute)

Fälle wo aktuell ein Pattern matcht, der Wert aber KEIN echtes Carrier-Tracking ist.

| # | Mail-Body-Snippet (Anker-Kontext, kein PII) | Falscher Match | Warum fälschlicherweise erkannt | REJECT-Pattern-Kandidat |
|---|---|---|---|---|
| 1 | `Ihre Bestellung #303-1234567-1234567` | `303-1234567-1234567` via `CONTEXT_TRACKING_RE` wenn Keyword davor | Amazon-Order-ID — Format `\d{3}-\d{7}-\d{7}` | `REJECT: /^\d{3}-\d{7}-\d{7}$/` |
| 2 | `orderingShipmentId=109727463192302` | `109727463192302` als `tracking` via `html-carrier-url` | Amazon-interne Shipment-ID, kein echter Carrier-Track (15-stellig, rein numerisch, kein Standard-Carrier-Format) | Kein REJECT, aber `confidence: 'medium'` + `source: 'amazon-shipment-id'` nach Plan §3.8 |
| 3 | `?shipmentId=1776971660745` im URL-Parameter | `1776971660745` (13-stellig, wenn `trackingId`-Param) | Amazon-interne URL-Parameter `shipmentId` (nicht `trackingId`) — nicht im Pattern, aber generischer URL-Catch könnte es treffen | Aktuell kein Match auf `shipmentId`-Param, aber `trk/tracking_number`-Generic könnte bei ähnlichen Namen matchen |
| 4 | `IBAN: DE89370400440532013000` | `DE89370400440532013000` könnte via `DE\d{8,14}` L115 matchen wenn 22 Stellen (tatsächlich zu lang, aber `DE89` + Ziffern) | IBAN-Prefix `DE` + Ziffern ist strukturell ähnlich zu `DE\d{8,14}`, jedoch IBANs sind 22-stellig → liegt außerhalb `\d{8,14}` → **HEUTE SICHER**, aber Grenzfall | REJECT: `/^DE\d{2}\d{4}\d{4}/` (IBAN-Prefix) |
| 5 | `In 78915 Meersburg …` (PLZ in Adressblock) | Bei naivem Body-Scan könnte `78915` als Teil eines 20-stelligen Ziffernblocks erscheinen, wenn Adresse kompakt steht | PLZ-Fragmente in langen Ziffernfolgen | REJECT: `/^\d{5}$/` — schützt PLZ allein stehend |
| 6 | `+49 89 12345678` (Telefonnummer nach Tracking-Keyword) | Wenn `Kontakt: +4989…` nahe einem Tracking-Keyword steht, kann `CONTEXT_TRACKING_RE` `+4989…` als Token erkennen | Telefonnummer-Format | REJECT: `/^\+?\d{2,4}\d{3,}$/` |
| 7 | `Rechnungsnummer: DE202412345` (10-stellig) | `DE202412345` trifft `DE\d{8,14}` L115 — `DE` + 9 Stellen = gültig nach heutigem Pattern | Rechnungsnummer beginnt oft mit `DE` + Jahr + laufende Nr | Erfordert Anchor-Pflicht (`requiresAnchor: true`) in T3c — ohne Anchor-Keyword kein Match |
| 8 | `22334455667788990011` (20-stellige Zahl in AGB-Footer, keine Tracking-Referenz) | Trifft `\d{20,22}` L105 — heute kein Anchor nötig | Zufällige 20-stellige Nummern (Referenznummern, Vorgangsnummern in Fußzeilen) | Anchor-Pflicht in T3c + DHL-Checksum via jkeen |

---

## C — Falsch-Negative (zu eng)

Legitime Tracking-Nummern die heute NICHT extrahiert werden (oder nicht korrekt).

| # | Tracking-Wert (Beispiel) | Carrier | Warum heute nicht erkannt | Plan-Fix |
|---|---|---|---|---|
| 1 | `1Z 999 AA1 0123456784` (mit Spaces) | UPS | `STRONG_TRACKING_PATTERNS[0]` matcht keinen Whitespace im Token; `\b(1Z[A-Z0-9]{16})\b` benötigt lückenlose 18 Zeichen | T3c: Whitespace-Normalisierung via `candidate.replace(/[\s ]+/g, '')` vor Pattern-Match |
| 2 | `JJD 01234567890 12345` (mit Spaces) | DHL | Analog UPS — Pattern L103 ist lückenlos | T3c: Whitespace-Normalisierung |
| 3 | `003 404 342 020 1234 5678` (20-stellig mit Spaces) | DHL | Pattern L105 `\d{20,22}` ohne Whitespace | T3c: Normalisierung |
| 4 | `00340434202012345678` ohne Anchor-Keyword (reiner Footer-Text, kein "Sendungsnummer:") | DHL | Nach Plan-T3c **wird** Anchor Pflicht → dann False-Negative für Mails ohne Keyword | Mitigation: HTML-URL-Scan als Fallback (nolp.dhl.de/?idc= bleibt ohne Anchor) |
| 5 | `FedEx 7489044985` | FedEx | Kein FedEx-STRONG-Pattern existiert; `CONTEXT_TRACKING_RE` würde `7489044985` (10 Stellen) erkennen wenn Keyword vorhanden, aber FedEx-10 und FedEx-12 und FedEx-15 werden nicht differenziert | T3b: FedEx-Pattern-Eintrag ergänzen (proprietäres Mod-10) |
| 6 | `JD014600004621907466` (Royal Mail JD-Prefix, 20 Stellen) | Royal Mail | Trifft `\d{20,22}` L105 wenn Anchor vorhanden, aber `JD`-Prefix wird nicht als Royal Mail erkannt → Carrier `undefined` | T3b: Royal Mail Pattern-Eintrag + jkeen-DB |
| 7 | `DE12345678` (10-stellig, gültig für DHL national) | DHL | Trifft L115 `DE\d{8,14}` — ABER ohne Anchor-Pflicht heute könnte er trotzdem durch. Nach T3c mit Anchor-Pflicht korrekt | T3c Anchor-Pflicht schützt + jkeen-Checksum bestätigt |
| 8 | `00340000000000000001` (DHL 20-stellig, gültige Checksum aber neue Format-Variante) | DHL | Trifft L105, Checksum unbekannt ohne jkeen | T2b: jkeen-DB liefert Checksum-Validator |
| 9 | `1234567890123456789012` (22-stellig USPS) | USPS | Trifft `\d{20,22}` L105 fälschlicherweise als DHL klassifiziert; kein USPS-Validator | T3b: Carrier-Detection per Checksum-Differenzierung (USPS IMpb vs DHL) |

---

## D — Carrier-Coverage-Matrix

| Carrier | Anchor-Pflicht heute | Validator vorhanden | jkeen-DB-Coverage (vermutet) | Plan Phase-1 Pflicht |
|---|---|---|---|---|
| **Amazon Logistics** | Nein (URL + TBA-STRONG ohne Anchor) | Nein (nur Format) | Nein — proprietäres TBA + Shipment-ID | Ja — TBA `strong`, ShipmentID `medium` |
| **DHL** | Nein (`\d{20,22}` anchor-frei!) | Nein | **Ja** — jkeen hat DHL Paket DE, JJD, S10 | Ja — Anchor + Checksum Pflicht nach T2b |
| **DHL Express** | Nein | Nein | Ja (jkeen) | Ja |
| **UPS** | Nein | Nein | **Ja** — jkeen hat 1Z-Mod10 | Ja |
| **DPD** | Nur via URL-Pattern | Nein | Ja (jkeen hat DPD) | Ja (URL-Pattern bleibt) |
| **GLS** | Nur via URL-Pattern | Nein | Ja (jkeen) | Ja |
| **Hermes/evri** | Nur via URL-Pattern | Nein | Fraglich — proprietär | Nein (Phase 2) |
| **FedEx** | Kein Pattern | Nein | **Ja** — jkeen hat FedEx 10/12/15 | Nein (Phase 2) |
| **Deutsche Post** | Nein (S10 `[A-Z]{2}\d{9}DE`) | Nein | Ja (S10 = UPU-Standard) | Ja — S10 Mod-11 |
| **Royal Mail** | Kein eigenes Pattern (würde `\d{20,22}` treffen via JD-Prefix = falsch) | Nein | Ja (jkeen hat Royal Mail) | Nein (Phase 2) |
| **USPS** | Kein eigenes Pattern (würde `\d{20,22}` treffen) | Nein | Ja (jkeen) | Nein (Phase 2) |
| **Canada Post** | Kein Pattern | Nein | Ja (jkeen) | Nein (Phase 2) |
| **SEUR** | Nur via URL-Pattern (`seur.com/?segOnLine=`) | Nein | Fraglich | Nein (Phase 2) |
| **Chronopost** | Nur via URL-Pattern (`chronopost.fr/?listeNumerosLT=`) | Nein | Ja (S10-basiert) | Nein (Phase 2) |
| **InPost** | Context-Anchor wenn Keyword vorhanden | Nein | Ja (jkeen) | Nein (Phase 2) |

**Legende:**
- Anchor-Pflicht = ob das Pattern heute ein Keyword (Sendungsnummer/Tracking) im Sentence-Window benötigt
- Validator = ob heute Checksum/Länge geprüft wird (aktuell: keine)
- jkeen-DB = ob https://github.com/jkeen/tracking_number_data JSON-Einträge für diesen Carrier bekannt sind

**Phase-1-Pflicht-Carrier (aus Plan §3.3):** Amazon Logistics, DHL, DHL Express, UPS, DPD, GLS, Deutsche Post — diese müssen nach T2b/T3c korrekt mit Anchor + Checksum funktionieren.

---

## E — Validatoren-Erwartung

Pro Carrier: korrekte Checksum-Methode, Beispiel-Nr + erwarteter Validierungs-Output.

### E.1 UPS — Mod-10 (proprietär)

**Format:** `1Z` + 16 alphanumerische Zeichen. Letztes Zeichen = Check-Digit.

**Algorithmus:**
1. Zeichen 3–17 (ohne Check-Digit) iterieren; Buchstaben zu Zahlen via `ord(c) - 63`, zweistellige Ergebnisse werden als zwei Ziffern summiert.
2. Gerade Positionen (1-indiziert) × 2, ungerade × 1.
3. Summe modulo 10 ergibt Expected-Check. Falls Ergebnis 10: Check = 0.

**Beispiel aus jkeen:** `1Z999AA10123456784`
- Zu validieren: `999AA10123456784` (16 Zeichen)
- Check-Digit: `4`
- Erwartetes Ergebnis: `valid`

**Beispiel ungültig [synth]:** `1Z999AA10123456785`
- Check-Digit: `5` — nicht korrekt → `invalid`

**jkeen-Schlüssel:** `ups_package` → Datei `supabase/functions/_shared/tracking_data/ups.json` (nach T2a)

---

### E.2 DHL Paket DE — Mod-10 (GS1)

**Format:** 20-22 Stellen, beginnt meist mit `003` oder `0034`. Letztes Zeichen = GS1-Checksum.

**Algorithmus (GS1-128 Mod-10):**
1. Alle Ziffern außer letzter.
2. Ungerade Positionen (von rechts, 1-indiziert) × 3, gerade × 1.
3. Summe; Check = `(10 - (Summe mod 10)) mod 10`.

**Beispiel aus Fixture:** `00340434202012345678`
- Alle außer letzter: `0034043420201234567`
- Checksum-Berechnung gegen `8`
- Hinweis: Fixture-Wert ist synthetisch; jkeen liefert echte Test-Nummern in `dhl_packet.json`.

**Beispiel ungültig [synth]:** `00340434202012345679`
- Check-Digit `9` vs. erwartet `8` → `invalid`

**jkeen-Schlüssel:** `dhl_packet` (vermutlich `dhl_germany_packet`)

---

### E.3 DHL JJD — Mod-10

**Format:** `JJD` + 10–18 Ziffern.

**Algorithmus:** Identisch zu GS1 Mod-10 auf den Ziffernblock nach `JJD`.

**Beispiel aus Test:** `JJD012345678901234` (18 Stellen gesamt)
- Ziffernblock: `012345678901234`
- Check-Digit (letzte Stelle): `4`

**Beispiel ungültig [synth]:** `JJD012345678901235` → `invalid`

**jkeen-Schlüssel:** `dhl_jjd`

---

### E.4 S10 (UPU-Standard) — Deutsche Post, Royal Mail, Chronopost, Alza (DPD CZ)

**Format:** `[A-Z]{2}` + 8 Ziffern + Check-Digit (1 Stelle) + `[A-Z]{2}` (Land-Suffix). Total 13 Zeichen.

**Algorithmus (S10 Mod-11):**
1. Die 8 Ziffern (Positionen 3–10) mit Gewichten `[8, 6, 4, 2, 3, 5, 9, 7]` multiplizieren.
2. Summe modulo 11 → Remainder.
3. Check = `11 - Remainder`. Wenn Check = 10 → `invalid`. Wenn Check = 11 → Check = 0.

**Beispiel aus Fixture:** `XJ123456789FR`
- Service-Code: `XJ` (Chronopost-Prefix)
- Seriennummer: `12345678`
- Check-Digit: `9`
- Suffix: `FR`
- Gewichtete Summe: `1×8 + 2×6 + 3×4 + 4×2 + 5×3 + 6×5 + 7×9 + 8×7 = 8+12+12+8+15+30+63+56 = 204`
- `204 mod 11 = 6`; Check = `11 - 6 = 5` ≠ `9` → **dieser Fixture-Wert ist synthetisch/unkorrekt** — jkeen liefert korrekte Test-Nummern.

**Anderes Beispiel `RR123456789CZ` (Alza DPD CZ):**
- Seriennummer: `12345678`, Check: `9`, Suffix: `CZ`
- Gleiche Berechnung — Fixture ist synthetisch; Validator muss via jkeen-Test-Nummern falsifiziert werden.

**jkeen-Schlüssel:** `s10` oder carrier-spezifisch (`royal_mail`, `deutsche_post`)

---

### E.5 DPD — proprietäres Format

**Format DE:** 14-stellig numerisch (Barcode-Format `05XXXXXXXXXXXXXXX`).
**Format UK/NL/etc.:** variiert (10–20 Stellen).

**Algorithmus:** Kein öffentlich dokumentierter Checksum-Standard. DPD verwendet proprietäres Format. jkeen-DB enthält vermutlich DPD-Einträge aus Community-Reverse-Engineering.

**Beispiel aus Fixture:** `15501234567890` (14-stellig, Amazon UK)
- Validator-Erwartung nach T2b: Format-Check 14 Stellen + ggf. jkeen-Checksum

**Carrier-Detection-Tipp:** `detectAdapter()` in `tracking_adapters.ts:277` erkennt DPD via `05\d{12}$`-Prefix. Allgemeines `\d{14}` ist mehrdeutig.

---

### E.6 Amazon Logistics — TBA (kein Checksum-Standard)

**Format:** `TBA` + 9–14 Ziffern.

**Algorithmus:** Amazon-proprietär, kein öffentlicher Checksum-Standard bekannt.

**Validierung nach Plan:** Nur Format-Check (Prefix + Länge). `confidence: 'strong'` bleibt erreichbar via Anchor + Format allein (kein jkeen-Checksum nötig).

**Beispiel:** `TBA987654321098` (15 Zeichen gesamt, 12 Ziffern) → `valid` (Format)
**Beispiel:** `TBA12345` (8 Zeichen) → `invalid` (zu kurz, min. 12 Zeichen gesamt)

---

### E.7 Amazon `orderingShipmentId` — kein echter Carrier

**Format:** 12–18 Stellen, rein numerisch.

**Validierung nach Plan:** Kein Checksum. Automatisch `confidence: 'medium'`, `source: 'amazon-shipment-id'`. Erscheint NICHT in `deals.tracking` (Persistenz-Mapping blockiert `medium`).

**Beispiel:** `109727463192302` (15 Stellen) → `medium`, gespeichert nur in `tracking_candidates[]`

---

## Zusammenfassung

**Sample-Count:** 23 echte Samples (A.1) + 17 synthetische Stand-Ins (A.2) = 40 Samples total.

**Erwartete Reject-Rate** nach T3a–T3c:
- Amazon-Order-IDs (`\d{3}-\d{7}-\d{7}`): ~100% korrekt geblockt
- `orderingShipmentId`-Werte: demoted zu `medium`, nicht rejected
- 20–22-stellige Zufallsnummern ohne Anchor: ~80–90% geblockt (Anchor-Pflicht)
- Echte DHL-20-stellig mit Anchor: weiterhin `strong` (nicht geblockt — Council-Finding #6 beachtet)

**Top-3-Patterns die rausfliegen (nach T3a/T3c):**
1. `\d{20,22}` ohne Anchor — heute STRONG, nach Plan nur mit Anchor + Checksum
2. `DE\d{8,14}` ohne Anchor — heute STRONG, nach Plan nur mit Anchor-Keyword
3. `orderingShipmentId=\d{8,20}` bleibt im Code aber als `confidence: 'medium'` — blockiert von Persistenz-Mapping

**Top-3-Patterns die bleiben:**
1. `1Z[A-Z0-9]{16}` (UPS) — strukturell eindeutig, bleibt `strong` (ggf. + Whitespace-Normalisierung)
2. `TBA\d{9,14}` (Amazon Logistics) — eindeutiger Prefix, bleibt `strong`
3. `JJD\d{10,18}` (DHL) — eindeutiger Prefix, bleibt `strong` (+ Checksum via jkeen)
