// Shop-Adapter. Reduziert auf die fünf Shops, die der User aktiv nutzt:
//   amazon (DE/COM/UK/FR/IT/ES), mediamarkt, saturn, pccomponentes, xkom.
//
// Jeder Adapter hat drei Ebenen:
//   matches(ctx)         — From-Header-Domain passt → Mail kommt überhaupt
//                          in die Inbox. Wird auch im inbox-poll als Whitelist
//                          benutzt (alles andere wird gar nicht gespeichert).
//   looksLikeOrder(ctx)  — Subject/Body sehen aus wie eine Order-/Versand-/
//                          Stornierungs-Mail (nicht Werbung/Newsletter).
//                          Wird vom inbox-poll geprüft, damit Promos nicht
//                          mal auf der Platte landen.
//   parse(ctx)           — Versucht order_id, tracking, product, total
//                          zu extrahieren. Darf null zurückgeben — dann landet
//                          die Mail im Unklassifiziert-Tab mit shop_key, der
//                          User kann manuell daraus einen Deal machen.

// Tracking-Detection (Plan 2026-06-03, T3): die Adapter-Pipeline delegiert die
// Sendungsnummer-Extraktion ausschliesslich an `detect()` aus
// `tracking_detection.ts`. Die alte Pattern-/API-Probe-Detection (dhl-de-prefix,
// context-numeric, enrichWithDhlValidation) ist entfernt. Der Import ist
// runtime-only (zirkulaer, aber kein Top-Level-Init-Zyklus): `tracking_detection.ts`
// nutzt `ANCHOR_WORDS`/`findAnchorBefore`/`MAX_BODY_LEN`/`TrackingCandidate` von
// hier, dieses Modul ruft `detect()` nur innerhalb von `resolveTrackingForAdapter`.
import { detect as detectTracking } from './tracking_detection.ts'

export interface ParsedOrderItem {
  product: string
  quantity: number
  unitPrice?: number
  currency?: string
  seller?: string
}

export interface OrderTotal {
  amount: number
  currency: string
}

export interface ParsedOrder {
  shopKey: string
  shopLabel: string
  orderId?: string
  product?: string
  quantity: number
  total?: number
  currency: string
  /// Primäres Tracking (für Backwards-Compat + die "auf Deal anwenden"-
  /// Aktion). Gleicht trackings[0], wenn vorhanden.
  tracking?: string
  /// Vollständige, deduplizierte Liste aller Tracking-Nrn aus der Mail.
  /// Eine Bestellung kann in mehrere Pakete gesplittet sein, dann hängen
  /// hier mehrere Werte drin.
  trackings?: string[]
  carrier?: string
  eta?: string
  status?: 'ordered' | 'shipped' | 'delivered' | 'cancelled' | 'refunded'

  // ── Forensik-Erweiterungen (alle optional, additiv) ──────────────────
  /// ISO-Date `YYYY-MM-DD`. Frühster im HTML genannter Liefertermin.
  /// Wenn ein Range angegeben ist (z.B. "18.-21. März 2026"), nimmt
  /// `eta_date` den Range-Start.
  etaDate?: string
  /// ISO-DateTime `YYYY-MM-DDTHH:mm:ssZ`. Aus Unix-Timestamp im
  /// Tracking-URL (Amazon: `&shipmentDate=…`) oder explizitem
  /// "versandt am …"-Block.
  shippedAt?: string
  /// Order-Total inkl. MwSt mit Currency.
  orderTotal?: OrderTotal
  /// MwSt-Satz in Prozent (PCComponentes / Marketplace zeigen explizit).
  taxRatePct?: number
  /// Ländercode der Versandadresse — kein Name/Straße (DSGVO).
  shippingAddressCountry?: string
  /// Item-Liste für Multi-Article-Bestellungen.
  items?: ParsedOrderItem[]
  /// Zustellart wenn explizit angegeben.
  deliveryMethod?: 'standard' | 'express' | 'pickup' | 'partner'
  /// Storno-Grund.
  cancellationReason?: string
  /// Verkäufer/Marketplace-Seller (Top-Level — bei Marketplace-Mails
  /// häufig pro Item nochmal in `items[].seller`).
  seller?: string

  // ── T3c: Strict-Tracking Felder ──────────────────────────────────────
  /// Confidence der primary Tracking-Nr (`tracking`). Strict-Mapping:
  /// `'strong'` wenn ein Candidate die Gate-Schwelle erreicht hat,
  /// sonst `'none'`.
  trackingConfidence?: 'strong' | 'none'
  /// Forensik-Liste aller gefundenen Candidates (auch medium/weak/none),
  /// max 10 Einträge — Plan §3.2. Wird in `parsed_payload.tracking_candidates`
  /// abgelegt.
  trackingCandidates?: TrackingCandidate[]
  /// `true` wenn die Mail Tracking-relevant ist (shipped/delivered), aber
  /// kein Candidate die Strong-Schwelle erreicht hat → UI zeigt
  /// „Manuell eingeben".
  trackingNeedsReview?: boolean
}

export interface MailContext {
  from: string
  subject: string
  text: string
  html: string
}

interface Adapter {
  key: string
  label: string
  matches: (ctx: MailContext) => boolean
  looksLikeOrder: (ctx: MailContext) => boolean
  parse: (ctx: MailContext) => ParsedOrder | null
}

// ── Helpers ────────────────────────────────────────────────────────────
const moneyRe = /([\d.]+,\d{2}|\d+\.\d{2})\s*(EUR|€|USD|\$|GBP|£|PLN|zł)?/i

// Pattern-basierte Body-Detection lebt vollständig in `tracking_detection.ts`
// (`detect()`). Hier bleibt nur die `ANCHOR_WORDS`-Liste (DE/EN/FR/IT/ES/PL)
// + `findAnchorBefore`, die `detect()` für die Anchor-Pflicht importiert.

// Body-Cap für Tracking-Scan (Plan §3.7, ReDoS-Mitigation).
export const MAX_BODY_LEN = 256 * 1024

// Reject-Patterns + die alte `findAllTrackings`/`gateTracking`-Pipeline sind
// mit dem Dead-Code-Cleanup (chore/audit-sustainability-1) entfernt: die
// produktive Detection läuft AUSSCHLIESSLICH über `tracking_detection.detect()`,
// das seine eigenen `REJECT_PATTERNS`/`checkReject` mitbringt (siehe
// `tracking_detection.ts` §2.2). Hier bleiben nur die Bausteine, die `detect()`
// importiert: `TrackingCandidate`/`TrackingConfidence`, `ANCHOR_WORDS`,
// `findAnchorBefore`, `MAX_BODY_LEN` — plus die Adapter-Status-Heuristik
// (`detectShipStatus`/`resolveStatusAndTracking`), die `detect()` aufruft.
export type TrackingConfidence = 'strong' | 'medium' | 'weak' | 'none'

export type TrackingCandidate = {
  /// Normalisierter Wert: Whitespace gestrippt, uppercased.
  value: string
  /// Roh-Token aus dem Mail-Body (vor Normalisierung).
  rawValue: string
  /// Carrier-Name, wenn aus Pattern oder Validator ableitbar.
  /// Validator-Carrier (jkeen-DB) gewinnt über Pattern-Carrier.
  carrier?: string
  /// Quelle des Matches.
  source:
    | 'strong-pattern'
    | 'context-anchor'
    | 'html-href'
    | 'amazon-shipment-id'
    | 'unknown'
  /// Confidence-Klassifikation. Persistenz erlaubt nur 'strong'.
  confidence: TrackingConfidence
  validation: {
    /// Anchor-Wort aus dem 80-Zeichen-Fenster vor dem Match. Max 50
    /// Zeichen (PII-Schutz, Council-Finding #7).
    anchorMatched?: string
    /// Reject-Grund, falls der Token von einem Reject-Pattern abgewiesen
    /// wurde (gesetzt von `tracking_detection.detect()`).
    rejectedBy?: string
    /// Checksum-Result (undefined wenn keine Checksum-Validierung lief).
    checksumValid?: boolean
    /// `true` wenn Whitespace gestrippt wurde (rawValue != value).
    normalized: boolean
    /// ID des Detection-Patterns, das gegriffen hat (Forensik).
    patternId?: string
  }
}

// ── Anchor-Worte (DE/EN/FR/IT/ES/PL) ──────────────────────────────────
// Quellen: Plan §3.3 + bestehende CONTEXT_TRACKING_RE-Tokens. Reihenfolge
// nach Spezifität (Mehrwort-Anker zuerst), damit `findAnchorBefore` den
// längsten Treffer bevorzugt — case-insensitive Suche.
export const ANCHOR_WORDS: string[] = [
  // DE
  'Sendungsnummer',
  'Sendungs-Nummer',
  'Sendungsnr',
  'Sendungsverfolgung',
  'Sendung',
  'Versandnummer',
  'Versand-Nr',
  'Paketnummer',
  'Paket-Nr',
  'Tracking-Nummer',
  'Tracking-Nr',
  'Trackingnummer',
  'Tracking',
  'Identcode',
  'Auftragsnummer',
  // EN
  'Tracking number',
  'Tracking Number',
  'Tracking ID',
  'Tracking #',
  'Tracking no',
  'Shipment ID',
  'Shipment',
  // FR
  'Numéro de suivi',
  'Numero de suivi',
  'Numéro de colis',
  'Suivi',
  // IT
  'Numero di tracciamento',
  'Numero tracciamento',
  'Numero di spedizione',
  // ES
  'Número de seguimiento',
  'Numero de seguimiento',
  'Número de envío',
  // PL
  'Numer przesyłki',
  'Numer przesylki',
  'Numer śledzenia',
]

/**
 * Prüft, ob im 80-Zeichen-Fenster VOR dem Match-Start ein Anchor-Wort
 * vorkommt. Liefert das kürzeste matched Anchor-Token zurück
 * (max 50 chars — PII-Schutz, Council-Finding #7).
 *
 * @param body Voller Mail-Body (oder normalisiert auf 256 KB).
 * @param matchStart Offset des Match-Beginns im Body.
 * @returns Anchor-Wort als String oder `null` wenn keiner gefunden.
 */
export function findAnchorBefore(body: string, matchStart: number): string | null {
  const start = Math.max(0, matchStart - 80)
  const window = body.slice(start, matchStart)
  const lower = window.toLowerCase()
  let bestIdx = -1
  let bestLen = -1
  let bestWord: string | null = null
  for (const word of ANCHOR_WORDS) {
    const needle = word.toLowerCase()
    // Word-Boundary-Check: anchor muss als eigenes Wort vorkommen, NICHT
    // als Substring innerhalb anderer Wörter. Bug 2026-05-15:
    // `Shipment` matchte als Substring von `orderingShipmentId` →
    // shipment-id wurde fälschlich als strong-context-tracking gewertet.
    // Erlaubt: Start-of-window / Whitespace / Punctuation vor + nach.
    const re = new RegExp(`(?:^|[^a-z0-9])${needle.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?=[^a-z0-9]|$)`, 'g')
    let m: RegExpExecArray | null
    let lastIdx = -1
    while ((m = re.exec(lower)) !== null) {
      // m.index ist der char VOR dem Anchor (oder 0 wenn am Start).
      // Den Anchor-Start ermitteln: wenn m.index===0 und der erste char
      // ist der Anchor → idx=0; sonst idx = m.index + 1.
      const matched = m[0]
      const anchorStart = matched.toLowerCase().startsWith(needle) ? m.index : m.index + 1
      lastIdx = anchorStart
    }
    if (lastIdx < 0) continue
    // Prefer (a) later anchor (closer to match), (b) on tie, longer word.
    if (lastIdx > bestIdx || (lastIdx === bestIdx && word.length > bestLen)) {
      bestIdx = lastIdx
      bestLen = word.length
      bestWord = window.slice(lastIdx, lastIdx + word.length)
    }
  }
  if (!bestWord) return null
  // PII-Schutz: max 50 chars zurückgeben.
  return bestWord.slice(0, 50)
}

