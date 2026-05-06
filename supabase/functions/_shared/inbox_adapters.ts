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

// Tracking-Detection ist bewusst RESTRIKTIV: lieber gar keine Nummer als
// eine erfundene. Amazon, DHL etc. bauen interne Shipment-IDs in URLs
// ("?shipmentId=1776971660745"), die wie Tracking-Nrn aussehen, aber
// keine sind. Wir akzeptieren deshalb nur:
//   1. Carrier-Strong-Pattern: 1Z…, TBA…, JJD…, [LL]NNN…NN[LL] (DE-DHL).
//   2. Numerische Nummern, die direkt hinter dem Wort
//      "Tracking" / "Sendungsnummer" / "Paketnummer" stehen.
const STRONG_TRACKING_PATTERNS: Array<{ re: RegExp; carrier?: string }> = [
  { re: /\b(1Z[A-Z0-9]{16})\b/, carrier: 'UPS' },
  { re: /\b(TBA\d{9,14})\b/i, carrier: 'Amazon Logistics' },
  { re: /\b(JJD\d{10,18})\b/, carrier: 'DHL' },
  { re: /\b([A-Z]{2}\d{9}DE)\b/, carrier: 'DHL' },
  { re: /\b(\d{20,22})\b/, carrier: 'DHL' },
]

