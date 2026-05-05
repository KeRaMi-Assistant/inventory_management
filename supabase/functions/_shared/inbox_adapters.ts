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
  tracking?: string
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
const trackingRe = /\b(1Z[A-Z0-9]{16}|[A-Z]{2}\d{9,12}[A-Z]{2}|JJD\d{10,18}|\d{20,22}|\d{12,14})\b/

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

const findTracking = (s: string): { tracking?: string; carrier?: string } => {
  const m = trackingRe.exec(s)
  if (!m) return {}
  const tn = m[1]
  let carrier: string | undefined
  if (/^1Z/.test(tn)) carrier = 'UPS'
  else if (/^JJD/.test(tn) || /\bdhl\b/i.test(s)) carrier = 'DHL'
  else if (/^[A-Z]{2}\d{9}DE$/.test(tn)) carrier = 'DHL'
  else if (/\bhermes\b/i.test(s)) carrier = 'Hermes'
  else if (/\bdpd\b/i.test(s)) carrier = 'DPD'
  else if (/\bgls\b/i.test(s)) carrier = 'GLS'
  else if (/\binpost\b/i.test(s)) carrier = 'InPost'
  return { tracking: tn, carrier }
}

const isShipped = (s: string): boolean =>
  /(versandt|verschickt|on its way|shipped|unterwegs|wir haben.*versen|wurde versendet|enviado|wysłan|wysylk|wysyłk)/i.test(s)

const isDelivered = (s: string): boolean =>
  /(zugestellt|delivered|angekommen|entregad|dostarczon)/i.test(s)

const isCancelled = (s: string): boolean =>
  /(storniert|cancell|anulado|anulowan|widerrufen)/i.test(s)

const isRefunded = (s: string): boolean =>
  /(erstattung|refund|rückerstattung|reembols|zwrot)/i.test(s)

