// Plan 2026-05-16 §D5/Tests — Unit-Tests fuer enrichWithDhlValidation().
//
// Deckt die 6 Pflicht-Cases ab:
//   1. No-API-Key short-circuit
//   2. Cache-Hit valid → kein API-Call
//   3. Cache-Miss → API valid → upsert + trackings=[...]
//   4. Cache-Miss → API null (404) → tracking_needs_review
//   5. Hard-Limit-5 + validation_capped-Log
//   6. Spike-Arrest: sleep wird vor 2./3. Call gerufen, NICHT vor erstem
//
// Ausfuehren mit:
//
//   deno test --allow-all supabase/functions/_shared/tracking_validation_test.ts

import {
  assert,
  assertEquals,
} from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  enrichWithDhlValidation,
  type ParsedMessageLike,
} from './tracking_validation.ts'
import type { ParsedTracking, TrackingAdapter } from './tracking_adapters.ts'

// ── Test-Helper ───────────────────────────────────────────────────────

interface CacheRow {
  tracking_norm: string
  is_valid: boolean
  result_state: 'valid' | 'invalid' | 'unknown'
  last_checked_at: string
}

interface UpsertRecord {
  tracking_norm: string
  is_valid: boolean
  result_state: string
  status_raw: unknown
}

function mockSupabase(
  cacheRows: Record<string, CacheRow>,
  upserts: UpsertRecord[],
) {
  return {
    from: (_table: string) => ({
      select: (_cols: string) => ({
        eq: (_col: string, val: string) => ({
          maybeSingle: () =>
            Promise.resolve({ data: cacheRows[val] ?? null, error: null }),
        }),
      }),
      upsert: (row: Record<string, unknown>, _opts?: { onConflict?: string }) => {
        upserts.push({
          tracking_norm: row.tracking_norm as string,
          is_valid: row.is_valid as boolean,
          result_state: row.result_state as string,
          status_raw: row.status_raw,
        })
        return Promise.resolve({ error: null })
      },
    }),
  }
}

function mockDhlAdapter(
  responder: (tn: string) => ParsedTracking | null,
): TrackingAdapter {
  return {
    id: 'dhl',
    label: 'DHL',
    fetchStatus: (tn: string, _key: string) => Promise.resolve(responder(tn)),
    parseResponse: () => null,
  }
}

function captureWarns(): { log: string[]; restore: () => void } {
  const log: string[] = []
  const orig = console.warn
  console.warn = (msg: unknown) => {
    log.push(typeof msg === 'string' ? msg : JSON.stringify(msg))
  }
  return {
    log,
    restore: () => {
      console.warn = orig
    },
  }
}

const sleepMockFactory = (): { calls: number; fn: (ms: number) => Promise<void> } => {
  let calls = 0
  return {
    get calls() {
      return calls
    },
    fn: (_ms: number) => {
      calls++
      return Promise.resolve()
    },
  }
}

// ── Tests ─────────────────────────────────────────────────────────────

Deno.test('enrichWithDhlValidation: No-API-Key short-circuit → trackings=[], needs_review=true (shipped)', async () => {
  const parsed: ParsedMessageLike = {
    trackingCandidates: [
      { value: 'JJD012345678901234', confidence: 'strong', carrier: 'DHL' },
    ],
  }
  const upserts: UpsertRecord[] = []
  const mockDhl = mockDhlAdapter(() => ({ status: 'in_transit' }))

  const result = await enrichWithDhlValidation(parsed, {
    status: 'shipped',
    workspaceId: 'ws-1',
    apiKey: null,
    supabaseAdmin: mockSupabase({}, upserts),
    dhlAdapterOverride: mockDhl,
  })

  assertEquals(result.trackings, [])
  assertEquals(result.tracking, null)
  assertEquals(result.tracking_confidence, 'none')
  assertEquals(result.tracking_needs_review, true)
  assertEquals(upserts.length, 0, 'no API-call → no upsert')
})

Deno.test('enrichWithDhlValidation: No-API-Key + status=ordered → needs_review=false', async () => {
  const parsed: ParsedMessageLike = {
    trackingCandidates: [
      { value: 'JJD012345678901234', confidence: 'strong', carrier: 'DHL' },
    ],
  }
  const upserts: UpsertRecord[] = []
  const mockDhl = mockDhlAdapter(() => null)

  const result = await enrichWithDhlValidation(parsed, {
    status: 'ordered',
    workspaceId: 'ws-1',
    apiKey: null,
    supabaseAdmin: mockSupabase({}, upserts),
    dhlAdapterOverride: mockDhl,
  })

  assertEquals(result.tracking_needs_review, false)
  assertEquals(result.trackings, [])
})

