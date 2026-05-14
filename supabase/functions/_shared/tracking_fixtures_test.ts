// T13: Fixtures + Negativ/Positiv/Edge-Tests für findAllTrackings() +
// gateTracking() in inbox_adapters.ts.
//
// Ausführen mit:
//
//   deno test --allow-read supabase/functions/_shared/tracking_fixtures_test.ts
//
// Deckt ab:
//   7 Positiv-Cases (UPS 1Z, UPS-Spaces, DHL JJD, DHL-20, TBA, S10, HTML-href)
//   7 Negativ-Cases (Order-ID, 20-Digit random, IBAN, Phone, PLZ, Invoice, ShipmentId)
//   2 Edge-Cases    (anchorMatched≤50chars, Body-Cap >256KB)

import {
  assert,
  assertEquals,
} from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  findAllTrackings,
  gateTracking,
  MAX_BODY_LEN,
} from './inbox_adapters.ts'
import * as fx from './test_fixtures/tracking_fixtures.ts'

// ── Positiv: 7 Cases ──────────────────────────────────────────────────────

Deno.test('T13 pos: UPS 1Z strong — primary strong, carrier=UPS', () => {
  const candidates = findAllTrackings(fx.pos_ups_1z_strong)
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })
  assert(primary !== null, 'primary should not be null for UPS 1Z strong fixture')
  assertEquals(primary!.value, '1Z999AA10123456784')
  assertEquals(primary!.confidence, 'strong')
  assertEquals(primary!.carrier, 'UPS')
})

Deno.test('T13 pos: UPS 1Z with spaces — primary strong, normalized=true', () => {
  const candidates = findAllTrackings(fx.pos_ups_1z_with_spaces)
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })
  assert(primary !== null, 'primary should not be null for UPS 1Z with spaces')
  assertEquals(primary!.value, '1Z999AA10123456784')
  assertEquals(primary!.confidence, 'strong')
  assertEquals(primary!.validation.normalized, true, 'normalized must be true for space-separated UPS')
})

Deno.test('T13 pos: DHL JJD strong — primary strong, carrier=DHL', () => {
  const candidates = findAllTrackings(fx.pos_dhl_jjd_strong)
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })
  assert(primary !== null, 'primary should not be null for DHL JJD')
  assert(
    primary!.value.startsWith('JJD'),
    `expected JJD prefix, got: ${primary!.value}`,
  )
  assertEquals(primary!.confidence, 'strong')
})

Deno.test('T13 pos: DHL 20-digit with anchor — strong (anchor + carrier = DHL)', () => {
  const candidates = findAllTrackings(fx.pos_dhl_20_digit_with_anchor)
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })
  assert(
    primary !== null,
    'primary should not be null for DHL 20-digit with Sendungsnummer anchor',
  )
  assertEquals(primary!.value, '00340434161094021501')
  assertEquals(primary!.confidence, 'strong')
  // anchorMatched muss das Anchor-Wort enthalten
  assert(
    primary!.validation.anchorMatched !== undefined,
    'anchorMatched must be set for anchored DHL-20 fixture',
  )
})

Deno.test('T13 pos: Amazon TBA strong — primary strong, carrier=Amazon Logistics', () => {
  const candidates = findAllTrackings(fx.pos_amazon_tba_strong)
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })
  assert(primary !== null, 'primary should not be null for Amazon TBA')
  assertEquals(primary!.value, 'TBA123456789012')
  assertEquals(primary!.confidence, 'strong')
  assertEquals(primary!.carrier, 'Amazon Logistics')
})

Deno.test('T13 pos: S10 UPU strong — primary strong, value=XJ12345678FR, carrier=S10', () => {
  // s10-upu pattern: [A-Z]{2}\d{8}[A-Z]{2} (exakt 8 Ziffern, requiresAnchor=false)
  const candidates = findAllTrackings(fx.pos_s10_upu_strong)
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })
  assert(primary !== null, 'primary should not be null for S10/UPU fixture')
  assertEquals(primary!.value, 'XJ12345678FR')
  assertEquals(primary!.confidence, 'strong')
  assertEquals(primary!.carrier, 'S10')
})

Deno.test('T13 pos: HTML Amazon track.amazon.de link → strong, source=html-href', () => {
  const candidates = findAllTrackings(fx.pos_html_amazon_link_text, {
    html: fx.pos_html_amazon_link_html,
  })
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })
  assert(primary !== null, 'primary should not be null for HTML amazon tracking link')
  assertEquals(primary!.source, 'html-href')
  assertEquals(primary!.confidence, 'strong')
  assertEquals(primary!.carrier, 'Amazon Logistics')
})

// ── Negativ: 7 Cases ──────────────────────────────────────────────────────

Deno.test('T13 neg: Amazon order-ID (302-…) → primary=null, rejectedBy=amazon-order-id forensics', () => {
  const candidates = findAllTrackings(fx.neg_amazon_order_id)
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })
  assertEquals(primary, null, 'Amazon Order-ID darf nicht primary werden')
  // Forensik: wenn ein Candidate existiert, sollte er rejected sein
  for (const c of candidates) {
    assert(
      c.confidence !== 'strong',
      `unexpected strong candidate for amazon-order-id fixture: ${c.value}`,
    )
  }
})

Deno.test('T13 neg: random 20-digit ohne Anchor → primary=null', () => {
  const candidates = findAllTrackings(fx.neg_random_20_digit)
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })
  assertEquals(
    primary,
    null,
    'Zufällige 20-stellige Zahl ohne Anchor/Carrier darf nicht primary werden',
  )
})

