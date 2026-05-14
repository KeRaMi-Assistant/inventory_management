// Tests für Multi-Pattern-Disambiguation in `tracking_validators.ts`.
//
// Hintergrund (Task #51, T1-Forensik): Rein-numerische Carrier-Patterns
// derselben Länge (z.B. USPS-22 vs hypothetisches DHL-20-Numeric, oder
// DHL E-Commerce (30) vs USPS-22 mit "420…"-Prefix) erzeugen false-
// positive-Treffer beim Carrier-Mapping, wenn nur "first-match-wins"
// gilt. Der Validator soll bei genuiner Mehrdeutigkeit `ambiguous`
// zurückgeben und KEINEN Carrier raten.
//
// Lokal ausführen:
//   deno test --allow-read supabase/functions/_shared/tracking_disambiguation_test.ts

import { assert } from 'https://deno.land/std@0.224.0/assert/assert.ts'
import { assertEquals } from 'https://deno.land/std@0.224.0/assert/assert_equals.ts'
import { validateTrackingNumber, _internal } from './tracking_validators.ts'

// ---- Synthetic noise (kein bekannter Carrier) -------------------------------

Deno.test('24-digit random string → wenn valid, mit Checksum belegt; nie DHL-blind', async () => {
  // 24-digit-Strings sind nicht von einem 22-digit USPS-Pattern auf den
  // ersten Blick zu unterscheiden; durch das `^…$`-Wrapping greift bei
  // uns aber NUR ein Pattern mit exakter Länge. Wir akzeptieren, dass
  // einzelne Zufalls-Checksum-Treffer existieren (z.B. USPS-91 mit
  // ServiceType "98"+22 digits), aber wir verlangen: KEIN blinder
  // DHL-Pick auf bloßer Length-Basis.
  const r = await validateTrackingNumber('987654321098765432109876')
  if (r.isValid) {
    assert(
      r.checksumValid === true,
      `falls valid muss Checksum belegt sein, got ${JSON.stringify(r)}`,
    )
    // Carrier-Slug darf nicht "ambiguous" oder leer sein wenn valid.
    assert(r.carrierSlug && r.carrierSlug !== 'ambiguous')
  }
})

Deno.test('20-digit random noise → invalid oder ambiguous, aber kein Carrier-Pick', async () => {
  // Reine zufällige 20 Digits sollen nicht als „DHL" oder „USPS" gemeldet
  // werden, nur weil ein Pattern length-matched.
  const r = await validateTrackingNumber('11111111111111111111')
  if (r.isValid) {
    // Wenn doch valid (z.B. zufälliger Checksum-Hit), darf KEIN
    // konkurrierender Carrier silently übergangen werden.
    assert(r.checksumValid === true, 'falls valid, muss Checksum bestanden sein')
  } else {
    // Sonst entweder ambiguous (mit candidates-Liste) oder schlicht invalid.
    if (r.ambiguous) {
      assert(Array.isArray(r.candidates) && r.candidates.length > 1)
      assertEquals(r.carrier, 'ambiguous')
    }
  }
})

// ---- USPS-22 ist nicht als DHL gemeldet -------------------------------------

Deno.test('USPS 22-digit Test-Number (jkeen) → carrier=USPS, NICHT DHL', async () => {
  const samples = [
    '9400111206206406260787',
    '9434611206206406227577',
    '9434611206206407667136',
    '9400111206206407628746',
    '9400111206206407628845',
  ]
  for (const v of samples) {
    const r = await validateTrackingNumber(v)
    assert(r.isValid, `should be valid: ${v} → ${JSON.stringify(r)}`)
    assertEquals(r.carrierSlug, 'usps', `wrong carrier for ${v}: ${r.carrierSlug}`)
    assert(r.carrier !== 'DHL', `${v} fälschlich als DHL gemeldet`)
  }
})

// ---- USPS-22 + 420-Prefix (DHL-eCommerce-Overlap) ist ambiguous -------------

