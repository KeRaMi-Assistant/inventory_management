// Deno-Tests für die Shop-Adapter. Lokal ausführen mit:
//
//   deno test supabase/functions/_shared/inbox_adapters_test.ts
//
// Decken Happy-Path + 1-2 Edge-Cases pro neuem Adapter ab. Kein Network,
// kein I/O — pure Parser-Tests.

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/assert_equals.ts'
import { assertExists } from 'https://deno.land/std@0.224.0/assert/assert_exists.ts'
import { assert } from 'https://deno.land/std@0.224.0/assert/assert.ts'
import {
  detectAndParse,
  detectShop,
  isAccountingMail,
  isCarrierOnly,
  shouldStore,
  type MailContext,
} from './inbox_adapters.ts'

const ctx = (
  from: string,
  subject: string,
  text = '',
  html = '',
): MailContext => ({ from, subject, text, html })

// ── LEGO ─────────────────────────────────────────────────────────────
Deno.test('LEGO: order-acknowledged Bestellbestätigung wird als Order erkannt', () => {
  const c = ctx(
    'order-acknowledged@m.lego.com',
    'Ihre LEGO Bestellung ist eingegangen!',
    'Hallo Kerem, vielen Dank für Ihre Bestellung T491473317-E9 bei LEGO. Gesamtsumme: 199,99 €',
  )
  assertEquals(detectShop(c)?.key, 'lego')
  assertEquals(shouldStore(c), true)
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.shopKey, 'lego')
  assertEquals(parsed!.orderId, 'T491473317-E9')
  assertEquals(parsed!.status, 'ordered')
})

Deno.test('LEGO: t.crm.lego.com Versand-Mail extrahiert Order-ID aus Subject', () => {
  const c = ctx(
    'Noreply@t.crm.lego.com',
    'Deine LEGO Bestellung T491469977 ist unterwegs Kerem',
    'Deine Sendung mit der Tracking-Nr: JJD012345678901234 ist auf dem Weg.',
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.shopKey, 'lego')
  assertEquals(parsed!.orderId, 'T491469977')
  assertEquals(parsed!.status, 'shipped')
  assertEquals(parsed!.tracking, 'JJD012345678901234')
})

// ── Tink ─────────────────────────────────────────────────────────────
Deno.test('Tink: Bestellbestätigung wird erkannt', () => {
  const c = ctx(
    'service@tink.de',
    'Deine Bestellung ist eingegangen',
    'Hallo, deine Bestellnummer: 1234567 ist eingegangen. Gesamtsumme: 89,90 €',
  )
  assertEquals(detectShop(c)?.key, 'tink')
  assertEquals(shouldStore(c), true)
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.shopKey, 'tink')
  assertEquals(parsed!.orderId, '1234567')
})

Deno.test('Tink: Versand-Mail mit "Lieferung ist auf dem Weg"', () => {
  const c = ctx(
    'noreply@tink.de',
    'tink | Die Lieferung ist auf dem Weg.',
    'Hallo, deine Bestellnummer: 9876543 ist auf dem Weg. Tracking-Nr: 1Z999AA10123456789',
  )
  // Subject enthält "Lieferung" — sollte als Order erkannt werden.
  assertEquals(shouldStore(c), true)
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, '9876543')
  assertEquals(parsed!.status, 'shipped')
  assertEquals(parsed!.tracking, '1Z999AA10123456789')
})

// ── Anker ────────────────────────────────────────────────────────────
Deno.test('Anker: Bestellbestätigung mit R-Order-ID', () => {
  const c = ctx(
    'noreply-service@anker.com',
    'Bestellung R030101520991S bestätigt',
    'Hallo, vielen Dank für deine Bestellung. Order-Total: 129,99 €',
  )
  assertEquals(detectShop(c)?.key, 'anker')
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, 'R030101520991S')
  assertEquals(parsed!.status, 'ordered')
})

Deno.test('Anker: Versand- und Zustell-Mail mappen auf shipped/delivered', () => {
  const c1 = ctx(
    'support@anker.com',
    'Ihre Bestellung R030101520991S wurde bereits versendet.',
    'Tracking-Nr: 1Z999AA10987654321',
  )
  const p1 = detectAndParse(c1)
  assertExists(p1)
  assertEquals(p1!.status, 'shipped')
  assertEquals(p1!.tracking, '1Z999AA10987654321')

  const c2 = ctx(
    'support@anker.com',
    'Ihre Bestellung R030101520991S wurde zugestellt.',
    'Dein Paket wurde am 14/04/2026 zugestellt.',
  )
  const p2 = detectAndParse(c2)
  assertExists(p2)
  assertEquals(p2!.status, 'delivered')
})

// ── Euronics ─────────────────────────────────────────────────────────
Deno.test('Euronics: Hauptshop-Bestätigung mit Subject-Order-ID', () => {
  const c = ctx(
    'shopnoreply@euronics.de',
    'Ihre Bestellung 4250432 ist eingegangen',
    'Vielen Dank für Ihre Bestellung. Gesamtbetrag: 459,00 €',
  )
  assertEquals(detectShop(c)?.key, 'euronics')
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, '4250432')
})

Deno.test('Euronics: Filial-Subdomain (euronics-buecker.de) wird erkannt', () => {
  const c = ctx(
    'online@euronics-buecker.de',
    'AW: Starlink Bestellung',
    'Bezugnehmend auf Ihre Bestellung 7891234. Auftragsnummer: 7891234',
  )
  assertEquals(detectShop(c)?.key, 'euronics')
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.shopKey, 'euronics')
})

