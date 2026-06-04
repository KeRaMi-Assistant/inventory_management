// Tracking-Detection — algorithmischer Detektor (DHL / Amazon / DPD).
//
// Self-contained Modul (Plan 2026-06-03 §2, Task T2). Importiert nur:
//   - Checksum-Primitiven aus `tracking_checksums.ts` (`_internal.*`),
//   - Anchor-Helper + Reject-Konstanten aus `inbox_adapters.ts`
//     (`ANCHOR_WORDS`, `findAnchorBefore`, `MAX_BODY_LEN`, `TrackingCandidate`).
//
// Leitprinzip (User-Direktive): „nichts falsches machen". Ein Falsch-Positiv
// (USt-IdNr./IBAN/Telefon wird zum Tracking) korrumpiert einen echten Deal →
// Falsch-Positive-Budget = 0. Checksum-Fail / Anchor-Miss → DROP, nie raten.
//
// ── Sicherheit / PII ──────────────────────────────────────────────────────
// Dieses Modul loggt NIEMALS rohe Mail-Bodies oder volle Tracking-Nummern.
// `redactTracking()` zeigt höchstens die letzten 4 Zeichen + Pattern-Name.
// REJECT_PATTERNS laufen ausschliesslich auf dem normalisierten 3–30-Zeichen-
// Token (ReDoS-safe), niemals gegen den Body.

import { _internal } from './tracking_checksums.ts'
import {
  ANCHOR_WORDS,
  findAnchorBefore,
  MAX_BODY_LEN,
  type TrackingCandidate,
} from './inbox_adapters.ts'

// Re-export für Konsumenten (T3-Verdrahtung), damit `tracking_detection.ts`
// die alleinige Detection-Schnittstelle bleibt.
export { ANCHOR_WORDS, findAnchorBefore, MAX_BODY_LEN }
export type { TrackingCandidate }

// ── Typen ───────────────────────────────────────────────────────────────────

/** Carrier-IDs (Detection-Scope). Immer lowercase (Plan §2.8 Casing-Fix). */
export type CarrierId = 'dhl' | 'amazon' | 'dpd'

/** Versand-Status (Spiegel von `ParsedOrder.status` in inbox_adapters.ts). */
export type ShipStatus =
  | 'ordered'
  | 'shipped'
  | 'delivered'
  | 'cancelled'
  | 'refunded'

export interface DetectionInput {
  subject: string
  text: string
  html: string
  status: ShipStatus
  /** Absender-Domain (lowercase, ohne `@`), z.B. `amazon.de`. Optional. */
  senderDomain?: string
}

export interface DetectionResult {
  /** Primäres Tracking (höchste Source-Priorität) oder `null`. */
  tracking: string | null
  /** Alle akzeptierten strong-Trackings (deduped by value). */
  trackings: string[]
  /** Carrier des primären Trackings (lowercase) oder `null`. */
  carrier: CarrierId | null
  /** Nur `'strong'` (akzeptiert) oder `'none'`. Kein medium im Output. */
  confidence: 'strong' | 'none'
  /** `true`, wenn akzeptierte Kandidaten existieren, aber kein eindeutiges
   *  strong-Primary (z.B. bare TBA ohne Amazon-Kontext, Cross-Carrier). */
  needsReview: boolean
  /** Forensik: ≤10 akzeptierte Kandidaten. */
  candidates: TrackingCandidate[]
}