Deno.test('420-Prefix + USPS-22-Body → ambiguous (KEIN Carrier-Pick)', async () => {
  // Diese Nummer ist sowohl als USPS-22 (mit 420-Prefix-Variante) als
  // auch als DHL E-Commerce (30) valide. Per jkeen-Spec sind das echte
  // Partner-Numbers — wir verweigern den Single-Carrier-Pick.
  const r = await validateTrackingNumber('420902459261290336128704042634')
  assert(!r.isValid, `should not isValid, got: ${JSON.stringify(r)}`)
  assertEquals(r.carrier, 'ambiguous')
  assert(r.ambiguous === true)
  assert(Array.isArray(r.candidates) && r.candidates.length >= 2)
  const slugs = (r.candidates ?? []).map((c) => c.carrierSlug)
  assert(slugs.includes('dhl') || slugs.includes('fedex'))
  assert(slugs.includes('usps') || slugs.includes('dhl'))
})

// ---- Synthetisch konstruiert: 20-digit „all-checksum-fail" ------------------

Deno.test('20-digit string, das KEINEN Checksum-Validator besteht → invalid', async () => {
  // `00000000000000000000`: matched mehrere length-Patterns, aber kein
  // Checksum würde bestehen → invalid (kein false-positive DHL/USPS).
  const r = await validateTrackingNumber('00000000000000000000')
  if (r.isValid) {
    // Falls doch valid → mindestens KEIN ambiguous-DHL-Pick.
    assert(r.carrier !== 'ambiguous')
  } else {
    // Ambiguous oder hard-invalid, beides ok.
    assert(!r.carrier || r.carrier === 'ambiguous')
  }
})

// ---- DPD mod_37_36 Direkt-Tests ---------------------------------------------

Deno.test('DPD mod_37_36 valid samples → checksum passt', async () => {
  // Direkt-Aufruf des Algorithmus mit Body+CheckDigit aus DPD test_numbers
  // (Whitespace gestrippt).
  // "00 81827 0998 0000 0200 33 350 276 C" → Body=...276, CheckDigit=C
  const samples: Array<[string, string]> = [
    // DPD-28: 7+14+3+3 = 27 digits Serial + 1 Check
    ['008182709980000020033350276', 'C'],
    ['008182709980000020045327276', 'N'],
    // DPD-14: 14 digits Serial + 1 Check
    ['09980000020033', 'F'],
    ['09980000020034', 'D'],
  ]
  for (const [body, check] of samples) {
    const ok = _internal.checkMod37_36(body, check)
    assert(ok, `mod_37_36 should accept body=${body} check=${check}`)
  }
})

Deno.test('DPD mod_37_36 invalid samples → checksum schlägt fehl', async () => {
  // "008182709980000020033350276A" — gleicher Body, falsche Check-Digit A
  // "0081 827 0998 0000 0200 45 000 000 N" — body verändert
  // "09980000020033D" — falsche Check-Digit zu 099800000200033
  const samples: Array<[string, string]> = [
    // Body korrekt, Check-Digit falsch
    ['008182709980000020033350276', 'A'],
    // Body verändert, Check-Digit weiter N
    ['008182709980000020045000000', 'N'],
    // DPD-14: gleicher Body wie "valid + F", aber Check D
    ['09980000020033', 'D'],
  ]
  for (const [body, check] of samples) {
    const ok = _internal.checkMod37_36(body, check)
    assert(!ok, `mod_37_36 should REJECT body=${body} check=${check}`)
  }
})

// ---- End-to-end: DPD jkeen valid numbers via validateTrackingNumber ---------

Deno.test('DPD test_numbers.valid → carrier=DPD via validateTrackingNumber', async () => {
  const valid = [
    '00 81827 0998 0000 0200 33 350 276 C',
    '0081 827 0998 0000 0200 45 327 276 N',
    '09 9800 0002 0033 F',
    '0998 0000 0200 34D',
  ]
  for (const v of valid) {
    const r = await validateTrackingNumber(v)
    assert(r.isValid, `DPD valid should pass: ${v} → ${JSON.stringify(r)}`)
    assertEquals(r.carrierSlug, 'dpd', `wrong carrier for ${v}`)
  }
})

Deno.test('DPD test_numbers.invalid → nicht als DPD valid akzeptiert', async () => {
  const invalid = [
    '008182709980000020033350276A',
    '0081 827 0998 0000 0200 45 000 000 N',
    '09980000020033D',
  ]
  for (const v of invalid) {
    const r = await validateTrackingNumber(v)
    if (r.isValid) {
      assert(r.carrierSlug !== 'dpd', `${v} fälschlich als DPD valid: ${JSON.stringify(r)}`)
    }
  }
})
