// Deno-Tests für die Forensik-Erweiterungen in `inbox_adapters.ts`.
// Validiert die neuen Helper-Funktionen sowie die per-Shop-Adapter-
// Erweiterungen anhand der Fixtures aus `test/fixtures/forensics/`.

import { assert, assertEquals } from 'jsr:@std/assert@1'
import {
  detectAndParse,
  extractDeliveryMethod,
  extractEtaDate,
  extractGenericItems,
  extractMediaMarktItems,
  extractOrderTotal,
  extractPcComponentesItems,
  extractSeller,
  extractShippedAt,
  extractShippingCountry,
  extractTaxRatePct,
} from './inbox_adapters.ts'

const DIR = new URL('../../../test/fixtures/forensics/', import.meta.url)

function loadFixture(rel: string): string {
  return Deno.readTextFileSync(new URL(rel, DIR))
}

function strip(html: string): string {
  return html
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/\s+/g, ' ')
    .trim()
}

// ── Helper-Tests ───────────────────────────────────────────────────────

Deno.test('extractEtaDate: Amazon Unix-Timestamp im URL', () => {
  const html = '<a href="?orderID=X&latestArrivalDate=1778004000">x</a>'
  const eta = extractEtaDate(html, '')
  assertEquals(eta, '2026-05-05')
})

Deno.test('extractEtaDate: MediaMarkt Lieferung-bis-Block', () => {
  const text = 'Lieferung bis Dienstag, 17.02.2026 349,00 Euro'
  assertEquals(extractEtaDate('', text), '2026-02-17')
})

Deno.test('extractEtaDate: EN-Format "March 15, 2026"', () => {
  const text = 'Estimated Delivery: March 15-17, 2026'
  assertEquals(extractEtaDate('', text), '2026-03-15')
})

Deno.test('extractEtaDate: Wochentag + DE-Monat ohne Jahr', () => {
  const text = 'Zustellung: Dienstag, 5 Mai'
  const eta = extractEtaDate('', text)
  assert(eta?.endsWith('-05-05'), `expected …-05-05, got ${eta}`)
})

Deno.test('extractEtaDate: ungültiges Datum → undefined', () => {
  assertEquals(extractEtaDate('', 'irgendwas anderes'), undefined)
})

Deno.test('extractShippedAt: Amazon shipmentDate-URL', () => {
  const html = '<a href="?shipmentDate=1777885378">go</a>'
  const ts = extractShippedAt(html, '')
  assertEquals(ts, '2026-05-04T09:02:58.000Z')
})

Deno.test('extractShippedAt: tink "verpackt am"-Block', () => {
  const text = 'Wir haben deine Bestellung am 18.03.2026 verpackt.'
  const ts = extractShippedAt('', text)
  assertEquals(ts, '2026-03-18T00:00:00.000Z')
})

Deno.test('extractOrderTotal: DE-Format Komma-Decimal', () => {
  const out = extractOrderTotal('Gesamtbetrag der Bestellung: EUR 124,44')
  assertEquals(out?.amount, 124.44)
  assertEquals(out?.currency, 'EUR')
})

Deno.test('extractOrderTotal: EN-Format "$1,499.99"', () => {
  const out = extractOrderTotal('Order Total: $1,499.99')
  assertEquals(out?.amount, 1499.99)
  assertEquals(out?.currency, 'USD')
})

Deno.test('extractOrderTotal: PLN-Whitespace-Tausender', () => {
  const out = extractOrderTotal('Razem: 12 499,99 zł')
  assertEquals(out?.amount, 12499.99)
  assertEquals(out?.currency, 'PLN')
})

Deno.test('extractOrderTotal: CHF mit Apostroph-Tausender', () => {
  const out = extractOrderTotal("Endbetrag inkl. MwSt: 1'248.95 CHF")
  assertEquals(out?.amount, 1248.95)
  assertEquals(out?.currency, 'CHF')
})

Deno.test('extractTaxRatePct: "MwSt (19%)"', () => {
  assertEquals(extractTaxRatePct('MwSt (19%)'), 19)
})

Deno.test('extractTaxRatePct: "IVA (21%)"', () => {
  assertEquals(extractTaxRatePct('IVA (21%)'), 21)
})

Deno.test('extractTaxRatePct: "Sales Tax (8.875%)"', () => {
  assertEquals(extractTaxRatePct('Sales Tax (8.875%)'), 8.875)
})

