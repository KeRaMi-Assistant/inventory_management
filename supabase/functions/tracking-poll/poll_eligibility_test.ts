// T16: Tests für tracking-poll Skip-Logik.
//
// Pure-Function-Tests gegen `isPollEligible` aus index.ts. Stellt sicher,
// dass Deals mit `tracking_needs_review=true` UND nicht-strong/-manual
// Confidence NICHT gepollt werden (verhindert API-Calls gegen legacy/fake
// Trackings nach T5-Migration).

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { isPollEligible } from './index.ts'

Deno.test('isPollEligible: skip when needs_review=true AND confidence=none', () => {
  assertEquals(
    isPollEligible({ tracking_needs_review: true, tracking_confidence: 'none' }),
    false,
  )
})

Deno.test('isPollEligible: skip when needs_review=true AND confidence=null', () => {
  assertEquals(
    isPollEligible({ tracking_needs_review: true, tracking_confidence: null }),
    false,
  )
})

Deno.test('isPollEligible: poll when needs_review=true BUT confidence=strong', () => {
  assertEquals(
    isPollEligible({ tracking_needs_review: true, tracking_confidence: 'strong' }),
    true,
  )
})

Deno.test('isPollEligible: poll when needs_review=true BUT confidence=manual', () => {
  assertEquals(
    isPollEligible({ tracking_needs_review: true, tracking_confidence: 'manual' }),
    true,
  )
})

Deno.test('isPollEligible: poll when needs_review=false (regardless of confidence)', () => {
  assertEquals(
    isPollEligible({ tracking_needs_review: false, tracking_confidence: 'none' }),
    true,
  )
  assertEquals(
    isPollEligible({ tracking_needs_review: false, tracking_confidence: 'strong' }),
    true,
  )
})

Deno.test('isPollEligible: poll when needs_review=null (legacy row, pre-T5)', () => {
  assertEquals(
    isPollEligible({ tracking_needs_review: null, tracking_confidence: null }),
    true,
  )
})

Deno.test('isPollEligible: poll on empty row (defensive default)', () => {
  assertEquals(isPollEligible({}), true)
})