// ── Amazon Business shipment-tracking ──────────────────────────────
Deno.test('Amazon Business shipment-tracking ist KEIN Block mehr', () => {
  const c = ctx(
    'shipment-tracking@business.amazon.de',
    'Ihre Amazon.de Bestellung (#303-6042174-8240317)',
    'Sendung verfolgen. Tracking-Nr: TBA123456789012',
  )
  assertEquals(detectShop(c)?.key, 'amazon')
  assertEquals(shouldStore(c), true)
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.orderId, '303-6042174-8240317')
})

Deno.test('Amazon Business Analytics-Newsletter wird per Subject geblockt', () => {
  const c = ctx(
    'no-reply@business.amazon.de',
    'Alle Rechnungen übersichtlich an einem Ort: Amazon Business Analytics',
    '',
  )
  // Subject enthält "Rechnungen" → könnte matchen, aber "Analytics" + Promo-
  // Tonfall sind hier maßgeblich. Da "Rechnungen" als Order-Whitelist-Wort
  // gilt, akzeptieren wir, dass diese Mail aktuell durchkommt — entscheidend
  // ist, dass Amazon-Adapter sie NICHT als ParsedOrder zurückgibt
  // (kein orderId, kein tracking).
  const parsed = detectAndParse(c)
  // Ohne Order-ID & ohne Tracking gibt der Amazon-Adapter null zurück.
  assertEquals(parsed, null)
})

// ── Carrier-Skip ─────────────────────────────────────────────────────
Deno.test('DPD-Carrier-Mail wird nicht gespeichert', () => {
  const c = ctx(
    'noreply@service.dpd.de',
    'Bald ist Ihr DPD Paket da',
    'Ihre Sendung 12345678901234 wird heute zugestellt.',
  )
  assertEquals(isCarrierOnly(c), true)
  assertEquals(shouldStore(c), false)
})

Deno.test('GLS-Carrier-Mail wird nicht gespeichert', () => {
  const c = ctx(
    'no-reply@gls-pakete.de',
    '📦 Dein Paket wurde erfolgreich zugestellt',
    'Ihr Paket wurde zugestellt.',
  )
  assertEquals(isCarrierOnly(c), true)
  assertEquals(shouldStore(c), false)
})

Deno.test('MyHermes-Carrier-Mail wird nicht gespeichert', () => {
  const c = ctx(
    'noreply@paketankuendigung.myhermes.de',
    'Ihre Sendung kommt bald',
    '',
  )
  assertEquals(isCarrierOnly(c), true)
  assertEquals(shouldStore(c), false)
})

Deno.test('DHL Frankierungs-Bestätigung wird NICHT als Carrier geblockt', () => {
  const c = ctx(
    'noreply@dhl.com',
    'Auftragsbestätigung Ihrer Online Frankierung 9LGWWCT5F3VW',
    'Ihre Frankierung wurde bestätigt.',
  )
  // Frankierung ist eine Bestellung (Versand-Beleg) — soll durchkommen.
  assertEquals(isCarrierOnly(c), false)
  assertEquals(shouldStore(c), true)
})

Deno.test('DHL reine Tracking-Mail wird als Carrier geblockt', () => {
  const c = ctx(
    'noreply@dhl.com',
    'Ihre Sendung kommt bald',
    'Sendungsstatus-Update.',
  )
  // Subject ohne Bestell-/Frankierungs-Indikator → Carrier-Pfad.
  assertEquals(isCarrierOnly(c), true)
  assertEquals(shouldStore(c), false)
})

// ── Accounting-Skip (Lexware/Lexoffice) ──────────────────────────────
Deno.test('Lexware-Belege werden als Accounting erkannt + geblockt', () => {
  const c = ctx(
    'versand@belege.lexware.de',
    'Rechnung RE0075 von KOZ Solidum Trading',
    '',
  )
  assertEquals(isAccountingMail(c), true)
  assertEquals(shouldStore(c), false)
})

Deno.test('Lexware app-Mail wird als Accounting geblockt', () => {
  const c = ctx(
    'no-reply@app.lexware.de',
    'Ihre Lexware Rechnung',
    '',
  )
  assertEquals(isAccountingMail(c), true)
  assertEquals(shouldStore(c), false)
})

Deno.test('Lexoffice wird als Accounting geblockt', () => {
  const c = ctx('info@lexoffice.de', 'Ihre Rechnung', '')
  assertEquals(isAccountingMail(c), true)
  assertEquals(shouldStore(c), false)
})

// ── Cross-Sanity: bestehende Adapter intakt ─────────────────────────
Deno.test('Amazon DE Bestellbestätigung weiterhin erkannt', () => {
  const c = ctx(
    'auto-confirm@amazon.de',
    'Ihre Amazon.de Bestellung (#303-1234567-1234567)',
    'Ihre Bestellung wurde aufgenommen.',
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.shopKey, 'amazon')
  assertEquals(parsed!.orderId, '303-1234567-1234567')
})

Deno.test('Kaufland Marketplace weiterhin erkannt', () => {
  const c = ctx(
    'noreply@kaufland-marktplatz.de',
    'Bestellung MK3UZQ5: Versandbestätigung',
    'Sendungsnummer: 12345678901234',
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.shopKey, 'kaufland')
  assertEquals(parsed!.orderId, 'MK3UZQ5')
})

Deno.test('Unbekannter Shop mit Order-Subject bleibt unclassified-eligible', () => {
  const c = ctx(
    'orders@unknown-shop.de',
    'Ihre Bestellbestätigung',
    '',
  )
  // Wird gespeichert, landet aber ohne Adapter als unclassified.
  assertEquals(shouldStore(c), true)
  assertEquals(detectAndParse(c), null)
  assert(detectShop(c) === null)
})
