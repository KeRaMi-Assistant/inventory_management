// Tests für die Re-Parse-Korrektur (Paket 2): wann darf ein neu erkanntes
// Tracking ein bestehendes ersetzen? (shouldReplaceTracking, pure fn)

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/assert_equals.ts'
import { shouldReplaceTracking } from './inbox_parse_runner.ts'

const strongParsed = {
  tracking: 'DE5455279839',
  trackingConfidence: 'strong' as const,
}

Deno.test('replace: needs_review-Altwert + strong-Neuwert → ersetzen', () => {
  assertEquals(
    shouldReplaceTracking(
      {
        tracking: '99999999999999',
        tracking_confidence: 'none',
        tracking_needs_review: true,
      },
      strongParsed,
    ),
    true,
  )
})

Deno.test('replace: Legacy-Altwert (confidence null) + strong → ersetzen', () => {
  assertEquals(
    shouldReplaceTracking(
      { tracking: 'ALT123456789', tracking_confidence: null, tracking_needs_review: null },
      strongParsed,
    ),
    true,
  )
})

Deno.test('replace: manual-Altwert wird NIE überschrieben', () => {
  assertEquals(
    shouldReplaceTracking(
      {
        tracking: 'USER123456789',
        tracking_confidence: 'manual',
        tracking_needs_review: false,
      },
      strongParsed,
    ),
    false,
  )
})

Deno.test('replace: strong-Altwert bleibt (kein strong→strong-Ping-Pong)', () => {
  assertEquals(
    shouldReplaceTracking(
      {
        tracking: 'DE1111111111',
        tracking_confidence: 'strong',
        tracking_needs_review: false,
      },
      strongParsed,
    ),
    false,
  )
})

Deno.test('replace: strong-Altwert MIT needs_review darf korrigiert werden', () => {
  assertEquals(
    shouldReplaceTracking(
      {
        tracking: 'DE1111111111',
        tracking_confidence: 'strong',
        tracking_needs_review: true,
      },
      strongParsed,
    ),
    true,
  )
})

Deno.test('replace: neuer Wert nicht-strong → nie ersetzen', () => {
  assertEquals(
    shouldReplaceTracking(
      {
        tracking: 'ALT123456789',
        tracking_confidence: 'none',
        tracking_needs_review: true,
      },
      { tracking: 'NEU123456789', trackingConfidence: 'none' as const },
    ),
    false,
  )
})

Deno.test('replace: identischer Wert → kein Replace (no-op)', () => {
  assertEquals(
    shouldReplaceTracking(
      {
        tracking: 'DE5455279839',
        tracking_confidence: 'none',
        tracking_needs_review: true,
      },
      strongParsed,
    ),
    false,
  )
})

Deno.test('replace: leerer Altwert → kein Replace-Pfad (Insert-Pfad greift)', () => {
  assertEquals(
    shouldReplaceTracking(
      { tracking: null, tracking_confidence: null, tracking_needs_review: null },
      strongParsed,
    ),
    false,
  )
})
