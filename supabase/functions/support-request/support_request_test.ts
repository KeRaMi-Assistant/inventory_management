// Tests für die reinen support-request-Helfer (Validierung, Mail-Builder,
// HTML-Escape). Auth/DB/Resend/ntfy werden nicht netzwerkig getestet.
//
//   deno test --no-check supabase/functions/support-request/support_request_test.ts

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/assert_equals.ts'
import { assert } from 'https://deno.land/std@0.224.0/assert/assert.ts'
import {
  buildSupportMail,
  escapeHtml,
  validateSupportPayload,
} from './index.ts'

// ── Validierung ──────────────────────────────────────────────────────────

Deno.test('validate: gültiger Payload inkl. Trimming', () => {
  const r = validateSupportPayload({
    subject: '  Problem mit Tracking  ',
    message: 'Die Sendung XYZ wird nicht aktualisiert, seit 3 Tagen.',
    workspace_id: 'ws-1',
    app_version: '1.2.3',
  })
  assert('payload' in r)
  const p = (r as { payload: { subject: string } }).payload
  assertEquals(p.subject, 'Problem mit Tracking')
})

Deno.test('validate: subject-Grenzen 3–150', () => {
  const msg = 'Eine ausreichend lange Nachricht für den Test.'
  assert('error' in validateSupportPayload({ subject: 'ab', message: msg }))
  assert('error' in validateSupportPayload({ subject: 'x'.repeat(151), message: msg }))
  assert('payload' in validateSupportPayload({ subject: 'abc', message: msg }))
  assert('payload' in validateSupportPayload({ subject: 'x'.repeat(150), message: msg }))
})

Deno.test('validate: message-Grenzen 10–5000', () => {
  assert('error' in validateSupportPayload({ subject: 'Titel', message: 'zu kurz' }))
  assert('error' in validateSupportPayload({ subject: 'Titel', message: 'x'.repeat(5001) }))
  assert('payload' in validateSupportPayload({ subject: 'Titel', message: 'x'.repeat(10) }))
})

Deno.test('validate: kaputte Bodies → error', () => {
  assert('error' in validateSupportPayload(null))
  assert('error' in validateSupportPayload('string'))
  assert('error' in validateSupportPayload({ subject: 42, message: [] }))
})

Deno.test('validate: app_version wird auf 50 Zeichen gekappt', () => {
  const r = validateSupportPayload({
    subject: 'Titel',
    message: 'Nachricht lang genug.',
    app_version: 'v'.repeat(100),
  })
  assert('payload' in r)
  assertEquals((r as { payload: { appVersion?: string } }).payload.appVersion!.length, 50)
})

// ── Mail-Builder ─────────────────────────────────────────────────────────

Deno.test('buildSupportMail: Titel, Kunde und Anliegen enthalten', () => {
  const m = buildSupportMail({
    subject: 'Tracking hängt',
    message: 'Seit gestern keine Updates mehr.',
    email: 'kunde@example.com',
    plan: 'soloPro',
    workspaceId: 'ws-42',
    appVersion: '1.2.3',
    requestId: 7,
  })
  assertEquals(m.subject, '[Support #7] Tracking hängt')
  assert(m.text.includes('Kunde: kunde@example.com'))
  assert(m.text.includes('Plan: soloPro'))
  assert(m.text.includes('Seit gestern keine Updates mehr.'))
  assert(m.html.includes('kunde@example.com'))
  assert(m.html.includes('Tracking hängt'))
})

Deno.test('buildSupportMail: User-Input wird HTML-escaped (kein XSS in Mail)', () => {
  const m = buildSupportMail({
    subject: '<script>alert(1)</script>',
    message: 'Hallo <img src=x onerror=alert(2)> Welt, langer Text.',
    email: 'a@b.c',
    plan: null,
    workspaceId: null,
    appVersion: null,
    requestId: 1,
  })
  assert(!m.html.includes('<script>'))
  assert(!m.html.includes('<img'))
  assert(m.html.includes('&lt;script&gt;'))
})

Deno.test('escapeHtml: alle 5 Spezialzeichen', () => {
  assertEquals(escapeHtml(`<a href="x" data-y='z'>&`), '&lt;a href=&quot;x&quot; data-y=&#39;z&#39;&gt;&amp;')
})
