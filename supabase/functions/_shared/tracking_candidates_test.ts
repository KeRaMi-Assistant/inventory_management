// Deno-Tests für die Anchor-Helper aus `inbox_adapters.ts`:
// `ANCHOR_WORDS` + `findAnchorBefore()`. Diese werden von
// `tracking_detection.detect()` für die Anchor-Pflicht (anchor-gated
// dhl-12/dhl-20/S10) importiert und bleiben damit live.
//
// Ausführen mit:
//
//   deno test --allow-read supabase/functions/_shared/tracking_candidates_test.ts
//
// Die früheren `findAllTrackings`/`TRACKING_PATTERNS`-Tests wurden mit dem
// Dead-Code-Cleanup (chore/audit-sustainability-1) entfernt — die Legacy-
// Body-Scan-Pipeline existiert nicht mehr. Candidate-/Reject-/Pattern-
// Verhalten ist über `tracking_detection.detect()` getestet
// (`tracking_detection_test.ts` + `inbox_vat_reject_test.ts`).

import {
  assert,
  assertEquals,
} from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  ANCHOR_WORDS,
  findAnchorBefore,
} from './inbox_adapters.ts'

// ── ANCHOR_WORDS ───────────────────────────────────────────────────────

Deno.test('ANCHOR_WORDS: enthält DE/EN/FR/IT/ES/PL Anchors', () => {
  // Stichprobe pro Sprache.
  assert(ANCHOR_WORDS.includes('Sendungsnummer'))
  assert(ANCHOR_WORDS.includes('Tracking number'))
  assert(ANCHOR_WORDS.includes('Numéro de suivi'))
  assert(ANCHOR_WORDS.includes('Numero di tracciamento'))
  assert(ANCHOR_WORDS.includes('Número de seguimiento'))
  assert(ANCHOR_WORDS.includes('Numer przesyłki'))
})

// ── findAnchorBefore ───────────────────────────────────────────────────

Deno.test('findAnchorBefore: findet Sendungsnummer im 80-char-Fenster', () => {
  const body = 'Hallo, deine Sendungsnummer: 1Z999AA10123456784 ist unterwegs.'
  const idx = body.indexOf('1Z')
  const a = findAnchorBefore(body, idx)
  assert(a !== null)
  assert(a!.toLowerCase().includes('sendungsnummer'))
})

Deno.test('findAnchorBefore: kein Anchor in 80-char-Fenster → null', () => {
  const filler = 'x'.repeat(200)
  const body = `Sendungsnummer ${filler} 1Z999AA10123456784`
  const idx = body.indexOf('1Z')
  const a = findAnchorBefore(body, idx)
  assertEquals(a, null)
})

Deno.test('findAnchorBefore: PII-Schutz, Returnwert ≤ 50 chars', () => {
  const body = 'Tracking number: 1Z999AA10123456784 — additional data follows here'
  const idx = body.indexOf('1Z')
  const a = findAnchorBefore(body, idx)
  assert(a !== null)
  assert(a!.length <= 50, `anchorMatched length must be ≤ 50, got ${a!.length}`)
})
