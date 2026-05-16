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

// T3c: `STRONG_TRACKING_PATTERNS` + `CONTEXT_TRACKING_RE` sind entfernt.
// Ersatz: `TRACKING_PATTERNS`-Tabelle weiter unten (Single-Source-of-Truth)
// + `ANCHOR_WORDS`-Liste (DE/EN/FR/IT/ES/PL) + sync `findAllTrackings()`,
// die Candidates mit Confidence-Klassifikation zurückgibt.

// Body-Cap für Tracking-Scan (Plan §3.7, ReDoS-Mitigation).
export const MAX_BODY_LEN = 256 * 1024

// ── REJECT_PATTERNS (T3a) ──────────────────────────────────────────────
// Negativ-Liste: läuft AUSSCHLIESSLICH gegen den bereits-gematchten Token
// (3-30 chars), NIEMALS gegen den vollen Mail-Body. So bleibt der Scan
// O(token-länge) und ReDoS-sicher.
//
// WICHTIG (Plan §3.5 + Council-Finding #6): KEIN `^\d{20}$`-Reject — das
// würde echte DHL-20-stellige Trackings blocken. DHL-20 wird stattdessen
// via jkeen-Checksum (T2b) validiert.
//
// Forensik-Report Sektion B (Falsch-Positive heute) ist die Quelle für
// jeden Eintrag hier. Reject-Hits werden NICHT silent gedroppt, sondern
// in `tracking_candidates[].validation.rejectedBy` geloggt (T3b liefert
// den Persistenz-Pfad). Heute (T3a): die Logging-Struktur ist vorbereitet,
// der konsumierende Code kommt in T3b.
export const REJECT_PATTERNS: Array<{ name: string; re: RegExp; reason: string }> = [
  {
    // Amazon-Order-IDs: 3-7-7-Block, z.B. `303-1234567-1234567`.
    // Forensik B#1.
    name: 'amazon_order_id',
    re: /^\d{3}-\d{7}-\d{7}$/,
    reason: 'amazon-order-id',
  },
  {
    // IBAN-Prefix DE + 20 Ziffern (DE-IBAN = 22 Zeichen). Forensik B#4.
    // Nach Whitespace-Normalisierung (T3c) trifft das alle DE-IBANs.
    name: 'iban_de',
    re: /^DE\d{20}$/,
    reason: 'iban-de',
  },
  {
    // Telefon-Form: optionales `+`, dann 2-4 Vorwahl-Stellen, dann ≥3
    // Stellen. Greift Reste wie `+498912345678`. Forensik B#6.
    name: 'phone_intl',
    re: /^\+\d{2,4}\d{3,}$/,
    reason: 'phone-intl',
  },
  {
    // PLZ-Fragment: 5 Ziffern, dann optionaler Whitespace, dann 6-12
    // Telefon-Ziffern. Defensiv für „PLZ + Phone in Footer". Forensik B#5+B#6.
    // Whitespace MANDATORY zwischen PLZ und Phone — sonst würde das
    // Pattern legitime 11-17-stellige Carrier-Trackings (DHL 14-stellig
    // u.a.) blocken. Whitespace im Token bleibt heute erhalten
    // (Normalisierung erst in T3c).
    name: 'plz_phone_combo',
    re: /^\d{5}\s\d{6,12}$/,
    reason: 'plz-phone-combo',
  },
  {
    // 5-stellige PLZ allein als Token (würde nur durch Context-RE matchen,
    // wenn Anchor + zu kurzes Folge-Token — defensiv). Forensik B#5.
    name: 'plz_only',
    re: /^\d{5}$/,
    reason: 'plz-only',
  },
  {
    // Zu kurze rein numerische IDs (1-7 Stellen). Sind nie echte
    // Carrier-Trackings (min. UPS=18, TBA=12, JJD=13, DHL=20, S10=13).
    // Heute matcht das CONTEXT_TRACKING_RE nicht (≥8 chars), aber Pattern
    // wie `\d{20,22}`-Fragmente nach Whitespace-Normalisierung könnten
    // theoretisch hier landen.
    name: 'too_short_numeric',
    re: /^\d{1,7}$/,
    reason: 'too-short-numeric',
  },
  {
    // Generische Auftragsnummer-Form 6-6-6. Forensik B (generischer Schutz).
    name: 'generic_order_3block',
    re: /^\d{6}-\d{6}-\d{6}$/,
    reason: 'generic-order-3block',
  },
]

