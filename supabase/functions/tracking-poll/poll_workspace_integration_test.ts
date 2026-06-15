// Integrationstests für den pollWorkspace-Loop (Review-Lücke #3 aus dem
// Multi-Parcel-Review: Aggregat-Completion war nur auf Pure-Function-Ebene
// getestet). Hier läuft der ECHTE Loop — Adapter-HTTP wird über einen
// ADAPTERS.dhl.fetchStatus-Override ersetzt (entkoppelt vom XML-Parsing),
// DB-Calls über einen thenable Fake-Admin-Client abgefangen + aufgezeichnet.
//
//   deno test --no-check supabase/functions/tracking-poll/poll_workspace_integration_test.ts

import { assert } from 'https://deno.land/std@0.224.0/assert/assert.ts'
import { assertEquals } from 'https://deno.land/std@0.224.0/assert/assert_equals.ts'
import { pollWorkspace } from './index.ts'
import { ADAPTERS, type ParsedTracking } from '../_shared/tracking_adapters.ts'

// ── Canned ParsedTracking ──────────────────────────────────────────────────
const delivered = (at: string): ParsedTracking => ({
  status: 'delivered',
  deliveredAt: at,
  lastEvent: 'Zugestellt',
  events: [{ occurredAt: at, status: 'delivered', text: 'Zugestellt' }],
})
const inTransit = (at: string): ParsedTracking => ({
  status: 'in_transit',
  lastEvent: 'Im Zustellzentrum',
  statusTimestamp: at,
  events: [{ occurredAt: at, status: 'in_transit', text: 'Im Zustellzentrum' }],
})

// ── Fake-Admin: thenable Chainable, zeichnet Writes auf ────────────────────
interface Writes {
  updates: { table: string; payload: Record<string, unknown> }[]
  inserts: { table: string; payload: unknown }[]
  upserts: { table: string; payload: unknown }[]
}

function makeFakeAdmin(deals: Record<string, unknown>[]) {
  const writes: Writes = { updates: [], inserts: [], upserts: [] }

  function builder(table: string) {
    let op: 'select' | 'update' | 'upsert' | 'insert' = 'select'
    let payload: Record<string, unknown> | null = null
    let returnsData = false

    const b: Record<string, unknown> = {}
    const chain = () => b
    for (const m of ['eq', 'is', 'not', 'or', 'order', 'limit']) b[m] = chain
    b.select = () => {
      if (op === 'update' || op === 'upsert') returnsData = true
      else op = 'select'
      return b
    }
    b.update = (v: Record<string, unknown>) => { op = 'update'; payload = v; return b }
    b.upsert = (v: unknown) => { op = 'upsert'; writes.upserts.push({ table, payload: v }); return b }
    b.insert = (v: unknown) => { op = 'insert'; writes.inserts.push({ table, payload: v }); return b }
    b.maybeSingle = () => Promise.resolve({ data: null, error: null })
    // Thenable: Auflösung anhand (table, op, returnsData).
    b.then = (resolve: (r: unknown) => unknown) => {
      if (op === 'update') {
        writes.updates.push({ table, payload: payload ?? {} })
        return resolve(returnsData ? { data: [{ id: 1 }], error: null } : { error: null })
      }
      if (op === 'upsert') {
        // notifications_sent.upsert().select() → Claim erfolgreich; sonst events.
        return resolve(returnsData ? { data: [{ ref_id: 'x' }], error: null } : { error: null })
      }
      if (op === 'insert') return resolve({ error: null })
      // initiale SELECT-Query (deals)
      return resolve({ data: deals, error: null })
    }
    return b
  }

  const admin = {
    from: (table: string) => builder(table),
    rpc: (name: string) =>
      Promise.resolve(
        name === 'get_carrier_api_key'
          ? { data: 'fake-key', error: null }
          : { error: null },
      ),
  }
  // deno-lint-ignore no-explicit-any
  return { admin: admin as any, writes }
}

const fakePush = { ensure: () => Promise.resolve(null) }

function deal(over: Record<string, unknown>): Record<string, unknown> {
  return {
    id: 1,
    workspace_id: 'ws-1',
    user_id: 'u-1',
    product: 'Test',
    tracking: 'DE1',
    trackings: null,
    carrier: 'dhl',
    tracking_confidence: 'strong',
    tracking_needs_review: false,
    status: 'Unterwegs',
    arrival_date: null,
    order_date: '2026-06-01T00:00:00Z',
    live_status: 'in_transit',
    live_status_last_event: 'x',
    live_status_updated_at: '2026-06-01T00:00:00Z',
    live_eta: null,
    last_polled_at: null,
    ...over,
  }
}

