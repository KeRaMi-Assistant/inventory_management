// Fixture-basierte Tests für die Amazon-HTML-Tracking-Extraktion.
// Quelle: test/fixtures/amazon_*.html (PII-redacted, synthetische
// Tracking-Nrn). Deckt DE/COM/UK/FR/IT/ES + Bestellbestätigung +
// Amazon-Logistics-only-Fall ab.
//
// Lokal ausführen mit:
//   deno test --allow-read supabase/functions/_shared/amazon_html_test.ts

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/assert_equals.ts'
import { assertExists } from 'https://deno.land/std@0.224.0/assert/assert_exists.ts'
import { assert } from 'https://deno.land/std@0.224.0/assert/assert.ts'
import { detectAndParse, type MailContext } from './inbox_adapters.ts'

// Resolve fixture pfad relativ zur Test-Datei. Die Tests laufen aus dem
// Repo-Root via `deno test`, also nutzen wir `import.meta.url` als Anker.
const FIXTURES_BASE = new URL('../../../test/fixtures/', import.meta.url)

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

Deno.test.ignore('Amazon DE Versandbestätigung mit DHL: extrahiert 20-stellige Nr', async () => {
  // Plan 2026-05-16 §D1/§D5: context-numeric-10-22-Pattern entfernt
  // (Falsch-Positiv-Quelle). 20-stellige DHL-Pakettracking-Nrn ohne
  // JJD/DE-Prefix werden jetzt nicht mehr extrahiert — final validiert
  // die DHL-API. Order-ID-Extraction + Status bleiben funktional.
  // Removed-by-design fuer den konkreten Tracking-Wert.
  const html = await loadFixture('amazon_de_shipped_dhl.html')
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
  assertEquals(parsed!.tracking, '00340434202012345678')
  assertEquals(parsed!.carrier, 'DHL')
})

Deno.test('Amazon DE mit Amazon Logistics (TBA nur im href)', async () => {
  const html = await loadFixture('amazon_de_shipped_amazon_logistics.html')
  const c = ctx(
    'versandbestaetigung@amazon.de',
    'Deine Amazon.de-Bestellung mit "tesa Paketband-Abroller..." wurde versandt!',
    html,
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, '305-1122334-4556677')
  assertEquals(parsed!.status, 'shipped')
  assertEquals(parsed!.tracking, 'TBA987654321098')
  assertEquals(parsed!.carrier, 'Amazon Logistics')
})

Deno.test.ignore('Amazon COM Versandbestätigung mit UPS Strong-Pattern', async () => {
  // Plan 2026-05-16 §D1/§D5: ups-1z-Pattern entfernt. Removed-by-design,
  // falls UPS via API-Adapter zurueckkehrt.
  const html = await loadFixture('amazon_com_shipped_ups.html')
  const c = ctx(
    'shipment-tracking@amazon.com',
    'Your Amazon.com order has been shipped',
    html,
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, '112-3344556-7788990')
  assertEquals(parsed!.status, 'shipped')
  assertEquals(parsed!.tracking, '1Z999AA10123456784')
  assertEquals(parsed!.carrier, 'UPS')
})

Deno.test('Amazon FR Versandbestätigung mit Chronopost', async () => {
  const html = await loadFixture('amazon_fr_shipped_chronopost.html')
  const c = ctx(
    'expedition-confirmation@amazon.fr',
    'Votre commande Amazon.fr a été expédiée',
    html,
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, '401-5566778-8990011')
  assertEquals(parsed!.status, 'shipped')
  assertEquals(parsed!.tracking, 'XJ123456789FR')
  assertEquals(parsed!.carrier, 'Chronopost')
})

Deno.test('Amazon IT Versandbestätigung mit TBA + track.amazon.it', async () => {
  const html = await loadFixture('amazon_it_shipped_amazon_logistics.html')
  const c = ctx(
    'conferma-spedizione@amazon.it',
    'Il tuo ordine Amazon.it è stato spedito',
    html,
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, '405-6677889-9001122')
  assertEquals(parsed!.status, 'shipped')
  assertEquals(parsed!.tracking, 'TBA456789012345')
  assertEquals(parsed!.carrier, 'Amazon Logistics')
})

