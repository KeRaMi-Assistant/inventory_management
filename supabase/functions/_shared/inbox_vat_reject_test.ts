// VAT-Kollisions-Wall — die „Reviewer liest diese Datei zuerst"-Datei.
// Plan 2026-06-03 §5b/§6 (Task T2), Negativ-Korpus.
//
// Ausführen mit:
//   deno test --allow-read supabase/functions/_shared/inbox_vat_reject_test.ts
//
// Leitprinzip (User-Direktive): „nichts falsches machen". Falsch-Positive-
// Budget = 0. JEDER Case hier MUSS `detect().tracking === null` ergeben bzw.
// `checkReject` muss den Token abweisen. Das ist der harte Merge-Blocker:
// eine USt-IdNr./IBAN/Telefon darf NIEMALS zum Tracking werden.
//
// Der Original-Bug: das alte Pattern `dhl-de-prefix` `\bDE\d{8,14}\b` matchte
// `DE123456789` (DE + 9 Ziffern) und machte aus einer USt-IdNr ein „DHL-
// Tracking". Dieser Detektor extrahiert `DE123456789` nie als Kandidaten
// (kein Pattern) und `vat_eu` ist Defense-in-Depth.

import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { checkReject, detect, type DetectionInput } from './tracking_detection.ts'

function base(over: Partial<DetectionInput>): DetectionInput {
  return { subject: '', text: '', html: '', status: 'shipped', ...over }
}

// ── checkReject: EU-VAT (2 Buchstaben + 9 Ziffern) ──────────────────────────
Deno.test('VAT-WALL: checkReject DE123456789 → vat_eu', () => {
  assertEquals(checkReject('DE123456789'), 'vat_eu')
})

Deno.test('VAT-WALL: checkReject EL123456789 (Greek-VAT) → vat_eu', () => {
  assertEquals(checkReject('EL123456789'), 'vat_eu')
})

Deno.test('VAT-WALL: checkReject EE123456789 (Estonia-VAT) → vat_eu', () => {
  assertEquals(checkReject('EE123456789'), 'vat_eu')
})

Deno.test('VAT-WALL: checkReject DE811569869 (echte USt-Form) → vat_eu', () => {
  assertEquals(checkReject('DE811569869'), 'vat_eu')
})

// ── detect: VAT im Body in diversen Formen → none ───────────────────────────
Deno.test('VAT-WALL: detect DE123456789 → none', () => {
  const r = detect(base({ text: 'DE123456789' }))
  assertEquals(r.tracking, null)
})

Deno.test('VAT-WALL: detect EL123456789 → none', () => {
  assertEquals(detect(base({ text: 'EL123456789' })).tracking, null)
})

Deno.test('VAT-WALL: detect EE123456789 → none', () => {
  assertEquals(detect(base({ text: 'EE123456789' })).tracking, null)
})

Deno.test('VAT-WALL: detect "DE 123 456 789" (mit Spaces) → none', () => {
  // KEIN globaler Whitespace-Strip → die getrennten Tokens bilden kein
  // contiguous Tracking-Pattern (Critique C1-#7).
  const r = detect(base({ text: 'DE 123 456 789' }))
  assertEquals(r.tracking, null)
})

Deno.test('VAT-WALL: detect Body "USt-IdNr.: DE123456789" → none', () => {
  const r = detect(base({
    subject: 'Ihre Rechnung',
    text: 'Rechnungsbetrag 49,90 EUR\nUSt-IdNr.: DE123456789\nVielen Dank',
  }))
  assertEquals(r.tracking, null)
})

// ── S10-Artefakt: DE123456789DE (13 Zeichen) → DROP ─────────────────────────
Deno.test('VAT-WALL: detect DE123456789DE (S10-Artefakt) → none', () => {
  // Matcht das S10-Pattern, wird aber gedroppt: leadingPrefix==country==DE ∈ VAT.
  const r = detect(base({ subject: 'Versand', text: 'Sendungsnummer DE123456789DE' }))
  assertEquals(r.tracking, null)
})

Deno.test('VAT-WALL: detect DE123456789DE auch mit Tracking-Anchor → none', () => {
  const r = detect(base({ text: 'Tracking-Nummer: DE123456789DE im Anhang' }))
  assertEquals(r.tracking, null)
})

// ── IBAN ─────────────────────────────────────────────────────────────────────
Deno.test('VAT-WALL: checkReject IBAN DE89370400440532013000 → iban_de', () => {
  assertEquals(checkReject('DE89370400440532013000'), 'iban_de')
})

Deno.test('VAT-WALL: detect IBAN DE89370400440532013000 → none', () => {
  const r = detect(base({ text: 'IBAN: DE89370400440532013000' }))
  assertEquals(r.tracking, null)
})

Deno.test('VAT-WALL: detect IBAN FR1420041010050500013M02606 → none', () => {
  const r = detect(base({ text: 'IBAN FR1420041010050500013M02606' }))
  assertEquals(r.tracking, null)
})

// ── Amazon-Order-ID ──────────────────────────────────────────────────────────
Deno.test('VAT-WALL: checkReject 303-1234567-1234567 → amazon_order_id', () => {
  assertEquals(checkReject('303-1234567-1234567'), 'amazon_order_id')
})

Deno.test('VAT-WALL: detect Amazon-Order 303-1234567-1234567 → none', () => {
  const r = detect(base({ subject: 'Ihre Bestellung', text: 'Bestellnummer 303-1234567-1234567' }))
  assertEquals(r.tracking, null)
})

