// T3c-spezifische Deno-Tests: Anchor-Pflicht-Refactor +
// Whitespace-Normalisierung-Strict-Pfad + gateTracking-Candidate-API +
// Body-Cap + HTML-Carrier-Source.
//
// Ausführen mit:
//
//   deno test --allow-read supabase/functions/_shared/tracking_t3c_test.ts

import {
  assert,
  assertEquals,
} from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  findAllTrackings,
  gateTracking,
  MAX_BODY_LEN,
  TRACKING_PATTERNS,
  type TrackingCandidate,
} from './inbox_adapters.ts'

// ── 1. Whitespace-Normalisierung — UPS 1Z mit Spaces ──────────────────

Deno.test.ignore('T3c: UPS 1Z mit Spaces → strong + normalized=true', () => {
  // Plan 2026-05-16 §D1/§D5: ups-1z-Pattern wurde entfernt. Whitespace-
  // Normalisierung gilt jetzt nur noch fuer DHL-Patterns. Test bleibt als
  // removed-by-design-Marker — wenn UPS via API-Adapter zurueckkommt,
  // muss das Pattern in TRACKING_PATTERNS reaktiviert werden.
  const body = 'Your shipment: 1Z 999 AA1 0123456784 is on its way.'
  const result = findAllTrackings(body)
  const ups = result.find((c) => c.value === '1Z999AA10123456784')
  assert(ups, 'expected UPS candidate via whitespace-normalized pass')
  assertEquals(ups!.confidence, 'strong')
  assertEquals(ups!.validation.normalized, true)
  assertEquals(ups!.carrier, 'UPS')
})

Deno.test('T3c: DHL JJD mit Spaces → strong + normalized=true', () => {
  const body = 'Tracking: JJD 0123 4567 8901 2345 67 unterwegs.'
  const result = findAllTrackings(body)
  const jjd = result.find((c) => c.value.startsWith('JJD'))
  assert(jjd, 'expected JJD candidate via whitespace-normalized pass')
  assertEquals(jjd!.confidence, 'strong')
  assertEquals(jjd!.validation.normalized, true)
})

// ── 2. gateTracking — Candidate-API ───────────────────────────────────

Deno.test('T3c gateTracking: min=strong returnt nur strong als primary', () => {
  const candidates: TrackingCandidate[] = [
    {
      value: 'XXX1234567890',
      rawValue: 'XXX1234567890',
      source: 'context-anchor',
      confidence: 'medium',
      validation: { normalized: false },
    },
    {
      value: '1Z999AA10123456784',
      rawValue: '1Z999AA10123456784',
      carrier: 'UPS',
      source: 'strong-pattern',
      confidence: 'strong',
      validation: { normalized: false },
    },
  ]
  // Sortierung simulieren: strong zuerst.
  candidates.sort((a, b) =>
    ({ strong: 3, medium: 2, weak: 1, none: 0 })[b.confidence] -
    ({ strong: 3, medium: 2, weak: 1, none: 0 })[a.confidence],
  )
  const { primary, rest } = gateTracking(candidates, { minConfidence: 'strong' })
  assert(primary)
  assertEquals(primary!.value, '1Z999AA10123456784')
  assertEquals(rest.length, 1)
  assertEquals(rest[0].confidence, 'medium')
})

Deno.test('T3c gateTracking: min=medium returnt auch medium', () => {
  const candidates: TrackingCandidate[] = [
    {
      value: 'XXX1234567890',
      rawValue: 'XXX1234567890',
      source: 'context-anchor',
      confidence: 'medium',
      validation: { normalized: false },
    },
  ]
  const { primary } = gateTracking(candidates, { minConfidence: 'medium' })
  assert(primary)
  assertEquals(primary!.confidence, 'medium')
})

Deno.test('T3c gateTracking: requireCarrier=true skipt primary ohne Carrier', () => {
  const candidates: TrackingCandidate[] = [
    {
      value: '1234567890123',
      rawValue: '1234567890123',
      source: 'context-anchor',
      confidence: 'strong',
      validation: { normalized: false },
    },
    {
      value: '1Z999AA10123456784',
      rawValue: '1Z999AA10123456784',
      carrier: 'UPS',
      source: 'strong-pattern',
      confidence: 'strong',
      validation: { normalized: false },
    },
  ]
  const { primary } = gateTracking(candidates, {
    minConfidence: 'strong',
    requireCarrier: true,
  })
  assert(primary)
  assertEquals(primary!.carrier, 'UPS')
})

Deno.test('T3c gateTracking: leere Liste → primary=null', () => {
  const { primary, rest } = gateTracking([], { minConfidence: 'strong' })
  assertEquals(primary, null)
  assertEquals(rest.length, 0)
})