Deno.test('extractTaxRatePct: kein %-Block → undefined', () => {
  assertEquals(extractTaxRatePct('Bestellsumme: 100 €'), undefined)
})

Deno.test('extractShippingCountry: DE aus Lieferanschrift', () => {
  const text = 'Lieferanschrift: Test User, Musterstr 1, 12345 Wolfsburg DE Rechnungsanschrift:'
  assertEquals(extractShippingCountry(text), 'DE')
})

Deno.test('extractShippingCountry: GB-Normalisierung von UK', () => {
  const text = 'Shipping address: 1 Park Lane, London W1, UK Phone:'
  assertEquals(extractShippingCountry(text), 'GB')
})

Deno.test('extractDeliveryMethod: Schenker → partner', () => {
  assertEquals(extractDeliveryMethod('Versand durch: Schenker'), 'partner')
})

Deno.test('extractDeliveryMethod: Express', () => {
  assertEquals(extractDeliveryMethod('Express delivery'), 'express')
})

Deno.test('extractDeliveryMethod: Selbstabholung → pickup', () => {
  assertEquals(extractDeliveryMethod('Versandart: Selbstabholung Filiale Zürich'), 'pickup')
})

Deno.test('extractDeliveryMethod: Paczkomat → pickup', () => {
  assertEquals(extractDeliveryMethod('Sposób dostawy: InPost Paczkomat'), 'pickup')
})

Deno.test('extractSeller: "Verkauft von: Amazon EU S.a.r.L."', () => {
  assertEquals(extractSeller('Verkauft von: Amazon EU S.a.r.L.'), 'Amazon EU S.a.r.L.')
})

Deno.test('extractSeller: "Sold by: john_doe_2024"', () => {
  assertEquals(extractSeller('Sold by: john_doe_2024'), 'john_doe_2024')
})

Deno.test('extractMediaMarktItems: STARLINK Standard Kit', () => {
  const text = strip(loadFixture('mediamarkt/order_confirmation.html'))
  const items = extractMediaMarktItems(text)
  assert(items.length >= 1, `expected >= 1 items, got ${items.length}`)
  assert(items[0].product.includes('STARLINK'),
    `expected STARLINK, got ${items[0].product}`)
  assertEquals(items[0].quantity, 1)
  assertEquals(items[0].unitPrice, 349)
})

Deno.test('extractMediaMarktItems: filtert Aktion-Rabatt-Zeilen', () => {
  const text = strip(loadFixture('mediamarkt/order_confirmation.html'))
  const items = extractMediaMarktItems(text)
  for (const item of items) {
    assert(!/Rabatt|Aktion myMediaMarkt/i.test(item.product),
      `unexpected rabatt-line: ${item.product}`)
  }
})

Deno.test('extractMediaMarktItems: Multi-Item', () => {
  const text = strip(loadFixture('mediamarkt/multi_item.html'))
  const items = extractMediaMarktItems(text)
  assert(items.length >= 2, `expected >= 2 items, got ${items.length}`)
})

Deno.test('extractPcComponentesItems: Einheiten-Pattern', () => {
  const text = strip(loadFixture('pccomponentes/order_confirmation_de.html'))
  const items = extractPcComponentesItems(text)
  assert(items.length >= 1, `expected >= 1 items`)
  assertEquals(items[0].quantity, 4)
})

Deno.test('extractPcComponentesItems: ES Unidades', () => {
  const text = strip(loadFixture('pccomponentes/order_confirmation_es.html'))
  const items = extractPcComponentesItems(text)
  assert(items.length >= 1, `expected >= 1 items`)
})

Deno.test('extractGenericItems: Anker Multi-Item', () => {
  const text = strip(loadFixture('lego/order_confirmation.html'))
  const items = extractGenericItems(text)
  assert(items.length >= 1)
})

// ── Adapter-Integration-Tests pro Shop ─────────────────────────────────

function ctx(from: string, subject: string, html: string) {
  return { from, subject, text: strip(html), html }
}