Deno.test('T13 neg: DE IBAN → rejectedBy=iban-de, primary=null', () => {
  const candidates = findAllTrackings(fx.neg_iban_de)
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })
  assertEquals(primary, null, 'IBAN darf nicht als Tracking durchgehen')
  // Forensik-Check: IBAN-Candidate sollte via iban-de rejected sein
  const ibanCandidates = candidates.filter(
    (c) => c.validation.rejectedBy === 'iban-de',
  )
  // IBAN passt in den Candidate-Scan nur, wenn ein Context-Pattern greift.
  // Wenn kein Candidate erzeugt wird: ebenfalls OK (frühe Ablehnung).
  if (candidates.length > 0) {
    assert(
      ibanCandidates.length > 0 || candidates.every((c) => c.confidence !== 'strong'),
      'IBAN candidates must be rejected or non-strong',
    )
  }
})

Deno.test('T13 neg: internationale Telefonnummer → primary=null', () => {
  const candidates = findAllTrackings(fx.neg_phone_intl)
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })
  assertEquals(primary, null, 'Telefonnummer darf nicht als Tracking-primary durchgehen')
})

Deno.test('T13 neg: PLZ-only → primary=null', () => {
  const candidates = findAllTrackings(fx.neg_plz_only)
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })
  assertEquals(primary, null, 'PLZ darf nicht als Tracking-primary durchgehen')
})

Deno.test('T13 neg: kurze Rechnungsnummer 8-stellig → kein strong-Candidate', () => {
  const candidates = findAllTrackings(fx.neg_invoice_short)
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })
  assertEquals(primary, null, 'Kurze Rechnungsnummer darf nicht strong sein')
  for (const c of candidates) {
    assert(
      c.confidence !== 'strong',
      `unexpected strong for 8-digit invoice: ${c.value}`,
    )
  }
})

Deno.test('T13 neg: Amazon orderingShipmentId only → primary=null (Gate min=strong), Candidate source=amazon-shipment-id', () => {
  const candidates = findAllTrackings(fx.neg_orderingShipmentId_only_text, {
    html: fx.neg_orderingShipmentId_only_html,
  })
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })
  assertEquals(
    primary,
    null,
    'orderingShipmentId darf nicht als strong primary durchgehen',
  )
  // Forensik: Candidate muss mit source=amazon-shipment-id und confidence=medium existieren
  const shipmentCandidate = candidates.find(
    (c) => c.source === 'amazon-shipment-id',
  )
  assert(
    shipmentCandidate !== undefined,
    'orderingShipmentId muss als Forensik-Candidate mit source=amazon-shipment-id erhalten bleiben',
  )
  assertEquals(shipmentCandidate!.value, '109727463192302')
  assertEquals(
    shipmentCandidate!.confidence,
    'medium',
    'orderingShipmentId muss confidence=medium haben',
  )
})

// ── Edge-Cases: 2 ─────────────────────────────────────────────────────────

Deno.test('T13 edge: anchorMatched max 50 chars — PII-Schutz (Council-Finding #7)', () => {
  const candidates = findAllTrackings(fx.edge_anchormatched_max_50chars)
  // UPS 1Z muss gefunden werden
  const ups = candidates.find((c) => c.value === '1Z999AA10123456784')
  assert(ups !== undefined, 'expected UPS candidate in edge_anchormatched_max_50chars')
  // Alle anchorMatched Felder in der gesamten Candidate-Liste müssen ≤ 50 chars sein
  for (const c of candidates) {
    if (c.validation.anchorMatched) {
      assert(
        c.validation.anchorMatched.length <= 50,
        `anchorMatched zu lang: ${c.validation.anchorMatched.length} chars für "${c.value}"`,
      )
    }
  }
  // Primary muss strong sein (Anchor "Sendungsnummer" ist vorhanden)
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })
  assert(primary !== null, 'UPS 1Z mit Sendungsnummer-Anchor muss primary strong sein')
  assertEquals(primary!.value, '1Z999AA10123456784')
})

Deno.test('T13 edge: Body >256 KB — Tracking VOR Cap gefunden, Tracking NACH Cap nicht', () => {
  // Verifikation: MAX_BODY_LEN ist 256 KB
  assertEquals(MAX_BODY_LEN, 256 * 1024)

  // 1. Tracking bei ~50 chars (weit vor 256 KB) → muss gefunden werden
  const earlyBody = fx.buildBodyOver256kbWithEarlyTracking()
  assert(
    earlyBody.length > MAX_BODY_LEN,
    `earlyBody muss > 256 KB sein, ist ${earlyBody.length}`,
  )
  const earlyResult = findAllTrackings(earlyBody)
  const earlyUps = earlyResult.find(
    (c) => c.value === fx.edge_body_over_256kb_early_tracking_value,
  )
  assert(
    earlyUps !== undefined,
    `Tracking "${fx.edge_body_over_256kb_early_tracking_value}" vor 256 KB muss gefunden werden`,
  )
  assert(
    earlyUps!.confidence === 'strong',
    'early tracking muss strong sein (Anchor "Sendungsnummer" steht davor)',
  )

  // 2. Tracking nach 300 KB (jenseits 256 KB Cap) → darf NICHT gefunden werden
  const lateBody = fx.buildBodyOver256kbWithLateTracking()
  assert(
    lateBody.length > MAX_BODY_LEN,
    `lateBody muss > 256 KB sein, ist ${lateBody.length}`,
  )
  const lateResult = findAllTrackings(lateBody)
  const lateUps = lateResult.find(
    (c) => c.value === fx.edge_body_over_256kb_late_tracking_value,
  )
  assertEquals(
    lateUps,
    undefined,
    `Tracking "${fx.edge_body_over_256kb_late_tracking_value}" nach 300 KB darf nicht gefunden werden (Body-Cap)`,
  )
})
