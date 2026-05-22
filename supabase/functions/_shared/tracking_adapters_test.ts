// Deno-Tests für die Carrier-Tracking-Adapter. Lokal ausführen mit:
//
//   deno test supabase/functions/_shared/tracking_adapters_test.ts
//
// Die Tests sind reine Parser-Tests (kein Network) — fetchStatus wird nicht
// aufgerufen. So bleibt der Test schnell und deterministisch.

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/assert_equals.ts'
import { assertExists } from 'https://deno.land/std@0.224.0/assert/assert_exists.ts'
import { assert } from 'https://deno.land/std@0.224.0/assert/assert.ts'
import {
  detectAdapter,
  dhlAdapter,
  dpdAdapter,
  upsAdapter,
} from './tracking_adapters.ts'

// ── DHL ─────────────────────────────────────────────────────────────────
Deno.test('DHL adapter parses delivered status', () => {
  const payload = {
    shipments: [
      {
        id: 'JJD0123456789012345',
        status: {
          statusCode: 'delivered',
          status: 'Zugestellt',
          description: 'Die Sendung wurde zugestellt.',
          timestamp: '2026-05-07T10:30:00Z',
        },
      },
    ],
  }
  const parsed = dhlAdapter.parseResponse(payload)
  assertExists(parsed)
  assertEquals(parsed!.status, 'delivered')
  assertEquals(parsed!.deliveredAt, '2026-05-07T10:30:00.000Z')
  assert(parsed!.lastEvent?.includes('Zugestellt'))
})

Deno.test('DHL adapter maps transit to in_transit', () => {
  const payload = {
    shipments: [
      {
        status: {
          statusCode: 'transit',
          description: 'In Zustellung',
          timestamp: '2026-05-06T08:00:00Z',
        },
      },
    ],
  }
  const parsed = dhlAdapter.parseResponse(payload)
  assertExists(parsed)
  assertEquals(parsed!.status, 'in_transit')
  assertEquals(parsed!.deliveredAt, undefined)
})

Deno.test('DHL adapter returns null for empty shipments', () => {
  assertEquals(dhlAdapter.parseResponse({ shipments: [] }), null)
  assertEquals(dhlAdapter.parseResponse({}), null)
  assertEquals(dhlAdapter.parseResponse(null), null)
})

// ── DHL Parcel DE Tracking (Post & Parcel Germany) ──────────────────────
// Schema: { pieceshipmentlist: { pieceshipment: <obj|array> } }
// Status-Quellen: delivery-event-flag, standard-event-code, event-status,
// event-text. Wird nach dem Migrations-Switch von "Shipment Tracking –
// Unified" auf "Parcel DE Tracking" erkannt (PR mit dem Adapter-Update).

Deno.test('DHL adapter parses Parcel-DE delivered via delivery-event-flag', () => {
  const payload = {
    pieceshipmentlist: {
      pieceshipment: {
        'piece-code': '00340434161094012345',
        'status': 'Die Sendung wurde zugestellt.',
        'status-timestamp': '2026-05-21T10:30:00Z',
        'delivery-event-flag': '1',
        pieceeventlist: {
          pieceevent: [
            {
              'event-timestamp': '2026-05-20T08:15:00Z',
              'event-status': 'In Zustellung',
              'standard-event-code': 'IZ',
              'event-text': 'In Zustellung',
            },
            {
              'event-timestamp': '2026-05-21T10:30:00Z',
              'event-status': 'Zugestellt',
              'standard-event-code': 'ZU',
              'event-text': 'Zugestellt — Empfänger',
            },
          ],
        },
      },
    },
  }
  const parsed = dhlAdapter.parseResponse(payload)
  assertExists(parsed)
  assertEquals(parsed!.status, 'delivered')
  assertEquals(parsed!.deliveredAt, '2026-05-21T10:30:00.000Z')
  assertEquals(parsed!.lastEvent, 'Zugestellt — Empfänger')
  assertEquals(parsed!.rawStatusCode, 'zu')
})

Deno.test('DHL adapter parses Parcel-DE in-transit', () => {
  const payload = {
    pieceshipmentlist: {
      pieceshipment: {
        'piece-code': '00340434161094012345',
        'status-timestamp': '2026-05-20T08:15:00Z',
        'delivery-event-flag': '0',
        pieceeventlist: {
          pieceevent: {
            'event-timestamp': '2026-05-20T08:15:00Z',
            'event-status': 'In Zustellung',
            'standard-event-code': 'IZ',
            'event-text': 'In Zustellung',
          },
        },
      },
    },
  }
  const parsed = dhlAdapter.parseResponse(payload)
  assertExists(parsed)
  assertEquals(parsed!.status, 'in_transit')
  assertEquals(parsed!.deliveredAt, undefined)
  assertEquals(parsed!.lastEvent, 'In Zustellung')
})

Deno.test('DHL adapter Parcel-DE: array of shipments → uses first', () => {
  const payload = {
    pieceshipmentlist: {
      pieceshipment: [
        {
          'piece-code': '00340434161094012345',
          'delivery-event-flag': '1',
          'status-timestamp': '2026-05-21T10:30:00Z',
          pieceeventlist: {
            pieceevent: { 'event-status': 'Zugestellt', 'standard-event-code': 'ZU' },
          },
        },
      ],
    },
  }
  const parsed = dhlAdapter.parseResponse(payload)
  assertExists(parsed)
  assertEquals(parsed!.status, 'delivered')
})