// ── 3. Body-Cap (256 KB) ──────────────────────────────────────────────

Deno.test('T3c Body-Cap: MAX_BODY_LEN = 256 KB exportiert', () => {
  assertEquals(MAX_BODY_LEN, 256 * 1024)
})

Deno.test('T3c Body-Cap: Tracking jenseits 256 KB wird abgeschnitten', () => {
  const padding = 'x'.repeat(MAX_BODY_LEN + 100)
  const body = padding + ' 1Z999AA10123456784'
  const result = findAllTrackings(body)
  const ups = result.find((c) => c.value === '1Z999AA10123456784')
  assertEquals(ups, undefined, 'Token jenseits des Body-Caps darf nicht matchen')
})

Deno.test('T3c Body-Cap: Tracking VOR 256 KB wird gefunden', () => {
  // Plan 2026-05-16 §D1/§D5: ups-1z-Pattern entfernt — Body-Cap-
  // Sicherheitsnetz mit JJD-Pattern (DHL) statt UPS 1Z testen.
  const body = 'JJD012345678901234 ' + 'x'.repeat(MAX_BODY_LEN + 100)
  const result = findAllTrackings(body)
  const jjd = result.find((c) => c.value === 'JJD012345678901234')
  assert(jjd, 'Token vor dem Body-Cap muss gefunden werden')
})

// ── 4. HTML-Pfad — Amazon Logistics URL → strong + carrier ────────────

Deno.test('T3c HTML: Amazon Logistics URL → strong + carrier', () => {
  const html = `<a href="https://track.amazon.de/tracking/ABCDEFGH1234567890">Track</a>`
  const result = findAllTrackings('', { html })
  const c = result.find((x) => x.source === 'html-href')
  assert(c, 'expected html-href candidate')
  assertEquals(c!.confidence, 'strong')
  assertEquals(c!.carrier, 'Amazon Logistics')
})

Deno.test('T3c HTML: orderingShipmentId → medium + source=amazon-shipment-id', () => {
  const html = `<a href="https://www.amazon.de/progress-tracker/package/?orderingShipmentId=109727463192302">Track</a>`
  const result = findAllTrackings('', { html })
  const c = result.find((x) => x.source === 'amazon-shipment-id')
  assert(c, 'expected amazon-shipment-id candidate')
  assertEquals(c!.confidence, 'medium')
  assertEquals(c!.value, '109727463192302')
})

// ── 5. Negativ-Suite: Mail mit Amazon-Order-ID only ───────────────────

Deno.test('T3c Negativ: Mail nur mit Amazon-Order-ID → primary=null', () => {
  const body = 'Your order 302-1234567-1234567 has been confirmed.'
  const candidates = findAllTrackings(body)
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })
  assertEquals(primary, null, 'Order-ID darf nicht als primary durchgehen')
})

Deno.test('T3c Negativ: 302-1234567-1234567 produziert keinen strong-Candidate', () => {
  // Die Order-ID enthält 7-stellige Fragmente (zu kurz für context-numeric
  // mit min=10) und Dashes (matchen nicht context-alphanumeric).
  // Wenn ein Candidate auftaucht, MUSS er via REJECT_PATTERNS rejected
  // (confidence='none') oder zumindest nicht 'strong' sein.
  const body = 'Your order 302-1234567-1234567 confirmed.'
  const candidates = findAllTrackings(body)
  for (const c of candidates) {
    assert(c.confidence !== 'strong', `unexpected strong candidate: ${c.value}`)
  }
})

// ── 6. TRACKING_PATTERNS-Tabelle: normalizable-Flag ───────────────────

Deno.test('T3c TRACKING_PATTERNS: dhl-jjd ist normalizable (DHL-only)', () => {
  // Plan 2026-05-16 §D1/§D5: TRACKING_PATTERNS reduziert auf DHL-Patterns.
  // Vorher: ups-1z + dhl-jjd + s10-upu. Jetzt nur noch dhl-jjd ist als
  // `normalizable: true` markiert (Whitespace-Toleranz fuer JJD-Format).
  // Die DHL-DE-Patterns sind kompakter und brauchen keine Whitespace-Pass.
  const norm = TRACKING_PATTERNS.filter((p) => p.normalizable).map((p) => p.id)
  assert(norm.includes('dhl-jjd'))
  // Removed-by-design (sollen NICHT mehr existieren):
  assert(!norm.includes('ups-1z'), 'ups-1z entfernt (Plan §D1)')
  assert(!norm.includes('s10-upu'), 's10-upu entfernt (Plan §D1)')
})
