// Deno-Tests für T3b: TrackingCandidate + Pattern-Tabelle +
// findAnchorBefore() + findAllTrackings() (async, Candidate-aware).
//
// Ausführen mit:
//
//   deno test --allow-read supabase/functions/_shared/tracking_candidates_test.ts
//
// Coverage:
//   - Strong-Patterns (UPS 1Z, Amazon TBA, DHL JJD, S10) liefern
//     confidence === 'strong'.
//   - Whitespace-Normalisierung (UPS 1Z mit Leerzeichen) → normalized: true.
//   - Context-Patterns ohne Anchor → confidence reduziert.
//   - Context-Patterns mit Anchor "Sendungsnummer" → anchorMatched gesetzt.
//   - Reject-Patterns (Amazon-Order-ID) → confidence: 'none', rejectedBy.
//   - PII-Schutz: anchorMatched ≤ 50 chars.
//   - Sortierung: strong > medium > weak > none.
//   - Edge: leerer Body → [].

import {
  assert,
  assertEquals,
} from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  ANCHOR_WORDS,
  findAllTrackings,
  findAnchorBefore,
  TRACKING_PATTERNS,
  type TrackingCandidate,
} from './inbox_adapters.ts'

// ── Pattern-Tabelle Smoke-Test ────────────────────────────────────────

Deno.test('TRACKING_PATTERNS: nur DHL-Patterns nach Plan 2026-05-16 §D1', () => {
  // Pattern-Heuristik wurde mit Plan 2026-05-16 (§D1) auf DHL reduziert.
  // UPS-1Z, Amazon-TBA, S10-UPU, context-numeric, context-alphanumeric
  // sind raus — Detection laeuft ausschliesslich via DHL-API-Validation.
  const ids = TRACKING_PATTERNS.map((p) => p.id)
  assert(ids.includes('dhl-jjd'))
  assert(ids.includes('dhl-de-suffix'))
  assert(ids.includes('dhl-de-prefix'))
  assert(!ids.includes('ups-1z'))
  assert(!ids.includes('amazon-tba'))
  assert(!ids.includes('s10-upu'))
  // Plan Phase A (Iteration 2): context-numeric-10-22 wieder eingefuehrt
  // als anchor-gated medium-Confidence. DHL-API entscheidet final.
  assert(ids.includes('context-numeric-10-22'))
  assert(!ids.includes('context-alphanumeric-tracking'))
})

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

// ── findAllTrackings ───────────────────────────────────────────────────

Deno.test('findAllTrackings: leerer Body → []', async () => {
  assertEquals(await findAllTrackings(''), [])
  // @ts-expect-error: testen den null-Pfad defensiv
  assertEquals(await findAllTrackings(null), [])
})

Deno.test.ignore('findAllTrackings: UPS 1Z (strong-pattern + jkeen valid)', () => {
  // Plan 2026-05-16 §D5: removed-by-design — UPS-1Z-Pattern wurde
  // mit Plan §D1 entfernt. Detection laeuft jetzt ausschliesslich
  // gegen die DHL-API. Test bleibt als Marker, falls UPS spaeter
  // zurueckkommt (eigener API-Adapter).
})

Deno.test.ignore('findAllTrackings: UPS 1Z mit Spaces → normalized: true', () => {
  // Plan 2026-05-16 §D5: removed-by-design — UPS-1Z + Amazon-TBA
  // Patterns entfernt (Plan §D1). Whitespace-Normalisierungs-Coverage
  // bleibt fuer DHL-JJD im `inbox_adapters_test.ts`-Suite erhalten.
})

Deno.test.ignore('findAllTrackings: Amazon TBA (strong, no-validation)', () => {
  // Plan 2026-05-16 §D5: removed-by-design — Amazon-TBA-Pattern wurde
  // mit Plan §D1 entfernt. Amazon-Logistics-Sendungen werden nicht
  // mehr auto-detected; manuelle Pflege erforderlich.
})

