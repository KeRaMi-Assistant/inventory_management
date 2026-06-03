// Plan 2026-06-03, T6 — Reduziert auf die überlebenden Helper.
//
// `enrichWithDhlValidation` + `ParsedMessageLike` wurden in T3 gelöscht
// (das API-Detection-Gate, das jedes Tracking ohne DHL-Key droppte). Die
// alten 6 enrich-Cases sind ersatzlos entfernt — Detection läuft jetzt
// rein algorithmisch in `tracking_detection.ts` (`detect()`), abgedeckt von
// `tracking_detection_test.ts` + `inbox_vat_reject_test.ts`.
//
// Hier verbleiben nur Smoke-Tests für die 3 Helper, die `tracking_validation.ts`
// noch exportiert:
//   * `normalizeTracking`        — Whitespace-strip + uppercase.
//   * `isCacheFresh`             — TTL-Helper (valid 7d / invalid 30d / unknown 1h).
//   * `stampPipelineHeartbeat`   — best-effort last_polled_at-Stempel.
//
// Ausführen mit:
//   deno test --allow-all supabase/functions/_shared/tracking_validation_test.ts

import {
  assert,
  assertEquals,
} from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  type CacheRow,
  isCacheFresh,
  normalizeTracking,
  stampPipelineHeartbeat,
} from './tracking_validation.ts'

// ── normalizeTracking ─────────────────────────────────────────────────

Deno.test('normalizeTracking: strippt Whitespace + uppercased', () => {
  assertEquals(normalizeTracking('jjd 0123 4567 8901'), 'JJD012345678901')
  assertEquals(normalizeTracking('  tba123456789012  '), 'TBA123456789012')
  assertEquals(normalizeTracking('00340434161094021501'), '00340434161094021501')
})

Deno.test('normalizeTracking: bereits normalisiert bleibt stabil', () => {
  assertEquals(normalizeTracking('JJD012345678901'), 'JJD012345678901')
})

// ── isCacheFresh ──────────────────────────────────────────────────────

const cacheRow = (
  state: CacheRow['result_state'],
  ageMs: number,
  nowMs: number,
): CacheRow => ({
  tracking_norm: 'JJD012345678901',
  is_valid: state === 'valid',
  result_state: state,
  last_checked_at: new Date(nowMs - ageMs).toISOString(),
})

Deno.test('isCacheFresh: valid TTL = 7 Tage', () => {
  const now = Date.now()
  const day = 24 * 60 * 60 * 1000
  assert(isCacheFresh(cacheRow('valid', 6 * day, now), now), 'valid 6d ist frisch')
  assert(!isCacheFresh(cacheRow('valid', 8 * day, now), now), 'valid 8d ist abgelaufen')
})

Deno.test('isCacheFresh: invalid TTL = 30 Tage', () => {
  const now = Date.now()
  const day = 24 * 60 * 60 * 1000
  assert(isCacheFresh(cacheRow('invalid', 29 * day, now), now), 'invalid 29d ist frisch')
  assert(!isCacheFresh(cacheRow('invalid', 31 * day, now), now), 'invalid 31d ist abgelaufen')
})

Deno.test('isCacheFresh: unknown TTL = 1 Stunde', () => {
  const now = Date.now()
  const hour = 60 * 60 * 1000
  assert(isCacheFresh(cacheRow('unknown', 30 * 60 * 1000, now), now), 'unknown 30min ist frisch')
  assert(!isCacheFresh(cacheRow('unknown', 2 * hour, now), now), 'unknown 2h ist abgelaufen')
})

Deno.test('isCacheFresh: ungültiger Timestamp → nicht frisch', () => {
  const row: CacheRow = {
    tracking_norm: 'X',
    is_valid: true,
    result_state: 'valid',
    last_checked_at: 'not-a-date',
  }
  assertEquals(isCacheFresh(row, Date.now()), false)
})

// ── stampPipelineHeartbeat ────────────────────────────────────────────

Deno.test('stampPipelineHeartbeat: ruft update() auf dem DHL-Key-Pfad', async () => {
  const calls: Array<{ table: string; eqs: Array<[string, string]> }> = []
  const mock = {
    from(table: string) {
      const eqs: Array<[string, string]> = []
      const chain = {
        update(_row: Record<string, unknown>) {
          calls.push({ table, eqs })
          return chain
        },
        eq(col: string, val: string) {
          eqs.push([col, val])
          return chain
        },
      }
      return chain
    },
  }
  // deno-lint-ignore no-explicit-any
  await stampPipelineHeartbeat(mock as any, 'ws-1')
  assertEquals(calls.length, 1)
  assertEquals(calls[0].table, 'workspace_carrier_credentials')
  assert(calls[0].eqs.some(([c, v]) => c === 'workspace_id' && v === 'ws-1'))
  assert(calls[0].eqs.some(([c, v]) => c === 'carrier_id' && v === 'dhl'))
})

Deno.test('stampPipelineHeartbeat: schluckt Fehler still (best-effort, kein Throw)', async () => {
  const mock = {
    from(_table: string) {
      throw new Error('db down')
    },
  }
  // Darf NICHT werfen — best-effort Heartbeat.
  // deno-lint-ignore no-explicit-any
  await stampPipelineHeartbeat(mock as any, 'ws-1')
})
