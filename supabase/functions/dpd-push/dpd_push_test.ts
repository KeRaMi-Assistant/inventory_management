// Tests für die reinen dpd-push-Helfer (Status-Map, Date-Parser, ACK-XML,
// Param-Konvertierung). Der HTTP-Handler selbst (Token-Gate, DB-Writes)
// wird nicht netzwerkig getestet — die Gates sind trivial + fail-closed.
//
//   deno test --no-check supabase/functions/dpd-push/dpd_push_test.ts

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/assert_equals.ts'
import { assert } from 'https://deno.land/std@0.224.0/assert/assert.ts'
import {
  buildAckXml,
  DPD_STATUS_MAP,
  dpdPushToParsed,
  isStatusRegression,
  parseDpdStatusDate,
} from './index.ts'

// ── Status-Mapping ───────────────────────────────────────────────────────

Deno.test('DPD-Status-Map: alle 13 dokumentierten Stati gemappt', () => {
  // Quelle: Tracking Push Service Doku 04/2023, Abschnitt URL-Parameter.
  const documented = [
    'start_order', 'pickup_driver', 'pickup_depot', 'delivery_depot',
    'delivery_carload', 'delivery_nab', 'delivery_notification',
    'delivery_customer', 'delivery_shop', 'error_pickup', 'error_return',
    'pickup_by_consignee', 'no_pickup_by_consignee',
  ]
  for (const s of documented) {
    assert(DPD_STATUS_MAP[s], `Status '${s}' fehlt im Mapping`)
  }
  assertEquals(Object.keys(DPD_STATUS_MAP).length, documented.length)
})

Deno.test('DPD-Status-Map: Klarna-Momente korrekt', () => {
  assertEquals(DPD_STATUS_MAP['delivery_carload'].status, 'out_for_delivery')
  assertEquals(DPD_STATUS_MAP['delivery_customer'].status, 'delivered')
  assertEquals(DPD_STATUS_MAP['delivery_shop'].status, 'delivered')
  assertEquals(DPD_STATUS_MAP['start_order'].status, 'pending')
  assertEquals(DPD_STATUS_MAP['delivery_nab'].status, 'exception')
  assertEquals(DPD_STATUS_MAP['error_return'].status, 'exception')
})

// ── statusdate-Parser ────────────────────────────────────────────────────

Deno.test('parseDpdStatusDate: ddMMyyyyHHmmss → ISO', () => {
  assertEquals(
    parseDpdStatusDate('09072014095100'),
    '2014-07-09T09:51:00.000Z',
  )
  assertEquals(
    parseDpdStatusDate('31122026235959'),
    '2026-12-31T23:59:59.000Z',
  )
})

Deno.test('parseDpdStatusDate: ungültig → undefined', () => {
  assertEquals(parseDpdStatusDate(null), undefined)
  assertEquals(parseDpdStatusDate(''), undefined)
  assertEquals(parseDpdStatusDate('2026-06-11'), undefined)
  assertEquals(parseDpdStatusDate('99992026120000'), undefined) // Tag 99
  assertEquals(parseDpdStatusDate('01132026120000'), undefined) // Monat 13
  assertEquals(parseDpdStatusDate('0107201409510'), undefined) // 13 Zeichen
})

// ── ACK-XML ──────────────────────────────────────────────────────────────

Deno.test('buildAckXml: DPD-Spec-Format', () => {
  assertEquals(
    buildAckXml('335298'),
    '<push><pushid>335298</pushid><status>OK</status></push>',
  )
})

Deno.test('buildAckXml: escaped defensiv', () => {
  assert(!buildAckXml('1<evil>&2').includes('<evil>'))
})

// ── Param → ParsedTracking ───────────────────────────────────────────────

function params(q: Record<string, string>): URLSearchParams {
  return new URLSearchParams(q)
}

Deno.test('dpdPushToParsed: voller Datensatz → ParsedTracking + Event', () => {
  const r = dpdPushToParsed(params({
    pnr: '01476810375209',
    status: 'delivery_carload',
    statusdate: '11062026083000',
    depot: '0134',
  }))
  assert(r)
  assertEquals(r!.pnr, '01476810375209')
  assertEquals(r!.parsed.status, 'out_for_delivery')
  assertEquals(r!.parsed.lastEvent, 'Auf Zustelltour')
  assertEquals(r!.parsed.statusTimestamp, '2026-06-11T08:30:00.000Z')
  assertEquals(r!.parsed.events!.length, 1)
  assertEquals(r!.parsed.events![0].location, 'Depot 0134')
  assertEquals(r!.parsed.events![0].rawCode, 'delivery_carload')
})

