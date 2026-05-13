// Live-Forensik-Tests für Amazon-Versandbestätigungen.
//
// Hintergrund: PR #37 hat zwar einen HTML-Adapter mit DHL/UPS/Chronopost/
// SEUR/DPD-Patterns gebaut, aber die echten Amazon-Versand-Mails enthalten
// **keine** dieser Carrier-Codes — Amazon wrappt jede Tracking-URL in
// einen `amazon.<tld>/gp/f.html?C=…&U=<URL-encoded shiptrack-URL>`
// -Redirect. Die einzige Tracking-Information ist der `orderingShipmentId`
// -Parameter (Amazon-Logistics-interne Shipment-ID, 12–18 Stellen).
//
// Diese Fixtures bilden das echte Live-Format ab (Redirect-Wrap +
// URL-encoded Ziel-URL); siehe `test/fixtures/amazon_live/README.md`.
// Der Test zeigt, dass `findTrackingsInHtml` nach decode trotz
// doppelter Encoding-Schicht noch matcht.
//
// Lokal ausführen mit:
//   deno test --allow-read supabase/functions/_shared/amazon_live_test.ts

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/assert_equals.ts'
import { assertExists } from 'https://deno.land/std@0.224.0/assert/assert_exists.ts'
import { detectAndParse, type MailContext } from './inbox_adapters.ts'

const FIXTURES_BASE = new URL('../../../test/fixtures/amazon_live/', import.meta.url)

async function loadFixture(name: string): Promise<string> {
  const url = new URL(name, FIXTURES_BASE)
  return await Deno.readTextFile(url)
}

const ctx = (
  from: string,
  subject: string,
  html: string,
  text = '',
): MailContext => ({ from, subject, text, html })

// T3c-Update: Plan §1 + §3.8 — `orderingShipmentId` ist Amazon-interne
// Shipment-ID, kein Carrier-Tracking. Sie landet als `confidence: 'medium'`,
// `source: 'amazon-shipment-id'` in `trackingCandidates[]`, aber NICHT als
// primary `tracking`. Wenn das ALLES ist, was die Mail enthält, gilt
// `tracking = undefined` + `trackingNeedsReview = true`.
Deno.test('Amazon DE Live-Wrap 01: orderingShipmentId bleibt in Candidates, NICHT als primary', async () => {
  const html = await loadFixture('amazon_de_live_redirect_wrap_01.html')
  const c = ctx(
    'versandbestaetigung@amazon.de',
    'Deine Amazon.de-Bestellung mit "Samsung 870 EVO SATA III..." wurde versandt!',
    html,
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.shopKey, 'amazon')
  assertEquals(parsed!.orderId, '306-4234293-3555528')
  assertEquals(parsed!.status, 'shipped')
  assertEquals(parsed!.tracking, undefined)
  assertEquals(parsed!.trackingConfidence, 'none')
  assertEquals(parsed!.trackingNeedsReview, true)
  // orderingShipmentId muss als Forensik-Candidate erhalten bleiben.
  const candidates = parsed!.trackingCandidates ?? []
  const shipId = candidates.find((c) => c.value === '106121425175302')
  assertExists(shipId)
  assertEquals(shipId!.source, 'amazon-shipment-id')
  assertEquals(shipId!.confidence, 'medium')
})

Deno.test('Amazon DE Live-Wrap 02: 2-Artikel-Versand — orderingShipmentId bleibt Candidate', async () => {
  const html = await loadFixture('amazon_de_live_redirect_wrap_02.html')
  const c = ctx(
    'versandbestaetigung@amazon.de',
    'Deine Amazon.de-Bestellung mit 2 x "Samsung 9100 PRO NVMe M.2..." wurde versandt!',
    html,
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, '306-5580998-3956325')
  assertEquals(parsed!.status, 'shipped')
  assertEquals(parsed!.tracking, undefined)
  assertEquals(parsed!.trackingConfidence, 'none')
  assertEquals(parsed!.trackingNeedsReview, true)
  const candidates = parsed!.trackingCandidates ?? []
  const shipId = candidates.find((c) => c.value === '108834567890123')
  assertExists(shipId)
  assertEquals(shipId!.source, 'amazon-shipment-id')
})