// T3b: TrackingCandidate-Vollform + Pattern-Tabelle + Anchor-Logic.
// `findAllTrackings()` ist die neue async Variante, die Candidates
// zurückgibt (siehe weiter unten). Der bestehende sync-Pfad bleibt
// als `findAllTrackingsLegacy(s, html?)` erhalten — Cutover in T3c.
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
    /// Reject-Grund, falls Token von REJECT_PATTERNS abgewiesen.
    rejectedBy?: string
    /// jkeen-Checksum-Result (undefined wenn Validator nicht gelaufen).
    checksumValid?: boolean
    /// `true` wenn Whitespace gestrippt wurde (rawValue != value).
    normalized: boolean
    /// ID des Patterns aus TRACKING_PATTERNS, das gegriffen hat.
    patternId?: string
  }
}

// ── Pattern-Tabelle (T3b) ──────────────────────────────────────────────
// Single-Source-of-Truth für Body-Pattern-Matching. Strong-Patterns sind
// format-eindeutig (UPS 1Z, Amazon TBA, DHL JJD, S10-UPU). Context-
// Patterns matchen generische Tokens, die NUR mit Anchor-Wort akzeptiert
// werden.
//
// T3c: Ersetzt `STRONG_TRACKING_PATTERNS` + `CONTEXT_TRACKING_RE`.
export type AdapterPatternValidator = 'jkeen' | 'length-only' | 'no-validation'

export type AdapterPattern = {
  /// Eindeutiger Pattern-Identifier (für Logging + Forensik).
  id: string
  /// Regex (wird global ausgewertet — Flags werden in `findAllTrackings`
  /// gesetzt).
  re: RegExp
  /// Wenn `true`: Anchor-Wort muss im 80-char-Fenster vor dem Match
  /// stehen, sonst wird confidence reduziert.
  requiresAnchor: boolean
  /// Default-Confidence wenn Pattern matcht + Validator OK.
  defaultConfidence: TrackingConfidence
  /// Bekannter Carrier (Validator-Output gewinnt aber).
  carrier?: string
  /// Source-Tag im Candidate.
  source: TrackingCandidate['source']
  /// Welcher Validator wird auf den normalisierten Wert angewandt.
  validator?: AdapterPatternValidator
  /// T3c: Wenn `true`, läuft ein zweiter Pass auf einer Whitespace-
  /// gestripten Body-Variante. Match-Position wird via Index-Map zurück
  /// auf den Original-Body gemappt (für Anchor-Detection). Pflicht für
  /// Patterns, deren Tokens in Mails häufig mit Spaces formatiert sind
  /// (UPS 1Z, DHL JJD, S10).
  normalizable?: boolean
}

export const TRACKING_PATTERNS: AdapterPattern[] = [
  // ── DHL-only Patterns (Plan 2026-05-16, §D1) ──────────────────────
  // Stakeholder-Wunsch: Tracking-Detection läuft ausschliesslich gegen
  // die DHL-API. Alle Non-DHL-Patterns (UPS-1Z, Amazon-TBA, S10-UPU,
  // context-numeric, context-alphanumeric) wurden entfernt. Final
  // entscheidet `enrichWithDhlValidation` per API-Probe, ob ein Match
  // wirklich eine gueltige DHL-Sendung ist.
  {
    id: 'dhl-jjd',
    re: /\bJJD\d{10,18}\b/g,
    requiresAnchor: false,
    defaultConfidence: 'strong',
    carrier: 'DHL',
    source: 'strong-pattern',
    validator: 'jkeen',
    normalizable: true,
  },
  {
    id: 'dhl-de-suffix',
    // [LL]NNN…NN[LL] mit `DE`-Suffix — eindeutiger DHL-Code.
    re: /\b[A-Z]{2}\d{9}DE\b/g,
    requiresAnchor: false,
    defaultConfidence: 'strong',
    carrier: 'DHL',
    source: 'strong-pattern',
    validator: 'jkeen',
  },
  {
    id: 'dhl-de-prefix',
    // DE-Prefix + 8–14 Digits ("DE5455279839", 12 Zeichen). Wird sowohl
    // von Amazon Logistics als auch DHL national genutzt — Plan D1
    // entscheidet, dass die DHL-API-Validierung den finalen Carrier-
    // Filter uebernimmt. Wenn die DHL-API 404 liefert, wird der Kandidat
    // verworfen.
    re: /\bDE\d{8,14}\b/g,
    requiresAnchor: false,
    defaultConfidence: 'strong',
    carrier: 'DHL',
    source: 'strong-pattern',
    validator: 'length-only',
  },
]

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

