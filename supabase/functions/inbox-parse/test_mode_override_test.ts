// TA0c (Plan 2026-05-14_strict_tracking_smoke_audit, Security-Finding #3):
// Tests für den authentifizierten Test-Mode-Override `reset_cooldown`.
//
// Wir testen NICHT den Deno.serve-Handler oder eine echte Supabase-Instanz
// (würde Live-Stack erfordern), sondern den extrahierten reinen
// Validator `evaluateTestModeOverride()`. Damit ist die kritische
// Auth-Entscheidung deterministisch und ohne Mock-Boilerplate testbar.
//
// Die vier Pflicht-Tests aus dem Plan:
//   1) Allowed-User + 'reset_cooldown'        → 'allow'
//   2) Anderer User + gleicher Body           → 'deny'
//   3) Service-Role + test_mode_override      → 'deny'
//   4) Allowed-User + ungültiger Wert ('foo') → 'ignore' (durchfallen)
//
// Zusätzliche Edge-Cases:
//   • Cron-Pfad bekommt ebenfalls 'deny'.
//   • User ohne email (None) bekommt 'deny'.
//   • Allowlist leer (ENV unset) → 'deny' für jeden.
//   • Body ohne test_mode_override → 'none'.
//   • E-Mail-Match ist case-insensitive.

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  buildAllowedEmails,
  evaluateTestModeOverride,
} from './index.ts'

const ALLOWED = buildAllowedEmails('test@test.com')

Deno.test('Test 1: allowed user + reset_cooldown → allow', () => {
  const decision = evaluateTestModeOverride({
    overrideValue: 'reset_cooldown',
    isCron: false,
    isService: false,
    userEmail: 'test@test.com',
    allowedEmails: ALLOWED,
  })
  assertEquals(decision, 'allow')
})

Deno.test('Test 2: non-allowed user + reset_cooldown → deny', () => {
  const decision = evaluateTestModeOverride({
    overrideValue: 'reset_cooldown',
    isCron: false,
    isService: false,
    userEmail: 'attacker@evil.com',
    allowedEmails: ALLOWED,
  })
  assertEquals(decision, 'deny')
})

Deno.test('Test 3: service-role + reset_cooldown → deny (no bypass)', () => {
  const decision = evaluateTestModeOverride({
    overrideValue: 'reset_cooldown',
    isCron: false,
    isService: true,
    // Auch wenn die E-Mail in der Allowlist wäre, muss service-role 403 bekommen.
    userEmail: 'test@test.com',
    allowedEmails: ALLOWED,
  })
  assertEquals(decision, 'deny')
})

Deno.test('Test 4: allowed user + ungültiger Wert (foo) → ignore', () => {
  const decision = evaluateTestModeOverride({
    overrideValue: 'foo',
    isCron: false,
    isService: false,
    userEmail: 'test@test.com',
    allowedEmails: ALLOWED,
  })
  assertEquals(decision, 'ignore')
})

// ── Edge Cases ─────────────────────────────────────────────────────────

Deno.test('Edge: cron-pfad + reset_cooldown → deny', () => {
  const decision = evaluateTestModeOverride({
    overrideValue: 'reset_cooldown',
    isCron: true,
    isService: false,
    userEmail: 'test@test.com',
    allowedEmails: ALLOWED,
  })
  assertEquals(decision, 'deny')
})

Deno.test('Edge: user without email → deny', () => {
  const decision = evaluateTestModeOverride({
    overrideValue: 'reset_cooldown',
    isCron: false,
    isService: false,
    userEmail: null,
    allowedEmails: ALLOWED,
  })
  assertEquals(decision, 'deny')
})

Deno.test('Edge: empty allowlist (ENV unset) → deny for anyone', () => {
  const empty = buildAllowedEmails('')
  const decision = evaluateTestModeOverride({
    overrideValue: 'reset_cooldown',
    isCron: false,
    isService: false,
    userEmail: 'test@test.com',
    allowedEmails: empty,
  })
  assertEquals(decision, 'deny')
})

Deno.test('Edge: no override in body → none', () => {
  const decision = evaluateTestModeOverride({
    overrideValue: undefined,
    isCron: false,
    isService: false,
    userEmail: 'test@test.com',
    allowedEmails: ALLOWED,
  })
  assertEquals(decision, 'none')
})

Deno.test('Edge: email match is case-insensitive', () => {
  const decision = evaluateTestModeOverride({
    overrideValue: 'reset_cooldown',
    isCron: false,
    isService: false,
    userEmail: 'TEST@Test.COM',
    allowedEmails: ALLOWED,
  })
  assertEquals(decision, 'allow')
})

Deno.test('Edge: allowlist whitespace trimmed', () => {
  const set = buildAllowedEmails('  test@test.com  ')
  assertEquals(set.has('test@test.com'), true)
  assertEquals(set.size, 1)
})

Deno.test('Edge: allowlist empty string yields empty set', () => {
  const set = buildAllowedEmails('')
  assertEquals(set.size, 0)
})