Deno.test('enrichWithDhlValidation: Cache-Hit valid → kein API-Call', async () => {
  const trackingNorm = 'JJD012345678901234'
  const cacheRows: Record<string, CacheRow> = {
    [trackingNorm]: {
      tracking_norm: trackingNorm,
      is_valid: true,
      result_state: 'valid',
      last_checked_at: new Date().toISOString(),
    },
  }
  const upserts: UpsertRecord[] = []
  let fetchCalled = false
  const mockDhl: TrackingAdapter = {
    id: 'dhl',
    label: 'DHL',
    fetchStatus: (_tn: string, _key: string) => {
      fetchCalled = true
      return Promise.resolve({ status: 'in_transit' })
    },
    parseResponse: () => null,
  }
  const parsed: ParsedMessageLike = {
    trackingCandidates: [
      { value: trackingNorm, confidence: 'strong', carrier: 'DHL' },
    ],
  }

  const result = await enrichWithDhlValidation(parsed, {
    status: 'shipped',
    workspaceId: 'ws-1',
    apiKey: 'KEY',
    supabaseAdmin: mockSupabase(cacheRows, upserts),
    dhlAdapterOverride: mockDhl,
  })

  assertEquals(fetchCalled, false, 'cache hit must skip fetch')
  assertEquals(upserts.length, 0, 'cache hit must skip upsert')
  assertEquals(result.trackings, [trackingNorm])
  assertEquals(result.tracking, trackingNorm)
  assertEquals(result.tracking_confidence, 'strong')
  assertEquals(result.tracking_needs_review, false)
})

Deno.test('enrichWithDhlValidation: Cache-Miss → API valid → upsert + trackings populated', async () => {
  const trackingNorm = 'JJD000000000VALID1'
  const upserts: UpsertRecord[] = []
  const mockDhl = mockDhlAdapter((tn) =>
    tn === trackingNorm ? { status: 'in_transit' } : null,
  )
  const parsed: ParsedMessageLike = {
    trackingCandidates: [
      { value: trackingNorm, confidence: 'strong', carrier: 'DHL' },
    ],
  }

  const result = await enrichWithDhlValidation(parsed, {
    status: 'shipped',
    workspaceId: 'ws-1',
    apiKey: 'KEY',
    supabaseAdmin: mockSupabase({}, upserts),
    dhlAdapterOverride: mockDhl,
  })

  assertEquals(result.trackings, [trackingNorm])
  assertEquals(result.tracking, trackingNorm)
  assertEquals(result.tracking_confidence, 'strong')
  assertEquals(result.tracking_needs_review, false)
  assertEquals(upserts.length, 1)
  assertEquals(upserts[0].tracking_norm, trackingNorm)
  assertEquals(upserts[0].is_valid, true)
  assertEquals(upserts[0].result_state, 'valid')
})

Deno.test('enrichWithDhlValidation: Cache-Miss → API null (404) → invalid + needs_review (shipped)', async () => {
  const trackingNorm = 'JJD000000000ABSENT'
  const upserts: UpsertRecord[] = []
  const mockDhl = mockDhlAdapter(() => null)
  const parsed: ParsedMessageLike = {
    trackingCandidates: [
      { value: trackingNorm, confidence: 'strong', carrier: 'DHL' },
    ],
  }

  const result = await enrichWithDhlValidation(parsed, {
    status: 'shipped',
    workspaceId: 'ws-1',
    apiKey: 'KEY',
    supabaseAdmin: mockSupabase({}, upserts),
    dhlAdapterOverride: mockDhl,
  })

  assertEquals(result.trackings, [])
  assertEquals(result.tracking, null)
  assertEquals(result.tracking_confidence, 'none')
  assertEquals(result.tracking_needs_review, true)
  assertEquals(upserts.length, 1)
  assertEquals(upserts[0].is_valid, false)
  assertEquals(upserts[0].result_state, 'invalid')
})

