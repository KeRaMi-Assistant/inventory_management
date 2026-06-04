// Auth-Gate + Auth-Type-Resolution Tests für tracking-poll.
//
// Testet die PURE Hilfsfunktionen `resolveAuthType` und `authGateDecision`,
// die aus dem Handler extrahiert wurden. Vollständige Allow/Deny-Matrix:
//
//   cron      → allow-full  (unabhängig von deal_id)
//   service   → allow-full  (unabhängig von deal_id)
//   jwt + deal_id     → allow-single-deal (Membership-Check folgt im Handler)
//   jwt + no deal_id  → deny-no-deal (kein Bulk für JWT-User)
//   none + deal_id    → deny-401
//   none + no deal_id → deny-401
//
// HTTP-Integration (Membership-DB-Lookup, JWT-Validation) ist NICHT
// im Pure-Function-Scope — der Browser-Smoke-Test deckt den vollen Pfad.

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  authGateDecision,
  resolveAuthType,
  type AuthType,
} from './index.ts'

// ── resolveAuthType ──────────────────────────────────────────────────────────

const CRON_SECRET = 'super-secret-cron-token'
const SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.service'

Deno.test('resolveAuthType: cron secret in header → cron', () => {
  assertEquals(
    resolveAuthType(`Bearer ${CRON_SECRET}`, CRON_SECRET, SERVICE_KEY),
    'cron',
  )
})

Deno.test('resolveAuthType: service key in header → service', () => {
  assertEquals(
    resolveAuthType(`Bearer ${SERVICE_KEY}`, CRON_SECRET, SERVICE_KEY),
    'service',
  )
})

Deno.test('resolveAuthType: unknown bearer token → jwt', () => {
  assertEquals(
    resolveAuthType('Bearer eyJhbGciOiJIUzI1NiJ9.user', CRON_SECRET, SERVICE_KEY),
    'jwt',
  )
})

Deno.test('resolveAuthType: empty auth header → none', () => {
  assertEquals(resolveAuthType('', CRON_SECRET, SERVICE_KEY), 'none')
})

Deno.test('resolveAuthType: no CRON_SECRET configured → jwt (not cron)', () => {
  // Wenn CRON_SECRET nicht gesetzt ist (undefined), darf ein beliebiger
  // Bearer-Token nicht als cron durchgehen.
  assertEquals(
    resolveAuthType(`Bearer ${CRON_SECRET}`, undefined, SERVICE_KEY),
    'jwt',
  )
})

Deno.test('resolveAuthType: no SERVICE_KEY configured → jwt (not service)', () => {
  assertEquals(
    resolveAuthType(`Bearer ${SERVICE_KEY}`, CRON_SECRET, undefined),
    'jwt',
  )
})

Deno.test('resolveAuthType: cron takes priority over service when tokens match', () => {
  // Extremer Edge-Case: beide Secrets zufällig identisch.
  const sameToken = 'shared-secret'
  const result = resolveAuthType(`Bearer ${sameToken}`, sameToken, sameToken)
  assertEquals(result, 'cron') // cron hat Priorität (dokumentierte Reihenfolge)
})

Deno.test('resolveAuthType: non-Bearer prefix → none', () => {
  // Alles ohne "Bearer " Prefix ist kein gültiges JWT-Format.
  assertEquals(
    resolveAuthType('Basic dXNlcjpwYXNz', CRON_SECRET, SERVICE_KEY),
    'none',
  )
})

// ── authGateDecision ─────────────────────────────────────────────────────────

// Hilfsfunktion um alle vier AuthType-Werte prägnant zu iterieren.
const authTypes: AuthType[] = ['cron', 'service', 'jwt', 'none']

Deno.test('authGateDecision: cron → allow-full (with and without deal_id)', () => {
  assertEquals(authGateDecision('cron', false), 'allow-full')
  assertEquals(authGateDecision('cron', true), 'allow-full')
})

Deno.test('authGateDecision: service → allow-full (with and without deal_id)', () => {
  assertEquals(authGateDecision('service', false), 'allow-full')
  assertEquals(authGateDecision('service', true), 'allow-full')
})