/**
 * Prüft, ob ein bereits gematchter Token von einem REJECT_PATTERN
 * abgewiesen wird.
 *
 * **ReDoS-Schutz:** Läuft AUSSCHLIESSLICH auf dem Token (3-30 Zeichen),
 * niemals auf der vollen Mail. Length-Cap + Patterns sind alle anchored
 * (`^…$`) → O(token-länge) worst case.
 *
 * Whitespace-Normalisierung passiert NICHT hier (kommt in T3c). Tokens
 * mit Whitespace geben `null` zurück (greifen Reject-Patterns nicht).
 *
 * @param token bereits extrahierter Tracking-Kandidat
 * @returns Reject-Grund-String, oder `null` wenn nichts matcht.
 */
export function checkRejectPatterns(token: string | null | undefined): string | null {
  // Defensiver Length-Cap als ReDoS-Schutz + Null-Safety.
  if (!token || typeof token !== 'string') return null
  if (token.length < 3 || token.length > 30) return null
  for (const p of REJECT_PATTERNS) {
    if (p.re.test(token)) {
      // PII-frei: nur Pattern-Name + Token-Prefix (max 4 chars).
      // Council-Security-Finding zu PII-Leaks.
      const tokPrefix = token.slice(0, 4)
      // deno-lint-ignore no-console
      console.log(`reject: ${p.name} matched (tok=${tokPrefix}…)`)
      return p.reason
    }
  }
  return null
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

// `inferCarrier()` wurde mit Plan 2026-05-16 (§D1) entfernt. Mit nur
// noch DHL-Patterns in `TRACKING_PATTERNS` ist Body-Carrier-Inference
// toter Code — `pattern.carrier ?? 'DHL'` liefert deterministisch den
// Carrier-Label. Endgueltige Validierung erfolgt durch
// `enrichWithDhlValidation` (DHL-API-Probe).

/// HTML-spezifische Tracking-Extraktion: liest `href`-Attribute aus dem
/// Roh-HTML und matcht typische Carrier-URL-Schemes. Wichtig für Amazon
/// & Co., die Tracking-Nummern oft NUR im Link-Ziel haben (text-Strip
/// schmeißt die `href`-Werte weg).
///
/// T3c: Gibt Candidates zurück (statt String-Liste). Bekannte Carrier-
/// Domains → `confidence: 'strong'`, `source: 'html-href'`. Generic-
/// URL-Catch → `confidence: 'medium'`. Amazon `orderingShipmentId` ist
/// ein Sonderfall (Council-Finding: interne Amazon-Logistics-Shipment-ID,
/// kein echtes Carrier-Tracking) → `source: 'amazon-shipment-id'`,
/// `confidence: 'medium'` — bleibt in der Candidate-Liste sichtbar,
/// aber nie primary.
function findTrackingsInHtml(html: string): TrackingCandidate[] {
  if (!html) return []
  const byValue = new Map<string, TrackingCandidate>()

  // Common Carrier-URL-Patterns. Reihenfolge: spezifisch → generisch.
  // Wichtig für Amazon: deren Versand-Mails wrappen jeden Tracking-Link
  // in einen `amazon.<tld>/gp/f.html?...&U=<URL-encoded-ZielURL>`-
  // Redirect. Die echten Carrier-URL-Parameter (`piececode`, `trackingId`,
  // `orderingShipmentId`) stehen also doppelt URL-encoded im href. Wir
  // matchen daher gegen RAW + decoded(URL) — siehe Loop unten.
  //
  // T3c: Pro Pattern entscheidet `source` über die Confidence:
  //   - 'html-href' + bekannter Carrier → 'strong'
  //   - 'amazon-shipment-id' (orderingShipmentId) → 'medium' (Council:
  //     interne Amazon-Logistics-ID, kein echtes Carrier-Tracking).
  //   - 'unknown' → 'medium' (generischer URL-Param-Catch).
  type UrlPattern = {
    re: RegExp
    carrier?: string
    source: TrackingCandidate['source']
    confidence: TrackingConfidence
  }
  const URL_PATTERNS: UrlPattern[] = [
    // Amazon Logistics: track.amazon.de/123ABC oder ?trackingId=...
    { re: /track\.amazon\.[a-z.]+\/(?:tracking\/)?([A-Z0-9]{10,30})\b/i, carrier: 'Amazon Logistics', source: 'html-href', confidence: 'strong' },
    { re: /[?&]trackingId=([A-Z0-9-]{8,30})/i, carrier: 'Amazon Logistics', source: 'html-href', confidence: 'strong' },
    // Amazon-Logistics-Shipment-ID (Sonderfall: T4-Notiz).
    { re: /[?&]orderingShipmentId=([0-9]{8,20})/i, carrier: 'Amazon Logistics', source: 'amazon-shipment-id', confidence: 'medium' },
    // DHL: nolp.dhl.de/?piececode=... oder /track/123
    { re: /[?&]piececode=([A-Z0-9]{8,30})/i, carrier: 'DHL', source: 'html-href', confidence: 'strong' },
    { re: /nolp\.dhl\.[a-z.]+\/.*?[?&]idc=([A-Z0-9]{10,30})/i, carrier: 'DHL', source: 'html-href', confidence: 'strong' },
    { re: /dhl\.[a-z.]+\/.*?\/track[^?]*\?(?:trackingNumber|tracking)=([A-Z0-9]{8,30})/i, carrier: 'DHL', source: 'html-href', confidence: 'strong' },
    // UPS
    { re: /ups\.com\/.*?[?&]tracknum(?:s)?=(1Z[A-Z0-9]{16})/i, carrier: 'UPS', source: 'html-href', confidence: 'strong' },
    // DPD
    { re: /dpd\.[a-z.]+\/.*?[?&]parcelno(?:r)?=(\d{10,20})/i, carrier: 'DPD', source: 'html-href', confidence: 'strong' },
    { re: /tracking\.dpd\.[a-z.]+\/.*?\/(\d{10,20})/i, carrier: 'DPD', source: 'html-href', confidence: 'strong' },
    { re: /(?:track\.)?dpd\.[a-z.]+\/parcels?\/(\d{10,20})/i, carrier: 'DPD', source: 'html-href', confidence: 'strong' },
    // GLS
    { re: /gls-?(?:pakete|group)\.[a-z.]+\/.*?[?&]match=([A-Z0-9]{8,30})/i, carrier: 'GLS', source: 'html-href', confidence: 'strong' },
    // Hermes
    { re: /hermesworld\.[a-z.]+\/.*?[?&]Barcode=([A-Z0-9]{8,30})/i, carrier: 'Hermes', source: 'html-href', confidence: 'strong' },
    // Chronopost (FR)
    { re: /chronopost\.[a-z.]+\/.*?[?&]listeNumerosLT=([A-Z0-9]{8,30})/i, carrier: 'Chronopost', source: 'html-href', confidence: 'strong' },
    // SEUR (ES)
    { re: /seur\.[a-z.]+\/.*?[?&]segOnLine=([A-Z0-9]{8,30})/i, carrier: 'SEUR', source: 'html-href', confidence: 'strong' },
    // GLS variant (US/UK)
    { re: /gls-?[a-z]*\.[a-z.]+\/.*?[?&]trackingNumber=([A-Z0-9]{8,30})/i, carrier: 'GLS', source: 'html-href', confidence: 'strong' },
    // Generic: any tracknum/tracking/trk parameter (last resort) — unknown carrier.
    { re: /[?&](?:trk|tracking_?number|tracknum|tracking_id|trackingnr)=([A-Z0-9-]{8,30})/i, source: 'unknown', confidence: 'medium' },
  ]

  const hrefRe = /href\s*=\s*["']([^"']{8,2000})["']/gi
  let h: RegExpExecArray | null
  while ((h = hrefRe.exec(html)) !== null) {
    const url = h[1]
    let decoded = url
    if (url.includes('%')) {
      try { decoded = decodeURIComponent(url) } catch { /* ignore */ }
    }
    const urlVariants = decoded === url ? [url] : [url, decoded]
    for (const p of URL_PATTERNS) {
      let matched = false
      for (const variant of urlVariants) {
        const m = p.re.exec(variant)
        if (m && m[1]) {
          const rawValue = m[1]
          const value = rawValue.replace(/\s+/g, '').toUpperCase()
          const rejectedBy = checkRejectPatterns(value) ?? undefined
          const carrier = p.carrier ?? 'DHL'
          let confidence: TrackingConfidence = p.confidence
          if (rejectedBy) confidence = 'none'
          const candidate: TrackingCandidate = {
            value,
            rawValue,
            carrier,
            source: p.source,
            confidence,
            validation: {
              rejectedBy,
              normalized: value !== rawValue,
              patternId: `html:${p.source}`,
            },
          }
          const prev = byValue.get(value)
          if (!prev || _CONFIDENCE_ORDER[confidence] > _CONFIDENCE_ORDER[prev.confidence]) {
            byValue.set(value, candidate)
          }
          matched = true
          break
        }
      }
      if (matched) break // nur das erste Match pro URL
    }
  }
  return Array.from(byValue.values())
}

// ── findAllTrackings (T3c: Sync, Candidate-aware) ──────────────────────
//
// Scannt den Body mit der zentralen `TRACKING_PATTERNS`-Tabelle, deduppt
// auf normalisiertem Wert, gibt `TrackingCandidate[]` sortiert nach
// Confidence (strong > medium > weak > none) zurück. Pro Token:
//   1. Body-Cap auf `MAX_BODY_LEN` (ReDoS-Mitigation).
//   2. Pattern-Match auf Original-Body (für Anchor-Lookup-Indizes).
//   3. Wenn `pattern.normalizable`: zweiter Pass auf Whitespace-gestripptem
//      Body-Clone, Index zurückmappen via Index-Map (für Patterns wie
//      `1Z 999 AA1 0123456784`, die User-Mails häufig mit Spaces formatieren).
//   4. Normalisierung (Whitespace-strip + uppercase) → `value`.
//   5. Reject-Pattern-Check (Forensik-Log via validation.rejectedBy).
//   6. Anchor-Detection wenn `pattern.requiresAnchor`.
//   7. Confidence-Adjustment (Reject → 'none', Anchor-Miss → step down).
//   8. HTML-href-Scan optional, wenn `html` mitgegeben.
//
// **Sync per Default** — der jkeen-Validator (T2b) ist nicht eingebunden,
// um die Adapter-Pipeline (`Adapter.parse`) ohne async-Cascade zu halten.
// Eine optionale jkeen-Validation kann als Post-Step gegen die Candidate-
// Liste laufen.
export interface FindAllTrackingsOptions {
  /// Wenn true: Patterns mit `requiresAnchor: true` aber ohne Anchor
  /// werden komplett geskippt (statt nur Confidence runter). Default
  /// false → alle Matches landen mit reduzierter Confidence in der
  /// Forensik-Liste.
  skipUnanchoredContext?: boolean
}

export const _CONFIDENCE_ORDER: Record<TrackingConfidence, number> = {
  strong: 3,
  medium: 2,
  weak: 1,
  none: 0,
}

function _stepDownConfidence(c: TrackingConfidence): TrackingConfidence {
  if (c === 'strong') return 'medium'
  if (c === 'medium') return 'weak'
  if (c === 'weak') return 'none'
  return 'none'
}

/// Baut eine whitespace-gestripte Variante des Bodies UND eine Index-
/// Map: `strippedIdx[i] = origIdx` mappt jedes Zeichen im stripped-Body
/// zurück auf seine Position im Original-Body. Wird für die
/// `normalizable: true` Patterns benutzt, damit `findAnchorBefore` auf
/// dem Original arbeiten kann.
function _buildStrippedBodyAndMap(body: string): { stripped: string; map: number[] } {
  const map: number[] = []
  let stripped = ''
  for (let i = 0; i < body.length; i++) {
    const ch = body[i]
    if (/\s/.test(ch)) continue
    stripped += ch
    map.push(i)
  }
  return { stripped, map }
}

export function findAllTrackings(
  body: string,
  options?: FindAllTrackingsOptions & { html?: string },
): TrackingCandidate[] {
  if (!body || typeof body !== 'string') {
    if (options?.html) return findTrackingsInHtml(options.html)
    return []
  }

  // T3c: Hard Body-Cap auf MAX_BODY_LEN = 256 KB.
  const scan = body.length > MAX_BODY_LEN ? body.slice(0, MAX_BODY_LEN) : body

  // Lazy: stripped-Variante nur bauen, wenn ein normalizable-Pattern
  // sie braucht.
  let strippedCache: { stripped: string; map: number[] } | null = null
  const getStripped = () => {
    if (!strippedCache) strippedCache = _buildStrippedBodyAndMap(scan)
    return strippedCache
  }

  // Deduplizierung auf normalisiertem Wert.
  const byValue = new Map<string, TrackingCandidate>()

  const addCandidate = (
    pattern: AdapterPattern,
    rawValue: string,
    origMatchStart: number,
    normalizedViaStrippedPass: boolean,
  ) => {
    const value = rawValue.replace(/\s+/g, '').toUpperCase()
    const normalized = normalizedViaStrippedPass || value !== rawValue

    const rejectedBy = checkRejectPatterns(value) ?? undefined

    let anchorMatched: string | undefined
    if (pattern.requiresAnchor) {
      const a = findAnchorBefore(scan, origMatchStart)
      if (a) anchorMatched = a
    }

    let confidence: TrackingConfidence = pattern.defaultConfidence
    if (rejectedBy) {
      confidence = 'none'
    } else if (pattern.requiresAnchor && !anchorMatched) {
      confidence = _stepDownConfidence(confidence)
    }

    if (options?.skipUnanchoredContext && pattern.requiresAnchor && !anchorMatched) {
      return
    }

    const carrier = pattern.carrier ?? 'DHL'

    const candidate: TrackingCandidate = {
      value,
      rawValue,
      carrier,
      source: pattern.source,
      confidence,
      validation: {
        anchorMatched,
        rejectedBy,
        normalized,
        patternId: pattern.id,
      },
    }
    const prev = byValue.get(value)
    if (!prev) {
      byValue.set(value, candidate)
    } else if (_CONFIDENCE_ORDER[confidence] > _CONFIDENCE_ORDER[prev.confidence]) {
      byValue.set(value, candidate)
    } else if (
      _CONFIDENCE_ORDER[confidence] === _CONFIDENCE_ORDER[prev.confidence] &&
      candidate.carrier && !prev.carrier
    ) {
      // Confidence-Tie: bevorzuge Candidate mit bekanntem Carrier
      // (z.B. HTML-Pattern liefert SEUR-Label, Body-Pattern nicht).
      byValue.set(value, candidate)
    }
  }

  for (const pattern of TRACKING_PATTERNS) {
    const flags = pattern.re.flags.includes('g') ? pattern.re.flags : `${pattern.re.flags}g`
    const re = new RegExp(pattern.re.source, flags)

    // Pass 1: Original-Body.
    let m: RegExpExecArray | null
    while ((m = re.exec(scan)) !== null) {
      addCandidate(pattern, m[0], m.index, false)
    }

    // Pass 2: Whitespace-gestripped-Body (nur für normalizable-Patterns).
    // T3c-Council-Finding #4: User-Mails formatieren UPS/JJD/S10 oft mit
    // Spaces ("1Z 999 AA1 0123456784"). Pattern matchen auf Pass-1 nicht,
    // deshalb zweiter Pass auf gestripptem Body. Index-Map mappt Match-
    // Start zurück auf Original, damit Anchor-Lookup funktioniert.
    //
    // **Wichtig**: Auf stripped-Body fehlen die Whitespace-Boundaries, also
    // matchen `\b…\b`-Anchored-Patterns oft nicht (Beispiel: `1Z…784is`).
    // Wir transformieren `\b` → `(?:^|(?<=[^A-Z0-9]))…(?=[^A-Z0-9]|$)` für
    // Pass-2. Defensiv: wenn der Source-Regex kein `\b` enthält, fallback
    // auf das Original.
    if (pattern.normalizable) {
      const { stripped, map } = getStripped()
      const src = pattern.re.source
      // Trailing `\b` ist auf stripped-Body wertlos, weil das Folge-Token
      // (z.B. `is on its way.` → `isonitsway.`) am Anfang Wort-Zeichen
      // hat. Wir entfernen es. Leading `\b` belassen wir, damit das
      // Pattern nicht mitten in einem alphanumerischen Block matcht.
      // Fix-Length-Pattern wie `1Z[A-Z0-9]{16}` (UPS) sind durch die
      // exakte Längenvorgabe trotzdem eindeutig.
      const pass2Src = src.replace(/\\b$/, '')
      const re2 = new RegExp(pass2Src, flags)
      let m2: RegExpExecArray | null
      while ((m2 = re2.exec(stripped)) !== null) {
        const rawValue = m2[0]
        const strippedIdx = m2.index
        const origIdx = map[strippedIdx] ?? 0
        // Skip, wenn das identische Token bereits aus Pass 1 vorliegt.
        const candidateValue = rawValue.replace(/\s+/g, '').toUpperCase()
        if (byValue.has(candidateValue)) continue
        addCandidate(pattern, rawValue, origIdx, true)
      }
    }
  }

  // HTML-Pfad: Candidates aus href-Attributen.
  if (options?.html) {
    const htmlCandidates = findTrackingsInHtml(options.html)
    for (const hc of htmlCandidates) {
      const prev = byValue.get(hc.value)
      if (!prev) {
        byValue.set(hc.value, hc)
      } else if (_CONFIDENCE_ORDER[hc.confidence] > _CONFIDENCE_ORDER[prev.confidence]) {
        byValue.set(hc.value, hc)
      } else if (
        _CONFIDENCE_ORDER[hc.confidence] === _CONFIDENCE_ORDER[prev.confidence] &&
        hc.carrier && !prev.carrier
      ) {
        byValue.set(hc.value, hc)
      }
    }
  }

  const candidates = Array.from(byValue.values())
  candidates.sort(
    (a, b) => _CONFIDENCE_ORDER[b.confidence] - _CONFIDENCE_ORDER[a.confidence],
  )
  return candidates
}

// ── gateTracking (T3c, Candidate-aware) ────────────────────────────────
/// Filtert eine Candidate-Liste nach minimaler Confidence-Schwelle.
/// Returns:
///   - `primary`: höchster Candidate, der durch das Gate kommt (oder null)
///   - `rest`: alle anderen Candidates (Forensik-Liste)
///
/// Plan §3.7: `minConfidence` Default 'strong'.
export type GateOptions = {
  /// Mindest-Confidence für primary. Default: `'strong'`.
  minConfidence?: TrackingConfidence
  /// Wenn true: primary muss `carrier !== undefined` haben. Default false.
  requireCarrier?: boolean
}

export function gateTracking(
  candidates: TrackingCandidate[],
  opts?: GateOptions,
): { primary: TrackingCandidate | null; rest: TrackingCandidate[] } {
  const min = opts?.minConfidence ?? 'strong'
  const requireCarrier = opts?.requireCarrier ?? false
  const minOrder = _CONFIDENCE_ORDER[min]
  let primary: TrackingCandidate | null = null
  const rest: TrackingCandidate[] = []
  for (const c of candidates) {
    if (
      !primary &&
      _CONFIDENCE_ORDER[c.confidence] >= minOrder &&
      (!requireCarrier || c.carrier !== undefined)
    ) {
      primary = c
    } else {
      rest.push(c)
    }
  }
  return { primary, rest }
}

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

/// Tracking-Nummern gibt es nur, wenn die Bestellung tatsächlich
/// versandt/zugestellt ist. Bestellbestätigungen, Stornos und Erstattungen
/// referenzieren manchmal die ALTE Tracking-Nr im Body — die wollen wir
/// nicht als gültig durchreichen, weil das den Deal-Status verfälscht.
///
/// T3c: heißt jetzt `gateTrackingByStatus` — die neue confidence-aware
/// Variante `gateTracking(candidates, opts)` ist ein separater Helper
/// weiter unten in der Pipeline.
function gateTrackingByStatus(
  status: 'ordered' | 'shipped' | 'delivered' | 'cancelled' | 'refunded',
  candidates: TrackingCandidate[],
): TrackingCandidate[] {
  if (status !== 'shipped' && status !== 'delivered') return []
  return candidates
}

/// Adapter-internes Helper: kombiniert `findAllTrackings` + Status-Gate +
/// Candidate-Gate (min='strong') zu einem Block, der die existierenden
/// 18 Call-Sites kurzhält. Liefert das Property-Bundle, das `ParsedOrder`
/// erwartet.
function resolveTrackingForAdapter(
  body: string,
  html: string,
  status: 'ordered' | 'shipped' | 'delivered' | 'cancelled' | 'refunded',
): {
  tracking?: string
  trackings?: string[]
  carrier?: string
  trackingConfidence: 'strong' | 'none'
  trackingCandidates: TrackingCandidate[]
  trackingNeedsReview: boolean
} {
  const allCandidates = findAllTrackings(body, { html })
  // Erst Status-Gate (Bestellbestätigungen ohne shipped/delivered →
  // Tracking-Nrn dropped).
  const statusGated = gateTrackingByStatus(status, allCandidates)
  // Dann Confidence-Gate (min='strong').
  const { primary } = gateTracking(statusGated, { minConfidence: 'strong' })
  // Max 10 Candidates in Forensik (Plan §3.2).
  const trackingCandidates = allCandidates.slice(0, 10)

  if (!primary) {
    // needs_review = true wenn der Mail-Status shipped/delivered ist,
    // aber kein strong-Candidate da ist.
    const shippedLike = status === 'shipped' || status === 'delivered'
    return {
      tracking: undefined,
      trackings: undefined,
      carrier: undefined,
      trackingConfidence: 'none',
      trackingCandidates,
      trackingNeedsReview: shippedLike && allCandidates.length > 0,
    }
  }

  const strongList = statusGated
    .filter((c) => _CONFIDENCE_ORDER[c.confidence] >= _CONFIDENCE_ORDER['strong'])
    .map((c) => c.value)

  return {
    tracking: primary.value,
    trackings: strongList.length > 0 ? strongList : [primary.value],
    carrier: primary.carrier,
    trackingConfidence: 'strong',
    trackingCandidates,
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
    const _trkScan = findAllTrackings(s, { html: ctx.html })
    const _hasStrong = _trkScan.some((c) => c.confidence === 'strong')
    const status = detectShipStatus(ctx.subject, s, _hasStrong)
    const _trk = resolveTrackingForAdapter(s, ctx.html, status)
    const { tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = _trk
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
    const _trkScan = findAllTrackings(s, { html: ctx.html })
    const _hasStrong = _trkScan.some((c) => c.confidence === 'strong')
    const status = detectShipStatus(ctx.subject, s, _hasStrong)
    const _trk = resolveTrackingForAdapter(s, ctx.html, status)
    const { tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = _trk
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
    const _trkScan = findAllTrackings(s, { html: ctx.html })
    const _hasStrong = _trkScan.some((c) => c.confidence === 'strong')
    const status = detectShipStatus(ctx.subject, s, _hasStrong)
    const _trk = resolveTrackingForAdapter(s, ctx.html, status)
    const { tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = _trk
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
    const _trkScan = findAllTrackings(s, { html: ctx.html })
    const _hasStrong = _trkScan.some((c) => c.confidence === 'strong')
    const status = detectShipStatus(ctx.subject, s, _hasStrong)
    const _trk = resolveTrackingForAdapter(s, ctx.html, status)
    const { tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = _trk
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
    const _trkScan = findAllTrackings(s, { html: ctx.html })
    const _hasStrong = _trkScan.some((c) => c.confidence === 'strong')
    const status = detectShipStatus(ctx.subject, s, _hasStrong)
    const _trk = resolveTrackingForAdapter(s, ctx.html, status)
    const { tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = _trk
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
    const _trkScan = findAllTrackings(s, { html: ctx.html })
    const _hasStrong = _trkScan.some((c) => c.confidence === 'strong')
    const status = detectShipStatus(ctx.subject, s, _hasStrong)
    const _trk = resolveTrackingForAdapter(s, ctx.html, status)
    const { tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = _trk
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
// kommen aus dem Body via `findAllTrackings`.
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
    const _trkScan = findAllTrackings(s, { html: ctx.html })
    const _hasStrong = _trkScan.some((c) => c.confidence === 'strong')
    const status = detectShipStatus(ctx.subject, s, _hasStrong)
    const _trk = resolveTrackingForAdapter(s, ctx.html, status)
    const { tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = _trk
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
    const _trkScan = findAllTrackings(s, { html: ctx.html })
    const _hasStrong = _trkScan.some((c) => c.confidence === 'strong')
    const status = detectShipStatus(ctx.subject, s, _hasStrong)
    const _trk = resolveTrackingForAdapter(s, ctx.html, status)
    const { tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = _trk
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
    const _trkScan = findAllTrackings(s, { html: ctx.html })
    const _hasStrong = _trkScan.some((c) => c.confidence === 'strong')
    const status = detectShipStatus(ctx.subject, s, _hasStrong)
    const _trk = resolveTrackingForAdapter(s, ctx.html, status)
    const { tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = _trk
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
    const _trkScan = findAllTrackings(s, { html: ctx.html })
    const _hasStrong = _trkScan.some((c) => c.confidence === 'strong')
    const status = detectShipStatus(ctx.subject, s, _hasStrong)
    const _trk = resolveTrackingForAdapter(s, ctx.html, status)
    const { tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = _trk
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
    const _trkScan = findAllTrackings(s, { html: ctx.html })
    const _hasStrong = _trkScan.some((c) => c.confidence === 'strong')
    const status = detectShipStatus(ctx.subject, s, _hasStrong)
    const _trk = resolveTrackingForAdapter(s, ctx.html, status)
    const { tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = _trk
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
    const _trkScan = findAllTrackings(s, { html: ctx.html })
    const _hasStrong = _trkScan.some((c) => c.confidence === 'strong')
    const status = detectShipStatus(ctx.subject, s, _hasStrong)
    const _trk = resolveTrackingForAdapter(s, ctx.html, status)
    const { tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = _trk
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
    const _trkScan = findAllTrackings(s, { html: ctx.html })
    const _hasStrong = _trkScan.some((c) => c.confidence === 'strong')
    const status = detectShipStatus(ctx.subject, s, _hasStrong)
    const _trk = resolveTrackingForAdapter(s, ctx.html, status)
    const { tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = _trk
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
    const _trkScan = findAllTrackings(s, { html: ctx.html })
    const _hasStrong = _trkScan.some((c) => c.confidence === 'strong')
    const status = detectShipStatus(ctx.subject, s, _hasStrong)
    const _trk = resolveTrackingForAdapter(s, ctx.html, status)
    const { tracking, trackings, carrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = _trk
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
    const _trkScan = findAllTrackings(s, { html: ctx.html })
    const _hasStrong = _trkScan.some((c) => c.confidence === 'strong')
    const status = detectShipStatus(ctx.subject, s, _hasStrong)
    const _trk = resolveTrackingForAdapter(s, ctx.html, status)
    const { tracking, trackings, carrier: rawCarrier, trackingConfidence, trackingCandidates, trackingNeedsReview } = _trk
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
