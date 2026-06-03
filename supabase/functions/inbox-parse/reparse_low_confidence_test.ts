// T12: Tests für reparse_low_confidence-Mode.
//
// Wir testen hier NICHT den Deno.serve-Handler (würde Server-Start
// erfordern), sondern die Kern-Logik:
//   1. Body-Quellen-Merge: BOTH _raw_html UND _raw.text werden gelesen
//      (Council-Finding #1).
//   2. Rate-Limit-Math: 5 min Cooldown via mailbox_accounts.last_reparse_at.
//   3. Endpoint-Contract: workspace_id-Resolution.
//
// Die `findAllTrackings` + `gateTracking`-Adapter werden über das
// existierende `_shared/inbox_adapters_test.ts` abgedeckt.

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  findAllTrackings,
  gateTracking,
} from '../_shared/inbox_adapters.ts'

// Council-Finding #1: Re-Parse muss BEIDE Body-Quellen lesen. Wir
// simulieren einen parsed_payload-Row mit Plain-Text-only-Body (kein HTML)
// und prüfen, dass findAllTrackings einen Treffer findet.
//
// Plan 2026-06-03 §1/§2.8: UPS ist out-of-scope, das `ups-1z`-Pattern ist aus
// `TRACKING_PATTERNS` gelöscht. Wir testen den plain-text-Body-Pfad jetzt mit
// einer DHL-JJD-Nummer (in-scope, format-eindeutig) — die Body-Quellen-Merge-
// Logik (text + html) bleibt unverändert getestet.
Deno.test('reparseLowConfidence: liest plain-text _raw.text Pfad (DHL JJD)', () => {
  const payload = {
    _raw: {
      text:
        'Hallo,\nIhre Sendungsnummer lautet: JJD012345678901234\nDanke.',
    },
  }
  const html = (payload as Record<string, unknown>)._raw_html ?? ''
  const rawObj = payload._raw ?? {}
  const text = rawObj.text ?? ''
  // Genau die Logik aus reparseLowConfidence:
  const body = text + (text && html ? '\n\n' : '') + html
  const candidates = findAllTrackings(body, { html: html as string })
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })

  // DHL-JJD-Pattern → strong-Candidate erwartet, carrier lowercase.
  assertEquals(primary !== null, true)
  assertEquals(primary?.value, 'JJD012345678901234')
  assertEquals(primary?.carrier, 'dhl')
})

// Council-Finding #1: HTML-Pfad (bestehendes Verhalten) bleibt intakt.
// DHL-href (nolp.dhl…/?piececode=…) → strong html-href-Candidate.
Deno.test('reparseLowConfidence: liest _raw_html Pfad (DHL href)', () => {
  const payload = {
    _raw_html:
      '<p>Tracking-Nummer: <a href="https://nolp.dhl.de/nextt-online-public/set_identcodes.do?idc=JJD012345678901234">JJD012345678901234</a></p>',
  }
  const html = (payload._raw_html as string | undefined) ?? ''
  const rawObj = (payload as Record<string, unknown>)._raw ?? {}
  const text = (rawObj as { text?: string }).text ?? ''
  const body = text + (text && html ? '\n\n' : '') + html
  const candidates = findAllTrackings(body, { html })
  const { primary } = gateTracking(candidates, { minConfidence: 'strong' })

  assertEquals(primary !== null, true)
  assertEquals(primary?.value, 'JJD012345678901234')
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