const stripHtml = (html: string): string =>
  html
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    .replace(/&[a-z]+;/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim()

const haystack = (ctx: MailContext): string =>
  `${ctx.subject}\n${ctx.text}\n${stripHtml(ctx.html)}`

const parseMoney = (s: string): { total?: number; currency: string } => {
  const m = moneyRe.exec(s)
  if (!m) return { currency: 'EUR' }
  const raw = m[1].replace(/\./g, '').replace(',', '.')
  const total = Number(raw)
  const sym = (m[2] ?? '').toUpperCase()
  const currency =
    sym === '€' || sym === 'EUR' ? 'EUR'
    : sym === '$' || sym === 'USD' ? 'USD'
    : sym === '£' || sym === 'GBP' ? 'GBP'
    : sym === 'PLN' || sym === 'ZŁ' || sym === 'ZL' ? 'PLN'
    : 'EUR'
  return { total: Number.isFinite(total) ? total : undefined, currency }
}

const findFirst = (s: string, patterns: RegExp[]): string | undefined => {
  for (const re of patterns) {
    const m = re.exec(s)
    if (m && m[1]) return m[1].trim()
  }
  return undefined
}

// Body-/HTML-Tracking-Extraktion (`findTrackingsInHtml`, `findAllTrackings`,
// `gateTracking`, `TRACKING_PATTERNS`, `REJECT_PATTERNS`/`checkRejectPatterns`)
// ist mit dem Dead-Code-Cleanup (chore/audit-sustainability-1) entfernt — der
// Pfad war prod-tot: die Adapter rufen ausschliesslich `resolveStatusAndTracking`
// → `tracking_detection.detect()` auf. detect() bringt eigene Pattern-,
// Reject-, Checksum- und HTML-href-Logik mit (siehe `tracking_detection.ts`).
// KEINE neue Detection-Logik hier ergaenzen — alles Neue gehoert nach
// `tracking_detection.ts`.
// Status-Detection ist subject-first und nur dann body-second, wenn das
// Subject völlig generisch ist. Hintergrund: Body-Texte enthalten oft
// AGB-Boilerplate ("Falls Sie stornieren möchten, klicken Sie hier")
// oder Footer-Hinweise, die simple Regex zum Falsch-Positive verleiten.
// Das Subject ist dagegen die Shop-kuratierte Zusammenfassung der Mail.

const cancelledRe = /\b(stornier|widerrufen|cancell|anulad|anulowan)/i
const refundedRe  = /\b(erstattung|gutschrift|refund|reembols|zwrot)/i
const deliveredRe = /\b(zugestell|delivered|angekommen|entregad|dostarczon)/i
const shippedRe   = /\b(versand|verschickt|wurde versendet|wir haben.*versen|shipped|on its way|unterwegs|tracking|sendung|paket|zustell|envío|enviado|wysłan|wysylk|wysyłk)/i

function detectShipStatus(
  subject: string,
  body: string,
  hasTracking: boolean,
): 'ordered' | 'shipped' | 'delivered' | 'cancelled' | 'refunded' {
  const subj = subject ?? ''
  // Subject hat Vorrang.
  if (cancelledRe.test(subj)) return 'cancelled'
  if (refundedRe.test(subj))  return 'refunded'
  if (deliveredRe.test(subj)) return 'delivered'
  if (shippedRe.test(subj))   return 'shipped'
  // Subject war generisch (z.B. "Bestellung #123") → Body-Fallback, aber
  // mit härteren Patterns (Vergangenheits-Form / explizite Bestätigungen).
  if (/\b(wurde\s+(?:storniert|gecancelt))\b/i.test(body)) return 'cancelled'
  if (/\b(wurde\s+(?:erstattet|zurückerstattet))\b/i.test(body)) return 'refunded'
  if (deliveredRe.test(body)) return 'delivered'
  if (hasTracking || shippedRe.test(body)) return 'shipped'
  return 'ordered'
}

// T3 (Plan 2026-06-03): `gateTrackingByStatus` ist entfernt — das Status-Gate
// (Tracking nur bei shipped/delivered) lebt jetzt in `tracking_detection.detect()`
// (§2.7). Der frühere Doppel-Gate (Status-Gate + Confidence-Gate) im alten
// `resolveTrackingForAdapter` ist durch den einen `detect()`-Call ersetzt.

/// Extrahiert die Absender-Domain (lowercase, ohne `@`) aus einem
/// From-Header. `"Amazon <shipment-tracking@amazon.de>"` → `amazon.de`.
/// Liefert `undefined`, wenn keine Domain erkennbar ist.
export function senderDomainFromHeader(from: string | null | undefined): string | undefined {
  if (!from || typeof from !== 'string') return undefined
  const at = from.lastIndexOf('@')
  if (at < 0) return undefined
  // Alles nach dem letzten `@` bis zum ersten Whitespace/`>`/`"`.
  const tail = from.slice(at + 1)
  const m = /^([A-Za-z0-9.-]+)/.exec(tail)
  if (!m) return undefined
  const domain = m[1].toLowerCase().replace(/\.+$/, '')
  return domain.length > 0 ? domain : undefined
}

/// Kombiniert Status-Detection + Tracking-Detection in einem Aufruf — der
/// gemeinsame Block aller Adapter-Call-Sites (Plan 2026-06-03, T3). Reihen-
/// folge: (1) lightweight Tracking-Probe mit `status='shipped'`, um zu wissen,
/// ob ueberhaupt eine pollbare Sendungsnummer im Body steckt (füttert
/// `detectShipStatus`-Heuristik „ordered → shipped, wenn Tracking vorhanden");
/// (2) echter Status; (3) finale Detection mit dem echten Status (gated).
/// Liefert `status` + die `ParsedOrder`-Tracking-Felder als ein Bundle.
export function resolveStatusAndTracking(ctx: MailContext): {
  status: 'ordered' | 'shipped' | 'delivered' | 'cancelled' | 'refunded'
  tracking?: string
  trackings?: string[]
  carrier?: string
  trackingConfidence: 'strong' | 'none'
  trackingCandidates: TrackingCandidate[]
  trackingNeedsReview: boolean
} {
  const subject = ctx.subject ?? ''
  const body = haystack(ctx)
  // (1) Probe: detect() mit shipped umgeht das Status-Gate, damit wir wissen,
  //     ob eine valide Sendungsnummer existiert (für die ordered→shipped-Nudge).
  const probe = detectTracking({
    subject,
    text: ctx.text ?? '',
    html: ctx.html ?? '',
    status: 'shipped',
    senderDomain: senderDomainFromHeader(ctx.from),
  })
  const hasTracking = !!probe.tracking
  // (2) Status (subject-first, body-second, Tracking-Nudge).
  const status = detectShipStatus(subject, body, hasTracking)
  // (3) Finale Detection mit echtem Status — bei ordered/cancelled/refunded
  //     liefert detect() NONE (Status-Gate).
  const resolved = resolveTrackingForAdapter(ctx, status)
  return { status, ...resolved }
}

/// Adapter-internes Helper (Plan 2026-06-03, T3): delegiert die Tracking-
/// Detection ausschliesslich an `tracking_detection.detect()`. Baut den
/// `DetectionInput` aus dem `MailContext` + dem bereits ermittelten
/// `status` (subject, text, html, senderDomain). `detect()` kapselt das
/// Status-Gate (Tracking nur bei shipped/delivered), Reject-/VAT-Filter,
/// Checksum-Validierung und Cross-Carrier-Widerspruch.
///
/// Mapping `DetectionResult` → `ParsedOrder`-Tracking-Felder:
///   * `carrier` ist bereits lowercase ('dhl'|'amazon'|'dpd') aus detect().
///   * `confidence: 'strong'` → primary akzeptiert; `'none'` → kein primary.
///   * `needsReview` → `trackingNeedsReview`.
/// Die 15 Adapter-Call-Sites laufen alle durch diesen einen Helper.
function resolveTrackingForAdapter(
  ctx: MailContext,
  status: 'ordered' | 'shipped' | 'delivered' | 'cancelled' | 'refunded',
): {
  tracking?: string
  trackings?: string[]
  carrier?: string
  trackingConfidence: 'strong' | 'none'
  trackingCandidates: TrackingCandidate[]
  trackingNeedsReview: boolean
} {
  const result = detectTracking({
    subject: ctx.subject ?? '',
    text: ctx.text ?? '',
    html: ctx.html ?? '',
    status,
    senderDomain: senderDomainFromHeader(ctx.from),
  })

  if (!result.tracking) {
    return {
      tracking: undefined,
      trackings: undefined,
      carrier: undefined,
      trackingConfidence: 'none',
      trackingCandidates: result.candidates,
      trackingNeedsReview: result.needsReview,
    }
  }

  return {
    tracking: result.tracking,
    trackings: result.trackings.length > 0 ? result.trackings : [result.tracking],
    // `detect()` emittiert Carrier lowercase. carrier kann nie 'amazon'-poll-
    // bar sein, aber wird zur Anzeige/Skip-Logik (T4) gespeichert.
    carrier: result.carrier ?? undefined,
    trackingConfidence: 'strong',
    trackingCandidates: result.candidates,
    trackingNeedsReview: false,
  }
}

// Subjects, die garantiert KEINE Order sind (Promo/Newsletter/Account-Stuff).
const isOrderishSubject = (subject: string): boolean => {
  const s = subject.toLowerCase()
  // Hard skip: Promo / Newsletter / Account-Verwaltung
  if (/\b(angebot|newsletter|spare|prozent|sale|promotion|deal des tages|wartet auf dich|sichern|profitieren|benutzerverwaltung|update|empfehl|inspirat|prime[- ]?duo|hinzufügen|jetzt entdecken|tipps|spotlight|black friday|cyber monday)/i.test(s)) return false
  // Whitelist-Pattern: typische Order-Mail-Subjects
  return /\b(bestell|order|auftrag|versand|lieferung|tracking|zustell|sendung|paket|stornier|widerruf|erstattung|gutschrift|rechnung|invoice|frankierung|shipping|shipped|delivery|envío|zamówieni|wysył|dostaw)/i.test(s)
}

// Carrier-Direkt-Mails (DPD, GLS, Hermes, DHL, MyHermes etc.). Das sind
// reine Tracking-Status-Updates und keine Order-Mails. Wenn ein Deal
// aktiv getrackt wird, kommt der Status ohnehin via tracking-poll rein —
// die direkten Carrier-Mails würden dann nur als "Unklassifiziert"
// herumliegen, weil sie weder Order-ID noch Produktname enthalten.
//
// Wichtig: NICHT für DHL-Frankierungs-Bestätigungen ("Online Frankierung
// QMBZ…") — das sind Versand-Belege, die der User für seine Buchhaltung
// nutzt. Die fangen wir gesondert über das `frankierung`-Subject ab.
//
// noreply@dhl.com bleibt erlaubt, weil DHL auch Bestellbestätigungen
// für Frankierungs-Online-Käufe von dort verschickt — Subject-Filter
// bestimmt dann ob "Auftragsbestätigung Online Frankierung" oder
// reine Tracking-Mail. Tracking-Mails von DHL kommen i.d.R. von
// noreply@track.dhlecommerce.com / noreply@dhl.de mit Subjects ohne
// "Bestellung"/"Auftrag".
const CARRIER_DOMAINS = [
  /(@|\.)service\.dpd\.de\b/i,
  /(@|\.)feedback\.dpd\.de\b/i,
  /(@|\.)gls-pakete\.de\b/i,
  /(@|\.)gls-group\.com\b/i,
  /(@|\.)paketankuendigung\.myhermes\.de\b/i,
  /(@|\.)myhermes\.de\b/i,
  /(@|\.)hermesworld\.com\b/i,
]

/// True wenn die Mail von einem Carrier kommt UND keine Frankierungs-/
/// Bestell-Bestätigung ist (DHL verschickt z.B. auch Frankierungs-
/// Belege, die wir behalten wollen).
export const isCarrierOnly = (ctx: MailContext): boolean => {
  // DHL gesondert: nur skippen wenn Subject NICHT nach Frankierung/
  // Bestellung aussieht.
  if (/(@|\.)dhl\.(com|de)\b/i.test(ctx.from)) {
    if (/\b(frankierung|auftragsbest|bestell|order|invoice|rechnung)\b/i
      .test(ctx.subject)) return false
    return true
  }
  return CARRIER_DOMAINS.some((re) => re.test(ctx.from))
}

// Accounting-Service-Mails (eigene Buchhaltung — Lexware/Lexoffice/
// Datev). Das sind Rechnungen für die SaaS-Subscription des Users
// und Kopien selbst-versendeter Belege. Sie sind weder Bestellung
// noch Versand noch Erstattung; sie würden nur den Inbox-Tab
// zumüllen, wenn wir sie aufnehmen.
const ACCOUNTING_DOMAINS = [
  /(@|\.)lexware\.de\b/i,
  /(@|\.)lexoffice\.de\b/i,
  /(@|\.)datev\.de\b/i,
  /(@|\.)sevdesk\.de\b/i,
]

export const isAccountingMail = (ctx: MailContext): boolean =>
  ACCOUNTING_DOMAINS.some((re) => re.test(ctx.from))

// Boilerplate-Phrasen, die KEIN echter Produktname sind. Trifft regelmäßig
// auf Amazon-AGB-Disclaimer in Versandbestätigungs-Mails (Widerrufsrecht etc.)
// und auf Service-Anrede-Texte ("Sie erhalten…", "Vielen Dank…").
const PRODUCT_BLACKLIST = [
  /^Waren,?\s+die\b/i,
  /^Gegenstände,?\s+die\b/i,
  /^Items?,?\s+(?:that|which)\b/i,
  /^Articulos?,?\s+que\b/i,
  /^Vom (?:Widerrufs|Rückgabe)/i,
  /^Hinweis(?:e)?\b/i,
  /\bWiderrufsrecht\b/i,
  /\bRückgaberecht\b/i,
  /\bGesundheitsschutz/i,
  /\bHygienegründen/i,
  /\bRückgabe\s+(?:geeignet|nicht)/i,
  /^(Hallo|Hi|Liebe|Sehr geehrt)/i,
  /^Sie\s+(erhalten|können|haben|werden|finden|bekommen)/i,
  /^Wir\s+(haben|melden|senden|werden|freuen|informieren)/i,
  /^Vielen\s+Dank\b/i,
  /^Danke\b/i,
  /^Du\s+(findest|kannst|hast|wirst|bist)/i,
  /^Ihre\s+(Bestellung|Lieferung|Sendung)\b/i,
  /^Deine\s+(Bestellung|Lieferung|Sendung)\b/i,
]

const sanitizeProduct = (raw?: string): string | undefined => {
  if (!raw) return undefined
  const cleaned = raw.replace(/\s+/g, ' ').trim()
  if (cleaned.length < 4) return undefined
  // Echte Produkt-/Markennamen starten mit Großbuchstabe, Ziffer oder
  // einem Quote. Lowercase-Anfang = meistens deutsches Verb/Pronomen
  // ("deiner", "findest", "wartet"…) das wir aus einem zu greedy
  // gematchten Body-Snippet erwischt haben.
  if (!/^["„«»]?[A-Z0-9ÄÖÜ]/u.test(cleaned)) return undefined
  if (/^(https?:\/\/|www\.)/i.test(cleaned)) return undefined
  if (/[<>{}|\\^`]/.test(cleaned)) return undefined
  for (const re of PRODUCT_BLACKLIST) {
    if (re.test(cleaned)) return undefined
  }
  return cleaned
}

/// MediaMarkt / Saturn / Kaufland linearisieren ihre Bestellübersicht im
/// HTML als Tabelle:
///   Anzahl | Artikelnummer und Beschreibung | Einzelpreis | Summe
///   1      | 2924946 STARLINK Standard Kit  | 279,00 €    | 279,00 €
/// Im Plaintext fällt die Spalten-Trennung weg, alles steht in einer Zeile.
///
/// Strategie: Suche nach "Artikelnummer", spring zur ersten 6-9 stelligen
/// Zahl (Artikelnummer hat Format `\d{6,9}` bei diesen Shops), dann nimm
/// die folgenden Großbuchstaben-Tokens. Multi-Token-Pflicht filtert
/// False-Positives wie "Cnodate" raus, die in Versand-/Zustell-Mails ohne
/// Item-Table aus Tracking-Widgets stammen.
const productFromArticleTable = (s: string): string | undefined => {
  const m = /Artikelnummer[\s\S]{0,400}?\b\d{6,9}\b[\s\S]{0,60}?([A-Z][A-Za-z0-9 \-+.,/&®™²³()€$£]{4,140})/.exec(s)
  if (!m || !m[1]) return undefined
  let cleaned = m[1]
    // Trailing Geldbetrag abschneiden: "STARLINK Standard Kit 279,00 Euro" → "STARLINK Standard Kit"
    .replace(/\s+\d+[.,]\d{2}\s*(?:Euro|€|EUR|USD|GBP|PLN|zł).*$/i, '')
    // MediaMarkt-Versandmails hängen oft "Lieferung bis Montag, …",
    // "Lieferanschrift …", "Versand durch DPD" hinten dran — alles ab
    // dem Schlüsselwort wegschneiden.
    .replace(/\s+(?:Lieferung\b|Lieferanschrift\b|Versand\s+durch\b|Versanddatum\b|Sendungsnummer\b|Tracking\b).*$/i, '')
    .replace(/\s+/g, ' ')
    .trim()
  // Single-Word-Treffer (z.B. "Cnodate") verwerfen — echte Produktnamen
  // bestehen aus Marke + Modell + ggf. Spec, also mind. 2 Tokens.
  if (cleaned.split(/\s+/).length < 2) return undefined
  return sanitizeProduct(cleaned)
}

// Versucht, einen Produktnamen aus dem Subject zu ziehen. Funktioniert für
// "Bestätigung deiner Bestellung von „<Produkt>"", "Versand: <Produkt>" usw.
const productFromSubject = (subject: string): string | undefined => {
  const patterns: RegExp[] = [
    /["„«»]([^"""„«»\n]{4,140})["""„«»]/,
    /(?:Bestätigung|Versand|Lieferung|Zustellung|Confirmation|Shipped):\s*([^\n]{4,140})/i,
  ]
  for (const re of patterns) {
    const m = re.exec(subject)
    if (m && m[1]) {
      const cleaned = sanitizeProduct(m[1])
      if (cleaned) return cleaned
    }
  }
  return undefined
}

// ── Forensik-Helper ────────────────────────────────────────────────────

/// DE-Monatsnamen → Monatsindex.
const DE_MONTHS: Record<string, number> = {
  'januar': 1, 'jan': 1, 'februar': 2, 'feb': 2, 'märz': 3, 'maerz': 3,
  'mär': 3, 'mar': 3, 'april': 4, 'apr': 4, 'mai': 5, 'juni': 6, 'jun': 6,
  'juli': 7, 'jul': 7, 'august': 8, 'aug': 8, 'september': 9, 'sep': 9,
  'sept': 9, 'oktober': 10, 'okt': 10, 'oct': 10, 'november': 11, 'nov': 11,
  'dezember': 12, 'dez': 12, 'dec': 12,
}
/// EN-Monatsnamen → Monatsindex.
const EN_MONTHS: Record<string, number> = {
  'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5,
  'june': 6, 'july': 7, 'august': 8, 'september': 9, 'october': 10,
  'november': 11, 'december': 12,
}
/// ES-Monatsnamen.
const ES_MONTHS: Record<string, number> = {
  'enero': 1, 'febrero': 2, 'marzo': 3, 'abril': 4, 'mayo': 5,
  'junio': 6, 'julio': 7, 'agosto': 8, 'septiembre': 9, 'octubre': 10,
  'noviembre': 11, 'diciembre': 12,
}

function monthIndex(name: string): number | null {
  const k = name.toLowerCase().replace(/\.$/, '')
  return DE_MONTHS[k] ?? EN_MONTHS[k] ?? ES_MONTHS[k] ?? null
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : String(n)
}

function isoFromYmd(y: number, m: number, d: number): string | undefined {
  if (!Number.isFinite(y) || !Number.isFinite(m) || !Number.isFinite(d)) return undefined
  if (m < 1 || m > 12 || d < 1 || d > 31) return undefined
  return `${y}-${pad2(m)}-${pad2(d)}`
}

/// Extrahiert das frühste ETA-Datum aus dem Mail-Body. Versucht in
/// dieser Reihenfolge:
///   1. Unix-Timestamp im URL (`&latestArrivalDate=1778004000`).
///   2. Numerisches DE-Format `15.05.2026`.
///   3. EN-Format `March 15, 2026` / `Mar 15, 2026`.
///   4. DE-Wort-Format `15. März 2026` oder `Donnerstag, 12.03.2026`.
///   5. Wochentag + DE-Monat ohne Jahr → mit aktuellem Jahr (mit
///      Roll-Over auf nächstes Jahr falls Datum > 4 Monate in
///      Vergangenheit liegt).
export function extractEtaDate(html: string, text: string): string | undefined {
  // (1) Unix-Timestamp. Auch HTML-entity-coded URLs (&amp;) abfangen.
  const decodedHtml = html.replace(/&amp;/g, '&')
  const tsMatch = /[?&]latestArrivalDate=(\d{10})\b/.exec(decodedHtml)
  if (tsMatch) {
    const ts = Number(tsMatch[1])
    if (Number.isFinite(ts)) {
      const d = new Date(ts * 1000)
      if (!Number.isNaN(d.getTime())) return d.toISOString().slice(0, 10)
    }
  }
  const haystack = text.length > 0 ? text : stripHtml(html)

  // (2) Numerisches DE-Format mit Wochentag-Prefix.
  // "Lieferung bis Dienstag, 17.02.2026" / "Lieferdatum: 18.03.2026".
  const numericDe = /(?:Lieferung\s+bis|Lieferdatum|Voraussichtliche?s?\s+(?:Lieferung|Liefertermin|Lieferdatum)|Geschätztes?\s+Lieferdatum|Voraussichtlicher?\s+Versand|Estimated\s+Delivery\s+Date)[\s:,]+(?:\w+,\s+)?(\d{1,2})\.(\d{1,2})\.(\d{4})/i.exec(haystack)
  if (numericDe) {
    return isoFromYmd(Number(numericDe[3]), Number(numericDe[2]), Number(numericDe[1]))
  }

  // (3) EN-Format: "March 15, 2026" / "Mar 15, 2026" / "March 15-17, 2026".
  const enFormat = /(?:Estimated\s+(?:Delivery|delivery)|Delivery\s+Date)[:\s]+(\w+)\s+(\d{1,2})(?:-\d{1,2})?,?\s+(\d{4})/i.exec(haystack)
  if (enFormat) {
    const m = monthIndex(enFormat[1])
    if (m !== null) return isoFromYmd(Number(enFormat[3]), m, Number(enFormat[2]))
  }

  // (4) DE-Wort-Format mit Tag.: "15. März 2026" / "Donnerstag, 18. März 2026".
  const deWord = /(\d{1,2})\.\s+(\w+)\s+(\d{4})/.exec(haystack)
  if (deWord) {
    const m = monthIndex(deWord[2])
    if (m !== null) return isoFromYmd(Number(deWord[3]), m, Number(deWord[1]))
  }

  // (4b) ES-Wort-Format: "Martes, 3 Marzo" → fallback ohne Jahr unten.
  const esWord = /(?:Entrega|entrega).{0,40}?(\d{1,2})\s+(\w+)/i.exec(haystack)
  if (esWord) {
    const m = monthIndex(esWord[2])
    if (m !== null) {
      const year = pickYearForMonth(m)
      return isoFromYmd(year, m, Number(esWord[1]))
    }
  }

  // (5) Wochentag + DE-Monat ohne Jahr: "Dienstag, 5 Mai", "Montag, 9 Februar".
  const dayMonth = /(?:Mon|Die|Mit|Don|Fre|Sam|Son|Mo|Di|Mi|Do|Fr|Sa|So)[a-zäöü]*,?\s+(\d{1,2})\.?\s+(\w+)/i.exec(haystack)
  if (dayMonth) {
    const m = monthIndex(dayMonth[2])
    if (m !== null) {
      const year = pickYearForMonth(m)
      return isoFromYmd(year, m, Number(dayMonth[1]))
    }
  }

  return undefined
}

/// Wähle das Jahr für ein gegebenes Monat: aktuelles Jahr, falls dieses
/// Monat noch dieses Jahr kommt; sonst nächstes Jahr (für Roll-Over wenn
/// die Mail erst ankommt nachdem das Datum-Year wechselte).
function pickYearForMonth(month: number): number {
  const now = new Date()
  const curMonth = now.getUTCMonth() + 1
  const curYear = now.getUTCFullYear()
  // Wenn Mail-Datum mehr als 4 Monate in Vergangenheit → nächstes Jahr.
  if (month + 4 < curMonth) return curYear + 1
  return curYear
}

/// Shipped-At aus Body extrahieren — Unix-Timestamp im URL hat Vorrang.
export function extractShippedAt(html: string, text: string): string | undefined {
  const decodedHtml = html.replace(/&amp;/g, '&')
  const tsMatch = /[?&]shipmentDate=(\d{10})\b/.exec(decodedHtml)
  if (tsMatch) {
    const ts = Number(tsMatch[1])
    if (Number.isFinite(ts)) {
      const d = new Date(ts * 1000)
      if (!Number.isNaN(d.getTime())) return d.toISOString()
    }
  }
  const haystack = text.length > 0 ? text : stripHtml(html)
  const m = /(?:versandt\s+am|verpackt\s+am|am\s+(\d{1,2}\.\d{1,2}\.\d{4})\s+verpackt|shipped\s+on)[:\s]*(\d{1,2}\.\d{1,2}\.\d{4})?/i
    .exec(haystack)
  if (m && (m[1] || m[2])) {
    const date = m[1] ?? m[2]
    const parts = /(\d{1,2})\.(\d{1,2})\.(\d{4})/.exec(date ?? '')
    if (parts) {
      const iso = isoFromYmd(Number(parts[3]), Number(parts[2]), Number(parts[1]))
      if (iso) return `${iso}T00:00:00.000Z`
    }
  }
  return undefined
}

/// Order-Total mit Currency aus Body — versucht mehrere Labels.
/// Akzeptiert Currency vor ODER nach dem Betrag, plus
/// CH-Format mit Apostroph-Tausender (1'248.95).
export function extractOrderTotal(text: string): OrderTotal | undefined {
  // Labels für die Total-Position. Das Label-Pattern wird gefolgt von
  // optionalen Prä-Currency-Symbolen + Betrag + optionalen Post-Currency.
  // Label-Block kann zwischen Hauptlabel und Suffix ein `:` enthalten
  // ("Gesamtsumme: inkl. MwSt 269 Euro") — deshalb erlauben wir `[\s:.]+`
  // zwischen Hauptlabel und optionalem `inkl. MwSt`-Anhängsel.
  const labelRe = /(Gesamtbetrag(?:[\s:.]+der\s+Bestellung)?|Gesamtsumme(?:[\s:.]+inkl\.\s+MwSt)?|Endbetrag(?:[\s:.]+inkl\.\s+MwSt)?|Order\s+Total|Importe\s+total|Total\s+amount|Razem|Celkem(?:\s+k\s+úhrad[ěe])?|Bestellbetrag(?:\s*\(inkl\.\s*MwSt\))?|Total)\s*[:.]?\s*((?:€|EUR|\$|USD|GBP|£|CHF|PLN|zł|Kč|CZK|Ft|HUF|Euro)\s*)?([\d.,'\s]+)\s*(€|EUR|\$|USD|GBP|£|CHF|PLN|zł|Kč|CZK|Ft|HUF|Euro|Euro\b)?/i
  const m = labelRe.exec(text)
  if (!m) return undefined
  const rawNum = (m[3] ?? '').replace(/['\s]/g, '')
  const amount = normalizeAmount(rawNum)
  if (amount === undefined) return undefined
  const currencyHint = (m[2] ?? m[4] ?? text.slice(m.index, m.index + 100))
    .trim()
  return { amount, currency: detectCurrency(currencyHint, text) }
}

function detectCurrency(near: string, full: string): string {
  if (/€|EUR|EURO/i.test(near)) return 'EUR'
  if (/\$|USD/i.test(near)) return 'USD'
  if (/£|GBP/i.test(near)) return 'GBP'
  if (/CHF/i.test(near)) return 'CHF'
  if (/PLN|ZŁ|ZL/i.test(near)) return 'PLN'
  if (/Kč|CZK/i.test(near)) return 'CZK'
  if (/Ft|HUF/i.test(near)) return 'HUF'
  // Fallback: scan full text.
  if (/CHF/i.test(full)) return 'CHF'
  if (/£|GBP/i.test(full)) return 'GBP'
  if (/\$|USD/i.test(full)) return 'USD'
  if (/zł|PLN/i.test(full)) return 'PLN'
  if (/Kč|CZK/i.test(full)) return 'CZK'
  return 'EUR'
}

function normalizeAmount(raw: string): number | undefined {
  // Handle DE/EU-Format (1.234,56) and EN-Format (1,234.56).
  // Heuristik: wenn beide Trenner vorhanden und letzter ist ',' → DE.
  // Wenn nur ',' → DE-Decimal. Wenn nur '.' und Position > 3 chars from
  // end → EN-Thousands (drop). Sonst EN-Decimal.
  const s = raw.replace(/\s/g, '')
  if (!/[\d.,]+/.test(s)) return undefined
  const lastComma = s.lastIndexOf(',')
  const lastDot = s.lastIndexOf('.')
  let cleaned: string
  if (lastComma > lastDot) {
    // DE: Komma als Dezimal, Punkt als Tausender.
    cleaned = s.replace(/\./g, '').replace(',', '.')
  } else if (lastDot > lastComma) {
    // EN: Punkt als Dezimal, Komma als Tausender.
    cleaned = s.replace(/,/g, '')
  } else {
    cleaned = s
  }
  const n = Number(cleaned)
  return Number.isFinite(n) ? n : undefined
}

/// Tax-Rate (% inkl. ohne %-Suffix) aus expliziten Labels.
export function extractTaxRatePct(text: string): number | undefined {
  // "MwSt (19%)", "IVA (21%)", "VAT (20%)", "TVA (19,6%)", "MwSt 19%",
  // "Sales Tax (8.875%)" (US-Kommunen mit 3 Decimal-Places).
  const m = /(?:MwSt|Mehrwertsteuer|VAT|IVA|TVA|Sales\s+Tax)\s*\(?(\d{1,2}(?:[.,]\d{1,4})?)\s*%\)?/i.exec(text)
  if (m && m[1]) {
    const n = normalizeAmount(m[1])
    if (n !== undefined && n > 0 && n < 50) return n
  }
  return undefined
}

/// Country-Code aus Lieferanschrift (DE/AT/CH/NL/...). Kein PII.
export function extractShippingCountry(text: string): string | undefined {
  const m = /(?:Lieferanschrift|Lieferadresse|Shipping\s+address|Dirección\s+de\s+envío)\s*:?[\s\S]{4,300}?\s+(DE|AT|CH|NL|ES|IT|FR|GB|UK|PL|CZ|SK|HU|BE|LU|DK|SE|FI|NO|US|CA)\b/i.exec(text)
  if (m) return m[1].toUpperCase().replace('UK', 'GB')
  return undefined
}

/// Lieferart-Detection. Heuristiken hierarchisch:
///   1. Explizite "Versandart"-Labels.
///   2. Spezial-Carrier (Schenker/Hellmann/Sperrgut → 'partner').
///   3. "Express"/"Premium"/"Priority" → 'express'.
///   4. "Click & Collect"/"Pickup"/"Selbstabholung"/"Paczkomat" → 'pickup'.
///   5. Fallback: 'standard' wenn irgendein Versand-Hinweis im Text.
export function extractDeliveryMethod(text: string): ParsedOrder['deliveryMethod'] {
  if (/Sperrgut|Schenker|Hellmann\s+Worldwide|Speditionsversand|Versand\s+durch:\s*Schenker/i.test(text)) {
    return 'partner'
  }
  if (/\b(Express|Priority|Premium\s+Versand|Same[- ]?Day|Prime\s+Express)\b/i.test(text)) {
    return 'express'
  }
  if (/(Click\s*&\s*Collect|Selbstabholung|Pickup|Pickup\s+Point|Paczkomat|Filialabholung)/i.test(text)) {
    return 'pickup'
  }
  if (/(Versand|Shipping|Standard\s+Versand|Post\s+Standard)/i.test(text)) {
    return 'standard'
  }
  return undefined
}

/// Storno-Grund aus expliziten Labels (DE/EN/ES). Stoppt am ersten
/// Sentence-Boundary (./!/?) oder am nächsten neuen-Satz-Anfang
/// ("Der …", "Wir …", "Eine …", EUR-Block) — sonst greift `[^.]{4,160}`
/// nach HTML-Strip oft die ganze Folge-Sentence mit ein.
export function extractCancellationReason(text: string): string | undefined {
  const m = /(?:Grund|Motivo|Reason|Razón)\s*:\s*([A-ZÄÖÜ][\wäöüÄÖÜß\- ]{2,80}?)(?=\s+(?:Der|Die|Das|Eine|Wir|Sie|Es|Ihre|Deine|Bei|EUR\b|USD\b|\$\d|GBP\b|CHF\b|Mit\s+freundlichen)|\s*[.!?,;]|\s*$|\s*\n)/i
    .exec(text)
  if (m && m[1]) return m[1].trim()
  return undefined
}

/// Multi-Item-Extraktion. Adapter-spezifische Layouts haben eigene
/// Parser, hier nur ein Generic-Fallback der nach 2+ Item-artigen
/// Blöcken sucht (Brand-Word + Preis).
export function extractGenericItems(text: string, fallbackCurrency = 'EUR'): ParsedOrderItem[] {
  const items: ParsedOrderItem[] = []
  // Sehr konservativ: matche Zeilen mit "<NAME mind. 2 Tokens> <Preis>".
  // Keine "ASIN-IDs" o.ä. mitnehmen.
  const re = /([A-Z][A-Za-z0-9 \-+./äöüÄÖÜß®™()]{6,80}(?:\s+[A-Z0-9][A-Za-z0-9 \-+./äöüÄÖÜß®™()]+){0,4})\s+(?:[\d.,]+\s*(?:€|EUR|\$|USD|GBP|£|CHF|PLN|zł)|EUR\s+[\d.,]+|\$[\d.,]+)/g
  let m: RegExpExecArray | null
  let count = 0
  while ((m = re.exec(text)) !== null && count < 10) {
    const name = m[1].trim()
    if (name.split(/\s+/).length < 2) continue
    if (/^(Versand|Total|Subtotal|Gesamt|Order|Mwst|VAT|IVA|Importe)/i.test(name)) continue
    items.push({ product: name, quantity: 1, currency: fallbackCurrency })
    count++
  }
  return items
}

/// Adapter-spezifischer MediaMarkt/Saturn-Item-Parser. Pattern:
///   `<qty>  <sku>  <name>  Lieferung bis …  <unit>  Euro  <sum>  Euro`.
export function extractMediaMarktItems(text: string): ParsedOrderItem[] {
  const items: ParsedOrderItem[] = []
  const re = /(\d{1,3})\s+(\d{6,9})\s+([A-Z][^\n]{4,140}?)\s+Lieferung\s+bis\s+\w+,\s*\d{1,2}\.\d{1,2}\.\d{4}\s+([\d.,]+)\s*Euro\s+([\d.,]+)\s*Euro/gi
  let m: RegExpExecArray | null
  while ((m = re.exec(text)) !== null) {
    const name = m[3].trim()
    if (/Aktion\s+myMediaMarkt|Rabatt/i.test(name)) continue
    const qty = Number(m[1])
    const unit = normalizeAmount(m[4])
    items.push({
      product: name,
      quantity: Number.isFinite(qty) ? qty : 1,
      unitPrice: unit,
      currency: 'EUR',
    })
  }
  return items
}

/// PCComponentes-Item-Parser. Pattern: `<NAME> Einheiten: <N> ...`.
/// Strategie: Wir splitten den Text bei `Einheiten:` (DE) und
/// `Unidades:` (ES) und nehmen pro Split den letzten "name + price"-
/// Block davor. Das umgeht das Header-Boilerplate ("Bestelldetails
/// Produkt Stk. Preis") robust ohne hard-coded Filter-Liste.
export function extractPcComponentesItems(text: string): ParsedOrderItem[] {
  const items: ParsedOrderItem[] = []
  const splitRe = /(Einheiten|Unidades)\s*:\s*(\d{1,3})(?:\s+([\d.,]+)\s*€)?/g
  let m: RegExpExecArray | null
  let lastIndex = 0
  while ((m = splitRe.exec(text)) !== null) {
    const before = text.slice(lastIndex, m.index)
    // Nimm das letzte Stück bevor Einheiten: das nicht zur Header-Boilerplate
    // gehört. Robustes Pattern: nimm bis zu 6 Tokens vor "Einheiten:".
    const nameMatch = /([A-Z][A-Za-z0-9 \-+./äöüÄÖÜßáéíóúñ®™()]{4,140}?)$/
      .exec(before.trim())
    lastIndex = m.index + m[0].length
    if (!nameMatch) continue
    let name = nameMatch[1].trim()
    // Header-Boilerplate ("Bestelldetails Produkt Stk. Preis") wegtrimmen.
    name = name.replace(/^(?:.*?Bestelldetails(?:\s+Produkt\s+Stk\.?\s+Preis)?\s+)/i, '')
      .replace(/^(?:.*?Detalles\s+del\s+pedido\s+)/i, '')
      .trim()
    if (name.length < 4) continue
    if (/^(Bestelldetails|Produkt|Stk|Preis|Subtotal|Total|MwSt|IVA|Detalles)/i.test(name)) continue
    const qty = Number(m[2])
    items.push({
      product: name,
      quantity: Number.isFinite(qty) ? qty : 1,
      unitPrice: m[3] ? normalizeAmount(m[3]) : undefined,
      currency: 'EUR',
    })
  }
  return items
}

/// Verkäufer (`seller`) aus expliziten Labels. Stoppt an Komma/Newline
/// oder am nächsten Section-Keyword (Lieferung, Total, ...). Punkte
/// innerhalb des Namens (S.a.r.L., S.A., GmbH.) werden NICHT als
/// Boundary genutzt — sonst würde "Amazon EU S.a.r.L." auf "Amazon EU S"
/// abgeschnitten.
export function extractSeller(text: string): string | undefined {
  const m = /(?:Verkauft\s+von|Sold\s+by|Vendido\s+por|Verkäufer)\s*[:\s]+([A-Za-z][\w.&\- ]{1,60}?)(?:\s+(?:Lieferung|Item\s+Number|Order\s+ID|Bestellnummer|EUR\s|USD\s|\$\s|MwSt|VAT|IVA|Quantity|Menge|Einheiten|Unidades|Total|Subtotal|Versand|Shipping|Address|Zwischensumme|Carrier|Estimated|Voraussichtlich)\b|\s*[,;\n]|\s*$)/i
    .exec(text)
  if (m && m[1]) {
    const cleaned = m[1].trim().replace(/\s+/g, ' ')
    // Header "Verkäufer Bestellnummer" überspringen.
    if (/Bestellnummer/i.test(cleaned)) return undefined
    return cleaned
  }
  return undefined
}

// ── Amazon (DE/COM/UK/FR/IT/ES) ────────────────────────────────────────
// Business-Subdomain wird zugelassen für Order-/Versand-Mailflows
// (`shipment-tracking@business.amazon.de`, `auto-confirm@business.amazon.de`).
// Werbe-Newsletter `no-reply@business.amazon.de` ("Amazon Business
// Analytics") werden via Subject-Promo-Filter (isOrderishSubject)
// abgefangen — nicht via from-Domain-Block.
const amazon: Adapter = {
  key: 'amazon',
  label: 'Amazon',
  matches: (ctx) =>
    /(@|\.)amazon\.(de|com|co\.uk|fr|it|es)\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => {
    const s = haystack(ctx)
    const orderId = findFirst(s, [
      /\b(\d{3}-\d{7}-\d{7})\b/,
      /Bestellung\s*#?\s*([0-9-]{10,25})/i,
      /Order\s*#?\s*([0-9-]{10,25})/i,
    ])
    // Spezifische Produkt-Pattern zuerst — die früheren generischen
    // "bestellt:"-Matches schnappten oft den AGB-Disclaimer
    // ("Waren, die aus Gründen…"). sanitizeProduct() filtert solche
    // Boilerplates raus.
    const product = sanitizeProduct(
      findFirst(s, [
        /item\(s\):\s*([^\n]{4,140})/i,
        /Artículos?\s*[:\s]+([^\n]{4,140})/i,
        /Artikel\s*[:\s]+([^\n]{4,140})/i,
        /Producto\s*[:\s]+([^\n]{4,140})/i,
        /Produkt\s*[:\s]+([^\n]{4,140})/i,
      ]),
    ) ?? productFromSubject(ctx.subject)
    const qty = Number(/(?:Menge|Anzahl|Quantity|Cantidad)\s*[:\s]+(\d{1,3})/i.exec(s)?.[1] ?? '1')
    const totalSrc = /(?:Gesamtsumme|Order Total|Zwischensumme|Total|Importe)[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { status, tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = resolveStatusAndTracking(ctx)
    const etaDate = extractEtaDate(ctx.html, s)
    const shippedAt = extractShippedAt(ctx.html, s)
    const orderTotal = extractOrderTotal(s)
    const taxRatePct = extractTaxRatePct(s)
    const seller = extractSeller(s)
    const deliveryMethod = /Amazon\s+Logistics/i.test(s)
      ? 'partner' as const
      : extractDeliveryMethod(s)
    const cancellationReason = status === 'cancelled'
      ? extractCancellationReason(s) : undefined
    if (!orderId && !product && !tracking) return null
    return {
      shopKey: 'amazon', shopLabel: 'Amazon',
      orderId, product, quantity: Math.max(1, qty),
      total, currency, tracking, trackings, carrier, status,
      trackingConfidence, trackingCandidates, trackingNeedsReview,
      etaDate, shippedAt, orderTotal, taxRatePct, seller,
      deliveryMethod, cancellationReason,
    }
  },
}

// ── MediaMarkt ─────────────────────────────────────────────────────────
const mediamarkt: Adapter = {
  key: 'mediamarkt',
  label: 'MediaMarkt',
  matches: (ctx) => /(@|\.)mediamarkt\.(de|at|ch|nl|es|hu|pl)\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => {
    const s = haystack(ctx)
    const orderId = findFirst(s, [
      /Bestellung\s*\(?\s*(\d{6,15})\s*\)?/i,
      /Bestell(?:nummer|ung)\s*[:#]?\s*(\d{6,15})/i,
      /Auftrags?nummer\s*[:#]?\s*(\d{6,15})/i,
    ])
    const product = sanitizeProduct(findFirst(s, [
      /Artikel\s*[:=]\s*([^\n]{4,140})/i,
      /Produkt\s*[:=]\s*([^\n]{4,140})/i,
    ])) ?? productFromArticleTable(s) ?? productFromSubject(ctx.subject)
    const totalSrc = /(?:Gesamtsumme|Summe|Total|Rechnungsbetrag|Gesamtbetrag)[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { status, tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = resolveStatusAndTracking(ctx)
    if (!orderId && !tracking) return null
    const etaDate = extractEtaDate(ctx.html, s)
    const orderTotal = extractOrderTotal(s)
    const items = extractMediaMarktItems(s)
    const shippingAddressCountry = extractShippingCountry(s)
    const deliveryMethod = extractDeliveryMethod(s)
    return {
      shopKey: 'mediamarkt', shopLabel: 'MediaMarkt',
      orderId, product, quantity: 1,
      total, currency, tracking, trackings, carrier, status,
      trackingConfidence, trackingCandidates, trackingNeedsReview,
      etaDate, orderTotal, items: items.length > 0 ? items : undefined,
      shippingAddressCountry, deliveryMethod,
    }
  },
}

// ── Saturn ─────────────────────────────────────────────────────────────
const saturn: Adapter = {
  key: 'saturn',
  label: 'Saturn',
  matches: (ctx) => /(@|\.)saturn\.(de|at|ch|nl|es|hu|pl)\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => {
    const s = haystack(ctx)
    const orderId = findFirst(s, [
      /Bestellung\s*\(?\s*(\d{6,15})\s*\)?/i,
      /Bestell(?:nummer|ung)\s*[:#]?\s*(\d{6,15})/i,
      /Auftrags?nummer\s*[:#]?\s*(\d{6,15})/i,
    ])
    const product = sanitizeProduct(
      findFirst(s, [/Artikel\s*[:=]\s*([^\n]{4,140})/i]),
    ) ?? productFromArticleTable(s) ?? productFromSubject(ctx.subject)
    const totalSrc = /(?:Gesamtsumme|Summe|Total|Rechnungsbetrag|Gesamtbetrag)[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { status, tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = resolveStatusAndTracking(ctx)
    if (!orderId && !tracking) return null
    const etaDate = extractEtaDate(ctx.html, s)
    const orderTotal = extractOrderTotal(s)
    const items = extractMediaMarktItems(s)
    const shippingAddressCountry = extractShippingCountry(s)
    const deliveryMethod = extractDeliveryMethod(s)
    return {
      shopKey: 'saturn', shopLabel: 'Saturn',
      orderId, product, quantity: 1,
      total, currency, tracking, trackings, carrier, status,
      trackingConfidence, trackingCandidates, trackingNeedsReview,
      etaDate, orderTotal, items: items.length > 0 ? items : undefined,
      shippingAddressCountry, deliveryMethod,
    }
  },
}

/// PCComponentes-spezifisches Produkt-Layout (HTML-Tabelle linearisiert):
///   "Bestelldetails Produkt Stk. Preis [PRODUKTNAME] Einheiten: N Verkauft von …"
/// Der Preis steht WEITER hinten (nach Lieferdatum-Block), deshalb
/// ankern wir nicht auf "€", sondern auf "Einheiten:" als nächstes
/// strukturelles Label nach dem Produktnamen.
const productFromPcComponentesLine = (s: string): string | undefined => {
  const patterns: RegExp[] = [
    // Layout A (ältere Mails): vollständiger Tabellen-Header.
    //   "Bestelldetails Produkt Stk. Preis Samsung 870 EVO … Einheiten: 4"
    /Bestelldetails\s+Produkt\s+Stk\.?\s+Preis\s+([A-Z][A-Za-z0-9 \-+.,/&®™²³()]{4,200}?)\s+Einheiten\s*:/i,
    // Layout B (neuere Mails): "Bestelldetails" direkt gefolgt vom Produkt,
    // kein "Produkt Stk. Preis"-Header dazwischen.
    //   "Bestelldetails Samsung 990 PRO M.2 … Einheiten: 2"
    /Bestelldetails\s+(?!Produkt\s+Stk)([A-Z][A-Za-z0-9 \-+.,/&®™²³()]{4,200}?)\s+Einheiten\s*:/i,
    // Fallback: nur "Preis"-Header als Anker.
    /\bPreis\s+([A-Z][A-Za-z0-9 \-+.,/&®™²³()]{4,200}?)\s+Einheiten\s*:/i,
  ]
  // Kein "alles vor Einheiten:"-Catch-all — der schluckt Service-Boilerplate
  // ("Sie erhalten eine Sendungsverfolgungs-E-Mail …") als angebliches
  // Produkt. PRODUCT_BLACKLIST in sanitizeProduct fängt Reste ab.
  for (const re of patterns) {
    const m = re.exec(s)
    if (m && m[1]) {
      const cleaned = m[1].replace(/\s+/g, ' ').trim()
      const checked = sanitizeProduct(cleaned)
      if (checked) return checked
    }
  }
  return undefined
}

// ── PcComponentes ──────────────────────────────────────────────────────
const pccomponentes: Adapter = {
  key: 'pccomponentes',
  label: 'PcComponentes',
  matches: (ctx) => /(@|\.)pccomponentes\.(com|es|fr|it|pt|de)\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => {
    const s = haystack(ctx)
    const orderId = findFirst(s, [
      // Deutsche Bestellbestätigung: "Bestellnummer: 6012026313871"
      /Bestellnummer\s*[:#=]\s*(\d{8,18})/i,
      /(?:n[uú]mero de )?pedido\s*[:#]?\s*([A-Z0-9-]{6,25})/i,
      /Order\s*number\s*[:#]?\s*([A-Z0-9-]{6,25})/i,
      /\b(PC[A-Z0-9-]{6,20})\b/,
      // Subject-Form: "wurde bestätigt." mit Order-ID irgendwo im Body —
      // 13-stellige Zahl nach Komma/Whitespace.
      /\b(\d{13})\b/,
    ])
    // Pattern-Hierarchie:
    //   1. Explizite Labels (Producto:, Artículo:)
    //   2. PCComponentes-Layout: Produkt + Preis + Einheiten
    //   3. Subject-Fallback
    const product = sanitizeProduct(findFirst(s, [
      /Producto\s*[:=]\s*([^\n]{4,140})/i,
      /Artículo\s*[:=]\s*([^\n]{4,140})/i,
      /Item\s*[:=]\s*([^\n]{4,140})/i,
    ])) ?? productFromPcComponentesLine(s) ?? productFromSubject(ctx.subject)
    const qty = Number(/Einheiten\s*[:=]\s*(\d{1,3})/i.exec(s)?.[1] ?? '1')
    const totalSrc = /(?:Gesamtbetrag|Gesamtsumme|Zwischensumme|Total|Importe)[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { status, tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = resolveStatusAndTracking(ctx)
    if (!orderId && !tracking) return null
    const etaDate = extractEtaDate(ctx.html, s)
    const orderTotal = extractOrderTotal(s)
    const items = extractPcComponentesItems(s)
    const taxRatePct = extractTaxRatePct(s)
    const seller = extractSeller(s)
    return {
      shopKey: 'pccomponentes', shopLabel: 'PcComponentes',
      orderId, product, quantity: Math.max(1, qty),
      total, currency: currency === 'EUR' ? 'EUR' : currency,
      tracking, trackings, carrier, status,
      trackingConfidence, trackingCandidates, trackingNeedsReview,
      etaDate, orderTotal, taxRatePct, seller,
      items: items.length > 0 ? items : undefined,
    }
  },
}

// ── X-Kom (Polen) ──────────────────────────────────────────────────────
const xkom: Adapter = {
  key: 'xkom',
  label: 'x-kom',
  matches: (ctx) => /(@|\.)x-kom\.(pl|de)\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => {
    const s = haystack(ctx)
    const orderId = findFirst(s, [
      /Zam[oó]wieni[ae]\s*(?:nr\.?|number)?\s*[:#]?\s*([A-Z0-9/-]{5,25})/i,
      /Order\s*(?:number|nr\.?)?\s*[:#]?\s*([A-Z0-9/-]{5,25})/i,
      /\b(\d{4}\/\d{2,6})\b/,
    ])
    const product = sanitizeProduct(findFirst(s, [
      /Produkt\s*[:\s]+([^\n]{4,140})/i,
      /Towar\s*[:\s]+([^\n]{4,140})/i,
      /Artikel\s*[:\s]+([^\n]{4,140})/i,
    ])) ?? productFromSubject(ctx.subject)
    const totalSrc = /(?:Suma|Razem|Wartość|Total)[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { status, tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = resolveStatusAndTracking(ctx)
    if (!orderId && !tracking) return null
    const etaDate = extractEtaDate(ctx.html, s)
    const orderTotal = extractOrderTotal(s)
    const deliveryMethod = /Paczkomat/i.test(s) ? 'pickup' as const
      : extractDeliveryMethod(s)
    return {
      shopKey: 'xkom', shopLabel: 'x-kom',
      orderId, product, quantity: 1,
      total, currency: currency === 'EUR' ? 'PLN' : currency, // x-kom default PLN
      tracking, trackings, carrier, status,
      trackingConfidence, trackingCandidates, trackingNeedsReview,
      etaDate, orderTotal, deliveryMethod,
    }
  },
}

// ── LEGO (Hauptshop + CRM-Notifications) ───────────────────────────────
// LEGO splittet seine Order-Mails über drei Sender:
//   - `order-acknowledged@m.lego.com`     → Bestelleingang
//   - `DoNotReply@lego.com`               → Bestellinfo (PDF-Mail)
//   - `Noreply@t.crm.lego.com`            → Bestätigung + Versand-Updates
// Order-IDs haben das Format `T<8-12 Ziffern>(-E\d)?` und stehen
// regelmäßig direkt im Subject. Wir parsen primär aus dem Subject und
// nur als Fallback aus dem Body, weil LEGO-Mails sehr Marketing-lastig
// sind (viele Promo-Phrasen, die `productFromSubject` durcheinander
// bringen würden).
const lego: Adapter = {
  key: 'lego',
  label: 'LEGO',
  matches: (ctx) => /(@|\.)(?:[a-z0-9.-]+\.)?lego\.com\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => {
    const s = haystack(ctx)
    const orderId = findFirst(s, [
      // Subject-Form: "#T492568051-E9", "Bestellung T491469977", "T492…"
      /\b(T\d{8,12}(?:-E\d)?)\b/,
      /Bestellnummer\s*[:#]?\s*([A-Z0-9-]{6,25})/i,
      /Order\s*number\s*[:#]?\s*([A-Z0-9-]{6,25})/i,
    ])
    const product = sanitizeProduct(findFirst(s, [
      /Artikel\s*[:=]\s*([^\n]{4,140})/i,
      /Produkt\s*[:=]\s*([^\n]{4,140})/i,
      /Item\s*[:=]\s*([^\n]{4,140})/i,
    ])) ?? productFromSubject(ctx.subject)
    const totalSrc = /(?:Gesamtsumme|Summe|Total|Gesamtbetrag|Order Total)[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { status, tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = resolveStatusAndTracking(ctx)
    if (!orderId && !tracking) return null
    const etaDate = extractEtaDate(ctx.html, s)
    const orderTotal = extractOrderTotal(s)
    const taxRatePct = extractTaxRatePct(s)
    const items = extractGenericItems(s, currency)
    const deliveryMethod = extractDeliveryMethod(s)
    return {
      shopKey: 'lego', shopLabel: 'LEGO',
      orderId, product, quantity: 1,
      total, currency, tracking, trackings, carrier, status,
      trackingConfidence, trackingCandidates, trackingNeedsReview,
      etaDate, orderTotal, taxRatePct, deliveryMethod,
      items: items.length > 0 ? items : undefined,
    }
  },
}

// ── Tink (Smart Home Reseller) ─────────────────────────────────────────
// Tink schickt klassische Lifecycle-Mails:
//   - "Deine Bestellung ist eingegangen"
//   - "Deine Bestellung wurde verpackt"
//   - "Die Lieferung ist auf dem Weg." / "wird noch heute zugestellt"
//   - "Die Lieferung wurde der Empfängerin … zugestellt"
// Order-IDs haben Format `\d{6,10}` und stehen typischerweise nur im
// Body, nicht im Subject. Carrier ist meist DHL/Hermes — Tracking-Nrn
// kommen aus dem Body via `resolveStatusAndTracking` → `detect()`.
const tink: Adapter = {
  key: 'tink',
  label: 'tink',
  matches: (ctx) => /(@|\.)tink\.de\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => {
    const s = ctx.subject.toLowerCase()
    if (isOrderishSubject(ctx.subject)) return true
    // Tinks Versand-Subjects nutzen "Lieferung" + Verb-Phrase, die unser
    // Standard-Whitelist abdeckt. Zusätzlich: "Deine Bestellung wurde
    // verpackt" → wird ebenfalls abgedeckt.
    return /\b(lieferung|bestellung|paket|versand|zustell)/i.test(s)
  },
  parse: (ctx) => {
    const s = haystack(ctx)
    const orderId = findFirst(s, [
      /Bestellnummer\s*[:#=]?\s*(\d{5,12})/i,
      /Auftrags?nummer\s*[:#=]?\s*(\d{5,12})/i,
      /Order(?:\s*number)?\s*[:#=]?\s*([A-Z0-9-]{5,15})/i,
    ])
    const product = sanitizeProduct(findFirst(s, [
      /Artikel\s*[:=]\s*([^\n]{4,140})/i,
      /Produkt\s*[:=]\s*([^\n]{4,140})/i,
    ])) ?? productFromSubject(ctx.subject)
    const totalSrc = /(?:Gesamtsumme|Summe|Total|Gesamtbetrag)[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { status, tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = resolveStatusAndTracking(ctx)
    if (!orderId && !tracking) return null
    const etaDate = extractEtaDate(ctx.html, s)
    const shippedAt = extractShippedAt(ctx.html, s)
    const orderTotal = extractOrderTotal(s)
    const taxRatePct = extractTaxRatePct(s)
    return {
      shopKey: 'tink', shopLabel: 'tink',
      orderId, product, quantity: 1,
      total, currency, tracking, trackings, carrier, status,
      trackingConfidence, trackingCandidates, trackingNeedsReview,
      etaDate, shippedAt, orderTotal, taxRatePct,
    }
  },
}

// ── Anker (Direkt-Shop) ────────────────────────────────────────────────
// Anker-Order-IDs: `R\d{12,15}S?` (z.B. `R030101520991S`). Stehen
// fast immer direkt im Subject. Sender:
//   - `noreply-service@anker.com`  → Bestätigung
//   - `support@anker.com`          → Versand + Zustellung
const anker: Adapter = {
  key: 'anker',
  label: 'Anker',
  matches: (ctx) => /(@|\.)anker\.com\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => {
    const s = haystack(ctx)
    const orderId = findFirst(s, [
      // Anker R-Format: 12-15 Ziffern + optionales S-Suffix.
      /\b(R\d{12,15}S?)\b/,
      /Bestellung\s+([A-Z0-9-]{8,20})/i,
      /Bestellnummer\s*[:#=]?\s*([A-Z0-9-]{6,20})/i,
      /Order\s*(?:number|#)?\s*[:#=]?\s*([A-Z0-9-]{6,20})/i,
    ])
    const product = sanitizeProduct(findFirst(s, [
      /Artikel\s*[:=]\s*([^\n]{4,140})/i,
      /Produkt\s*[:=]\s*([^\n]{4,140})/i,
      /Item\s*[:=]\s*([^\n]{4,140})/i,
    ])) ?? productFromSubject(ctx.subject)
    const totalSrc = /(?:Gesamtsumme|Summe|Total|Gesamtbetrag|Order Total)[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { status, tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = resolveStatusAndTracking(ctx)
    if (!orderId && !tracking) return null
    const etaDate = extractEtaDate(ctx.html, s)
    const orderTotal = extractOrderTotal(s)
    const taxRatePct = extractTaxRatePct(s)
    const deliveryMethod = extractDeliveryMethod(s)
    return {
      shopKey: 'anker', shopLabel: 'Anker',
      orderId, product, quantity: 1,
      total, currency, tracking, trackings, carrier, status,
      trackingConfidence, trackingCandidates, trackingNeedsReview,
      etaDate, orderTotal, taxRatePct, deliveryMethod,
    }
  },
}

// ── Euronics (Hauptshop + Filial-Subdomains) ───────────────────────────
// Euronics betreibt sowohl die Plattform-Domain `euronics.de` als auch
// individuelle Händler-Subdomains nach Schema `euronics-<filiale>.de`
// (z.B. `online@euronics-buecker.de`). Beide werden vom selben Adapter
// abgedeckt. Order-IDs sind kurze Numbers (6-8 Ziffern), die direkt
// im Subject stehen ("Ihre Bestellung 4250432 ist eingegangen").
const euronics: Adapter = {
  key: 'euronics',
  label: 'Euronics',
  matches: (ctx) => /(@|\.)(?:[a-z0-9-]+\.)?euronics(?:-[a-z0-9-]+)?\.de\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => {
    const s = haystack(ctx)
    const orderId = findFirst(s, [
      // Subject-Form: "Ihre Bestellung 4250432 ist eingegangen"
      /Bestellung\s+(\d{6,12})\b/i,
      /Bestellnummer\s*[:#=]?\s*([A-Z0-9-]{4,15})/i,
      /Auftrags?nummer\s*[:#=]?\s*([A-Z0-9-]{4,15})/i,
      /Order\s*number\s*[:#=]?\s*([A-Z0-9-]{4,15})/i,
    ])
    const product = sanitizeProduct(findFirst(s, [
      /Artikel\s*[:=]\s*([^\n]{4,140})/i,
      /Produkt\s*[:=]\s*([^\n]{4,140})/i,
      /Bezeichnung\s*[:=]\s*([^\n]{4,140})/i,
    ])) ?? productFromArticleTable(s) ?? productFromSubject(ctx.subject)
    const totalSrc = /(?:Gesamtsumme|Summe|Total|Rechnungsbetrag|Gesamtbetrag|Endbetrag)[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { status, tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = resolveStatusAndTracking(ctx)
    if (!orderId && !tracking) return null
    const etaDate = extractEtaDate(ctx.html, s)
    const orderTotal = extractOrderTotal(s)
    const taxRatePct = extractTaxRatePct(s)
    // Filiale aus Sender-Domain ableiten (euronics-buecker.de → "Euronics Bücker").
    const subdomainMatch = /euronics-([a-z0-9-]+)\.de/i.exec(ctx.from)
    const seller = subdomainMatch
      ? `Euronics ${subdomainMatch[1].charAt(0).toUpperCase()}${subdomainMatch[1].slice(1)}`
      : 'Euronics'
    return {
      shopKey: 'euronics', shopLabel: 'Euronics',
      orderId, product, quantity: 1,
      total, currency, tracking, trackings, carrier, status,
      trackingConfidence, trackingCandidates, trackingNeedsReview,
      etaDate, orderTotal, taxRatePct, seller,
    }
  },
}

// ── Kaufland (Marketplace + Onlineshop) ────────────────────────────────
// Marketplace-Mails kommen oft von `<random>@kaufland-marktplatz.de` oder
// `noreply@kaufland-marktplatz.de`, der Hauptshop von `kaufland.de`.
// Order-IDs sind 6-12 alphanumerische Zeichen (z.B. MK3UZQ5) und stehen
// regelmäßig direkt im Subject hinter "Bestellung ".
const kaufland: Adapter = {
  key: 'kaufland',
  label: 'Kaufland',
  matches: (ctx) => /(@|\.)kaufland(?:-marktplatz)?\.(de|com)\b/i.test(ctx.from),
  // Versand-Mails von Kaufland-Marktplatz haben zusätzlich gerne kurze
  // Subjects wie "Versandbestätigung" oder "Bestellung X: Ihr Paket ist
  // im Transit" — beides matcht isOrderishSubject (versand/bestell).
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => {
    const s = haystack(ctx)
    const orderId = findFirst(s, [
      // Subject-Form: "Bestellung MK3UZQ5: …" — Großbuchstaben Pflicht.
      /Bestellung\s+([A-Z0-9]{5,12})(?=[\s:.,]|$)/,
      // Body-Form mit Trenner: "Bestellnummer: MK3UZQ5"
      /Bestellnummer\s*[:#=]\s*([A-Z0-9-]{5,25})/i,
      /Auftrags?nummer\s*[:#=]\s*([A-Z0-9-]{5,25})/i,
      /Order\s*number\s*[:#=]\s*([A-Z0-9-]{5,25})/i,
      // Body-Form ohne Trenner: HTML-Tabellen werden im Plaintext linearisiert
      // ("Verkäufer Bestellnummer WGServices MK3UZQ5"). Wir springen bis zu
      // 80 Chars vor und nehmen das erste Token mit Großbuchstabe + Ziffer —
      // das überspringt Header-Werte ohne Ziffer wie "WGServices".
      /Bestellnummer[\s\S]{0,80}?\b([A-Z][A-Z0-9-]*\d[A-Z0-9-]*)\b/,
      /Auftrags?nummer[\s\S]{0,80}?\b([A-Z][A-Z0-9-]*\d[A-Z0-9-]*)\b/,
    ])
    const product = sanitizeProduct(findFirst(s, [
      /Artikel\s*[:=]\s*([^\n]{4,140})/i,
      /Produkt\s*[:=]\s*([^\n]{4,140})/i,
      /Bezeichnung\s*[:=]\s*([^\n]{4,140})/i,
    ])) ?? productFromArticleTable(s) ?? productFromSubject(ctx.subject)
    const totalSrc = /(?:Gesamtsumme|Summe|Total|Rechnungsbetrag|Endbetrag|Gesamtbetrag)[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { status, tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = resolveStatusAndTracking(ctx)
    // Kaufland-Marketplace listet jeden Artikel als eigenen Versandblock
    // mit "Sendungsnummer: <Nr.>". Wir zählen ausschließlich diese
    // Label-Form (nicht URL-Param "?sendungsnummer=…", nicht reine
    // "Sendungsnummer"-Headline) und nur in einer Body-Quelle, sonst
    // verdoppelt sich bei multipart/alternative.
    const countSource = ctx.text.length > 0 ? ctx.text : stripHtml(ctx.html)
    const sendungsBlocks =
      (countSource.match(/Sendungsnummer\s*:\s*\d{6,}/gi) ?? []).length
    const quantity = Math.max(1, sendungsBlocks)
    if (!orderId && !tracking) return null
    const etaDate = extractEtaDate(ctx.html, s)
    const orderTotal = extractOrderTotal(s)
    const taxRatePct = extractTaxRatePct(s)
    // Erster Verkäufer im "Verkäufer Bestellnummer …"-Block. Name darf
    // keine Whitespace enthalten — sonst würden Multi-Verkäufer-Listen
    // ("WGServices MK4ABCD TechHandel Berlin") komplett gegriffen.
    const sellerMatch = /Verkäufer\s+Bestellnummer\s+(\w[\w\-]{1,40})\s+([A-Z0-9]{5,15})/i.exec(s)
    const seller = sellerMatch ? sellerMatch[1].trim() : undefined
    const deliveryMethod = extractDeliveryMethod(s)
    return {
      shopKey: 'kaufland', shopLabel: 'Kaufland',
      orderId, product, quantity,
      total, currency, tracking, trackings, carrier, status,
      trackingConfidence, trackingCandidates, trackingNeedsReview,
      etaDate, orderTotal, taxRatePct, seller, deliveryMethod,
    }
  },
}

// ── Dell (Direct-Shop) ─────────────────────────────────────────────────
// Dell-Order-IDs: 8-10 numerische Codes; Mails kommen von
// `*@dell.com` und `*@order.dell.com`. EN/DE-Hybrid.
const dell: Adapter = {
  key: 'dell',
  label: 'Dell',
  matches: (ctx) => /(@|\.)(?:[a-z0-9.-]+\.)?dell\.com\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => {
    const s = haystack(ctx)
    const orderId = findFirst(s, [
      /(?:Order\s+(?:Number|#)|Bestellnummer)\s*[:#]?\s*(\d{8,10})/i,
      /\b(\d{9})\b/,
    ])
    const product = sanitizeProduct(findFirst(s, [
      /(?:Item|Artikel|Produkt|Description)\s*[:=]\s*([^\n]{4,140})/i,
    ])) ?? productFromSubject(ctx.subject)
    const totalSrc = /(?:Order\s+Total|Bestellsumme|Gesamt)\s*[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { status, tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = resolveStatusAndTracking(ctx)
    if (!orderId && !tracking) return null
    const etaDate = extractEtaDate(ctx.html, s)
    const orderTotal = extractOrderTotal(s)
    const taxRatePct = extractTaxRatePct(s)
    const items = extractGenericItems(s, currency)
    return {
      shopKey: 'dell', shopLabel: 'Dell',
      orderId, product, quantity: 1,
      total, currency, tracking, trackings, carrier, status,
      trackingConfidence, trackingCandidates, trackingNeedsReview,
      etaDate, orderTotal, taxRatePct,
      items: items.length > 0 ? items : undefined,
    }
  },
}

// ── eBay (Marketplace) ─────────────────────────────────────────────────
// eBay-Mails sind seller-zentrisch. Order-ID-Format mit Bindestrichen
// (17-12345-67890) oder reine Item-Nrn (12-stellig).
const ebay: Adapter = {
  key: 'ebay',
  label: 'eBay',
  matches: (ctx) =>
    /(@|\.)(?:[a-z0-9.-]+\.)?ebay\.(com|de|co\.uk|fr|it|es|nl|at|ch)\b/i
      .test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => {
    const s = haystack(ctx)
    const orderId = findFirst(s, [
      /Order\s+ID\s*:\s*(\d{2}-\d{5}-\d{5})/i,
      /(?:Item\s+(?:Number|#)|Bestellnummer)\s*[:#]?\s*(\d{8,15})/i,
      /\b(\d{2}-\d{5}-\d{5})\b/,
    ])
    const product = sanitizeProduct(findFirst(s, [
      /(?:Item|Artikel|Produkt)\s*[:=]\s*([^\n]{4,140})/i,
    ])) ?? productFromSubject(ctx.subject)
    const seller = extractSeller(s)
    const totalSrc = /(?:Total|Gesamt|Importe)\s*[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { status, tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = resolveStatusAndTracking(ctx)
    if (!orderId && !tracking) return null
    const etaDate = extractEtaDate(ctx.html, s)
    const orderTotal = extractOrderTotal(s)
    return {
      shopKey: 'ebay', shopLabel: 'eBay',
      orderId, product, quantity: 1,
      total, currency, tracking, trackings, carrier, status,
      trackingConfidence, trackingCandidates, trackingNeedsReview,
      etaDate, orderTotal, seller,
    }
  },
}

// ── Galaxus (CH/DE) ────────────────────────────────────────────────────
// Sender: `*@notifications.galaxus.de`. Order-ID: 8-12 numerisch.
// CH-Format mit Apostroph als Tausender-Trenner; CHF-Default für CH.
const galaxus: Adapter = {
  key: 'galaxus',
  label: 'Galaxus',
  matches: (ctx) =>
    /(@|\.)(?:[a-z0-9.-]+\.)?galaxus\.(de|ch|com|at)\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => {
    const s = haystack(ctx)
    const orderId = findFirst(s, [
      /(?:Bestellung|Order|Bestellbest[äa]tigung)\s+(?:Nr\.?|#)?\s*(\d{8,12})/i,
      /Bestellnummer\s*[:#=]?\s*(\d{6,15})/i,
    ])
    const product = sanitizeProduct(findFirst(s, [
      /(?:Artikel|Produkt|Bezeichnung)\s*[:=]\s*([^\n]{4,140})/i,
    ])) ?? productFromSubject(ctx.subject)
    const totalSrc = /(?:Endbetrag(?:\s+inkl\.\s+MwSt)?|Gesamt|Total)\s*[:\s]+([^\n]{1,40})/i
      .exec(s)?.[1] ?? ''
    const { total, currency: parsedCurrency } = parseMoney(totalSrc)
    // CHF default für galaxus.ch.
    const isCh = /galaxus\.ch/i.test(ctx.from) || /CHF/i.test(s)
    const currency = parsedCurrency === 'EUR' && isCh ? 'CHF' : parsedCurrency
    const { status, tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = resolveStatusAndTracking(ctx)
    if (!orderId && !tracking) return null
    const etaDate = extractEtaDate(ctx.html, s)
    const orderTotal = extractOrderTotal(s)
    const taxRatePct = extractTaxRatePct(s)
    const items = extractGenericItems(s, currency)
    const deliveryMethod = extractDeliveryMethod(s)
    return {
      shopKey: 'galaxus', shopLabel: 'Galaxus',
      orderId, product, quantity: 1,
      total, currency, tracking, trackings, carrier, status,
      trackingConfidence, trackingCandidates, trackingNeedsReview,
      etaDate, orderTotal, taxRatePct, deliveryMethod,
      items: items.length > 0 ? items : undefined,
    }
  },
}

// ── Alza (CZ/SK/DE/AT/HU/UK) ───────────────────────────────────────────
const alza: Adapter = {
  key: 'alza',
  label: 'Alza',
  matches: (ctx) =>
    /(@|\.)(?:[a-z0-9.-]+\.)?alza\.(de|cz|sk|at|hu|co\.uk|com)\b/i
      .test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => {
    const s = haystack(ctx)
    const orderId = findFirst(s, [
      /(?:Order\s+(?:Number|#)|Bestellnummer)\s*[:#]?\s*(\d{10,14})/i,
      /\b(\d{12})\b/,
    ])
    const product = sanitizeProduct(findFirst(s, [
      /(?:Description|Artikel|Produkt|Bezeichnung)\s*[:=]\s*([^\n]{4,140})/i,
    ])) ?? productFromSubject(ctx.subject)
    const totalSrc = /(?:Order\s+total|Celkem|Gesamtsumme|Total)\s*[:\s]+([^\n]{1,40})/i
      .exec(s)?.[1] ?? ''
    const { total, currency: parsedCurrency } = parseMoney(totalSrc)
    // Currency aus Sender-Domain.
    const currency = /alza\.cz/i.test(ctx.from) ? 'CZK'
      : /alza\.co\.uk/i.test(ctx.from) ? 'GBP'
      : /alza\.hu/i.test(ctx.from) ? 'HUF'
      : parsedCurrency
    const { status, tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = resolveStatusAndTracking(ctx)
    if (!orderId && !tracking) return null
    const etaDate = extractEtaDate(ctx.html, s)
    const orderTotal = extractOrderTotal(s)
    const taxRatePct = extractTaxRatePct(s)
    const items = extractGenericItems(s, currency)
    return {
      shopKey: 'alza', shopLabel: 'Alza',
      orderId, product, quantity: 1,
      total, currency, tracking, trackings, carrier, status,
      trackingConfidence, trackingCandidates, trackingNeedsReview,
      etaDate, orderTotal, taxRatePct,
      items: items.length > 0 ? items : undefined,
    }
  },
}

// ── XXXLutz (DE/AT) ────────────────────────────────────────────────────
// Möbel-Marketplace mit Sperrgut-Versand via Speditionen.
const xxxlutz: Adapter = {
  key: 'xxxlutz',
  label: 'XXXLutz',
  matches: (ctx) =>
    /(@|\.)(?:[a-z0-9.-]+\.)?(?:xxxlutz|xxxlgroup)\.(de|at|com|cz|sk|pl|hu)\b/i
      .test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => {
    const s = haystack(ctx)
    const orderId = findFirst(s, [
      /(?:Auftrags?nummer|Bestellnummer)\s*[:#=]?\s*([A-Z0-9]{6,15})/i,
      /\b(MP\d{8})\b/,
      /\b(XXL\d{6,10})\b/,
    ])
    const product = sanitizeProduct(findFirst(s, [
      /(?:Artikel|Produkt|Bezeichnung)\s*[:=]\s*([^\n]{4,140})/i,
    ])) ?? productFromArticleTable(s) ?? productFromSubject(ctx.subject)
    const totalSrc = /(?:Gesamtsumme(?:\s+inkl\.\s+MwSt)?|Gesamt|Endbetrag)\s*[:\s]+([^\n]{1,40})/i
      .exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { status, tracking, trackings, carrier: rawCarrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = resolveStatusAndTracking(ctx)
    // Carrier-Override: wenn Spedition genannt, ist das wichtiger.
    const speditionMatch = /Versand\s+durch:\s*([A-Z][A-Za-z\s]{2,40})/i.exec(s)
    const carrier = speditionMatch
      ? speditionMatch[1].trim().split(/\s/)[0]
      : rawCarrier
    if (!orderId && !tracking) return null
    const etaDate = extractEtaDate(ctx.html, s)
    const orderTotal = extractOrderTotal(s)
    const taxRatePct = extractTaxRatePct(s)
    const deliveryMethod = extractDeliveryMethod(s)
    return {
      shopKey: 'xxxlutz', shopLabel: 'XXXLutz',
      orderId, product, quantity: 1,
      total, currency, tracking, trackings, carrier, status,
      trackingConfidence, trackingCandidates, trackingNeedsReview,
      etaDate, orderTotal, taxRatePct, deliveryMethod,
    }
  },
}

const REGISTRY: Adapter[] = [
  amazon, mediamarkt, saturn, pccomponentes, xkom, kaufland,
  lego, tink, anker, euronics,
  dell, ebay, galaxus, alza, xxxlutz,
]

export function detectAndParse(ctx: MailContext): ParsedOrder | null {
  for (const adapter of REGISTRY) {
    if (!adapter.matches(ctx)) continue
    try {
      const result = adapter.parse(ctx)
      if (result) return result
    } catch (e) {
      console.warn(`Adapter ${adapter.key} threw`, e)
    }
  }
  return null
}

/// Welche shop_key gehört zu dieser Mail (auch wenn parse() später null
/// liefert)? Wird vom inbox-parse genutzt, um auch unklassifizierten
/// Shop-Mails einen shop_key zu verpassen, damit das UI sortieren kann.
export function detectShop(ctx: MailContext): { key: string; label: string } | null {
  for (const adapter of REGISTRY) {
    if (adapter.matches(ctx)) {
      return { key: adapter.key, label: adapter.label }
    }
  }
  return null
}

/// Vom inbox-poll als Whitelist + Promo-Filter genutzt.
///
/// Logik:
///   0. Carrier-Direkt-Mails (DPD/GLS/Hermes-Tracking) → skippen.
///      Status-Updates bekommen Deals via tracking-poll, nicht via Mail.
///   0a. Eigene Buchhaltungs-Mails (Lexware/Lexoffice) → skippen.
///       Sind Rechnungen für die SaaS-Subscription, nicht für Bestellungen.
///   1. Bekannter Shop + Order-Subject → speichern (Adapter parst später).
///   2. Bekannter Shop + Promo-Subject → skippen.
///   3. Unbekannter Shop + Order-Subject → speichern, landet als
///      "unclassified" (User kann manuell daraus einen Deal machen).
///   4. Unbekannter Shop + generisches Subject → skippen (Newsletter etc.).
export function shouldStore(ctx: MailContext): boolean {
  if (isCarrierOnly(ctx)) return false
  if (isAccountingMail(ctx)) return false
  for (const adapter of REGISTRY) {
    if (adapter.matches(ctx)) {
      return adapter.looksLikeOrder(ctx)
    }
  }
  return isOrderishSubject(ctx.subject)
}

export const ADAPTER_KEYS = REGISTRY.map((a) => a.key)