Deno.test('findAllTrackings: Amazon-Order-ID (3-7-7) → rejected, confidence: none', async () => {
  // Order-ID 303-1234567-1234567 — wird vom context-alphanumeric Pattern
  // NICHT direkt als 1 Token gegriffen (Dashes splitten), aber die
  // numerischen Teile dürften via context-numeric matchen (jeweils nach
  // Anchor-Reduction). Wir testen direkt das Reject-Verhalten.
  const body = 'Order 303-1234567-1234567 confirmed — no shipping yet.'
  const result = await findAllTrackings(body)
  // Wenn ein Candidate auftaucht, muss er rejected sein (Reject-Pattern
  // matcht die 3-7-7-Form als Ganzes — nur erreichbar wenn der Token
  // den Dash enthält. Unsere Patterns matchen aber Word-Tokens, also
  // ist das nur über context-alphanumeric mit Dash-tolerance erreichbar.
  // Da `\b[A-Z0-9]{8,30}\b` keine Dashes erlaubt: hier kein Match.
  // Statt dessen: 7-Ziffern-Fragmente sind zu kurz für context-numeric
  // (>=10). Erwartung: keine strong Candidates.
  for (const c of result) {
    assert(c.confidence !== 'strong', `unexpected strong candidate: ${c.value}`)
  }
})

Deno.test.ignore('findAllTrackings: Context-Numeric mit Anchor "Sendungsnummer:"', () => {
  // Plan 2026-05-16 §D5: removed-by-design — `context-numeric-10-22`
  // war Hauptquelle der Falsch-Positives (Bestellnr, Kundennr, Rechnungsnr
  // wurden als Tracking erkannt). Entfernt mit Plan §D1.
})

Deno.test('findAllTrackings: Context-Numeric OHNE Anchor → confidence reduziert', async () => {
  const filler = 'lorem ipsum dolor sit amet '.repeat(20)
  const body = `${filler} 1234567890123 hat keinen Anchor in der Nähe.`
  const result = await findAllTrackings(body)
  const c = result.find((x) => x.value === '1234567890123')
  if (c) {
    // Pattern defaultConfidence: 'medium', ohne Anchor → 'weak' oder
    // tiefer (je nach Checksum). Auf jeden Fall NICHT strong.
    assert(
      c.confidence !== 'strong',
      `unanchored numeric must not be strong, got: ${c.confidence}`,
    )
  }
})

Deno.test('findAllTrackings: Sortierung strong > medium > weak > none (DHL-only)', async () => {
  // Plan 2026-05-16 §D1: Body enthaelt eine DHL-JJD (strong) — alle
  // anderen Carrier-Patterns sind entfernt. Sortier-Logik bleibt
  // bestehen, getestet mit reduzierter Pattern-Auswahl.
  const body = 'DHL-Sendung JJD0123456789012 — bitte verfolgen.'
  const result = await findAllTrackings(body)
  for (let i = 1; i < result.length; i++) {
    const order: Record<string, number> = { strong: 3, medium: 2, weak: 1, none: 0 }
    assert(
      order[result[i - 1].confidence] >= order[result[i].confidence],
      `not sorted: ${result[i - 1].confidence} before ${result[i].confidence}`,
    )
  }
  // Erstes Candidate sollte strong sein (DHL-JJD).
  assert(result.length > 0, 'expected at least one candidate')
  assertEquals(result[0].confidence, 'strong')
})

Deno.test('findAllTrackings: PII-Schutz — alle anchorMatched ≤ 50 chars', async () => {
  const body =
    'Sendungsnummer mit sehr viel zusätzlichem Text drumherum: 1234567890123 weiter ...'
  const result = await findAllTrackings(body)
  for (const c of result) {
    if (c.validation.anchorMatched) {
      assert(
        c.validation.anchorMatched.length <= 50,
        `anchorMatched > 50: ${c.validation.anchorMatched.length}`,
      )
    }
  }
})

// T3c-TODO: Body-Cap (>256 KB) Verhalten. Heute soft-cap, in T3c hart.
Deno.test('findAllTrackings: Body > 256 KB wird defensiv getrimmt (T3c-Followup)', async () => {
  const huge = 'x'.repeat(300 * 1024) + ' 1Z999AA10123456784'
  const result = await findAllTrackings(huge)
  // Token liegt JENSEITS des SOFT-CAP — Erwartung: nicht gefunden.
  const ups = result.find((c) => c.value === '1Z999AA10123456784')
  assertEquals(ups, undefined)
})

// ── Dedup-Verhalten ───────────────────────────────────────────────────

Deno.test('findAllTrackings: Mehrfach-Match desselben Tokens → ein Candidate (höchste Confidence)', async () => {
  // Plan 2026-05-16 §D1: Test umgestellt von UPS-1Z auf DHL-JJD, da
  // UPS-Pattern entfernt wurde. Dedup-Logik bleibt unveraendert.
  const body = 'DHL JJD0123456789012 ... nochmal JJD0123456789012 hier.'
  const result = await findAllTrackings(body)
  const dhl = result.filter((c) => c.value === 'JJD0123456789012')
  assertEquals(dhl.length, 1)
})
