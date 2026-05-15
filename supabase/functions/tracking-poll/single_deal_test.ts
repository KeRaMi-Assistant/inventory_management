// Tests für den Single-Deal-Re-Track-Pfad in tracking-poll.
//
// Pure-Function-Tests gegen die exportierten Helper:
//   * `parseDealIdFromBody` — Body-Validierung (400 bei kaputtem deal_id).
//   * `computeRetrackCooldown` — 30s-Cooldown via live_status_updated_at.
//
// HTTP-Integration (Auth-Workflow, workspace_members-Lookup) testen wir
// nicht in Deno-Unit — das deckt der Browser-Smoke-Test ab.

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  computeRetrackCooldown,
  parseDealIdFromBody,
} from './index.ts'

// ── parseDealIdFromBody ──────────────────────────────────────────────────

Deno.test('parseDealIdFromBody: valid integer → returns dealId', () => {
  assertEquals(parseDealIdFromBody({ deal_id: 42 }), { dealId: 42 })
})

Deno.test('parseDealIdFromBody: numeric string → returns dealId', () => {
  assertEquals(parseDealIdFromBody({ deal_id: '42' }), { dealId: 42 })
})

Deno.test('parseDealIdFromBody: missing deal_id → empty object (no error)', () => {
  assertEquals(parseDealIdFromBody({}), {})
  assertEquals(parseDealIdFromBody({ deal_id: undefined }), {})
  assertEquals(parseDealIdFromBody({ deal_id: null }), {})
})

Deno.test('parseDealIdFromBody: zero or negative → error', () => {
  assertEquals(parseDealIdFromBody({ deal_id: 0 }), { error: 'invalid deal_id' })
  assertEquals(parseDealIdFromBody({ deal_id: -5 }), { error: 'invalid deal_id' })
})

Deno.test('parseDealIdFromBody: non-integer → error', () => {
  assertEquals(
    parseDealIdFromBody({ deal_id: 1.5 }),
    { error: 'invalid deal_id' },
  )
  assertEquals(
    parseDealIdFromBody({ deal_id: 'abc' }),
    { error: 'invalid deal_id' },
  )
})

Deno.test('parseDealIdFromBody: non-object body → empty object', () => {
  assertEquals(parseDealIdFromBody(null), {})
  assertEquals(parseDealIdFromBody('string'), {})
  assertEquals(parseDealIdFromBody(42), {})
})

// ── computeRetrackCooldown ───────────────────────────────────────────────

const T0 = '2026-05-15T10:00:00.000Z'
const T0_MS = new Date(T0).getTime()

Deno.test('computeRetrackCooldown: null last → no cooldown', () => {
  assertEquals(computeRetrackCooldown(null, T0_MS), null)
})

Deno.test('computeRetrackCooldown: old timestamp (>30s) → no cooldown', () => {
  // 60s ago
  assertEquals(computeRetrackCooldown(T0, T0_MS + 60_000), null)
})

Deno.test('computeRetrackCooldown: exactly 30s → no cooldown (boundary)', () => {
  assertEquals(computeRetrackCooldown(T0, T0_MS + 30_000), null)
})

Deno.test('computeRetrackCooldown: 5s ago → retry-after 25s', () => {
  assertEquals(computeRetrackCooldown(T0, T0_MS + 5_000), 25)
})

Deno.test('computeRetrackCooldown: same moment → retry-after 30s', () => {
  assertEquals(computeRetrackCooldown(T0, T0_MS), 30)
})

Deno.test('computeRetrackCooldown: future timestamp → no cooldown (defensive)', () => {
  assertEquals(computeRetrackCooldown(T0, T0_MS - 5_000), null)
})

Deno.test('computeRetrackCooldown: invalid date → no cooldown', () => {
  assertEquals(computeRetrackCooldown('not-a-date', T0_MS), null)
})

Deno.test('computeRetrackCooldown: custom cooldown window respected', () => {
  // 10s ago, cooldown=60s → retry-after 50s.
  assertEquals(computeRetrackCooldown(T0, T0_MS + 10_000, 60_000), 50)
})
