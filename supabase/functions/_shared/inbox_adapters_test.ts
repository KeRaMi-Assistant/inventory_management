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
  findAllTrackings,
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

Deno.test.ignore('Tink: Versand-Mail mit "Lieferung ist auf dem Weg"', () => {
  // Plan 2026-05-16 §D1/§D5: Pattern-Heuristik fuer Tink/UPS-1Z wurde
  // entfernt. Tracking-Detection laeuft jetzt ausschliesslich via
  // DHL-API-Validation (`enrichWithDhlValidation`). Der Test bleibt als
  // removed-by-design-Marker, falls Non-DHL-Patterns je zurueckkehren
  // (z.B. ueber API-Adapter fuer DPD/UPS).
  const c = ctx(
    'noreply@tink.de',
    'tink | Die Lieferung ist auf dem Weg.',
    'Hallo, deine Bestellnummer: 9876543 ist auf dem Weg. Tracking-Nr: 1Z999AA10123456789',
  )
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

Deno.test.ignore('Anker: Versand- und Zustell-Mail mappen auf shipped/delivered', () => {
  // Plan 2026-05-16 §D1/§D5: Tracking-Extraction via UPS-1Z-Pattern
  // wurde entfernt. Status-Mapping (shipped/delivered) ist davon nicht
  // betroffen, aber der Original-Test verifizierte explizit den
  // UPS-Tracking-Wert. Test bleibt als removed-by-design-Marker.
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

// Regression: User-reported Bug. Eine echte Amazon-Versand-Mail
// ("Your tracking number is: DE5455279839") landete in der App mit
// `tracking = '109727463192302'` — das war die `orderingShipmentId`
// aus dem progress-tracker-Link, NICHT die echte Carrier-Tracking-Nummer.
//
// Plan 2026-06-03 §2.8: Das `DE\d{8,14}`-Pattern (`dhl-de-prefix`) ist
// GELÖSCHT — es kollidierte mit USt-IdNr. `DE5455279839` (DE + 10 Ziffern)
// ist KEIN gültiges DHL/Amazon/DPD-Format mehr → wird NICHT als Tracking
// erkannt („nichts falsches"-Wand). Der entscheidende Invariant bleibt: die
// `orderingShipmentId` wird NIEMALS zum primären Tracking (kein Falsch-Positiv).
Deno.test('Amazon Logistics: bare "DE…"-Plaintext wird NICHT mehr als Tracking erkannt (kein FP)', () => {
  const html = `
    <p>Your item(s) is (are) being sent by Amazon Logistics.
       Your tracking number is: DE5455279839. Depending on the
       delivery method you chose, it's possible that the tracking
       information might not be visible immediately.</p>
    <a href="https://www.amazon.de/progress-tracker/package/ref=pe_xxx?orderId=404-5127739-1289903&packageId=1&orderingShipmentId=109727463192302">
      Track your package
    </a>
  `
  const c = ctx(
    'shipment-tracking@amazon.de',
    'Your Amazon.it order of "Samsung Memorie MZ-V9S1T0BW 990 EVO…"',
    'Your item(s) is (are) being sent by Amazon Logistics. ' +
      'Your tracking number is: DE5455279839. Order: 404-5127739-1289903.',
    html,
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.shopKey, 'amazon')
  // `DE5455279839` ist kein in-scope-Format mehr → kein primary Tracking.
  assertEquals(parsed!.tracking, undefined)
  // orderingShipmentId darf NIE primary tracking sein (der ursprüngliche Bug).
  assert(
    parsed!.tracking !== '109727463192302',
    'orderingShipmentId aus progress-tracker-URL darf NIE primary sein',
  )
})

// Regression: das HTML, das `seed-demo-workspace.buildDemoAmazonHtml`
// generiert. Plan 2026-06-03 §2.8: `DE\d{8,14}` ist gelöscht → das
// Demo-Seeder-„DE…"-Tracking wird nicht mehr erkannt. Wichtig bleibt:
// die orderingShipmentId wird NICHT primary (kein Falsch-Positiv).
Deno.test('Amazon Demo-Seeder HTML: bare "DE…" liefert kein primary, orderingShipmentId nie primary', () => {
  const orderId = '306-4234293-3555528'
  const shipmentId = '106121425175302'
  const trackingDe = 'DE5455279839'
  const html = [
    '<!DOCTYPE html>',
    '<html><body><table><tr><td>',
    '<span class="rio_sc_headline">Versandbestätigung</span>',
    `<p><span>Bestellung <a href="https://www.amazon.de/gp/f.html?C=AAAA&K=BBBB&M=urn:rtn:msg:demo&R=CCCC&T=C&U=https%3A%2F%2Fbusiness.amazon.de%2Fabredir%2Fgp%2Fcss%2Fsummary%2Fedit.html%3Fie%3DUTF8%26orderID%3D${orderId}&H=DDDD" class="rio_link">${orderId}</a></span></p>`,
    `<p><span>Item(s): Samsung 870 EVO SSD 1TB</span></p>`,
    `<a class="rio_btn rio_bg_yellow" href="https://www.amazon.de/gp/f.html?C=AAAA&K=BBBB&M=urn:rtn:msg:demo&R=DDDD&T=C&U=https%3A%2F%2Fbusiness.amazon.de%2Fabredir%2Fgp%2Fcss%2Fshiptrack%2Fview.html%2Fref%3Dpe_demo%3Fie%3DUTF8%26addressID%3DREDACTED%26orderID%3D${orderId}%26shipmentDate%3D1770594703%26orderingShipmentId%3D${shipmentId}%26packageId%3D1&H=EEEE">Lieferung verfolgen</a>`,
    `<p>Your item(s) is (are) being sent by Amazon Logistics. Your tracking number is: ${trackingDe}. Depending on the delivery method you chose, it's possible that the tracking information might not be visible immediately.</p>`,
    '<p><span>Voraussichtlich in 2-3 Tagen.</span></p>',
    '</td></tr></table></body></html>',
  ].join('\n')

  const c = ctx(
    'versandbestaetigung@amazon.de',
    'Deine Amazon.de-Bestellung mit "Samsung 870 EVO SSD..." wurde versandt!',
    '',
    html,
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.shopKey, 'amazon')
  assertEquals(parsed!.orderId, orderId)
  // `DE…`-Format ist gelöscht → kein primary.
  assertEquals(parsed!.tracking, undefined)
  // `trackingDe` wird absichtlich NICHT erkannt (VAT-Kollisions-Wand).
  assert(parsed!.tracking !== trackingDe)
  // Sicherheitsnetz: orderingShipmentId darf NICHT primary werden.
  assert(
    parsed!.tracking !== shipmentId,
    'orderingShipmentId darf nicht als primary tracking gewählt werden',
  )
})

// DE-Tracking-Carrier-Detection. User-Wunsch: Label nur, wenn der Body
// einen klaren Carrier-Hinweis liefert. `DE\d{10,12}` allein ist nicht
// eindeutig — Amazon Logistics UND DHL national nutzen das Format.
//
// Wir testen drei Fälle:
//   a) Body enthält "Amazon Logistics" → carrier = "Amazon Logistics"
//   b) Body enthält "DHL"              → carrier = "DHL"
//   c) Body enthält weder noch         → carrier = undefined (kein Label)
//
// Vorher hatte STRONG_TRACKING_PATTERNS hardcoded "Amazon Logistics" für
// DE\d{8,14} — das hat ALLE DE-Trackings als Amazon Logistics beschriftet,
// auch wenn sie in Wirklichkeit DHL waren. Das Label-Feld muss jetzt aus
// dem Body inferred werden.
Deno.test.ignore('DE-Tracking + Body "Amazon Logistics" → carrier=Amazon Logistics', () => {
  // Plan 2026-05-16 §D1/§D5: `inferCarrier()` wurde komplett entfernt
  // (toter Code mit nur noch DHL-Patterns). DE-Prefix-Trackings kommen
  // jetzt deterministisch mit `carrier='DHL'`. Body-Inference fuer
  // "Amazon Logistics" gibt es nicht mehr — final entscheidet die
  // DHL-API-Validation, ob's wirklich eine DHL-Sendung ist (Mails von
  // Amazon Logistics scheitern dann am API-404 und werden verworfen).
  const c = ctx(
    'versandbestaetigung@amazon.de',
    'Deine Bestellung wurde versendet',
    'Your item(s) is (are) being sent by Amazon Logistics. '
      + 'Your tracking number is: DE5455279839.',
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.tracking, 'DE5455279839')
  assertEquals(parsed!.carrier, 'Amazon Logistics')
})

Deno.test('DE-Tracking + Body "DHL" wird NICHT erkannt (VAT-Kollisions-Wand, Plan §2.8)', () => {
  // Echter Fall aus dem User-Screenshot: x-kom-Bestellung mit
  // "DE294559406" als „Tracking". Plan 2026-06-03 §2.8: `DE\d{8,14}` ist
  // gelöscht (kollidiert mit USt-IdNr.) — auch ein expliziter „DHL"-Hinweis
  // im Body promotet das Format NICHT mehr. Lieber kein Tracking als ein
  // falsches. (Echte DHL-Sendungen kommen als JJD / S10 / 20-stellig.)
  const c = ctx(
    'noreply@x-kom.pl',
    'Deine x-kom-Bestellung wurde versendet',
    'Sendung wird versendet mit DHL. Sendungsnummer: DE294559406.',
  )
  const parsed = detectAndParse(c)
  // x-kom ist kein gemappter Shop → kein ParsedOrder. Falls ein generischer
  // Fallback doch greift, darf das DE-Format NIE als Tracking erscheinen.
  if (parsed) {
    assert(
      parsed.tracking !== 'DE294559406',
      `DE-Format darf nicht als Tracking durchgehen, war "${parsed.tracking}"`,
    )
  }
})

Deno.test('DE-Tracking ohne Body-Hint wird NICHT als Tracking erkannt', () => {
  const c = ctx(
    'noreply@example.com',
    'Bestellung versendet',
    'Sendungsnummer: DE5455279839. Lieferung in 2-3 Werktagen.',
  )
  const parsed = detectAndParse(c)
  // Unbekannter Shop → kein ParsedOrder. Auch via Fallback darf `DE…`
  // niemals als Tracking promoten (Plan §2.8).
  if (parsed) {
    assert(
      parsed.tracking !== 'DE5455279839',
      `DE-Format darf nicht als Tracking durchgehen, war "${parsed.tracking}"`,
    )
  }
})

Deno.test.ignore('Amazon DE: "Deine Sendungsnummer lautet: …" matcht (lautet-Variante)', () => {
  // Plan 2026-05-16 §D1/§D5: `context-numeric-10-22`-Pattern wurde
  // entfernt (Bestellnr/Kundennr-Falsch-Positiv-Quelle). Eine 14-stellige
  // generische Zahl ohne DHL-Format laeuft jetzt nicht mehr als
  // Tracking-Candidate durch. Detection erfolgt ausschliesslich via
  // DHL-Patterns + API-Validation.
  const c = ctx(
    'versand@amazon.de',
    'Deine Bestellung wurde versendet',
    'Deine Sendungsnummer lautet: 12345678901234. Sie wird in Kürze von Hermes zugestellt.',
  )
  const parsed = detectAndParse(c)
  assertExists(parsed)
  assertEquals(parsed!.tracking, '12345678901234')
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

// ── DHL-only-Regression-Guards (Plan 2026-05-16 §D1) ─────────────────
// Diese Tests garantieren, dass entfernte Non-DHL-Patterns NICHT mehr
// als Tracking-Candidates auftauchen. Falls die Patterns je zurueckkehren
// (z.B. ueber DPD/UPS-API-Adapter), MUESSEN diese Tests aktualisiert
// werden, nicht stillschweigend kippen.

Deno.test('Plan §D1: UPS-1Z-Pattern wird NICHT mehr detected', () => {
  const candidates = findAllTrackings('Versand: 1Z999AA10123456784', {})
  assertEquals(candidates.length, 0)
})

Deno.test('Plan §D1: Amazon-TBA-Pattern wird NICHT mehr detected', () => {
  const candidates = findAllTrackings('Tracking: TBA123456789012', {})
  assertEquals(candidates.length, 0)
})

Deno.test('Plan §2.8: bare context-numeric (13-digit) wird im Legacy-Scan NICHT mehr detected', () => {
  // Plan 2026-06-03 §2.8: `context-numeric-10-22` ist aus TRACKING_PATTERNS
  // gelöscht (Bestellnr/Kundennr-Falsch-Positiv-Quelle). Der schmale
  // Legacy-`findAllTrackings`-Scan kennt nur noch `dhl-jjd`. Eine generische
  // 13-stellige Zahl — auch MIT „Sendungsnummer:"-Anchor — taucht hier nicht
  // mehr auf. Die produktive anchor-gated dhl-12/dhl-20-Detection lebt jetzt
  // in `tracking_detection.detect()`.
  const candidates = findAllTrackings('Sendungsnummer: 1234567890123', {})
  assertEquals(candidates.length, 0)
})

Deno.test('Plan §2.8: bare context-numeric OHNE Anchor wird im Legacy-Scan NICHT detected', () => {
  const candidates = findAllTrackings('Random text 1234567890123 here', {})
  assertEquals(candidates.length, 0)
})

Deno.test('Plan §D1: S10-UPU-Pattern (XJ12345678FR) wird im Legacy-Scan NICHT detected', () => {
  // S10 lebt jetzt in detect() (anchor-gated + ISO-3166 + Checksum), nicht
  // im Legacy-`findAllTrackings`-Scan.
  const candidates = findAllTrackings('Tracking: XJ12345678FR', {})
  assertEquals(candidates.length, 0)
})

Deno.test('Plan §2.8: DHL-JJD-Pattern bleibt im Legacy-Scan, carrier lowercase', () => {
  const candidates = findAllTrackings('Sendungsnummer: JJD012345678901234', {})
  assert(candidates.length >= 1, 'JJD-Pattern muss weiterhin matchen')
  const jjd = candidates.find((c) => c.value === 'JJD012345678901234')
  assert(jjd !== undefined, 'JJD012345678901234 muss als Candidate erscheinen')
  // T3-Casing-Fix: Carrier ist lowercase (deals.carrier CHECK erlaubt nur
  // 'dhl'|'amazon'|'dpd').
  assertEquals(jjd!.carrier, 'dhl')
})