Deno.test('DHL adapter Parcel-DE: text fallback when no event-code', () => {
  const payload = {
    pieceshipmentlist: {
      pieceshipment: {
        'piece-code': '00340434161094012345',
        'status-timestamp': '2026-05-21T10:30:00Z',
        pieceeventlist: {
          pieceevent: {
            'event-timestamp': '2026-05-21T10:30:00Z',
            'event-text': 'Die Sendung wurde zugestellt.',
          },
        },
      },
    },
  }
  const parsed = dhlAdapter.parseResponse(payload)
  assertExists(parsed)
  assertEquals(parsed!.status, 'delivered')
  assertEquals(parsed!.deliveredAt, '2026-05-21T10:30:00.000Z')
})

Deno.test('DHL adapter Parcel-DE returns null for empty list', () => {
  assertEquals(
    dhlAdapter.parseResponse({ pieceshipmentlist: { pieceshipment: [] } }),
    null,
  )
  assertEquals(dhlAdapter.parseResponse({ pieceshipmentlist: {} }), null)
})

// ── DPD ─────────────────────────────────────────────────────────────────
Deno.test('DPD adapter parses delivered from latest statusInfo', () => {
  const payload = {
    parcelLifeCycleData: {
      statusInfo: [
        { status: 'ACCEPTED', date: '2026-05-05T10:00:00Z' },
        { status: 'IN_TRANSIT', date: '2026-05-06T08:00:00Z' },
        {
          status: 'DELIVERED',
          description: 'Zugestellt',
          date: '2026-05-07T11:15:00Z',
        },
      ],
    },
  }
  const parsed = dpdAdapter.parseResponse(payload)
  assertExists(parsed)
  assertEquals(parsed!.status, 'delivered')
  assertEquals(parsed!.deliveredAt, '2026-05-07T11:15:00.000Z')
  assertEquals(parsed!.lastEvent, 'Zugestellt')
})

Deno.test('DPD adapter maps IN_TRANSIT', () => {
  const parsed = dpdAdapter.parseResponse({
    parcelLifeCycleData: {
      statusInfo: [
        { status: 'IN_TRANSIT', date: '2026-05-06T08:00:00Z' },
      ],
    },
  })
  assertExists(parsed)
  assertEquals(parsed!.status, 'in_transit')
  assertEquals(parsed!.deliveredAt, undefined)
})

Deno.test('DPD adapter returns null for missing lifecycle', () => {
  assertEquals(dpdAdapter.parseResponse({}), null)
  assertEquals(dpdAdapter.parseResponse({ parcelLifeCycleData: {} }), null)
})

// ── UPS ─────────────────────────────────────────────────────────────────
Deno.test('UPS adapter parses Delivered code D', () => {
  const payload = {
    trackResponse: {
      shipment: [
        {
          package: [
            {
              currentStatus: {
                code: 'D',
                description: 'Delivered',
                simpleDescription: 'Delivered',
              },
              deliveryDate: [{ date: '20260507' }],
            },
          ],
        },
      ],
    },
  }
  const parsed = upsAdapter.parseResponse(payload)
  assertExists(parsed)
  assertEquals(parsed!.status, 'delivered')
  assertEquals(parsed!.deliveredAt, '2026-05-07T00:00:00.000Z')
  assertEquals(parsed!.lastEvent, 'Delivered')
})

Deno.test('UPS adapter maps in-transit codes', () => {
  for (const code of ['I', 'M', 'O', 'P']) {
    const parsed = upsAdapter.parseResponse({
      trackResponse: {
        shipment: [
          {
            package: [
              {
                currentStatus: { code, description: code },
              },
            ],
          },
        ],
      },
    })
    assertExists(parsed)
    assertEquals(parsed!.status, 'in_transit')
  }
})

Deno.test('UPS adapter returns null for empty packages', () => {
  assertEquals(upsAdapter.parseResponse({}), null)
  assertEquals(
    upsAdapter.parseResponse({ trackResponse: { shipment: [] } }),
    null,
  )
})

// ── detectAdapter ───────────────────────────────────────────────────────
Deno.test('detectAdapter chooses UPS for 1Z…', () => {
  assertEquals(detectAdapter('1Z999AA10123456784')?.id, 'ups')
  assertEquals(detectAdapter('1z999aa10123456784')?.id, 'ups')
})

Deno.test('detectAdapter chooses DPD for 0500-prefixed 14 digits', () => {
  assertEquals(detectAdapter('05001234567890')?.id, 'dpd')
})

Deno.test('detectAdapter chooses DHL for JJD-prefix and DE-prefix', () => {
  assertEquals(detectAdapter('JJD0123456789012345')?.id, 'dhl')
  assertEquals(detectAdapter('DE12345678')?.id, 'dhl')
  assertEquals(detectAdapter('00340434161094019748')?.id, 'dhl')
})

Deno.test('detectAdapter falls back to null on unknown', () => {
  assertEquals(detectAdapter('???'), null)
  assertEquals(detectAdapter(''), null)
})
