// T13: Tracking-Fixture-Bodies für inbox_adapters.ts Tests.
//
// Statt echter EML-Files werden Mail-Bodies als TypeScript-Konstanten
// definiert (einfacher zu pflegen, kein RFC-822-MIME-Parsing nötig).
// Jede Konstante repräsentiert einen realistischen Mail-Body-Text.

// ── Positiv-Cases (Pflicht: gateTracking → primary ≠ null, confidence === 'strong') ──

/** UPS 1Z Strong — plain Text-Body mit UPS 1Z-Tracking ohne Spaces */
export const pos_ups_1z_strong =
  'Ihre Bestellung wurde versandt. Sendungsnummer: 1Z999AA10123456784. ' +
  'Bitte verfolgen Sie Ihr Paket auf ups.com.'

/** UPS 1Z with Spaces — UPS-Tracking mit Leerzeichen zwischen Blöcken.
 *  Council-Finding #4: Whitespace-Normalisierung muss greifen,
 *  normalized=true im Candidate.
 */
export const pos_ups_1z_with_spaces =
  'Your UPS shipment is on its way. Tracking number: 1Z 999 AA1 0123456784. ' +
  'Estimated delivery: tomorrow.'

/** DHL JJD Strong — JJD-Format mit Anchor "Sendungsnummer" */
export const pos_dhl_jjd_strong =
  'Sendungsnummer: JJD012345678901234 — Ihr Paket ist unterwegs. ' +
  'Verfolgen Sie die Sendung auf dhl.de.'

/** DHL 20-Digit with Anchor — 20-stellige DHL-Tracking-Nr mit "Sendungsnummer:"-Anchor.
 *  Council-Finding #6: KEIN Reject auf 20-stellige Zahlen — nur Checksum validiert.
 *  00340434161094021501 ist eine gültige DHL-20-Paket-Tracking-Nr.
 */
export const pos_dhl_20_digit_with_anchor =
  'Sendungsnummer: 00340434161094021501. Ihr Paket ist auf dem Weg zu Ihnen. ' +
  'Versandpartner: DHL.'

/** Amazon Logistics TBA Strong — TBA-Prefix, strong ohne Anchor */
export const pos_amazon_tba_strong =
  'Your package has been shipped via Amazon Logistics. ' +
  'Tracking number: TBA123456789012. ' +
  'Track your delivery at amazon.de.'

/** S10 / UPU Strong — S10-Format XJ12345678FR (2 Buchst + 8 Ziffern + 2 Buchst = 12 Zeichen).
 *  Das TRACKING_PATTERNS s10-upu Regex matcht \b[A-Z]{2}\d{8}[A-Z]{2}\b (exakt 8 Ziffern).
 *  Kein Anchor nötig (requiresAnchor: false), carrier=S10.
 */
export const pos_s10_upu_strong =
  'Tracking number: XJ12345678FR. Your international shipment is on its way. ' +
  'Expected delivery in 5-10 business days.'

/** HTML Amazon Link — track.amazon.de/tracking/ href → html-href source */
export const pos_html_amazon_link_text =
  'Your package has been shipped. Track your delivery below.'

export const pos_html_amazon_link_html =
  '<html><body>' +
  '<p>Ihre Bestellung wurde versendet.</p>' +
  '<a href="https://track.amazon.de/tracking/ABCDEFGH12345678">Sendung verfolgen</a>' +
  '</body></html>'

// ── Negativ-Cases (Pflicht: gateTracking → primary === null) ──────────────

/** Amazon Order-ID ohne Anchor — 302-Präfix-Order-ID, kein echtes Tracking */
export const neg_amazon_order_id =
  'Your order 302-1234567-1234567 has been confirmed. ' +
  'We will ship your package soon. Thank you for shopping with us.'

/** Random 20-Digit — 20 Ziffern ohne Anchor und ohne Carrier-Pattern */
export const neg_random_20_digit =
  'Invoice number: 12345678901234567890. ' +
  'Please keep this for your records. Payment received successfully.'

