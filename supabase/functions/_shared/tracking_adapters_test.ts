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
  // Paket 1: IZ ("In Zustellung") mappt jetzt präzise auf out_for_delivery
  // (vorher pauschal in_transit) — der Klarna-Moment für den Status-Push.
  assertEquals(parsed!.status, 'out_for_delivery')
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

// ── DHL Parcel DE Tracking — XML-Response (Public Query) ───────────────
// Die Parcel-DE-Tracking-API liefert nach einem `?xml=<request/>`-Probe
// **XML zurück**, kein JSON. Adapter muss das via parseResponse(string)
// erkennen können.

Deno.test('DHL adapter parses Parcel-DE XML response — delivered', () => {
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<data name="pieceshipmentlist" request-id="abc" code="0">
  <data name="pieceshipment" error-status="0"
        piece-code="00340434161094012345"
        delivery-event-flag="1"
        status="Zugestellt"
        status-timestamp="2026-05-22T10:30:00Z">
    <data name="pieceeventlist" piece-id="abc">
      <data name="pieceevent"
            event-timestamp="2026-05-21T08:15:00Z"
            event-status="In Zustellung"
            standard-event-code="IZ"
            event-text="In Zustellung"/>
      <data name="pieceevent"
            event-timestamp="2026-05-22T10:30:00Z"
            event-status="Zugestellt"
            standard-event-code="ZU"
            event-text="Zugestellt"/>
    </data>
  </data>
</data>`
  const parsed = dhlAdapter.parseResponse(xml)
  assertExists(parsed)
  assertEquals(parsed!.status, 'delivered')
  assertEquals(parsed!.deliveredAt, '2026-05-22T10:30:00.000Z')
  assertEquals(parsed!.lastEvent, 'Zugestellt')
  assertEquals(parsed!.rawStatusCode, 'zu')
})

Deno.test('DHL adapter parses Parcel-DE XML — in_transit', () => {
  const xml = `<data name="pieceshipmentlist" code="0">
  <data name="pieceshipment"
        piece-code="00340434161094012345"
        delivery-event-flag="0"
        status-timestamp="2026-05-21T08:15:00Z">
    <data name="pieceeventlist">
      <data name="pieceevent"
            event-timestamp="2026-05-21T08:15:00Z"
            standard-event-code="IZ"
            event-text="In Zustellung"/>
    </data>
  </data>
</data>`
  const parsed = dhlAdapter.parseResponse(xml)
  assertExists(parsed)
  // Paket 1: IZ → out_for_delivery (siehe JSON-Pendant oben).
  assertEquals(parsed!.status, 'out_for_delivery')
  assertEquals(parsed!.deliveredAt, undefined)
})

Deno.test('DHL adapter parses Parcel-DE XML — text-only fallback', () => {
  // Self-closing pieceevent ohne standard-event-code — Adapter
  // soll trotzdem über event-text="Zugestellt" auf delivered fallen.
  const xml = `<data name="pieceshipmentlist" code="0">
  <data name="pieceshipment" piece-code="X"
        status-timestamp="2026-05-22T10:30:00Z">
    <data name="pieceeventlist">
      <data name="pieceevent"
            event-timestamp="2026-05-22T10:30:00Z"
            event-text="Sendung wurde zugestellt."/>
    </data>
  </data>
</data>`
  const parsed = dhlAdapter.parseResponse(xml)
  assertExists(parsed)
  assertEquals(parsed!.status, 'delivered')
})

Deno.test('DHL adapter returns null for empty XML / unrelated text', () => {
  assertEquals(dhlAdapter.parseResponse(''), null)
  assertEquals(dhlAdapter.parseResponse('not xml'), null)
  assertEquals(
    dhlAdapter.parseResponse('<?xml version="1.0"?><error>no data</error>'),
    null,
  )
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

Deno.test('UPS adapter maps transit/out-for-delivery/pending codes', () => {
  // Paket 1: präzisere Status-Aufteilung — O=Out for Delivery,
  // M=Order Processed (pending), I/P bleiben in_transit.
  const expectations: Array<[string, string]> = [
    ['I', 'in_transit'],
    ['P', 'in_transit'],
    ['O', 'out_for_delivery'],
    ['M', 'pending'],
  ]
  for (const [code, expected] of expectations) {
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
    assertEquals(parsed!.status, expected)
  }
})

Deno.test('UPS adapter returns null for empty packages', () => {
  assertEquals(upsAdapter.parseResponse({}), null)
  assertEquals(
    upsAdapter.parseResponse({ trackResponse: { shipment: [] } }),
    null,
  )
})

// ── detectAdapter (Plan 2026-06-03, T4 — DHL/Amazon/DPD-Scope) ────────────
// Scope-Reduktion: UPS ist OUT-of-scope (kein Poll-Adapter mehr), Amazon
// Logistics ist detection-only (keine öffentliche Status-API). `detectAdapter`
// ist nur noch der Fallback, wenn `deals.carrier` fehlt — der persistierte
// lowercase-Carrier ist primär.

Deno.test('detectAdapter: UPS 1Z… ist out-of-scope → null', () => {
  // Plan §1/§3.4: UPS hat keinen Poll-Adapter mehr. 1Z darf NICHT mehr auf
  // UPS geroutet werden — Poller würde sonst gegen einen entfernten Adapter
  // laufen.
  assertEquals(detectAdapter('1Z999AA10123456784'), null)
  assertEquals(detectAdapter('1z999aa10123456784'), null)
})

Deno.test('detectAdapter: Amazon TBA… ist detection-only → null', () => {
  // Plan §3.4: Amazon Logistics hat keine öffentliche Status-API → kein
  // Poll-Adapter. TBA wird erkannt + gespeichert, aber nie gepollt.
  assertEquals(detectAdapter('TBA123456789012'), null)
})

Deno.test('detectAdapter chooses DPD for 05-prefixed 14 digits', () => {
  assertEquals(detectAdapter('05001234567890')?.id, 'dpd')
})

Deno.test('detectAdapter chooses DHL for JJD / S10 / 20-digit / 14-digit', () => {
  // JJD-Prefix → DHL.
  assertEquals(detectAdapter('JJD0123456789012345')?.id, 'dhl')
  // S10 international (2 Service + 9 Ziffern + 2 ISO-Land) → DHL.
  assertEquals(detectAdapter('RB123456785GB')?.id, 'dhl')
  // 20-stellige DHL-Sendungsnummer → DHL.
  assertEquals(detectAdapter('00340434161094019748')?.id, 'dhl')
  // 14-stellige Numerik OHNE 05-Prefix → default DHL (Research R3
  // Kollisionsregel: bare \d{12,14} fällt auf DHL, nicht DPD).
  assertEquals(detectAdapter('12345678901234')?.id, 'dhl')
})

Deno.test('detectAdapter: DE-Prefix ist KEINE DHL-Heuristik mehr → null', () => {
  // Plan §2.8: das alte `DE\d{8,14}`-DHL-Routing ist gelöscht (VAT-Kollision).
  // `DE12345678` darf nicht mehr blind auf DHL geroutet werden.
  assertEquals(detectAdapter('DE12345678'), null)
})

Deno.test('detectAdapter falls back to null on unknown', () => {
  assertEquals(detectAdapter('???'), null)
  assertEquals(detectAdapter(''), null)
})

// ── Paket 1: Event-Timeline + ETA ────────────────────────────────────────

Deno.test('DHL Parcel-DE XML: events-Array mit Location + normalisierten Stati', () => {
  const xml = `<data name="pieceshipmentlist" code="0">
  <data name="pieceshipment"
        piece-code="00340434161094012345"
        delivery-event-flag="0"
        status-timestamp="2026-06-10T08:15:00Z">
    <data name="pieceeventlist">
      <data name="pieceevent"
            event-timestamp="2026-06-09T18:00:00Z"
            standard-event-code="BA"
            event-location="Hamburg"
            event-text="Sendung im Paketzentrum bearbeitet"/>
      <data name="pieceevent"
            event-timestamp="2026-06-10T08:15:00Z"
            standard-event-code="IZ"
            event-location="Berlin"
            event-text="In Zustellung"/>
    </data>
  </data>
</data>`
  const parsed = dhlAdapter.parseResponse(xml)
  assertExists(parsed)
  assertEquals(parsed!.status, 'out_for_delivery')
  assertExists(parsed!.events)
  assertEquals(parsed!.events!.length, 2)
  const [ba, iz] = parsed!.events!
  assertEquals(ba.status, 'in_transit')
  assertEquals(ba.location, 'Hamburg')
  assertEquals(ba.rawCode, 'BA')
  assertEquals(ba.occurredAt, '2026-06-09T18:00:00.000Z')
  assertEquals(iz.status, 'out_for_delivery')
  assertEquals(iz.text, 'In Zustellung')
})

Deno.test('DHL Parcel-DE XML: ES-Code → pending', () => {
  const xml = `<data name="pieceshipmentlist" code="0">
  <data name="pieceshipment" piece-code="123" delivery-event-flag="0">
    <data name="pieceeventlist">
      <data name="pieceevent"
            event-timestamp="2026-06-10T07:00:00Z"
            standard-event-code="ES"
            event-text="Die Sendung wurde elektronisch angekündigt"/>
    </data>
  </data>
</data>`
  const parsed = dhlAdapter.parseResponse(xml)
  assertExists(parsed)
  assertEquals(parsed!.status, 'pending')
})

Deno.test('DHL Unified: events + estimatedTimeOfDelivery (ETA)', () => {
  const payload = {
    shipments: [
      {
        id: 'JJD0123456789012345',
        estimatedTimeOfDelivery: '2026-06-11T16:00:00Z',
        status: {
          statusCode: 'transit',
          status: 'Unterwegs',
          timestamp: '2026-06-10T08:00:00Z',
        },
        events: [
          {
            timestamp: '2026-06-09T20:00:00Z',
            statusCode: 'transit',
            status: 'Im Paketzentrum',
            location: { address: { addressLocality: 'Köln' } },
          },
          {
            timestamp: '2026-06-10T08:00:00Z',
            statusCode: 'out-for-delivery',
            status: 'In Zustellung',
          },
        ],
      },
    ],
  }
  const parsed = dhlAdapter.parseResponse(payload)
  assertExists(parsed)
  assertEquals(parsed!.etaDate, '2026-06-11T16:00:00.000Z')
  assertExists(parsed!.events)
  assertEquals(parsed!.events!.length, 2)
  assertEquals(parsed!.events![0].location, 'Köln')
  assertEquals(parsed!.events![0].status, 'in_transit')
  assertEquals(parsed!.events![1].status, 'out_for_delivery')
})

Deno.test('DPD: statusInfo wird zur Event-Timeline, OUT_FOR_DELIVERY präzise', () => {
  const payload = {
    parcelLifeCycleData: {
      statusInfo: [
        {
          status: 'ACCEPTED',
          description: 'Paket angenommen',
          date: '2026-06-09T10:00:00Z',
          city: 'Aschaffenburg',
        },
        {
          status: 'OUT_FOR_DELIVERY',
          description: 'Im Zustellfahrzeug',
          date: '2026-06-10T07:30:00Z',
        },
      ],
    },
  }
  const parsed = dpdAdapter.parseResponse(payload)
  assertExists(parsed)
  assertEquals(parsed!.status, 'out_for_delivery')
  assertExists(parsed!.events)
  assertEquals(parsed!.events!.length, 2)
  assertEquals(parsed!.events![0].status, 'in_transit')
  assertEquals(parsed!.events![0].location, 'Aschaffenburg')
  assertEquals(parsed!.events![1].status, 'out_for_delivery')
})