// ── ISO-3166 Alpha-2 Country-Set (S10 Länder-Code-Wand) ──────────────────────
// Quelle: `tracking_data/couriers/s10.json` (UPU-Mitgliedsländer, 191 Codes).
// Ein S10 ist NUR gültig, wenn die letzten 2 Buchstaben ein realer Länder-Code
// sind. So fallen VAT-Artefakte mit Fantasie-„Land" (z.B. `…XX`) raus.
// Wichtig: `EL` (Greek-VAT-Prefix) ist KEIN S10-Land (Griechenland = `GR`).
export const ISO_3166_S10: ReadonlySet<string> = new Set([
  'AF', 'AL', 'DZ', 'AO', 'AG', 'AR', 'AM', 'AU', 'AT', 'AZ', 'BS', 'BH', 'BD',
  'BB', 'BY', 'BE', 'BZ', 'BJ', 'BT', 'BO', 'BA', 'BW', 'BR', 'BN', 'BG', 'BF',
  'BI', 'KH', 'CM', 'CA', 'CV', 'CF', 'TD', 'CL', 'CN', 'HK', 'CO', 'KM', 'CG',
  'CR', 'HR', 'CU', 'CY', 'CZ', 'CI', 'KP', 'CD', 'DK', 'DJ', 'DM', 'DO', 'EC',
  'EG', 'SV', 'GQ', 'ER', 'EE', 'ET', 'FJ', 'FI', 'FR', 'GA', 'GM', 'GE', 'DE',
  'GH', 'GB', 'GR', 'GD', 'GT', 'GN', 'GW', 'GY', 'HT', 'HN', 'HU', 'IS', 'IN',
  'ID', 'IR', 'IQ', 'IE', 'IL', 'IT', 'JM', 'JP', 'JO', 'KZ', 'KE', 'KI', 'KR',
  'KW', 'KG', 'LA', 'LV', 'LB', 'LS', 'LR', 'LY', 'LI', 'LT', 'LU', 'MG', 'MW',
  'MY', 'MV', 'ML', 'MT', 'MR', 'MU', 'MX', 'MD', 'MC', 'MN', 'ME', 'MA', 'MZ',
  'MM', 'NA', 'NR', 'NP', 'NL', 'NZ', 'NI', 'NE', 'NG', 'NO', 'OM', 'PK', 'PA',
  'PG', 'PY', 'PE', 'PH', 'PL', 'PT', 'QA', 'RO', 'RU', 'RW', 'KN', 'LC', 'VC',
  'WS', 'SM', 'ST', 'SA', 'SN', 'RS', 'SC', 'SL', 'SG', 'SK', 'SI', 'SB', 'SO',
  'ZA', 'SS', 'ES', 'LK', 'SD', 'SR', 'SZ', 'SE', 'CH', 'SY', 'TJ', 'TZ', 'TH',
  'MK', 'TL', 'TG', 'TO', 'TT', 'TN', 'TR', 'TM', 'TV', 'UG', 'UA', 'AE', 'US',
  'UY', 'UZ', 'VU', 'VA', 'VE', 'VN', 'YE', 'ZM', 'ZW',
])

// EU-VAT-Prefixe (für „leadingPrefix == country AND country ∈ VAT"-Drop, §2.6).
// Plan-Verkürzung {DE,EL,EE,…VAT}: alle 2-Buchstaben-EU-VAT-Codes. `EL`+`EE`
// sind explizit genannt; der Rest deckt die übrigen EU-Mitglieder ab.
const EU_VAT_PREFIXES: ReadonlySet<string> = new Set([
  'DE', 'EL', 'EE', 'AT', 'BE', 'BG', 'CY', 'CZ', 'DK', 'ES', 'FI', 'FR', 'HR',
  'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO', 'SE', 'SI',
  'SK', 'XI', // XI = Nordirland-VAT
])