Deno.test('authGateDecision: jwt + deal_id → allow-single-deal', () => {
  assertEquals(authGateDecision('jwt', true), 'allow-single-deal')
})

Deno.test('authGateDecision: jwt + no deal_id → deny-no-deal (kein Bulk für JWT)', () => {
  assertEquals(authGateDecision('jwt', false), 'deny-no-deal')
})

Deno.test('authGateDecision: none + deal_id → deny-401 (kein Token)', () => {
  assertEquals(authGateDecision('none', true), 'deny-401')
})

Deno.test('authGateDecision: none + no deal_id → deny-401', () => {
  assertEquals(authGateDecision('none', false), 'deny-401')
})

// ── Vollständige 4×2-Matrix ───────────────────────────────────────────────

Deno.test('authGateDecision: vollständige Matrix', () => {
  // Zeile: authType; Spalte: hasDealId
  const matrix: Record<AuthType, [AuthGateResult, AuthGateResult]> = {
    cron:    ['allow-full',         'allow-full'],
    service: ['allow-full',         'allow-full'],
    jwt:     ['deny-no-deal',       'allow-single-deal'],
    none:    ['deny-401',           'deny-401'],
  }
  for (const authType of authTypes) {
    const [withoutDeal, withDeal] = matrix[authType]
    assertEquals(
      authGateDecision(authType, false),
      withoutDeal,
      `${authType} + no deal_id`,
    )
    assertEquals(
      authGateDecision(authType, true),
      withDeal,
      `${authType} + deal_id`,
    )
  }
})

// ── Semantische Garantien ─────────────────────────────────────────────────

Deno.test('authGateDecision: nur cron/service dürfen allow-full zurückgeben', () => {
  for (const authType of authTypes) {
    for (const hasDeal of [true, false]) {
      const result = authGateDecision(authType, hasDeal)
      if (result === 'allow-full') {
        const isBackend = authType === 'cron' || authType === 'service'
        assertEquals(isBackend, true, `allow-full nur für Backend, nicht ${authType}`)
      }
    }
  }
})

Deno.test('authGateDecision: allow-single-deal nur für jwt + deal_id', () => {
  for (const authType of authTypes) {
    for (const hasDeal of [true, false]) {
      const result = authGateDecision(authType, hasDeal)
      if (result === 'allow-single-deal') {
        assertEquals(authType, 'jwt')
        assertEquals(hasDeal, true)
      }
    }
  }
})

// ── Integration: resolveAuthType → authGateDecision Pipeline ────────────────

Deno.test('Integration: cron-Header → allow-full (kein deal_id)', () => {
  const authType = resolveAuthType(`Bearer ${CRON_SECRET}`, CRON_SECRET, SERVICE_KEY)
  assertEquals(authGateDecision(authType, false), 'allow-full')
})

Deno.test('Integration: service-Header → allow-full (kein deal_id)', () => {
  const authType = resolveAuthType(`Bearer ${SERVICE_KEY}`, CRON_SECRET, SERVICE_KEY)
  assertEquals(authGateDecision(authType, false), 'allow-full')
})

Deno.test('Integration: JWT-User ohne deal_id → deny-no-deal', () => {
  const authType = resolveAuthType('Bearer eyJuser.token', CRON_SECRET, SERVICE_KEY)
  assertEquals(authGateDecision(authType, false), 'deny-no-deal')
})

Deno.test('Integration: JWT-User mit deal_id → allow-single-deal (Membership-Check folgt)', () => {
  const authType = resolveAuthType('Bearer eyJuser.token', CRON_SECRET, SERVICE_KEY)
  assertEquals(authGateDecision(authType, true), 'allow-single-deal')
})

Deno.test('Integration: kein Auth + deal_id → deny-401', () => {
  const authType = resolveAuthType('', CRON_SECRET, SERVICE_KEY)
  assertEquals(authGateDecision(authType, true), 'deny-401')
})

// Typ-Alias für Tests (damit kein TypeScript-Fehler)
type AuthGateResult = ReturnType<typeof authGateDecision>
