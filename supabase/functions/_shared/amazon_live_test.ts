// Live-Forensik-Tests für Amazon-Versandbestätigungen (Regression-Anker).
//
// Hintergrund: echte Amazon-Versand-Mails enthalten **keine** Carrier-Codes —
// Amazon wrappt jede Tracking-URL in einen
// `amazon.<tld>/gp/f.html?C=…&U=<URL-encoded shiptrack-URL>`-Redirect. Die
// einzige „Tracking"-Information ist der `orderingShipmentId`-Parameter
// (Amazon-Logistics-interne Shipment-ID) — KEIN echtes Carrier-Tracking.
//
// Plan 2026-06-03 §2.7/§2.8 — der GETESTETE Regression-Invariant:
//   1. `orderingShipmentId` wird NIEMALS zum primären `tracking`.
//   2. Eine bare `DE…`-Plaintext-Nummer (alt: `dhl-de-prefix`, kollidierte mit
//      USt-IdNr.) wird NICHT mehr als Tracking promotet.
//   → Konsequenz: alle 5 Live-Wraps liefern `tracking=undefined`,
//     `trackingConfidence='none'` — „lieber kein Tracking als ein falsches".
//
// NOTE (T6 — dokumentierter Verhaltens-Drift, KEIN Test-Workaround):
//   Die `orderingShipmentId` taucht in diesen Live-Fixtures NICHT mehr als
//   Forensik-Candidate auf. Grund: `tracking_detection.detect()` scannt den
//   RAW-HTML ohne URL-Decode; in den Live-Wraps steht der Parameter
//   doppelt-URL-encoded (`orderingShipmentId%3D…`), das href-Pattern
//   `[?&]orderingShipmentId=(\d…)` greift darauf nicht. Der alte
//   `findTrackingsInHtml`-Pfad decodete die Redirect-URL vorher. Der für den
//   User sichtbare Invariant (kein Falsch-Positiv) ist UNVERÄNDERT erfüllt;
//   verloren ist nur die forensische Aufbewahrung des medium-Candidates. Das
//   ist ein `tracking_detection.ts`-Belang (T2 href-Decode), nicht T6 (Tests).
//
// Lokal ausführen mit:
//   deno test --allow-read supabase/functions/_shared/amazon_live_test.ts

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/assert_equals.ts'
import { assertExists } from 'https://deno.land/std@0.224.0/assert/assert_exists.ts'
import { assert } from 'https://deno.land/std@0.224.0/assert/assert.ts'
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

Deno.test('Amazon DE Live-Wrap 01: orderingShipmentId wird NIE primary tracking', async () => {
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
  // Kern-Invariant: die orderingShipmentId darf NIE zum Tracking werden.
  assert(parsed!.tracking !== '106121425175302')
})

Deno.test('Amazon DE Live-Wrap 02: 2-Artikel-Versand — orderingShipmentId nie primary', async () => {
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
  assert(parsed!.tracking !== '108834567890123')
})

Deno.test('Amazon IT Live-Wrap: bare "DE5455279839"-Plaintext wird NICHT erkannt (VAT-Wand)', async () => {
  // Diese Fixture ist die echte Mail aus dem User-Bug-Report:
  // Order 404-5127739-1289903, Plain-Text "Your tracking number is:
  // DE5455279839", parallel orderingShipmentId=109727463192302.
  //
  // Plan 2026-06-03 §2.8: `DE\d{8,14}` ist gelöscht (USt-IdNr.-Kollision).
  // `DE5455279839` wird NICHT mehr promotet — kein Falsch-Positiv. Und die
  // orderingShipmentId wird ebenfalls nie primary. → tracking=undefined.
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
  assertEquals(parsed!.tracking, undefined)
  assertEquals(parsed!.trackingConfidence, 'none')
  // Weder die DE-VAT-aussehende Nummer noch die orderingShipmentId dürfen
  // jemals als primary Tracking durchgehen.
  assert(parsed!.tracking !== 'DE5455279839')
  assert(parsed!.tracking !== '109727463192302')
})

Deno.test('Amazon ES Live-Wrap: orderingShipmentId only → kein primary tracking', async () => {
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
})

Deno.test('Amazon FR Live-Wrap: orderingShipmentId only → kein primary tracking', async () => {
  const html = await loadFixture('amazon_fr_live_redirect_wrap.html')
  const c = ctx(
    'confirmation-commande@amazon.fr',
    'Your Amazon.fr order of 2 x "Samsung SSD 870 EVO..." has been dispatched!',
    html,
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, '402-4004849-1316335')
  // "dispatched" matcht weder DE noch EN shippedRe → status='ordered'.
  // Wichtig: ohne strong-Candidate gilt tracking=undefined.
  assertEquals(parsed!.tracking, undefined)
  assertEquals(parsed!.trackingConfidence, 'none')
  assert(parsed!.tracking !== '111777888999000')
})

// Plan 2026-06-03 §2.7/§2.8: Keiner der 5 Live-Wraps darf ein primary Tracking
// produzieren (orderingShipmentId nie primary, DE-VAT-Format gelöscht). Das ist
// der harte „nichts falsches"-Regression-Anker: 0 Falsch-Positive über alle 5.
Deno.test('5 Live-Fixtures: 0 Falsch-Positive — kein primary Tracking', async () => {
  const fixtures = [
    'amazon_de_live_redirect_wrap_01.html',
    'amazon_de_live_redirect_wrap_02.html',
    'amazon_it_live_redirect_wrap.html',
    'amazon_es_live_redirect_wrap.html',
    'amazon_fr_live_redirect_wrap.html',
  ]
  let withTracking = 0
  let none = 0
  for (const file of fixtures) {
    const html = await loadFixture(file)
    const c = ctx(
      'versandbestaetigung@amazon.de',
      'wurde versandt!',
      html,
    )
    const parsed = detectAndParse(c)
    if (parsed?.tracking) withTracking++
    if (parsed?.trackingConfidence === 'none') none++
  }
  assertEquals(withTracking, 0, 'KEINE Fixture darf ein primary Tracking liefern (0 FP)')
  assertEquals(none, 5, 'alle 5 Live-Wraps → confidence=none')
})