/** DE IBAN — IBAN-ähnliche Zeichenkette, muss via iban-de rejected werden */
export const neg_iban_de =
  'Ihre Bankverbindung: DE89370400440532013000 — bitte überweisen Sie ' +
  'den Betrag auf dieses Konto. Kontoinhaber: Max Mustermann.'

/** Internationale Telefonnummer — +49-Prefix, muss phone-intl rejected werden */
export const neg_phone_intl =
  'Bei Fragen wenden Sie sich bitte an unseren Kundendienst: +49 30 1234567890. ' +
  'Wir sind Mo-Fr 9-17 Uhr erreichbar.'

/** PLZ-only — 5-stellige PLZ ohne echtes Tracking */
export const neg_plz_only =
  'Lieferadresse: Musterstraße 1, 10115 Berlin. ' +
  'Bitte stellen Sie sicher, dass die Adresse korrekt ist.'

/** Invoice short — 8-stellige Rechnungsnummer ohne Anchor */
export const neg_invoice_short =
  'Rechnungsnummer 12345678. Betrag: 49,99 €. Fälligkeitsdatum: 01.06.2026. ' +
  'Bitte zahlen Sie rechtzeitig.'

/** Amazon orderingShipmentId only — nur shipmentId aus progress-tracker-URL,
 *  kein starkes Tracking. Muss als medium/none in Candidates landen,
 *  aber primary=null bei minConfidence='strong'.
 */
export const neg_orderingShipmentId_only_html =
  '<html><body>' +
  '<a href="https://www.amazon.de/progress-tracker/package/ref=pe_xxx?' +
  'orderId=404-5127739-1289903&packageId=1&orderingShipmentId=109727463192302">' +
  'Bestellung verfolgen' +
  '</a>' +
  '</body></html>'

export const neg_orderingShipmentId_only_text =
  'Ihre Bestellung wurde bearbeitet. Klicken Sie oben, um den Status zu verfolgen.'

// ── Edge-Cases ────────────────────────────────────────────────────────────

/** Edge: anchorMatched max 50 chars — sehr langer Text vor dem Anchor-Wort.
 *  Plan §3.2: anchorMatched KEIN Folge-Text, max 50 chars (PII-Schutz).
 *  Der Surrounding-Context ist bewusst sehr lang — wir prüfen, dass
 *  findAnchorBefore() trotzdem ≤ 50 chars zurückgibt.
 */
export const edge_anchormatched_max_50chars =
  'Sehr geehrte Kundin, sehr geehrter Kunde, wir freuen uns, Ihnen mitteilen ' +
  'zu können, dass Ihre Bestellung auf dem Weg ist und die folgende ' +
  'Sendungsnummer: 1Z999AA10123456784 für die Nachverfolgung verwenden können. ' +
  'Mit freundlichen Grüßen, Ihr Shop-Team.'

/** Edge: Body >256 KB — synthetisches Body über Body-Cap.
 *  Tracking VOR 100 KB: muss gefunden werden.
 *  Tracking nach 300 KB: darf NICHT gefunden werden (Body-Cap greift).
 *  Zwei Varianten: early_tracking_value und late_tracking_value.
 */
export const edge_body_over_256kb_early_tracking_value = '1Z999AA10123456784'
export const edge_body_over_256kb_late_tracking_value = '1Z888BB20987654321'

/** Body, in dem das frühe Tracking bei ~50 KB liegt (vor 256 KB Cap) */
export function buildBodyOver256kbWithEarlyTracking(): string {
  const prefix = 'Sendungsnummer: 1Z999AA10123456784 — '
  // Filler bis auf ~310 KB total
  const filler = 'lorem ipsum dolor sit amet consectetur adipiscing elit. '.repeat(6000)
  return prefix + filler
}

/** Body, in dem das late Tracking jenseits 256 KB liegt */
export function buildBodyOver256kbWithLateTracking(): string {
  // 300 KB filler, dann Tracking
  const filler = 'x'.repeat(300 * 1024)
  return filler + ' Sendungsnummer: 1Z888BB20987654321'
}
