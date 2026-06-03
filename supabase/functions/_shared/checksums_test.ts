// Checksum-Primitiven isoliert — Plan 2026-06-03 §5b/§6/§11 (Task T2).
//
// Ausführen mit:
//   deno test --allow-read supabase/functions/_shared/checksums_test.ts
//
// Testet die `_internal`-Primitiven aus `tracking_validators.ts` DIREKT
// (nicht über den JSON-getriebenen Validator) gegen die im Plan §11
// numerisch verifizierten Vektoren:
//   - DHL mod-10 3/1  (20-stellig Sendungsnummer)
//   - DHL mod-10 4/9  (12-stellig Identcode)
//   - UPU S10 mod-11  (RB…785DE / CC…829DE)
//   - DPD ISO 7064 MOD 37,36
// Plus mutated-digit-Negative: jede valide Nummer mit 1 geflippter Ziffer
// MUSS fehlschlagen (beweist, dass die Checksum-Mathematik korrekt verdrahtet
// ist und nicht nur per Pattern „durchwinkt").
//
// Signatur-Hinweis (verifiziert gegen tracking_validators.ts):
//   checkMod10(serial, check, { name, evens_multiplier, odds_multiplier, reverse? })
//     - serial = alle Ziffern AUSSER der Prüfziffer
//     - check  = die Prüfziffer (als String)
//   checkS10(serial, check)
//     - serial = exakt 8 Ziffern, check = 9. Ziffer
//   checkMod37_36(serial, check)
//     - serial = Body (ohne Prüfzeichen), check = 1 Prüfzeichen

import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { _internal } from './tracking_validators.ts'

const { checkMod10, checkS10, checkMod37_36 } = _internal

// Helper: split a full numeric string into serial + last-digit check.
function splitLast(full: string): { serial: string; check: string } {
  return { serial: full.slice(0, -1), check: full.slice(-1) }
}

// Helper: flip one digit (deterministisch) für mutated-Negative.
function flipDigit(full: string, idx: number): string {
  const d = Number(full[idx])
  const flipped = ((d + 1) % 10).toString()
  return full.slice(0, idx) + flipped + full.slice(idx + 1)
}

// ── DHL mod-10 3/1 (20-stellig) ───────────────────────────────────────────
const DHL20_SPEC = { name: 'mod10' as const, evens_multiplier: 3, odds_multiplier: 1 }

Deno.test('DHL mod-10 3/1: 00340433836442636597 → check 7 valid', () => {
  const { serial, check } = splitLast('00340433836442636597')
  assertEquals(check, '7')
  assert(checkMod10(serial, check, DHL20_SPEC), 'expected valid DHL-20 checksum')
})

Deno.test('DHL mod-10 3/1: mutated digit → invalid', () => {
  const full = '00340433836442636597'
  // Flippe drei verschiedene Positionen — alle müssen fehlschlagen.
  for (const idx of [0, 5, 18]) {
    const mutated = flipDigit(full, idx)
    const { serial, check } = splitLast(mutated)
    assert(
      !checkMod10(serial, check, DHL20_SPEC),
      `mutated DHL-20 at idx ${idx} (…${mutated.slice(-4)}) must fail`,
    )
  }
})

// ── DHL mod-10 4/9 (12-stellig Identcode) ──────────────────────────────────
const DHL12_SPEC = { name: 'mod10' as const, evens_multiplier: 4, odds_multiplier: 9 }

Deno.test('DHL mod-10 4/9: 201298452277 valid', () => {
  const { serial, check } = splitLast('201298452277')
  assert(checkMod10(serial, check, DHL12_SPEC), 'expected valid Identcode checksum')
})

Deno.test('DHL mod-10 4/9: mutated digit → invalid', () => {
  const full = '201298452277'
  for (const idx of [0, 4, 10]) {
    const mutated = flipDigit(full, idx)
    const { serial, check } = splitLast(mutated)
    assert(
      !checkMod10(serial, check, DHL12_SPEC),
      `mutated Identcode at idx ${idx} must fail`,
    )
  }
})

// ── UPU S10 mod-11 ─────────────────────────────────────────────────────────
// S10 = 2 Service-Buchstaben + 8 Serial-Ziffern + 1 Prüfziffer + 2 Land.
// checkS10 erwartet die 8 Serial-Ziffern + die Prüfziffer.
function s10Parts(full: string): { serial: string; check: string } {
  const body9 = full.slice(2, 11) // 9 Ziffern zwischen Service + Land
  return { serial: body9.slice(0, 8), check: body9.slice(8) }
}

Deno.test('S10 mod-11: RB123456785DE → serial 12345678 / check 5 valid', () => {
  const { serial, check } = s10Parts('RB123456785DE')
  assertEquals(serial, '12345678')
  assertEquals(check, '5')
  assert(checkS10(serial, check), 'expected valid S10 checksum')
})

Deno.test('S10 mod-11: CC473124829DE → serial 47312482 / check 9 valid', () => {
  const { serial, check } = s10Parts('CC473124829DE')
  assertEquals(serial, '47312482')
  assertEquals(check, '9')
  assert(checkS10(serial, check), 'expected valid S10 checksum')
})

Deno.test('S10 mod-11: mutated serial digit → invalid', () => {
  // RB123456785DE: body9 = 123456785. Flip eine Serial-Ziffer.
  const { serial, check } = s10Parts('RB123456785DE')
  for (const idx of [0, 3, 7]) {
    const mutated = flipDigit(serial, idx)
    assert(!checkS10(mutated, check), `mutated S10 serial at idx ${idx} must fail`)
  }
})

Deno.test('S10 mod-11: mutated check digit → invalid', () => {
  const { serial } = s10Parts('RB123456785DE')
  // Korrekte Prüfziffer ist 5; alle anderen müssen fehlschlagen.
  for (const c of ['0', '1', '4', '6', '9']) {
    assert(!checkS10(serial, c), `S10 with wrong check digit ${c} must fail`)
  }
})

// ── DPD ISO 7064 MOD 37,36 ─────────────────────────────────────────────────
Deno.test('DPD mod-37/36: 09980000020034 → D valid', () => {
  assert(checkMod37_36('09980000020034', 'D'), 'expected valid DPD mod-37/36 checksum')
})

Deno.test('DPD mod-37/36: wrong check char → invalid', () => {
  for (const c of ['A', 'B', 'C', 'E', '0', '9']) {
    assert(!checkMod37_36('09980000020034', c), `DPD wrong check ${c} must fail`)
  }
})

Deno.test('DPD mod-37/36: mutated body digit → invalid', () => {
  const body = '09980000020034'
  for (const idx of [0, 6, 13]) {
    const mutated = flipDigit(body, idx)
    assert(!checkMod37_36(mutated, 'D'), `mutated DPD body at idx ${idx} must fail`)
  }
})