// ── Telefon ──────────────────────────────────────────────────────────────────
Deno.test('VAT-WALL: checkReject +498912345678 → phone_intl', () => {
  assertEquals(checkReject('+498912345678'), 'phone_intl')
})

Deno.test('VAT-WALL: detect Telefon +498912345678 → none', () => {
  const r = detect(base({ text: 'Rückfragen: +498912345678' }))
  assertEquals(r.tracking, null)
})

Deno.test('VAT-WALL: detect "+49 30 1234567890" → none', () => {
  // Mit Spaces → kein contiguous numerisches Tracking-Pattern.
  const r = detect(base({ text: 'Tel.: +49 30 1234567890' }))
  assertEquals(r.tracking, null)
})

// ── PLZ ───────────────────────────────────────────────────────────────────────
Deno.test('VAT-WALL: checkReject 10115 → plz_only', () => {
  assertEquals(checkReject('10115'), 'plz_only')
})

Deno.test('VAT-WALL: detect PLZ 10115 → none', () => {
  const r = detect(base({ text: 'Lieferadresse 10115 Berlin' }))
  assertEquals(r.tracking, null)
})

Deno.test('VAT-WALL: checkReject 12345678 (8-stellig) → too_short? nein, aber kein Tracking', () => {
  // 8 Ziffern: NICHT too_short_numeric (1-7). Aber detect findet kein Pattern.
  assertEquals(checkReject('12345678'), null)
  const r = detect(base({ text: 'Kundennummer 12345678' }))
  assertEquals(r.tracking, null)
})

// ── Anchorlos numerisch (GA-Client-ID) → none, beweist Anchor-Pflicht ───────
Deno.test('VAT-WALL: GA-cid 12345678901234567890 OHNE Anchor → none', () => {
  // 20-stellig, würde mod-10-3/1 evtl. bestehen — aber kein Anchor → none.
  const r = detect(base({ text: 'cid=12345678901234567890 im Pixel' }))
  assertEquals(r.tracking, null)
})

// ── Checksum-mutiert → none, beweist Checksum-Gate ──────────────────────────
Deno.test('VAT-WALL: DHL-20 checksum-mutiert (mit Anchor) → none', () => {
  // 00340433836442636597 ist valide (check 7); 98 am Ende ist mutiert.
  const r = detect(base({ text: 'Sendungsnummer 00340433836442636598' }))
  assertEquals(r.tracking, null)
})

Deno.test('VAT-WALL: S10 checksum-mutiert (mit Anchor) → none', () => {
  // RB123456785DE ist valide (check 5); RB123456786DE ist mutiert.
  const r = detect(base({ text: 'Sendungsnummer RB123456786DE' }))
  assertEquals(r.tracking, null)
})

// ── No-Shipment-Mails → 0 Trackings ─────────────────────────────────────────
Deno.test('VAT-WALL: Bestellbestätigung (status ordered) → none', () => {
  const r = detect(base({
    status: 'ordered',
    subject: 'Bestellbestätigung',
    text: 'Vielen Dank für Ihre Bestellung 303-1234567-1234567. Betrag 49,90 EUR.',
  }))
  assertEquals(r.tracking, null)
})

Deno.test('VAT-WALL: Rechnung (VAT + IBAN, status shipped) → none', () => {
  const r = detect(base({
    subject: 'Ihre Rechnung Nr. RG-2026-00123',
    text: 'USt-IdNr.: DE123456789\nIBAN: DE89370400440532013000\nBetrag 119,00 EUR',
  }))
  assertEquals(r.tracking, null)
})

Deno.test('VAT-WALL: Newsletter → none', () => {
  const r = detect(base({
    subject: 'Unsere Mai-Angebote',
    text: 'Entdecken Sie 50% Rabatt! Jetzt shoppen. Tel +498912345678. PLZ 10115.',
  }))
  assertEquals(r.tracking, null)
})

Deno.test('VAT-WALL: Passwort-Reset → none', () => {
  const r = detect(base({
    subject: 'Setzen Sie Ihr Passwort zurück',
    text: 'Klicken Sie auf den Link. Code 12345. Gültig 10115 Sekunden.',
  }))
  assertEquals(r.tracking, null)
})

// ── Aggregat: KEIN Negativ-Case darf je ein Tracking liefern ────────────────
Deno.test('VAT-WALL: Aggregat — gesamtes Negativ-Korpus liefert 0 Trackings', () => {
  const corpus: DetectionInput[] = [
    base({ text: 'DE123456789' }),
    base({ text: 'EL123456789' }),
    base({ text: 'EE123456789' }),
    base({ text: 'DE 123 456 789' }),
    base({ text: 'USt-IdNr.: DE123456789' }),
    base({ text: 'Sendungsnummer DE123456789DE' }),
    base({ text: 'DE89370400440532013000' }),
    base({ text: 'FR1420041010050500013M02606' }),
    base({ text: 'Bestellnummer 303-1234567-1234567' }),
    base({ text: '+498912345678' }),
    base({ text: '10115' }),
    base({ text: 'RG-2026-00123' }),
    base({ text: 'cid=12345678901234567890' }),
    base({ text: 'Sendungsnummer 00340433836442636598' }), // mutiert
    base({ text: 'Sendungsnummer RB123456786DE' }), // mutiert
  ]
  for (const input of corpus) {
    const r = detect(input)
    assert(
      r.tracking === null,
      `FALSCH-POSITIV: "${input.text.slice(0, 24)}…" lieferte ${r.tracking}`,
    )
    assertEquals(r.confidence, 'none')
  }
})