Deno.test('dpdPushToParsed: delivered setzt deliveredAt', () => {
  const r = dpdPushToParsed(params({
    pnr: '01476810375209',
    status: 'delivery_customer',
    statusdate: '11062026120000',
  }))
  assert(r)
  assertEquals(r!.parsed.status, 'delivered')
  assertEquals(r!.parsed.deliveredAt, '2026-06-11T12:00:00.000Z')
})

Deno.test('dpdPushToParsed: pnr wird normalisiert (Spaces/Case)', () => {
  const r = dpdPushToParsed(params({
    pnr: ' 0147 6810 375209 ',
    status: 'pickup_depot',
  }))
  assert(r)
  assertEquals(r!.pnr, '01476810375209')
})

Deno.test('dpdPushToParsed: unbekannter Status / fehlende pnr → null', () => {
  assertEquals(dpdPushToParsed(params({ pnr: '123', status: 'warp_drive' })), null)
  assertEquals(dpdPushToParsed(params({ status: 'delivery_customer' })), null)
  assertEquals(dpdPushToParsed(params({ pnr: '123' })), null)
})

Deno.test('dpdPushToParsed: pnr mit Filter-Metazeichen → null (or-Injection-Wand)', () => {
  // Security-Review feature/multi-parcel-deals #1: pnr fließt in einen
  // PostgREST-.or()-Filterstring (Service-Role, RLS aus). Filter-Metazeichen
  // dürfen die Validierungsgrenze nicht passieren.
  for (const evil of [
    '01476810375209,id.gt.0', // or-Filter-Bruch
    '0147)*,(deleted_at.not.is.null',
    '0147.6810', // Punkt = Operator-Trenner
    'DE-123', // Bindestrich ist bei DPD nicht erlaubt
    '014768*',
  ]) {
    assertEquals(
      dpdPushToParsed(params({ pnr: evil, status: 'delivery_customer' })),
      null,
      `pnr "${evil}" hätte abgelehnt werden müssen`,
    )
  }
})

Deno.test('dpdPushToParsed: fehlendes statusdate → Event ohne occurredAt', () => {
  const r = dpdPushToParsed(params({ pnr: '01476810375209', status: 'pickup_driver' }))
  assert(r)
  assertEquals(r!.parsed.statusTimestamp, undefined)
  assertEquals(r!.parsed.events![0].occurredAt, undefined)
})

// ── Monotonie-Guard (Out-of-Order-Pushes) ────────────────────────────────

Deno.test('isStatusRegression: verspäteter Scan dreht Fortschritt nicht zurück', () => {
  assertEquals(isStatusRegression('out_for_delivery', 'in_transit'), true)
  assertEquals(isStatusRegression('out_for_delivery', 'pending'), true)
  assertEquals(isStatusRegression('in_transit', 'pending'), true)
})

Deno.test('isStatusRegression: delivered ist terminal', () => {
  assertEquals(isStatusRegression('delivered', 'in_transit'), true)
  assertEquals(isStatusRegression('delivered', 'exception'), true)
  assertEquals(isStatusRegression('delivered', 'delivered'), false)
})

Deno.test('isStatusRegression: exception überschreibt + wird überschrieben', () => {
  assertEquals(isStatusRegression('out_for_delivery', 'exception'), false)
  assertEquals(isStatusRegression('exception', 'in_transit'), false)
  assertEquals(isStatusRegression('exception', 'delivered'), false)
})

Deno.test('isStatusRegression: Fortschritt + Erst-Status erlaubt', () => {
  assertEquals(isStatusRegression(null, 'pending'), false)
  assertEquals(isStatusRegression('pending', 'in_transit'), false)
  assertEquals(isStatusRegression('in_transit', 'out_for_delivery'), false)
  assertEquals(isStatusRegression('in_transit', 'in_transit'), false)
})

Deno.test('parseDpdStatusDate: Date.UTC-Overflow wird verworfen (31.02.)', () => {
  // Review-Fix: 31.02.2026 würde sonst still zum 03.03. überrollen.
  assertEquals(parseDpdStatusDate('31022026120000'), undefined)
  assertEquals(parseDpdStatusDate('30022026120000'), undefined)
  // Gültiger Schalttag bleibt gültig (2028 ist Schaltjahr).
  assertEquals(parseDpdStatusDate('29022028120000'), '2028-02-29T12:00:00.000Z')
})