// ── REJECT_PATTERNS (Plan §2.2) ──────────────────────────────────────────────
// Läuft ZUERST, auf dem normalisierten Token (3–30 chars). Alle `^…$`-anchored
// → O(Token-Länge), ReDoS-sicher. NIEMALS gegen den Body.
export const REJECT_PATTERNS: ReadonlyArray<{ name: string; re: RegExp }> = [
  // ── DER KERN: EU-VAT (DE/EL/EE/…) — exakt 2 Buchstaben + exakt 9 Ziffern.
  //    Ein echtes S10 hat 2 NACHGESTELLTE Land-Buchstaben (13 Zeichen) → matcht
  //    NICHT. Kein gültiges DHL/Amazon/DPD-Format hat ^[A-Z]{2}\d{9}$.
  { name: 'vat_eu', re: /^[A-Z]{2}\d{9}$/ },
  // IBAN (DE = DE + 20 Ziffern; generisch = 2 Buchst + 2 Prüf + 11-30 alnum).
  { name: 'iban_de', re: /^DE\d{20}$/ },
  // Generische IBAN (Nicht-DE): 2 Buchst + 2 Prüf + 11-30 alnum. DE ist
  // AUSGENOMMEN (negative Lookahead `(?!DE\d)`), weil DE vollständig von
  // `iban_de` (DE+20) + `vat_eu` (DE+9) abgedeckt ist — sonst würde ein
  // DE+13/14-stelliges Tracking (DE-Prefix-Format) fälschlich als IBAN
  // gerejected.
  { name: 'iban_any', re: /^(?!DE\d)[A-Z]{2}\d{2}[A-Z0-9]{11,30}$/ },
  // Amazon-Order-ID 3-7-7 (kein Tracking).
  { name: 'amazon_order_id', re: /^\d{3}-\d{7}-\d{7}$/ },
  // Telefon — NUR mit literalem '+' (Critique C1-#1 BLOCKER: die lose Variante
  //   ^\+?\d…$ würde JEDE rein-numerische Sendungsnummer rejecten → niemals
  //   digit-count-basiert rejecten).
  { name: 'phone_intl', re: /^\+\d{2,4}\d{3,}$/ },
  { name: 'plz_phone_combo', re: /^\d{5}\s\d{6,12}$/ },
  { name: 'plz_only', re: /^\d{5}$/ },
  // Zu kurz: echte in-scope Numerik ist ≥12 Ziffern.
  { name: 'too_short_numeric', re: /^\d{1,7}$/ },
  { name: 'generic_order_3block', re: /^\d{6}-\d{6}-\d{6}$/ },
]

/**
 * Prüft einen bereits normalisierten Token gegen REJECT_PATTERNS.
 * @returns Reject-Pattern-Name (z.B. `'vat_eu'`) oder `null` (nicht rejected).
 */
export function checkReject(token: string | null | undefined): string | null {
  if (!token || typeof token !== 'string') return null
  // Length-Cap als ReDoS-Schutz. 3–34 deckt alle Reject-Formate
  // (`vat_eu`=11, `iban_any`≤34, `plz_phone_combo`≤18 inkl. Space).
  if (token.length < 3 || token.length > 34) return null
  for (const p of REJECT_PATTERNS) {
    if (p.re.test(token)) return p.name
  }
  return null
}

// ── Normalisierung ───────────────────────────────────────────────────────────

/** Whitespace strippen + uppercase (für Reject-Check + Klassifikation). */
function normalizeToken(raw: string): string {
  return raw.replace(/\s+/g, '').toUpperCase()
}

/** PII-armes Logging: nur die letzten 4 Zeichen sichtbar. */
export function redactTracking(value: string): string {
  if (!value) return '∅'
  if (value.length <= 4) return `…${value}`
  return `…${value.slice(-4)}`
}

// Lokales stripHtml (inbox_adapters.ts exportiert es nicht). Verhalten identisch
// zur dortigen Helper-Funktion.
function stripHtml(html: string): string {
  if (!html) return ''
  return html
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
}

// ── Validator-IDs ────────────────────────────────────────────────────────────
type ValidatorId =
  | 'jjd-prefix'
  | 's10-checksum'
  | 'dhl20-mod10'
  | 'dhl-identcode-mod10'
  | 'de-prefix'
  | 'tba-source-gate'
  | 'dpd-name-anchor'
  | 'amazon-shipment-id'

// ── Strong-Pattern (alpha-präfigiert / format-eindeutig) — Plan §2.3 ─────────
interface BodyPattern {
  id: string
  re: RegExp
  carrier: CarrierId
  requiresAnchor: boolean
  validator: ValidatorId
}

