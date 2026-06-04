// Plan 2026-06-03, T6 — Reduziert auf die überlebenden Helper.
//
// `enrichWithDhlValidation` + `ParsedMessageLike` wurden in T3 gelöscht
// (das API-Detection-Gate, das jedes Tracking ohne DHL-Key droppte). Die
// alten 6 enrich-Cases sind ersatzlos entfernt — Detection läuft jetzt
// rein algorithmisch in `tracking_detection.ts` (`detect()`), abgedeckt von
// `tracking_detection_test.ts` + `inbox_vat_reject_test.ts`.
//
// Hier verbleiben nur Smoke-Tests für die 2 Helper, die `tracking_validation.ts`
// noch exportiert:
//   * `normalizeTracking`        — Whitespace-strip + uppercase.
//   * `stampPipelineHeartbeat`   — best-effort last_polled_at-Stempel.
//
// Die `isCacheFresh`/`CacheRow`-Cache-Helper wurden mit dem Dead-Code-Cleanup
// entfernt (Tabelle `tracking_validation_cache` gedroppt) — ihre Tests fielen
// ersatzlos weg.
//
// Ausführen mit:
//   deno test --allow-all supabase/functions/_shared/tracking_validation_test.ts

import {
  assert,
  assertEquals,
} from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
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