async function runPoll(
  deals: Record<string, unknown>[],
  cannedByTracking: Record<string, ParsedTracking>,
  budget = 200,
) {
  const original = ADAPTERS.dhl.fetchStatus
  ADAPTERS.dhl.fetchStatus = (tn: string) =>
    Promise.resolve(cannedByTracking[tn] ?? null)
  try {
    const { admin, writes } = makeFakeAdmin(deals)
    const stat = await pollWorkspace(
      admin, 'ws-1', new Set(['dhl']), budget,
      undefined, undefined, new Map(), '2026-06-15', fakePush,
    )
    return { stat, writes }
  } finally {
    ADAPTERS.dhl.fetchStatus = original
  }
}

const arrivalUpdates = (w: Writes) =>
  w.updates.filter((u) => u.table === 'deals' && u.payload.status === 'Angekommen')

// ── Tests ──────────────────────────────────────────────────────────────────

Deno.test('pollWorkspace: Multi-Parcel ALLE zugestellt → Aggregat-Completion', async () => {
  const { stat, writes } = await runPoll(
    [deal({ tracking: 'DE1', trackings: ['DE1', 'DE2'] })],
    { DE1: delivered('2026-06-10T10:00:00Z'), DE2: delivered('2026-06-12T09:00:00Z') },
  )
  const arrivals = arrivalUpdates(writes)
  // Genau EIN Completion-Write (der Aggregat-Block), arrival_date = jüngste Lieferung.
  assertEquals(arrivals.length, 1)
  assertEquals(arrivals[0].payload.arrival_date, '2026-06-12T09:00:00Z')
  // Primary-Update (suppressCompletion) setzt live_status, NICHT status.
  const primaryUpd = writes.updates.find(
    (u) => u.table === 'deals' && u.payload.live_status === 'delivered' &&
      u.payload.status === undefined,
  )
  assert(primaryUpd, 'Primary-live_status-Update ohne status erwartet')
  assertEquals(stat.checked, 2)
})

Deno.test('pollWorkspace: Multi-Parcel Primary geliefert, Sekundär unterwegs → KEINE Completion', async () => {
  const { writes } = await runPoll(
    [deal({ tracking: 'DE1', trackings: ['DE1', 'DE2'] })],
    { DE1: delivered('2026-06-10T10:00:00Z'), DE2: inTransit('2026-06-11T08:00:00Z') },
  )
  assertEquals(arrivalUpdates(writes).length, 0)
  // Sekundär-Events werden unter der eigenen Nummer geschrieben.
  const secondaryEvents = writes.upserts.filter((u) =>
    u.table === 'tracking_events' &&
    (u.payload as Record<string, unknown>[]).some((r) => r.tracking === 'DE2'))
  assert(secondaryEvents.length > 0, 'Sekundär-tracking_events für DE2 erwartet')
})

Deno.test('pollWorkspace: Single-Parcel zugestellt → persistLiveStatus schließt ab', async () => {
  const { stat, writes } = await runPoll(
    [deal({ tracking: 'DE1', trackings: null })],
    { DE1: delivered('2026-06-10T10:00:00Z') },
  )
  // Genau ein Completion-Write (aus persistLiveStatus, kein Aggregat-Block).
  assertEquals(arrivalUpdates(writes).length, 1)
  assertEquals(stat.delivered, 1)
})

Deno.test('pollWorkspace: Budget-Cap bricht vor 2. Paket → keine falsche Completion', async () => {
  const { stat, writes } = await runPoll(
    [deal({ tracking: 'DE1', trackings: ['DE1', 'DE2'] })],
    { DE1: delivered('2026-06-10T10:00:00Z'), DE2: delivered('2026-06-12T09:00:00Z') },
    1, // Budget = 1 Call
  )
  // Nur 1 Call; DE2 nie gepollt → allDelivered=false → kein Completion-Write.
  assertEquals(stat.checked, 1)
  assertEquals(arrivalUpdates(writes).length, 0)
})

Deno.test('pollWorkspace: fetchStatus-Fehler beim Sekundär → allDelivered=false', async () => {
  const original = ADAPTERS.dhl.fetchStatus
  ADAPTERS.dhl.fetchStatus = (tn: string) => {
    if (tn === 'DE2') return Promise.reject(new Error('carrier 500'))
    return Promise.resolve(delivered('2026-06-10T10:00:00Z'))
  }
  try {
    const { admin, writes } = makeFakeAdmin([deal({ tracking: 'DE1', trackings: ['DE1', 'DE2'] })])
    const stat = await pollWorkspace(
      admin, 'ws-1', new Set(['dhl']), 200,
      undefined, undefined, new Map(), '2026-06-15', fakePush,
    )
    assertEquals(arrivalUpdates(writes).length, 0)
    assertEquals(stat.errors, 1)
  } finally {
    ADAPTERS.dhl.fetchStatus = original
  }
})