const STRONG_PATTERNS: ReadonlyArray<BodyPattern> = [
  // DHL JJD / JVGL / J[A-Z]{2,3} — 3-4 Buchstaben Prefix, kann nie VAT sein.
  {
    id: 'dhl-jjd',
    re: /\bJ[A-Z]{2,3}\d{10,21}\b/g,
    carrier: 'dhl',
    requiresAnchor: false,
    validator: 'jjd-prefix',
  },
  // DHL S10 international: 2 Service + 9 Ziffern + 2 ISO-Land (13 Zeichen).
  {
    id: 'dhl-s10',
    re: /\b[A-Z]{2}\d{9}[A-Z]{2}\b/g,
    carrier: 'dhl',
    requiresAnchor: true,
    validator: 's10-checksum',
  },
  // Amazon Logistics: TB[ACM] + exakt 12 Ziffern (15 Zeichen). KEINE Checksum.
  {
    id: 'amazon-tba',
    re: /\bTB[ACM]\d{12}\b/g,
    carrier: 'amazon',
    requiresAnchor: false,
    validator: 'tba-source-gate',
  },
  // DE-Prefix-Tracking: `DE` + 10–14 Ziffern (Amazon-Logistics-DE /
  // Deutsche-Post-DHL-National). DAS ist das dominante reale Format dieses
  // Postfachs (verifiziert 2026-06-03: 30 Deals + 30 Amazon-Mails = DE+10).
  // ABGRENZUNG zur USt-IdNr: VAT = `DE` + EXAKT 9 Ziffern (11 Zeichen) →
  // wird von `vat_eu` (^[A-Z]{2}\d{9}$) gerejected; dieses Pattern startet bei
  // 10 Ziffern, matcht also NIE eine VAT. DE-IBAN (DE+20) ist via `iban_de`
  // abgedeckt und durch die Längenobergrenze (14) ausgeschlossen. Keine
  // öffentliche Checksum. ANCHOR PFLICHT (Fix 2026-06-04, Audit-Finding): ohne
  // Checksum ist `DE`+10-14 sonst ununterscheidbar von Kunden-/Referenz-/
  // Vertragsnummern (`Kundennummer: DE1234567890`) → Falsch-Positiv auf einem
  // echten Deal (verletzt „Falsch-Positive-Budget = 0"). Mit requiresAnchor wird
  // nur akzeptiert, wenn ein Tracking-Anchor (Sendungsnummer/Tracking/…) im
  // 80-Zeichen-Fenster davor steht — reale Amazon-/DHL-DE-Mails ("Your tracking
  // number is: DE…", "Sendungsnummer: DE…") erfüllen das; ein „Kundennummer:"-
  // Footer nicht (kein Tracking-Anchor).
  {
    id: 'dhl-de',
    re: /\bDE\d{10,14}\b/g,
    carrier: 'dhl',
    requiresAnchor: true,
    validator: 'de-prefix',
  },
]

// ── Anchor-gated numerische Pattern — Plan §2.5 (requiresAnchor: true) ────────
const ANCHORED_PATTERNS: ReadonlyArray<BodyPattern> = [
  // DHL 20-stellig — mod-10 3/1.
  {
    id: 'dhl-20',
    re: /\b\d{20}\b/g,
    carrier: 'dhl',
    requiresAnchor: true,
    validator: 'dhl20-mod10',
  },
  // DHL 12-stellig Identcode — mod-10 4/9.
  {
    id: 'dhl-12',
    re: /\b\d{12}\b/g,
    carrier: 'dhl',
    requiresAnchor: true,
    validator: 'dhl-identcode-mod10',
  },
  // DPD 14-stellig — NUR via href (§2.4) oder expliziten „DPD"-Anchor; nie aus
  // reiner 14-stelliger Zahl (kollidiert mit DHL). Gate nur über URL/Anchor.
  {
    id: 'dpd-14',
    re: /\b\d{14}\b/g,
    carrier: 'dpd',
    requiresAnchor: true,
    validator: 'dpd-name-anchor',
  },
]

// ── HTML-href-Pattern (Carrier-Domain → strong) — Plan §2.4 ──────────────────
interface HrefPattern {
  re: RegExp
  carrier: CarrierId
  source: 'html-href' | 'amazon-shipment-id'
}

