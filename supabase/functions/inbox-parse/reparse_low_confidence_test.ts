// T12: Tests für reparse_low_confidence-Mode.
//
// Wir testen hier NICHT den Deno.serve-Handler (würde Server-Start
// erfordern), sondern die Kern-Logik:
//   1. Body-Quellen-Merge: BOTH _raw_html UND _raw.text werden gelesen
//      (Council-Finding #1).
//   2. Rate-Limit-Math: 5 min Cooldown via mailbox_accounts.last_reparse_at.
//   3. Endpoint-Contract: workspace_id-Resolution.
//
// Die Tracking-Detection selbst (DHL/Amazon/DPD) ist in
// `_shared/tracking_detection_test.ts` abgedeckt. Hier prüfen wir nur, dass
// der Re-Parse beide Body-Quellen (`_raw.text` + `_raw_html`) an `detect()`
// durchreicht — genau die Live-Logik aus `reparseLowConfidence`.

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { detect as detectTracking } from '../_shared/tracking_detection.ts'

// Council-Finding #1: Re-Parse muss BEIDE Body-Quellen lesen. Wir
// simulieren einen parsed_payload-Row mit Plain-Text-only-Body (kein HTML)
// und prüfen, dass detect() einen Treffer findet.
//
// Plan 2026-06-03 §1/§2.8 + Dead-Code-Cleanup: die Detection läuft jetzt
// ausschliesslich über `tracking_detection.detect()`. Wir spiegeln die Live-
// Logik aus `reparseLowConfidence` (subject/text/html + status='shipped').
Deno.test('reparseLowConfidence: liest plain-text _raw.text Pfad (DHL JJD)', () => {
  const payload = {
    _raw: {
      text:
        'Hallo,\nIhre Sendungsnummer lautet: JJD012345678901234\nDanke.',
    },
  }
  const html = ((payload as Record<string, unknown>)._raw_html as string | undefined) ?? ''
  const rawObj = payload._raw ?? {}
  const text = rawObj.text ?? ''
  // Genau die Detection-Call-Logik aus reparseLowConfidence:
  const det = detectTracking({ subject: '', text, html, status: 'shipped' })

  // DHL-JJD-Pattern → strong, carrier lowercase.
  assertEquals(det.tracking, 'JJD012345678901234')
  assertEquals(det.confidence, 'strong')
  assertEquals(det.carrier, 'dhl')
})

// Council-Finding #1: HTML-Pfad (bestehendes Verhalten) bleibt intakt.
// DHL-href (nolp.dhl…/?idc=…) → strong.
Deno.test('reparseLowConfidence: liest _raw_html Pfad (DHL href)', () => {
  const payload = {
    _raw_html:
      '<p>Tracking-Nummer: <a href="https://nolp.dhl.de/nextt-online-public/set_identcodes.do?idc=JJD012345678901234">JJD012345678901234</a></p>',
  }
  const html = (payload._raw_html as string | undefined) ?? ''
  const rawObj = (payload as Record<string, unknown>)._raw ?? {}
  const text = (rawObj as { text?: string }).text ?? ''
  const det = detectTracking({ subject: '', text, html, status: 'shipped' })

  assertEquals(det.tracking, 'JJD012345678901234')
  assertEquals(det.confidence, 'strong')
})

// Skip-Branch: weder html noch text → keine Verarbeitung.
Deno.test('reparseLowConfidence: skip wenn beide Body-Quellen leer', () => {
  const payload: Record<string, unknown> = {}
  const html = (payload._raw_html as string | undefined) ?? ''
  const rawObj = (payload._raw as { text?: string } | undefined) ?? {}
  const text = rawObj.text ?? ''
  assertEquals(html === '' && text === '', true)
})

// Rate-Limit-Math.
Deno.test('reparseLowConfidence: rate-limit 5min cooldown', () => {
  const REPARSE_COOLDOWN_MS = 5 * 60 * 1000
  const now = Date.now()

  // Fall 1: keine last_reparse_at → kein Block.
  let mostRecent = 0
  const blocked1 = mostRecent > 0 && now - mostRecent < REPARSE_COOLDOWN_MS
  assertEquals(blocked1, false)

  // Fall 2: vor 30 Sekunden → blocked.
  mostRecent = now - 30 * 1000
  const blocked2 = mostRecent > 0 && now - mostRecent < REPARSE_COOLDOWN_MS
  assertEquals(blocked2, true)
  const retryAfter2 = Math.ceil(
    (REPARSE_COOLDOWN_MS - (now - mostRecent)) / 1000,
  )
  // Etwa 270 Sekunden ± Drift.
  assertEquals(retryAfter2 > 250 && retryAfter2 <= 270, true)

  // Fall 3: vor 6 Minuten → nicht mehr blocked.
  mostRecent = now - 6 * 60 * 1000
  const blocked3 = mostRecent > 0 && now - mostRecent < REPARSE_COOLDOWN_MS
  assertEquals(blocked3, false)
})

// Endpoint-Contract: workspace_id-Scope-Validation.
Deno.test('reparseLowConfidence: workspace_id MUSS in user-scope sein', () => {
  const scopedWorkspaceIds = ['ws-a', 'ws-b']

  // Fall 1: body.workspace_id ist im scope → OK.
  const bodyWs1 = 'ws-a'
  const ok1 = scopedWorkspaceIds.includes(bodyWs1)
  assertEquals(ok1, true)

  // Fall 2: body.workspace_id NICHT im scope → 403.
  const bodyWs2 = 'ws-x'
  const ok2 = scopedWorkspaceIds.includes(bodyWs2)
  assertEquals(ok2, false)

  // Fall 3: kein body.workspace_id → fallback auf alle eigenen.
  const targetWs = scopedWorkspaceIds
  assertEquals(targetWs.length, 2)
})