const CONTEXT_TRACKING_RE =
  /(?:tracking(?:[-\s]?(?:nummer|nr\.?|number|no\.?|#))?|sendungs?(?:[-\s]?(?:nummer|nr\.?))|paket(?:[-\s]?(?:nummer|nr\.?))|nr[uú]mero\s+de\s+seguimiento|numer\s+przesy(?:ł|l)ki)\s*[:\s#=-]*\s*([A-Z0-9-]{8,30})/i

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

function inferCarrier(tn: string, body: string): string | undefined {
  if (/^1Z/.test(tn)) return 'UPS'
  if (/^TBA/i.test(tn)) return 'Amazon Logistics'
  if (/^JJD/.test(tn)) return 'DHL'
  if (/^[A-Z]{2}\d{9}DE$/.test(tn)) return 'DHL'
  if (/\bdhl\b/i.test(body)) return 'DHL'
  if (/\bhermes\b/i.test(body)) return 'Hermes'
  if (/\bdpd\b/i.test(body)) return 'DPD'
  if (/\bgls\b/i.test(body)) return 'GLS'
  if (/\binpost\b/i.test(body)) return 'InPost'
  if (/\bups\b/i.test(body)) return 'UPS'
  return undefined
}

const findTracking = (s: string): { tracking?: string; carrier?: string } => {
  const all = findAllTrackings(s)
  if (all.trackings.length === 0) return {}
  return { tracking: all.trackings[0], carrier: all.carrier }
}

/// Sucht ALLE Tracking-Nrn in der Mail, dedupliziert. Strong-Patterns
/// werden global gescannt; Context-Bound-Pattern auch (mehrere
/// "Sendungsnummer:"-Blöcke in einer Versandbestätigung).
function findAllTrackings(s: string): { trackings: string[]; carrier?: string } {
  const seen = new Set<string>()
  const out: string[] = []
  let carrier: string | undefined

  for (const p of STRONG_TRACKING_PATTERNS) {
    const re = new RegExp(p.re.source, p.re.flags.includes('g') ? p.re.flags : `${p.re.flags}g`)
    let m: RegExpExecArray | null
    while ((m = re.exec(s)) !== null) {
      const tn = m[1]
      if (!tn || seen.has(tn)) continue
      seen.add(tn)
      out.push(tn)
      carrier ??= p.carrier ?? inferCarrier(tn, s)
    }
  }

  // Context-bound — global iterieren.
  const ctxRe = new RegExp(CONTEXT_TRACKING_RE.source, 'gi')
  let m: RegExpExecArray | null
  while ((m = ctxRe.exec(s)) !== null) {
    const tn = (m[1] ?? '').trim()
    if (tn.length < 8 || !/\d{4,}/.test(tn) || seen.has(tn)) continue
    seen.add(tn)
    out.push(tn)
    carrier ??= inferCarrier(tn, s)
  }

  return { trackings: out, carrier }
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
function gateTracking(
  status: 'ordered' | 'shipped' | 'delivered' | 'cancelled' | 'refunded',
  trackings: string[],
  carrier?: string,
): { tracking?: string; trackings?: string[]; carrier?: string } {
  if (status !== 'shipped' && status !== 'delivered') {
    return { tracking: undefined, trackings: undefined, carrier: undefined }
  }
  if (trackings.length === 0) return { carrier: undefined }
  return { tracking: trackings[0], trackings, carrier }
}

// Subjects, die garantiert KEINE Order sind (Promo/Newsletter/Account-Stuff).
const isOrderishSubject = (subject: string): boolean => {
  const s = subject.toLowerCase()
  // Hard skip: Promo / Newsletter / Account-Verwaltung
  if (/\b(angebot|newsletter|spare|prozent|sale|promotion|deal des tages|wartet auf dich|sichern|profitieren|benutzerverwaltung|update|empfehl|inspirat|prime[- ]?duo|hinzufügen|jetzt entdecken|tipps|spotlight|black friday|cyber monday)/i.test(s)) return false
  // Whitelist-Pattern: typische Order-Mail-Subjects
  return /\b(bestell|order|auftrag|versand|lieferung|tracking|zustell|sendung|paket|stornier|widerruf|erstattung|gutschrift|rechnung|invoice|frankierung|shipping|shipped|delivery|envío|zamówieni|wysył|dostaw)/i.test(s)
}

// Boilerplate-Phrasen, die KEIN echter Produktname sind. Trifft regelmäßig
// auf Amazon-AGB-Disclaimer in Versandbestätigungs-Mails (Widerrufsrecht etc.).
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

// ── Amazon (DE/COM/UK/FR/IT/ES) ────────────────────────────────────────
const amazon: Adapter = {
  key: 'amazon',
  label: 'Amazon',
  matches: (ctx) =>
    /(@|\.)amazon\.(de|com|co\.uk|fr|it|es)\b/i.test(ctx.from)
    && !/business\.amazon/i.test(ctx.from), // Business-Werbung ausschließen
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
    const rawShip = findAllTrackings(s)
    const status = detectShipStatus(ctx.subject, s, rawShip.trackings.length > 0)
    const { tracking, trackings, carrier } = gateTracking(
      status, rawShip.trackings, rawShip.carrier)
    if (!orderId && !product && !tracking) return null
    return {
      shopKey: 'amazon', shopLabel: 'Amazon',
      orderId, product, quantity: Math.max(1, qty),
      total, currency, tracking, trackings, carrier, status,
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
    const rawShip = findAllTrackings(s)
    const status = detectShipStatus(ctx.subject, s, rawShip.trackings.length > 0)
    const { tracking, trackings, carrier } = gateTracking(
      status, rawShip.trackings, rawShip.carrier)
    if (!orderId && !tracking) return null
    return {
      shopKey: 'mediamarkt', shopLabel: 'MediaMarkt',
      orderId, product, quantity: 1,
      total, currency, tracking, trackings, carrier, status,
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
    const rawShip = findAllTrackings(s)
    const status = detectShipStatus(ctx.subject, s, rawShip.trackings.length > 0)
    const { tracking, trackings, carrier } = gateTracking(
      status, rawShip.trackings, rawShip.carrier)
    if (!orderId && !tracking) return null
    return {
      shopKey: 'saturn', shopLabel: 'Saturn',
      orderId, product, quantity: 1,
      total, currency, tracking, trackings, carrier, status,
    }
  },
}

/// PCComponentes-spezifisches Produkt-Layout: Bestelldetails-Block mit
///   "Produktname    465,00 €
///    Einheiten: 2
///    Verkauft von PCCOMPONENTES"
/// Wir verankern auf dem `Einheiten:`-Label und greifen das Großbuchstaben-
/// Token mit Preis direkt davor.
const productFromPcComponentesLine = (s: string): string | undefined => {
  const m = /([A-Z][^\n]{4,160})\s+\d+[.,]\d{2}\s*€[\s\S]{0,120}?Einheiten\s*:/i
    .exec(s)
  if (!m || !m[1]) return undefined
  const cleaned = m[1]
    .replace(/\s+\d+[.,]\d{2}\s*(?:Euro|€|EUR).*$/i, '')
    .replace(/\s+/g, ' ')
    .trim()
  return sanitizeProduct(cleaned)
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
    const rawShip = findAllTrackings(s)
    const status = detectShipStatus(ctx.subject, s, rawShip.trackings.length > 0)
    const { tracking, trackings, carrier } = gateTracking(
      status, rawShip.trackings, rawShip.carrier)
    if (!orderId && !tracking) return null
    return {
      shopKey: 'pccomponentes', shopLabel: 'PcComponentes',
      orderId, product, quantity: Math.max(1, qty),
      total, currency: currency === 'EUR' ? 'EUR' : currency,
      tracking, trackings, carrier, status,
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
    const rawShip = findAllTrackings(s)
    const status = detectShipStatus(ctx.subject, s, rawShip.trackings.length > 0)
    const { tracking, trackings, carrier } = gateTracking(
      status, rawShip.trackings, rawShip.carrier)
    if (!orderId && !tracking) return null
    return {
      shopKey: 'xkom', shopLabel: 'x-kom',
      orderId, product, quantity: 1,
      total, currency: currency === 'EUR' ? 'PLN' : currency, // x-kom default PLN
      tracking, trackings, carrier, status,
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
    const rawShip = findAllTrackings(s)
    const status = detectShipStatus(ctx.subject, s, rawShip.trackings.length > 0)
    const { tracking, trackings, carrier } = gateTracking(
      status, rawShip.trackings, rawShip.carrier)
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
    return {
      shopKey: 'kaufland', shopLabel: 'Kaufland',
      orderId, product, quantity,
      total, currency, tracking, trackings, carrier, status,
    }
  },
}

const REGISTRY: Adapter[] = [
  amazon, mediamarkt, saturn, pccomponentes, xkom, kaufland,
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
///   1. Bekannter Shop + Order-Subject → speichern (Adapter parst später).
///   2. Bekannter Shop + Promo-Subject → skippen.
///   3. Unbekannter Shop + Order-Subject → speichern, landet als
///      "unclassified" (User kann manuell daraus einen Deal machen).
///   4. Unbekannter Shop + generisches Subject → skippen (Newsletter etc.).
export function shouldStore(ctx: MailContext): boolean {
  for (const adapter of REGISTRY) {
    if (adapter.matches(ctx)) {
      return adapter.looksLikeOrder(ctx)
    }
  }
  return isOrderishSubject(ctx.subject)
}

export const ADAPTER_KEYS = REGISTRY.map((a) => a.key)