const HREF_PATTERNS: ReadonlyArray<HrefPattern> = [
  // Amazon: nur TB[ACM]\d{12} aus dem Pfad promoten; sonst „Amazon erkannt,
  //   Tracking unbekannt" (kein Capture).
  { re: /track\.amazon\.[a-z.]+\/(?:tracking\/)?(TB[ACM]\d{12})\b/i, carrier: 'amazon', source: 'html-href' },
  { re: /[?&]trackingId=(TB[ACM]\d{12})\b/i, carrier: 'amazon', source: 'html-href' },
  // orderingShipmentId bleibt medium / amazon-shipment-id, NIE primary.
  { re: /[?&]orderingShipmentId=(\d{8,20})/i, carrier: 'amazon', source: 'amazon-shipment-id' },
  // DHL
  { re: /[?&]piececode=([A-Z0-9]{8,30})/i, carrier: 'dhl', source: 'html-href' },
  { re: /nolp\.dhl\.[a-z.]+\/.*?[?&]idc=([A-Z0-9]{10,30})/i, carrier: 'dhl', source: 'html-href' },
  { re: /dhl\.[a-z.]+\/.*?\/track[^?]*\?(?:trackingNumber|tracking)=([A-Z0-9]{8,30})/i, carrier: 'dhl', source: 'html-href' },
  // DPD — inkl. der ?query=-Form, die die App selbst erzeugt.
  { re: /tracking\.dpd\.[a-z.]+\/parcelstatus\?(?:[^&]*&)*query=(\d{10,20})/i, carrier: 'dpd', source: 'html-href' },
  { re: /dpd\.[a-z.]+\/.*?[?&]parcelno(?:r)?=(\d{10,20})/i, carrier: 'dpd', source: 'html-href' },
  { re: /(?:track\.)?dpd\.[a-z.]+\/parcels?\/(\d{10,20})/i, carrier: 'dpd', source: 'html-href' },
]

// Amazon-Kontext-Token (für tba-source-gate Variante 3).
const AMAZON_CONTEXT_RE = /\bamazon(?:\.[a-z]{2,3})?\b|\bamazon\s+logistics\b/i

// ── Interne Klassifikations-Repräsentation ──────────────────────────────────
type Outcome = 'strong' | 'medium' | 'drop'

interface RawMatch {
  value: string // normalisiert
  raw: string
  carrier: CarrierId
  validator: ValidatorId
  source: TrackingCandidate['source']
  anchor: string | null
  patternId: string
  /** `true`, wenn Absender-Domain ∈ amazon.<tld> (für tba-source-gate). */
  senderDomainMatch?: boolean
  /** `true`, wenn „DPD" im 80-Zeichen-Fenster vor dem Match steht (dpd-14). */
  dpdNameInWindow?: boolean
}

interface ClassifyContext {
  /** Amazon-Kontext im Body / Absender (für tba-source-gate Variante 3). */
  hasAmazonContext: boolean
}

