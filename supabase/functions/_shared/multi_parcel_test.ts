// Tests für Multi-Parcel (2026-06-12): deals.trackings[] — Merge-Logik
// (mergeDealTrackings), Paket-Aufzählung (dealParcelNumbers) und
// Event-Rows mit Tracking-Override (buildTrackingEventRows).
//
//   deno test --no-check supabase/functions/_shared/multi_parcel_test.ts

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/assert_equals.ts'
import { mergeDealTrackings } from './inbox_parse_runner.ts'
import {
  buildLiveStatusUpdate,
  buildTrackingEventRows,
  dealParcelNumbers,
} from './live_status.ts'
import type { ParsedTracking } from './tracking_adapters.ts'

// ── mergeDealTrackings ─────────────────────────────────────────────────────

Deno.test('merge: frische Mehrfach-Mail auf leeren Deal → alle Nummern, Primary vorn', () => {
  assertEquals(
    mergeDealTrackings(
      { tracking: null, trackings: null },
      { tracking: 'A1', trackings: ['A1', 'B2', 'C3'] },
      { newPrimary: 'A1', droppedOldPrimary: false },
    ),
    ['A1', 'B2', 'C3'],
  )
})

Deno.test('merge: zweite Versand-Mail ergänzt Sekundär-Paket, Primary bleibt vorn', () => {
  assertEquals(
    mergeDealTrackings(
      { tracking: 'A1', trackings: ['A1'] },
      { tracking: 'B2', trackings: ['B2'] },
      { newPrimary: null, droppedOldPrimary: false },
    ),
    ['A1', 'B2'],
  )
})

Deno.test('merge: identische Liste → null (kein Write)', () => {
  assertEquals(
    mergeDealTrackings(
      { tracking: 'A1', trackings: ['A1', 'B2'] },
      { tracking: 'B2', trackings: ['A1', 'B2'] },
      { newPrimary: null, droppedOldPrimary: false },
    ),
    null,
  )
})

Deno.test('merge: Pre-Backfill-Deal (trackings=null) → opportunistischer Backfill', () => {
  assertEquals(
    mergeDealTrackings(
      { tracking: 'A1', trackings: null },
      { tracking: 'A1', trackings: ['A1'] },
      { newPrimary: null, droppedOldPrimary: false },
    ),
    ['A1'],
  )
})

Deno.test('merge: Tracking-Replace wirft alten (falschen) Primary aus der Liste', () => {
  assertEquals(
    mergeDealTrackings(
      { tracking: 'FALSCH99', trackings: ['FALSCH99', 'B2'] },
      { tracking: 'NEU11', trackings: ['NEU11'] },
      { newPrimary: 'NEU11', droppedOldPrimary: true },
    ),
    ['NEU11', 'B2'],
  )
})

Deno.test('merge: Duplikate + Whitespace werden normalisiert', () => {
  assertEquals(
    mergeDealTrackings(
      { tracking: 'A1', trackings: ['A1'] },
      { tracking: ' A1 ', trackings: [' A1 ', 'B2', 'B2', '  '] },
      { newPrimary: null, droppedOldPrimary: false },
    ),
    ['A1', 'B2'],
  )
})

Deno.test('merge: komplett leer → null', () => {
  assertEquals(
    mergeDealTrackings(
      { tracking: null, trackings: null },
      { tracking: undefined as unknown as string, trackings: [] },
      { newPrimary: null, droppedOldPrimary: false },
    ),
    null,
  )
})

// ── dealParcelNumbers ──────────────────────────────────────────────────────

Deno.test('parcels: Primary zuerst, Sekundäre in Array-Reihenfolge, dedupliziert', () => {
  assertEquals(
    dealParcelNumbers({ tracking: 'A1', trackings: ['B2', 'A1', 'C3'] }),
    ['A1', 'B2', 'C3'],
  )
})

Deno.test('parcels: Single-Tracking-Deal (Pre-Backfill) → genau [tracking]', () => {
  assertEquals(dealParcelNumbers({ tracking: 'A1', trackings: null }), ['A1'])
})

Deno.test('parcels: leere/Whitespace-Einträge fliegen raus', () => {
  assertEquals(
    dealParcelNumbers({ tracking: '  ', trackings: ['', ' B2 '] }),
    ['B2'],
  )
})

// ── buildTrackingEventRows mit trackingOverride ────────────────────────────

const parsedWithEvents: ParsedTracking = {
  status: 'in_transit',
  lastEvent: 'Paket im Zustellzentrum',
  events: [
    {
      occurredAt: '2026-06-12T08:00:00Z',
      status: 'in_transit',
      text: 'Paket im Zustellzentrum',
    },
  ],
}

Deno.test('events: Override schreibt Rows unter der Sekundär-Nummer', () => {
  const rows = buildTrackingEventRows(
    { id: 7, workspace_id: 'ws-1', tracking: 'PRIMARY1' },
    'dhl',
    parsedWithEvents,
    '2026-06-12T09:00:00Z',
    false,
    'SECOND2',
  )
  assertEquals(rows.length, 1)
  assertEquals(rows[0].tracking, 'SECOND2')
  assertEquals(rows[0].deal_id, 7)
})

Deno.test('events: ohne Override bleibt Primary-Verhalten identisch', () => {
  const rows = buildTrackingEventRows(
    { id: 7, workspace_id: 'ws-1', tracking: 'PRIMARY1' },
    'dhl',
    parsedWithEvents,
    '2026-06-12T09:00:00Z',
    false,
  )
  assertEquals(rows.length, 1)
  assertEquals(rows[0].tracking, 'PRIMARY1')
})

Deno.test('events: Sekundär ohne Event-Array + includeSynthetic=false → leer', () => {
  const rows = buildTrackingEventRows(
    { id: 7, workspace_id: 'ws-1', tracking: 'PRIMARY1' },
    'dhl',
    { status: 'in_transit', lastEvent: 'Nur Last-Event' } as ParsedTracking,
    '2026-06-12T09:00:00Z',
    false,
    'SECOND2',
  )
  assertEquals(rows.length, 0)
})

// ── buildLiveStatusUpdate: suppressCompletion (Multi-Parcel-Aggregat) ──────

Deno.test('liveStatus: suppressCompletion setzt live_status=delivered, aber NICHT status/arrival_date', () => {
  const deal = { live_status: 'in_transit' as const, live_status_last_event: 'x' }
  const parsed = {
    status: 'delivered',
    lastEvent: 'Zugestellt',
    deliveredAt: '2026-06-12T10:00:00Z',
  } as ParsedTracking
  const patch = buildLiveStatusUpdate(deal, parsed, '2026-06-12T11:00:00Z', {
    suppressCompletion: true,
  })
  assertEquals(patch?.live_status, 'delivered')
  // Deal-Abschluss unterdrückt → der Aggregat-Block setzt das erst, wenn ALLE
  // Pakete da sind.
  assertEquals(patch?.status, undefined)
  assertEquals(patch?.arrival_date, undefined)
})

Deno.test('liveStatus: ohne suppressCompletion schließt das Primary den Deal (Bestandsverhalten)', () => {
  const deal = { live_status: 'in_transit' as const, live_status_last_event: 'x' }
  const parsed = {
    status: 'delivered',
    lastEvent: 'Zugestellt',
    deliveredAt: '2026-06-12T10:00:00Z',
  } as ParsedTracking
  const patch = buildLiveStatusUpdate(deal, parsed, '2026-06-12T11:00:00Z')
  assertEquals(patch?.status, 'Angekommen')
  assertEquals(patch?.arrival_date, '2026-06-12T10:00:00Z')
})