Deno.test('Amazon IT Live-Wrap: echte User-Mail mit Plain-Text "DE5455279839" + orderingShipmentId', async () => {
  // Diese Fixture ist die echte Mail aus dem User-Bug-Report:
  // Order 404-5127739-1289903, Plain-Text "Your tracking number is:
  // DE5455279839", parallel orderingShipmentId=109727463192302 im
  // shiptrack-Redirect-Link.
  // Erwartetes Verhalten: STRONG-Pattern für DE\d{8,14} matcht das
  // Plain-Text-Tracking BEFORE der HTML-href-Fallback die orderingShipmentId
  // findet — User sieht die echte Carrier-Tracking-Nummer.
  const html = await loadFixture('amazon_it_live_redirect_wrap.html')
  const c = ctx(
    'conferma-spedizione@amazon.it',
    'Your Amazon.it order of "Samsung Memorie MZ-V9S1T0BW..." has been dispatched!',
    html,
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, '404-5127739-1289903')
  assertEquals(parsed!.status, 'shipped')
  assertEquals(
    parsed!.tracking, 'DE5455279839',
    'Plain-Text Carrier-Tracking muss gegen orderingShipmentId-Fallback gewinnen',
  )
  assertEquals(parsed!.carrier, 'Amazon Logistics')
  // orderingShipmentId aus dem href darf max. als Sekundär-Tracking
  // dazukommen (in trackings[]), niemals als primary `tracking`.
  if (parsed!.trackings && parsed!.trackings.length > 1) {
    assertEquals(parsed!.trackings[0], 'DE5455279839')
  }
})

Deno.test('Amazon ES Live-Wrap: Spanish "envío" — orderingShipmentId only → needs_review', async () => {
  const html = await loadFixture('amazon_es_live_redirect_wrap.html')
  const c = ctx(
    'confirmar-envio@amazon.es',
    'Your Amazon.es order of "Seagate BarraCuda 2TB..." has been dispatched!',
    html,
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, '405-4447968-7281969')
  assertEquals(parsed!.status, 'shipped')
  assertEquals(parsed!.tracking, undefined)
  assertEquals(parsed!.trackingConfidence, 'none')
  assertEquals(parsed!.trackingNeedsReview, true)
})

Deno.test('Amazon FR Live-Wrap: French "expédié" — orderingShipmentId only → no primary tracking', async () => {
  const html = await loadFixture('amazon_fr_live_redirect_wrap.html')
  const c = ctx(
    'confirmation-commande@amazon.fr',
    'Your Amazon.fr order of 2 x "Samsung SSD 870 EVO..." has been dispatched!',
    html,
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, '402-4004849-1316335')
  // Status hängt von subject/body-Keywords ab. "dispatched" matcht nicht
  // den DE/EN shippedRe — wird daher als 'ordered' klassifiziert.
  // Wichtig: ohne STRONG tracking-candidate gilt status=='ordered' →
  // gateTrackingByStatus dropped alle Candidates, daher tracking=undefined.
  assertEquals(parsed!.tracking, undefined)
  assertEquals(parsed!.trackingConfidence, 'none')
  // orderingShipmentId muss als Forensik-Candidate erhalten bleiben.
  const candidates = parsed!.trackingCandidates ?? []
  const shipId = candidates.find((c) => c.value === '111777888999000')
  assertExists(shipId)
  assertEquals(shipId!.source, 'amazon-shipment-id')
})

// T3c-Update: nur die IT-Fixture liefert ein STRONG Plain-Text-Tracking
// (DE5455279839 mit Anchor "Your tracking number is"). Die anderen 4
// haben nur orderingShipmentId → needs_review=true. Verify-Coverage:
// 1 strong + 4 needs_review = 5 total.
Deno.test('5 Live-Fixtures: Plain-Text-Tracking gewinnt, sonst needs_review', async () => {
  const fixtures = [
    'amazon_de_live_redirect_wrap_01.html',
    'amazon_de_live_redirect_wrap_02.html',
    'amazon_it_live_redirect_wrap.html',
    'amazon_es_live_redirect_wrap.html',
    'amazon_fr_live_redirect_wrap.html',
  ]
  let strong = 0
  let needsReview = 0
  for (const file of fixtures) {
    const html = await loadFixture(file)
    const c = ctx(
      'versandbestaetigung@amazon.de',
      'wurde versandt!',
      html,
    )
    const parsed = detectAndParse(c)
    if (parsed?.trackingConfidence === 'strong') strong++
    if (parsed?.trackingNeedsReview === true) needsReview++
  }
  assertEquals(strong, 1, 'genau 1 Fixture (IT) hat Plain-Text-DE-Tracking')
  assertEquals(needsReview, 4, '4 Fixtures haben nur orderingShipmentId → needs_review')
})