// ── classifyAndValidate (Plan §2.6) ──────────────────────────────────────────
// Deterministisch: Validator BESTÄTIGT (→ strong), ist prefix-/source-eindeutig
// (→ strong), oder SCHEITERT (→ drop, nie geraten).
function classifyAndValidate(
  m: RawMatch,
  ctx: ClassifyContext,
): { outcome: Outcome; checksumValid?: boolean } {
  switch (m.validator) {
    case 'jjd-prefix': {
      // J[A-Z]{2,3}\d{10,21} — keine öffentliche Checksum; 3+ Buchstaben → nie VAT.
      return { outcome: 'strong' }
    }

    case 's10-checksum': {
      // [A-Z]{2}\d{9}[A-Z]{2}, requiresAnchor=true.
      const v = m.value
      if (v.length !== 13) return { outcome: 'drop' }
      const leadingPrefix = v.slice(0, 2)
      const country = v.slice(11, 13)
      // Land = letzte 2 Buchstaben muss real sein.
      if (!ISO_3166_S10.has(country)) return { outcome: 'drop' }
      // VAT+Land-Artefakt: `DE123456789DE` → leadingPrefix == country ∈ VAT → DROP.
      if (leadingPrefix === country && EU_VAT_PREFIXES.has(country)) {
        return { outcome: 'drop' }
      }
      const body9 = v.slice(2, 11) // 9 Ziffern nach den 2 Service-Buchstaben
      const serial = body9.slice(0, 8)
      const check = body9.slice(8)
      const ok = _internal.checkS10(serial, check)
      return ok ? { outcome: 'strong', checksumValid: true } : { outcome: 'drop', checksumValid: false }
    }

    case 'dhl20-mod10': {
      // \d{20}, requiresAnchor=true. mod-10 3/1.
      const v = m.value
      if (v.length !== 20 || !/^\d{20}$/.test(v)) return { outcome: 'drop' }
      const ok = _internal.checkMod10(v.slice(0, 19), v.slice(19), {
        name: 'mod10',
        evens_multiplier: 3,
        odds_multiplier: 1,
      })
      return ok ? { outcome: 'strong', checksumValid: true } : { outcome: 'drop', checksumValid: false }
    }

    case 'dhl-identcode-mod10': {
      // \d{12}, requiresAnchor=true. mod-10 4/9.
      const v = m.value
      if (v.length !== 12 || !/^\d{12}$/.test(v)) return { outcome: 'drop' }
      const ok = _internal.checkMod10(v.slice(0, 11), v.slice(11), {
        name: 'mod10',
        evens_multiplier: 4,
        odds_multiplier: 9,
      })
      return ok ? { outcome: 'strong', checksumValid: true } : { outcome: 'drop', checksumValid: false }
    }

    case 'de-prefix': {
      // DE + 10–14 Ziffern. Keine öffentliche Checksum; format-eindeutig
      // (VAT = DE+9 ist schon per Reject raus, IBAN = DE+20 per Reject/Länge).
      // DE+10–14 in einer Versandmail ist das Amazon-/DHL-DE-Tracking.
      const v = m.value
      if (!/^DE\d{10,14}$/.test(v)) return { outcome: 'drop' }
      return { outcome: 'strong' }
    }

    case 'tba-source-gate': {
      // TB[ACM]\d{12} — KEINE Checksum. Sicheres Gate:
      //   - source == html-href (track.amazon / trackingId=)            ODER
      //   - Mail-Absender-Domain ∈ @amazon.<tld>                        ODER
      //   - (Tracking-Anchor im Fenster UND Amazon-Kontext-Token).
      const fromHref = m.source === 'html-href'
      const fromSender = !!m.senderDomainMatch
      const fromAnchorCtx = !!m.anchor && ctx.hasAmazonContext
      if (fromHref || fromSender || fromAnchorCtx) {
        return { outcome: 'strong' }
      }
      // bare TBA in Nicht-Amazon-Mail → MEDIUM + needs_review.
      return { outcome: 'medium' }
    }

    case 'dpd-name-anchor': {
      // \d{14} aus href ODER mit DPD-spezifischem Anchor.
      // DPD-href → strong. Sonst: „DPD" muss explizit im Fenster vor dem Match
      //   stehen (m.dpdNameInWindow). „DPD" ist KEIN generisches ANCHOR_WORD —
      //   ein bloßes „Paketnummer" reicht NICHT (kollidiert mit DHL, §2.6).
      const fromHref = m.source === 'html-href'
      if (fromHref || m.dpdNameInWindow) {
        return { outcome: 'strong' }
      }
      // bare \d{14} fällt NICHT automatisch auf DPD → DROP als DPD.
      return { outcome: 'drop' }
    }

    case 'amazon-shipment-id': {
      // orderingShipmentId — bleibt medium, NIE primary (Gating filtert es raus).
      return { outcome: 'medium' }
    }

    default:
      return { outcome: 'drop' }
  }
}

// ── Source-Priorität (html-href > strong-pattern > anchored) ─────────────────
function sourcePriority(source: TrackingCandidate['source']): number {
  switch (source) {
    case 'html-href': return 3
    case 'strong-pattern': return 2
    case 'context-anchor': return 1
    default: return 0
  }
}