// Subjects, die garantiert KEINE Order sind (Promo/Newsletter/Account-Stuff).
const isOrderishSubject = (subject: string): boolean => {
  const s = subject.toLowerCase()
  // Hard skip: Promo / Newsletter / Account-Verwaltung
  if (/\b(angebot|newsletter|spare|prozent|sale|promotion|deal des tages|wartet auf dich|sichern|profitieren|benutzerverwaltung|update|empfehl|inspirat|prime[- ]?duo|hinzufügen|jetzt entdecken|tipps|spotlight|black friday|cyber monday)/i.test(s)) return false
  // Whitelist-Pattern: typische Order-Mail-Subjects
  return /\b(bestell|order|auftrag|versand|lieferung|tracking|zustell|sendung|paket|stornier|widerruf|erstattung|gutschrift|rechnung|invoice|frankierung|shipping|shipped|delivery|envío|zamówieni|wysył|dostaw)/i.test(s)
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
    const product = findFirst(s, [
      /(?:bestellt|ordered|gekauft)[:\s]+["“]?([^"”\n]{4,140})["”]?/i,
      /Lieferung von:?\s*([^\n]{4,140})/i,
    ])
    const qty = Number(/(?:Menge|Anzahl|Quantity)\s*[:\s]+(\d{1,3})/i.exec(s)?.[1] ?? '1')
    const totalSrc = /(?:Gesamtsumme|Order Total|Zwischensumme|Total)[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { tracking, carrier } = findTracking(s)
    const status = isCancelled(s) ? 'cancelled'
      : isRefunded(s) ? 'refunded'
      : isDelivered(s) ? 'delivered'
      : isShipped(s) || tracking ? 'shipped'
      : 'ordered'
    if (!orderId && !product && !tracking) return null
    return {
      shopKey: 'amazon', shopLabel: 'Amazon',
      orderId, product, quantity: Math.max(1, qty),
      total, currency, tracking, carrier, status,
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
    const product = findFirst(s, [
      /Artikel\s*[:\s]+([^\n]{4,140})/i,
      /Produkt\s*[:\s]+([^\n]{4,140})/i,
    ])
    const totalSrc = /(?:Gesamtsumme|Summe|Total|Rechnungsbetrag)[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { tracking, carrier } = findTracking(s)
    const status = isCancelled(s) ? 'cancelled'
      : isRefunded(s) ? 'refunded'
      : isDelivered(s) ? 'delivered'
      : isShipped(s) || tracking ? 'shipped'
      : 'ordered'
    if (!orderId && !tracking) return null
    return {
      shopKey: 'mediamarkt', shopLabel: 'MediaMarkt',
      orderId, product, quantity: 1,
      total, currency, tracking, carrier, status,
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
    const product = findFirst(s, [/Artikel\s*[:\s]+([^\n]{4,140})/i])
    const totalSrc = /(?:Gesamtsumme|Summe|Total|Rechnungsbetrag)[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { tracking, carrier } = findTracking(s)
    const status = isCancelled(s) ? 'cancelled'
      : isRefunded(s) ? 'refunded'
      : isDelivered(s) ? 'delivered'
      : isShipped(s) || tracking ? 'shipped'
      : 'ordered'
    if (!orderId && !tracking) return null
    return {
      shopKey: 'saturn', shopLabel: 'Saturn',
      orderId, product, quantity: 1,
      total, currency, tracking, carrier, status,
    }
  },
}

// ── PcComponentes ──────────────────────────────────────────────────────
const pccomponentes: Adapter = {
  key: 'pccomponentes',
  label: 'PcComponentes',
  matches: (ctx) => /(@|\.)pccomponentes\.(com|es|fr|it|pt)\b/i.test(ctx.from),
  looksLikeOrder: (ctx) => isOrderishSubject(ctx.subject),
  parse: (ctx) => {
    const s = haystack(ctx)
    const orderId = findFirst(s, [
      /(?:n[uú]mero de )?pedido\s*[:#]?\s*([A-Z0-9-]{6,25})/i,
      /Order\s*number\s*[:#]?\s*([A-Z0-9-]{6,25})/i,
      /\b(PC[A-Z0-9-]{6,20})\b/,
    ])
    const product = findFirst(s, [
      /Producto\s*[:\s]+([^\n]{4,140})/i,
      /Artículo\s*[:\s]+([^\n]{4,140})/i,
      /Item\s*[:\s]+([^\n]{4,140})/i,
    ])
    const totalSrc = /(?:Total|Importe)[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { tracking, carrier } = findTracking(s)
    const status = isCancelled(s) ? 'cancelled'
      : isRefunded(s) ? 'refunded'
      : isDelivered(s) ? 'delivered'
      : isShipped(s) || tracking ? 'shipped'
      : 'ordered'
    if (!orderId && !tracking) return null
    return {
      shopKey: 'pccomponentes', shopLabel: 'PcComponentes',
      orderId, product, quantity: 1,
      total, currency: currency === 'EUR' ? 'EUR' : currency,
      tracking, carrier, status,
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
    const product = findFirst(s, [
      /Produkt\s*[:\s]+([^\n]{4,140})/i,
      /Towar\s*[:\s]+([^\n]{4,140})/i,
      /Artikel\s*[:\s]+([^\n]{4,140})/i,
    ])
    const totalSrc = /(?:Suma|Razem|Wartość|Total)[:\s]+([^\n]{1,40})/i.exec(s)?.[1] ?? ''
    const { total, currency } = parseMoney(totalSrc)
    const { tracking, carrier } = findTracking(s)
    const status = isCancelled(s) ? 'cancelled'
      : isRefunded(s) ? 'refunded'
      : isDelivered(s) ? 'delivered'
      : isShipped(s) || tracking ? 'shipped'
      : 'ordered'
    if (!orderId && !tracking) return null
    return {
      shopKey: 'xkom', shopLabel: 'x-kom',
      orderId, product, quantity: 1,
      total, currency: currency === 'EUR' ? 'PLN' : currency, // x-kom default PLN
      tracking, carrier, status,
    }
  },
}

const REGISTRY: Adapter[] = [
  amazon, mediamarkt, saturn, pccomponentes, xkom,
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
export function shouldStore(ctx: MailContext): boolean {
  for (const adapter of REGISTRY) {
    if (!adapter.matches(ctx)) continue
    return adapter.looksLikeOrder(ctx)
  }
  return false
}

export const ADAPTER_KEYS = REGISTRY.map((a) => a.key)