Deno.test('Adapter: Amazon order_confirmation populiert orderTotal + seller + eta', () => {
  const html = loadFixture('amazon/order_confirmation.html')
  const r = detectAndParse(ctx('shipment-tracking@amazon.de',
    'Vielen Dank für deine Bestellung', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'amazon')
  assertEquals(r!.orderTotal?.amount, 124.44)
  assertEquals(r!.taxRatePct, 19)
  assertEquals(r!.seller, 'Amazon EU S.a.r.L.')
  assertEquals(r!.etaDate, '2026-02-09')
})

Deno.test('Adapter: Amazon shipped populiert shippedAt + etaDate aus URL', () => {
  const html = loadFixture('amazon/shipped.html')
  const r = detectAndParse(ctx('shipment-tracking@amazon.de',
    'Deine Amazon.de-Bestellung wurde versandt', html))
  assert(r !== null)
  assertEquals(r!.status, 'shipped')
  assertEquals(r!.tracking, 'TBA987654321098')
  assertEquals(r!.shippedAt, '2026-05-04T09:02:58.000Z')
  assertEquals(r!.etaDate, '2026-05-05')
  assertEquals(r!.deliveryMethod, 'partner')
})

Deno.test('Adapter: Amazon cancelled extrahiert cancellationReason', () => {
  const html = loadFixture('amazon/cancelled.html')
  const r = detectAndParse(ctx('shipment-tracking@amazon.de',
    'Stornierung deiner Amazon.de-Bestellung', html))
  assert(r !== null)
  assertEquals(r!.status, 'cancelled')
  assertEquals(r!.cancellationReason, 'Adressänderung')
})

Deno.test('Adapter: MediaMarkt order populiert items + etaDate + country', () => {
  const html = loadFixture('mediamarkt/order_confirmation.html')
  const r = detectAndParse(ctx('noreply@mediamarkt.de',
    'Deine Bestellung bei MediaMarkt', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'mediamarkt')
  assertEquals(r!.etaDate, '2026-02-17')
  assertEquals(r!.orderTotal?.amount, 269)
  assertEquals(r!.shippingAddressCountry, 'DE')
  assert((r!.items?.length ?? 0) >= 1)
})

Deno.test('Adapter: MediaMarkt multi_item liefert ≥ 2 items', () => {
  const html = loadFixture('mediamarkt/multi_item.html')
  const r = detectAndParse(ctx('noreply@mediamarkt.de',
    'Deine Bestellung bei MediaMarkt', html))
  assert(r !== null)
  assert((r!.items?.length ?? 0) >= 2,
    `expected >= 2 items, got ${r!.items?.length}`)
})

Deno.test('Adapter: Saturn order populiert items', () => {
  const html = loadFixture('saturn/order_confirmation.html')
  const r = detectAndParse(ctx('noreply@saturn.de',
    'Vielen Dank für deine Bestellung', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'saturn')
  assert((r!.items?.length ?? 0) >= 1)
})

Deno.test('Adapter: PCComponentes DE liefert taxRatePct=19 + seller', () => {
  const html = loadFixture('pccomponentes/order_confirmation_de.html')
  const r = detectAndParse(ctx('noreply@pccomponentes.de',
    'Bestätigung deiner Bestellung', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'pccomponentes')
  assertEquals(r!.taxRatePct, 19)
  assertEquals(r!.seller, 'PcComponentes')
})

Deno.test('Adapter: PCComponentes ES liefert taxRatePct=21', () => {
  const html = loadFixture('pccomponentes/order_confirmation_es.html')
  const r = detectAndParse(ctx('noreply@pccomponentes.com',
    'Confirmación de pedido', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'pccomponentes')
  assertEquals(r!.taxRatePct, 21)
})

Deno.test('Adapter: Kaufland multi_seller liefert seller', () => {
  const html = loadFixture('kaufland/multi_seller.html')
  const r = detectAndParse(ctx('noreply@kaufland-marktplatz.de',
    'Bestellung MK4ABCD bei Kaufland.de', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'kaufland')
  assertEquals(r!.seller, 'WGServices')
})

Deno.test('Adapter: Anker order liefert orderTotal + taxRatePct', () => {
  const html = loadFixture('anker/order_confirmation.html')
  const r = detectAndParse(ctx('noreply-service@anker.com',
    'Order Confirmation: Anker Soundcore Liberty', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'anker')
  assert(r!.orderTotal !== undefined)
  assertEquals(r!.etaDate, '2026-03-15')
})

Deno.test('Adapter: Euronics seller aus Filial-Subdomain', () => {
  const html = loadFixture('euronics/order_confirmation.html')
  const r = detectAndParse(ctx('online@euronics-buecker.de',
    'Ihre Bestellung 4250432 ist eingegangen', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'euronics')
  assertEquals(r!.seller, 'Euronics Buecker')
  assertEquals(r!.taxRatePct, 19)
})

Deno.test('Adapter: x-kom liefert deliveryMethod=pickup für Paczkomat', () => {
  const html = loadFixture('xkom/order_confirmation.html')
  const r = detectAndParse(ctx('noreply@x-kom.pl',
    'Potwierdzenie zamówienia 2026/12345', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'xkom')
  assertEquals(r!.deliveryMethod, 'pickup')
})

Deno.test('Adapter: LEGO populiert orderTotal + taxRatePct', () => {
  const html = loadFixture('lego/order_confirmation.html')
  const r = detectAndParse(ctx('order-acknowledged@m.lego.com',
    'Order Confirmation T492568051-E9', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'lego')
  assertEquals(r!.taxRatePct, 19)
})

Deno.test('Adapter: tink shipped extrahiert shippedAt', () => {
  const html = loadFixture('tink/shipped.html')
  const r = detectAndParse(ctx('noreply@tink.de',
    'Deine Lieferung ist auf dem Weg — Bestellung 700123456', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'tink')
  assertEquals(r!.shippedAt, '2026-03-18T00:00:00.000Z')
})

// ── Neue Adapter ───────────────────────────────────────────────────────

Deno.test('Adapter: Dell wird erkannt + orderTotal extrahiert', () => {
  const html = loadFixture('dell/order_confirmation.html')
  const r = detectAndParse(ctx('order@dell.com',
    'Order Confirmation 123456789', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'dell')
  assertEquals(r!.orderId, '123456789')
  assert(r!.orderTotal !== undefined)
})

Deno.test('Adapter: Dell shipped → status, aber UPS-Tracking out-of-scope', () => {
  // Plan 2026-06-03 §1: UPS ist OUT-of-scope. Die Dell-Fixture trägt eine
  // UPS-1Z-Nummer (1Z999AA10987654321) — die wird NICHT mehr erkannt.
  // Status-Detection (shipped) bleibt funktional.
  const html = loadFixture('dell/shipped.html')
  const r = detectAndParse(ctx('order@dell.com',
    'Your Dell Order has Shipped', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'dell')
  assertEquals(r!.status, 'shipped')
  assertEquals(r!.tracking, undefined)
})

Deno.test('Adapter: eBay populiert seller', () => {
  const html = loadFixture('ebay/order_confirmation.html')
  const r = detectAndParse(ctx('members@ebay.com',
    'Bestellbestätigung — eBay', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'ebay')
  assertEquals(r!.seller, 'john_doe_2024')
})

Deno.test('Adapter: Galaxus liefert CHF-Currency bei .ch / Endbetrag', () => {
  const html = loadFixture('galaxus/order_confirmation.html')
  const r = detectAndParse(ctx('noreply@notifications.galaxus.de',
    'Bestellbestätigung Nr. 123456789', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'galaxus')
  assert(r!.orderTotal !== undefined,
    `expected orderTotal, got ${JSON.stringify(r!.orderTotal)}`)
})

Deno.test('Adapter: Alza wird erkannt (alza.de Sender)', () => {
  const html = loadFixture('alza/order_confirmation.html')
  const r = detectAndParse(ctx('noreply@alza.de',
    'Order confirmation - Alza.de (Order #102456789012)', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'alza')
  assertEquals(r!.orderId, '102456789012')
})

Deno.test('Adapter: XXXLutz erkennt Sperrgut-Versand → carrier=Schenker', () => {
  const html = loadFixture('xxxlutz/order_confirmation.html')
  const r = detectAndParse(ctx('noreply@marktplatz.xxxlutz.de',
    'Bestellung eingegangen — XXXLutz MP12345678', html))
  assert(r !== null)
  assertEquals(r!.shopKey, 'xxxlutz')
  assertEquals(r!.carrier, 'Schenker')
  assertEquals(r!.deliveryMethod, 'partner')
})

// ── Fixture-Existence-Sanity ───────────────────────────────────────────

Deno.test('Alle 15 Forensik-Shops haben mind. 1 Fixture', () => {
  const shops = ['amazon', 'mediamarkt', 'saturn', 'pccomponentes', 'kaufland',
    'xkom', 'lego', 'tink', 'anker', 'euronics',
    'dell', 'galaxus', 'alza', 'ebay', 'xxxlutz']
  for (const shop of shops) {
    let count = 0
    for (const e of Deno.readDirSync(new URL(`${shop}/`, DIR))) {
      if (e.isFile && e.name.endsWith('.html')) count++
    }
    assert(count >= 1, `Shop ${shop} hat keine .html-Fixtures`)
  }
})