Deno.test('enrichWithDhlValidation: Hard-Limit-5 → genau 5 API-Calls + validation_capped warn-log', async () => {
  const candidates = Array.from({ length: 7 }, (_, i) => ({
    value: `JJD00000000VALID${String(i).padStart(2, '0')}`,
    confidence: 'strong' as const,
    carrier: 'DHL',
  }))
  const upserts: UpsertRecord[] = []
  let fetchCount = 0
  const mockDhl: TrackingAdapter = {
    id: 'dhl',
    label: 'DHL',
    fetchStatus: (_tn: string, _key: string) => {
      fetchCount++
      return Promise.resolve(null) // alle invalid — kein Cache-Pollution-Risiko
    },
    parseResponse: () => null,
  }
  const sleepMock = sleepMockFactory()
  const parsed: ParsedMessageLike = { trackingCandidates: candidates }

  const warns = captureWarns()
  try {
    await enrichWithDhlValidation(parsed, {
      status: 'shipped',
      workspaceId: 'ws-1',
      apiKey: 'KEY',
      supabaseAdmin: mockSupabase({}, upserts),
      dhlAdapterOverride: mockDhl,
      sleep: sleepMock.fn,
    })
  } finally {
    warns.restore()
  }

  assertEquals(fetchCount, 5, 'Hard-Limit cap auf 5 API-Calls')
  assertEquals(upserts.length, 5)
  const cappedLog = warns.log.find((l) => l.includes('validation_capped'))
  assert(cappedLog !== undefined, 'expected validation_capped warn-log')
  const parsedLog = JSON.parse(cappedLog!)
  assertEquals(parsedLog.event, 'validation_capped')
  assertEquals(parsedLog.candidate_count, 7)
  assertEquals(parsedLog.dropped_count, 2)
  assertEquals(parsedLog.workspace_id, 'ws-1')
})

Deno.test('enrichWithDhlValidation: Spike-Arrest → sleep wird (n-1) Mal gerufen, nicht vor erstem Call', async () => {
  const candidates = [
    { value: 'JJD000000000FIRST1', confidence: 'strong' as const, carrier: 'DHL' },
    { value: 'JJD000000000SECOND', confidence: 'strong' as const, carrier: 'DHL' },
    { value: 'JJD000000000THIRD1', confidence: 'strong' as const, carrier: 'DHL' },
  ]
  const upserts: UpsertRecord[] = []
  const mockDhl = mockDhlAdapter(() => null) // alle invalid, jeder triggert API-Call
  const sleepMock = sleepMockFactory()
  const parsed: ParsedMessageLike = { trackingCandidates: candidates }

  await enrichWithDhlValidation(parsed, {
    status: 'shipped',
    workspaceId: 'ws-1',
    apiKey: 'KEY',
    supabaseAdmin: mockSupabase({}, upserts),
    dhlAdapterOverride: mockDhl,
    sleep: sleepMock.fn,
  })

  // 3 Kandidaten → 3 API-Calls → sleep zwischen Call 1 und 2, sowie Call 2
  // und 3 = 2 sleep-Aufrufe (Spike-Arrest gilt nur ZWISCHEN Calls).
  assertEquals(sleepMock.calls, 2, 'sleep darf vor erstem API-Call NICHT laufen')
})

Deno.test('enrichWithDhlValidation: Network-Exception → unknown-Cache (kein Cache-Poisoning)', async () => {
  const trackingNorm = 'JJD000000000NETERR'
  const upserts: UpsertRecord[] = []
  const mockDhl: TrackingAdapter = {
    id: 'dhl',
    label: 'DHL',
    fetchStatus: (_tn: string, _key: string) => Promise.reject(new Error('ECONNRESET')),
    parseResponse: () => null,
  }
  const parsed: ParsedMessageLike = {
    trackingCandidates: [
      { value: trackingNorm, confidence: 'strong', carrier: 'DHL' },
    ],
  }

  const result = await enrichWithDhlValidation(parsed, {
    status: 'shipped',
    workspaceId: 'ws-1',
    apiKey: 'KEY',
    supabaseAdmin: mockSupabase({}, upserts),
    dhlAdapterOverride: mockDhl,
  })

  assertEquals(result.trackings, [])
  assertEquals(result.tracking_needs_review, true)
  assertEquals(upserts.length, 1)
  assertEquals(upserts[0].result_state, 'unknown', 'Network-Error → unknown TTL (1h, kein Cache-Poison)')
})
