// Deno-Tests für T3a: REJECT_PATTERNS + checkRejectPatterns().
// Ausführen mit:
//
//   deno test --allow-read supabase/functions/_shared/inbox_reject_patterns_test.ts
//
// Coverage:
//   - 7 Negativ-Cases (Order-IDs, IBAN, PLZ+Phone, etc. → rejected)
//   - 4 Positiv-Cases (echte Carrier-Trackings → NICHT rejected)
//   - Edge: Whitespace-Token (T3a tut keine Normalisierung — kommt in T3c)
//   - Edge: null/undefined/empty/oversized → null Result, kein Crash

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/assert_equals.ts'
import {
  checkRejectPatterns,
  REJECT_PATTERNS,
} from './inbox_adapters.ts'

// ── Negativ-Cases (Pflicht: != null) ─────────────────────────────────

Deno.test('REJECT: Amazon-Order-ID (303-1234567-1234567)', () => {
  const r = checkRejectPatterns('303-1234567-1234567')
  assertEquals(r, 'amazon-order-id')
})

Deno.test('REJECT: Amazon-Order-ID (verschiedene Präfixe)', () => {
  assertEquals(checkRejectPatterns('123-4567890-1234567'), 'amazon-order-id')
  assertEquals(checkRejectPatterns('999-0000000-9999999'), 'amazon-order-id')
})

Deno.test('REJECT: DE-IBAN (DE89370400440532013000)', () => {
  // 22 Zeichen: DE + 20 Ziffern (nach Whitespace-Normalisierung in T3c).
  const r = checkRejectPatterns('DE89370400440532013000')
  assertEquals(r, 'iban-de')
})

Deno.test('REJECT: 8-stellige reine Rechnungsnummer → too-short-numeric (≤7) NICHT', () => {
  // 8-stellig → fällt NICHT in too_short_numeric (1-7). Soll auch nicht
  // rejected werden, damit DHL-Frankierungsnummern etc. nicht blocken.
  // Test bestätigt: 8-stellige Zahlen sind KEIN Reject.
  assertEquals(checkRejectPatterns('12345678'), null)
})

Deno.test('REJECT: zu kurze numerische ID (1-7 Stellen)', () => {
  assertEquals(checkRejectPatterns('123'), 'too-short-numeric')
  assertEquals(checkRejectPatterns('1234567'), 'too-short-numeric')
})

Deno.test('REJECT: PLZ allein (5 Ziffern)', () => {
  assertEquals(checkRejectPatterns('78915'), 'plz-only')
})

Deno.test('REJECT: PLZ + Phone-Combo (Whitespace Pflicht — schützt echte 14-stellige Trackings)', () => {
  assertEquals(checkRejectPatterns('78915 891234567'), 'plz-phone-combo')
  // OHNE Whitespace darf 14-stelliges NICHT als plz-phone matchen
  // (sonst kollidiert es mit DHL-14-stelligen Trackings).
  assertEquals(checkRejectPatterns('80331089123456'), null)
})

Deno.test('REJECT: Internationale Telefonnummer (+49…)', () => {
  assertEquals(checkRejectPatterns('+498912345678'), 'phone-intl')
})

Deno.test('REJECT: generische Auftrags-3-Block (123456-654321-987654)', () => {
  assertEquals(checkRejectPatterns('123456-654321-987654'), 'generic-order-3block')
})

// ── Positiv-Cases (Pflicht: == null) ─────────────────────────────────

Deno.test('PASS: UPS 1Z…', () => {
  // 18 chars, beginnt mit 1Z → niemals von REJECT_PATTERNS getroffen.
  assertEquals(checkRejectPatterns('1Z999AA10123456784'), null)
})

Deno.test('PASS: Amazon Logistics TBA…', () => {
  // 15 chars, beginnt mit TBA → nicht rejected.
  assertEquals(checkRejectPatterns('TBA123456789012'), null)
})

Deno.test('PASS: DHL JJD…', () => {
  // 16 chars, beginnt mit JJD → nicht rejected.
  assertEquals(checkRejectPatterns('JJD012345678901'), null)
})

Deno.test('PASS: DHL 20-stellig (Council-Finding #6 — DARF nicht blocken)', () => {
  // 20 Ziffern. KEIN `^\d{20}$`-Reject erlaubt — Plan §3.5.
  assertEquals(checkRejectPatterns('00340434161094021501'), null)
})

Deno.test('PASS: S10-Format (XJ123456789FR)', () => {
  assertEquals(checkRejectPatterns('XJ123456789FR'), null)
})

Deno.test('PASS: DE-Tracking (DE5455279839 — 12 chars)', () => {
  // 12 chars, NICHT IBAN-Form (DE + 20) → nicht rejected.
  assertEquals(checkRejectPatterns('DE5455279839'), null)
})

// ── Edge-Cases ───────────────────────────────────────────────────────

Deno.test('EDGE: Whitespace im Token bleibt unrejected (Normalisierung kommt in T3c)', () => {
  // T3a wirft keinen Whitespace-Normalizer ein. Tokens mit Whitespace
  // passieren die Reject-Patterns nicht (alle sind anchored ohne `\s`).
  assertEquals(checkRejectPatterns('1Z 999 AA1 0123456784'), null)
})

Deno.test('EDGE: leerer String → null', () => {
  assertEquals(checkRejectPatterns(''), null)
})

Deno.test('EDGE: null → null', () => {
  assertEquals(checkRejectPatterns(null), null)
})

Deno.test('EDGE: undefined → null', () => {
  assertEquals(checkRejectPatterns(undefined), null)
})

Deno.test('EDGE: Token-Länge 2 (unter Cap) → null', () => {
  // Length-Cap: < 3 chars → früher Exit, keine Pattern-Auswertung.
  assertEquals(checkRejectPatterns('12'), null)
})

Deno.test('EDGE: Token-Länge 31 (über Cap) → null', () => {
  // Length-Cap: > 30 chars → früher Exit. DE+22 IBAN ist 22 chars, fällt
  // also drin. Ein 31-char-Random ist Out-of-Scope für Reject.
  assertEquals(checkRejectPatterns('1234567890123456789012345678901'), null)
})

Deno.test('EDGE: REJECT_PATTERNS exportiert + nicht leer', () => {
  assertEquals(REJECT_PATTERNS.length >= 7, true)
  // Sanity: jeder Eintrag hat name + re + reason
  for (const p of REJECT_PATTERNS) {
    assertEquals(typeof p.name, 'string')
    assertEquals(p.re instanceof RegExp, true)
    assertEquals(typeof p.reason, 'string')
  }
})