// ── Match-Sammlung: Body-Text (numerisch/S10/strong) ─────────────────────────
function collectBodyMatches(
  bodyText: string,
  senderIsAmazon: boolean,
): RawMatch[] {
  const out: RawMatch[] = []
  const allPatterns = [...STRONG_PATTERNS, ...ANCHORED_PATTERNS]
  for (const p of allPatterns) {
    const re = new RegExp(p.re.source, 'g')
    let m: RegExpExecArray | null
    while ((m = re.exec(bodyText)) !== null) {
      const raw = m[0]
      const value = normalizeToken(raw)
      const anchor = findAnchorBefore(bodyText, m.index)
      // requiresAnchor: ohne Anchor kein Body-Match (numerisch + S10).
      if (p.requiresAnchor && !anchor) continue
      // Für dpd-14: prüfe, ob „DPD" explizit im 80-Zeichen-Fenster davor steht
      //   („DPD" ist kein generisches ANCHOR_WORD).
      const winStart = Math.max(0, m.index - 80)
      const dpdNameInWindow = p.id === 'dpd-14'
        ? /\bdpd\b/i.test(bodyText.slice(winStart, m.index))
        : undefined
      out.push({
        value,
        raw,
        carrier: p.carrier,
        validator: p.validator,
        source: p.requiresAnchor ? 'context-anchor' : 'strong-pattern',
        anchor,
        patternId: p.id,
        senderDomainMatch: senderIsAmazon,
        dpdNameInWindow,
      })
    }
  }
  return out
}

// ── Match-Sammlung: HTML-hrefs (raw HTML, separat) ───────────────────────────
//
// Recall-Fix (Review T6): Amazon-Versandmails wrappen die echte Carrier-URL
// häufig in einen Redirect der Form
//   `amazon.<tld>/gp/f.html?...&U=https%3A%2F%2Ftrack.amazon.de%2Ftracking%2FTBA…`
// — die Ziel-URL (track.amazon, trackingId, orderingShipmentId) steht dort
// also URL-ENCODED. Die HREF_PATTERNS matchen die encodete Form nicht. Wir
// scannen daher zusätzlich eine EINMAL URL-dekodierte Variante des HTMLs
// (best-effort, try/catch). Das ist exakt das historische Pattern aus
// `inbox_adapters.ts::findTrackingsInHtml` (`&U=`-Extraktion + decode), nur
// schlank auf den href-Scan reduziert — KEIN body-weiter Decode der
// numerischen Pfade, daher kein neuer Falsch-Positiv (die VAT-Wall + numeric
// Reject-Logik in collectBodyMatches bleiben unberührt).
function collectHrefMatches(rawHtml: string, senderIsAmazon: boolean): RawMatch[] {
  if (!rawHtml) return []

  // Decode-Varianten: roh + (falls `%` vorhanden) einmal URL-dekodiert.
  // decodeURIComponent ist best-effort; bei Malformed-Escape → rohe Form.
  const variants: string[] = [rawHtml]
  if (rawHtml.includes('%')) {
    try {
      const decoded = decodeURIComponent(rawHtml)
      if (decoded !== rawHtml) variants.push(decoded)
    } catch {
      /* malformed escape → nur rohe Variante scannen */
    }
  }

  const out: RawMatch[] = []
  // Dedupe per normalisiertem Value + Carrier: derselbe Treffer aus roher und
  // dekodierter Variante (oder doppelter Pattern-Treffer) erzeugt nur EINEN
  // Candidate. Carrier ist Teil des Keys, damit ein identischer numerischer
  // Wert für unterschiedliche Carrier nicht fälschlich kollabiert.
  const seen = new Set<string>()
  for (const haystack of variants) {
    for (const p of HREF_PATTERNS) {
      const re = new RegExp(p.re.source, p.re.flags.includes('g') ? p.re.flags : p.re.flags + 'g')
      let m: RegExpExecArray | null
      while ((m = re.exec(haystack)) !== null) {
        const captured = m[1]
        if (!captured) continue
        const value = normalizeToken(captured)
        const dedupeKey = `${p.carrier}:${p.source}:${value}`
        if (seen.has(dedupeKey)) continue
        seen.add(dedupeKey)
        const validator: ValidatorId = p.source === 'amazon-shipment-id'
          ? 'amazon-shipment-id'
          : p.carrier === 'amazon'
            ? 'tba-source-gate'
            : p.carrier === 'dpd'
              ? 'dpd-name-anchor'
              : 'jjd-prefix' // dhl href-capture: source-eindeutig (Domain) → strong
        out.push({
          value,
          raw: captured,
          carrier: p.carrier,
          validator,
          source: p.source,
          anchor: null,
          patternId: `href-${p.carrier}`,
          senderDomainMatch: senderIsAmazon,
        })
      }
    }
  }
  return out
}