Deno.test('Amazon ES Versandbestätigung mit SEUR', async () => {
  const html = await loadFixture('amazon_es_shipped_seur.html')
  const c = ctx(
    'confirmar-envio@amazon.es',
    'Tu pedido Amazon.es ha sido enviado',
    html,
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, '408-1199887-7665544')
  assertEquals(parsed!.status, 'shipped')
  assertEquals(parsed!.tracking, '14001122334455')
  assertEquals(parsed!.carrier, 'SEUR')
})

Deno.test('Amazon UK Versandbestätigung mit DPD Pfad-Tracking', async () => {
  const html = await loadFixture('amazon_uk_shipped_dpd.html')
  const c = ctx(
    'shipment-tracking@amazon.co.uk',
    'Your Amazon.co.uk order has been dispatched',
    html,
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, '202-9988776-5544332')
  assertEquals(parsed!.status, 'shipped')
  assertEquals(parsed!.tracking, '15501234567890')
  assertEquals(parsed!.carrier, 'DPD')
})

Deno.test('Amazon Bestellbestätigung (NICHT versandt) liefert kein Tracking', async () => {
  const html = await loadFixture('amazon_de_order_confirmation.html')
  const c = ctx(
    'bestellbestaetigung@amazon.de',
    'Deine Amazon.de Bestellung von "DJI Mini 3 Fly More Combo".',
    html,
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, '303-7766554-4332211')
  assertEquals(parsed!.status, 'ordered')
  assertEquals(parsed!.tracking, undefined)
})

Deno.test('Amazon Progress-Tracker only: Versand-Status, aber kein Tracking', async () => {
  // Mail mit shipping-Subject, aber NUR Amazon-internem progress-tracker
  // Link (kein Carrier-URL, kein Strong-Pattern). Erwartung: status='shipped',
  // tracking=undefined — Amazon-shipmentId ist intern und kein echtes
  // Tracking. Deal-Status wird im match-Branch trotzdem auf "Unterwegs"
  // hochgesetzt (siehe inbox_parse_runner).
  const html = await loadFixture('amazon_de_shipped_amazon_progress_only.html')
  const c = ctx(
    'versandbestaetigung@amazon.de',
    'Deine Amazon.de-Bestellung mit "Tischsteckdose..." und 1 weiteren Artikel(n) wurde versandt!',
    html,
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, '304-9988776-6655443')
  assertEquals(parsed!.status, 'shipped')
  assertEquals(parsed!.tracking, undefined)
})

Deno.test('Mehrere Carrier-Keys: Sammlung aus Fixtures liefert >= 2 distinct', async () => {
  const carriers = new Set<string>()
  for (const file of [
    'amazon_de_shipped_dhl.html',
    'amazon_de_shipped_amazon_logistics.html',
    'amazon_com_shipped_ups.html',
    'amazon_fr_shipped_chronopost.html',
    'amazon_it_shipped_amazon_logistics.html',
    'amazon_es_shipped_seur.html',
    'amazon_uk_shipped_dpd.html',
  ]) {
    const html = await loadFixture(file)
    const tld = file.includes('amazon_de_') ? 'de'
      : file.includes('amazon_com_') ? 'com'
      : file.includes('amazon_fr_') ? 'fr'
      : file.includes('amazon_it_') ? 'it'
      : file.includes('amazon_es_') ? 'es'
      : 'co.uk'
    const c = ctx(
      `versandbestaetigung@amazon.${tld}`,
      'wurde versandt!',
      html,
    )
    const parsed = detectAndParse(c)
    if (parsed?.carrier) carriers.add(parsed.carrier)
  }
  // Plan 2026-05-16 §D1/§D5: TRACKING_PATTERNS reduziert auf DHL-only,
  // DHL-/UPS-Pattern-Detection entfernt. HTML-href-Pfad liefert weiterhin
  // Carrier-Labels fuer Amazon Logistics / Chronopost / SEUR / DPD. Mit
  // den 7 Fixtures kommen wir damit auf >=3 distincte Carrier (statt 5).
  assert(
    carriers.size >= 3,
    `Erwartete >= 3 distinct Carrier (nach §D1), gefunden: ${[...carriers].join(', ')}`,
  )
})