function toCandidate(m: RawMatch, confidence: TrackingCandidate['confidence'], checksumValid?: boolean): TrackingCandidate {
  return {
    value: m.value,
    rawValue: m.raw,
    carrier: m.carrier,
    source: m.source,
    confidence,
    validation: {
      anchorMatched: m.anchor ?? undefined,
      checksumValid,
      normalized: m.raw !== m.value,
      patternId: m.patternId,
    },
  }
}

// ── detect (Plan §2.7) — „right or none, never random" ───────────────────────
export function detect(input: DetectionInput): DetectionResult {
  const NONE: DetectionResult = {
    tracking: null,
    trackings: [],
    carrier: null,
    confidence: 'none',
    needsReview: false,
    candidates: [],
  }

  // Tracking nur bei shipped/delivered.
  if (input.status === 'ordered' || input.status === 'cancelled' || input.status === 'refunded') {
    return NONE
  }

  // Scan-Haystack: sichtbarer Body-Text (subject + text + stripHtml(html)),
  // gecappt auf MAX_BODY_LEN. KEIN globaler Whitespace-Strip + Re-Scan.
  const rawBody = `${input.subject}\n${input.text}\n${stripHtml(input.html)}`
  const bodyText = rawBody.length > MAX_BODY_LEN ? rawBody.slice(0, MAX_BODY_LEN) : rawBody
  const rawHtml = (input.html ?? '').slice(0, MAX_BODY_LEN)

  const senderIsAmazon = !!input.senderDomain && /(?:^|\.)amazon\.[a-z.]+$/i.test(input.senderDomain)
  const hasAmazonContext = senderIsAmazon || AMAZON_CONTEXT_RE.test(bodyText)

  // 1) Kandidaten sammeln (Body strong/anchored + hrefs separat).
  const rawMatches: RawMatch[] = [
    ...collectBodyMatches(bodyText, senderIsAmazon),
    ...collectHrefMatches(rawHtml, senderIsAmazon),
  ]

  // 2) Reject-Filter auf normalisiertem Token (vor Klassifikation).
  const surviving = rawMatches.filter((m) => checkReject(m.value) === null)

  // 3) Klassifizieren + validieren.
  const accepted: TrackingCandidate[] = []
  for (const m of surviving) {
    const { outcome, checksumValid } = classifyAndValidate(m, { hasAmazonContext })
    if (outcome === 'drop') continue
    const conf: TrackingCandidate['confidence'] = outcome === 'strong' ? 'strong' : 'medium'
    accepted.push(toCandidate(m, conf, checksumValid))
  }

  // 4) Strong-Filter: nur strong, kein amazon-shipment-id.
  const strong = accepted.filter(
    (c) => c.confidence === 'strong' && c.source !== 'amazon-shipment-id',
  )

  const candidatesOut = accepted.slice(0, 10)

  if (strong.length === 0) {
    // needsReview, wenn shipped/delivered + akzeptierte (medium) Kandidaten da.
    const needsReview = accepted.length > 0
    return { ...NONE, needsReview, candidates: candidatesOut }
  }

  // 5) Dedupe by value, dann Cross-Carrier-Widerspruch prüfen.
  const byValue = new Map<string, TrackingCandidate>()
  for (const c of strong) {
    const existing = byValue.get(c.value)
    if (!existing || sourcePriority(c.source) > sourcePriority(existing.source)) {
      byValue.set(c.value, c)
    }
  }
  const unique = [...byValue.values()]
  const carriers = new Set(unique.map((c) => c.carrier))
  if (carriers.size > 1) {
    // Cross-Carrier-Widerspruch → lieber keins als falsch.
    return { ...NONE, needsReview: true, candidates: candidatesOut }
  }

  // 6) Primary by source priority (html-href > strong-pattern).
  const primary = unique.reduce((best, c) =>
    sourcePriority(c.source) > sourcePriority(best.source) ? c : best
  )

  return {
    tracking: primary.value,
    trackings: unique.map((c) => c.value),
    carrier: (primary.carrier as CarrierId) ?? null,
    confidence: 'strong',
    needsReview: false,
    candidates: candidatesOut,
  }
}
