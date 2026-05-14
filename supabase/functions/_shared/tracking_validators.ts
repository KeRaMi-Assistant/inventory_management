// Dünner Deno-Interpreter für die jkeen-Tracking-Number-JSON-Specs unter
// `tracking_data/couriers/*.json`. Implementiert Regex-Match + Checksum-
// Validierung (mod10, mod7, s10, sum_product_with_weightings_and_modulo,
// luhn). Wird in T3b/T3c von den Inbox-Adaptern als strict-extraction-
// Stage verwendet.
//
// API:
//   - loadCarrierSpecs(): Promise<CarrierSpec[]>  (lazy, cached)
//   - validateTrackingNumber(value): Promise<ValidationResult>
//
// NICHT implementiert (Followup T2b-followup):
//   - `additional`-Block-Lookups (Service-Type-Lookups, Country-Code-Lookups,
//     `exists`-Validierungen wie S10/Courier). Ein-paar Test-Numbers schlagen
//     deshalb fehl, die schmaler-Match-only fokussiert ist. Wir loggen sie
//     in Tests, brechen aber nicht ab.
//   - `serial_number_format.prepend_if` (FedEx SmartPost).
//   - `partners`-Linking + `partner_id`-Cross-Refs.

import { dirname, fromFileUrl, join } from 'https://deno.land/std@0.224.0/path/mod.ts'

const COURIERS_DIR = new URL('./tracking_data/couriers/', import.meta.url)
const COURIER_FILES = [
  'amazon.json',
  'canadapost.json',
  'dhl.json',
  'dpd.json',
  'fedex.json',
  'landmark.json',
  'lasership.json',
  'old_dominion.json',
  'ontrac.json',
  's10.json',
  'ups.json',
  'usps.json',
]

export type ChecksumName =
  | 'mod10'
  | 'mod7'
  | 's10'
  | 'sum_product_with_weightings_and_modulo'
  | 'luhn'
  | 'mod_37_36'

export interface ChecksumSpec {
  name: ChecksumName
  evens_multiplier?: number
  odds_multiplier?: number
  weightings?: number[]
  modulo?: number
  modulo1?: number
  modulo2?: number
  reverse?: boolean
}

export interface SerialFormatSpec {
  prependIfMatchesRegex?: RegExp
  prependContent?: string
}

export interface PatternSpec {
  description: string
  id?: string
  regex: RegExp
  rawRegex: string
  validation?: ChecksumSpec
  serialFormat?: SerialFormatSpec
  testValid: string[]
  testInvalid: string[]
}

export interface CarrierSpec {
  carrier: string
  carrierSlug: string
  patterns: PatternSpec[]
}

export interface ValidationResult {
  isValid: boolean
  carrier?: string
  carrierSlug?: string
  matchedPattern?: string
  checksumName?: string
  checksumValid?: boolean
  serial?: string
  /**
   * Wenn mehrere Pattern matchen und keiner durch Checksum-Disambiguation
   * eindeutig gewinnt, listen wir alle Kandidaten — und `carrier` bleibt
   * `'ambiguous'`. Konsumenten sollen in dem Fall KEINEN Carrier annehmen
   * (lieber "kein Tracking" als falscher Carrier).
   */
  ambiguous?: boolean
  candidates?: Array<{
    carrier: string
    carrierSlug: string
    matchedPattern: string
    checksumName?: string
    checksumValid?: boolean | null
  }>
}

let _specsCache: CarrierSpec[] | null = null

// ---- Loader -----------------------------------------------------------------

export async function loadCarrierSpecs(): Promise<CarrierSpec[]> {
  if (_specsCache) return _specsCache
  const specs: CarrierSpec[] = []
  for (const file of COURIER_FILES) {
    const url = new URL(file, COURIERS_DIR)
    const text = await Deno.readTextFile(url)
    const json = JSON.parse(text)
    const carrierSlug = file.replace(/\.json$/, '')
    const patterns: PatternSpec[] = []
    for (const t of (json.tracking_numbers ?? [])) {
      const rawRegex = Array.isArray(t.regex) ? t.regex.join('') : t.regex
      if (!rawRegex) continue
      let regex: RegExp
      try {
        // Wrap mit ^…$ damit Whole-String-Match.
        regex = new RegExp(`^${rawRegex}$`)
      } catch (_e) {
        continue // ungültiger Regex → Pattern überspringen
      }
      const prependIf = t.validation?.serial_number_format?.prepend_if
      let serialFormat: SerialFormatSpec | undefined
      if (prependIf?.matches_regex && typeof prependIf.content === 'string') {
        try {
          serialFormat = {
            prependIfMatchesRegex: new RegExp(prependIf.matches_regex),
            prependContent: prependIf.content,
          }
        } catch (_e) {
          serialFormat = undefined
        }
      }
      patterns.push({
        description: t.name ?? t.id ?? '(unnamed)',
        id: t.id,
        regex,
        rawRegex,
        validation: t.validation?.checksum
          ? normalizeChecksum(t.validation.checksum)
          : undefined,
        serialFormat,
        testValid: t.test_numbers?.valid ?? [],
        testInvalid: t.test_numbers?.invalid ?? [],
      })
    }
    specs.push({
      carrier: json.name ?? carrierSlug,
      carrierSlug,
      patterns,
    })
  }
  _specsCache = specs
  return specs
}

function normalizeChecksum(c: Record<string, unknown>): ChecksumSpec {
  return {
    name: c.name as ChecksumName,
    evens_multiplier: c.evens_multiplier as number | undefined,
    odds_multiplier: c.odds_multiplier as number | undefined,
    weightings: c.weightings as number[] | undefined,
    modulo: c.modulo as number | undefined,
    modulo1: c.modulo1 as number | undefined,
    modulo2: c.modulo2 as number | undefined,
    reverse: c.reverse as boolean | undefined,
  }
}

// ---- Validator --------------------------------------------------------------

interface CandidateMatch {
  carrier: string
  carrierSlug: string
  matchedPattern: string
  checksumName?: string
  /** true=valid, false=fail, null=kein Validator vorhanden */
  checksumValid: boolean | null
  serial?: string
}

export async function validateTrackingNumber(
  value: string,
): Promise<ValidationResult> {
  const specs = await loadCarrierSpecs()
  // KEINE harte Whitespace-Normalisierung: viele Patterns enthalten bereits
  // `\s*` zwischen Zeichen. Wir testen 2 Formen: roh + ohne Whitespace.
  const trimmed = value.trim()
  const stripped = trimmed.replace(/\s+/g, '')

  // Sammle ALLE matchenden Patterns, um Multi-Carrier-Ambiguität (z.B.
  // USPS-22 vs DHL/Deutsche-Post-Numeric-20) per Checksum aufzulösen
  // statt den ersten Treffer zu nehmen.
  const matches: CandidateMatch[] = []
  // Dedupe-Set über (carrierSlug, pattern.description, serial) — sonst
  // matched dasselbe Pattern für `trimmed` UND `stripped` doppelt.
  const seen = new Set<string>()

  for (const spec of specs) {
    for (const pattern of spec.patterns) {
      const inputs = [trimmed, stripped]
      for (const candidate of inputs) {
        const m = pattern.regex.exec(candidate)
        if (!m) continue
        const serial = m.groups?.SerialNumber?.replace(/\s+/g, '')
        const dedupeKey = `${spec.carrierSlug}::${pattern.description}::${serial ?? candidate}`
        if (seen.has(dedupeKey)) continue
        seen.add(dedupeKey)
        let checksumValid: boolean | null = null
        if (pattern.validation) {
          checksumValid = runChecksum(pattern.validation, m, candidate, pattern.serialFormat)
        }
        matches.push({
          carrier: spec.carrier,
          carrierSlug: spec.carrierSlug,
          matchedPattern: pattern.description,
          checksumName: pattern.validation?.name,
          checksumValid,
          serial,
        })
      }
    }
  }

  if (matches.length === 0) return { isValid: false }

  // Disambiguation-Strategie:
  //  1) Genau ein Match, der entweder checksum-valid ist ODER keinen
  //     Validator hat → eindeutig.
  //  2) Mehrere Matches: bevorzuge die mit checksumValid === true.
  //     - Genau einer → der gewinnt.
  //     - Mehrere → ambiguous (alle als Kandidaten zurück, KEINEN als
  //       primary auswählen).
  //  3) Keiner mit checksumValid === true:
  //     - Wenn ALLE checksumValid === null (kein Validator) und alle
  //       gehören zu unterschiedlichen Carriern → ambiguous.
  //     - Wenn ALLE checksumValid === null und nur EIN Carrier vertreten
  //       → akzeptiere ihn (Match-only, ohne Checksum).
  //     - Sonst (alle checksumValid === false) → invalid (kein false-
  //       positive, lieber "kein Tracking").
  const passes = matches.filter((m) => m.checksumValid === true)
  if (passes.length === 1) {
    return resultFromMatch(passes[0])
  }
  if (passes.length > 1) {
    // Mehrere Checksum-Winner: nur dann eindeutig, wenn sie alle zum
    // SELBEN Carrier gehören (mehrere Patterns desselben Couriers).
    const carriers = new Set(passes.map((p) => p.carrierSlug))
    if (carriers.size === 1) return resultFromMatch(passes[0])
    return ambiguousResult(passes)
  }
  // Kein Checksum-Winner.
  const noValidator = matches.filter((m) => m.checksumValid === null)
  if (noValidator.length === matches.length) {
    // ALLE ohne Validator → nur als eindeutig akzeptieren wenn ein Carrier.
    const carriers = new Set(matches.map((m) => m.carrierSlug))
    if (carriers.size === 1) return resultFromMatch(matches[0])
    return ambiguousResult(matches)
  }
  // Irgendein Pattern hatte Validator und failed → nicht akzeptieren
  // (auch wenn andere Patterns ohne Validator matchen würden, lieber
  // invalid melden als falschen Carrier).
  return { isValid: false }
}

function resultFromMatch(m: CandidateMatch): ValidationResult {
  return {
    isValid: true,
    carrier: m.carrier,
    carrierSlug: m.carrierSlug,
    matchedPattern: m.matchedPattern,
    checksumName: m.checksumName,
    checksumValid: m.checksumValid === null ? undefined : m.checksumValid,
    serial: m.serial,
  }
}

function ambiguousResult(matches: CandidateMatch[]): ValidationResult {
  return {
    isValid: false,
    carrier: 'ambiguous',
    ambiguous: true,
    candidates: matches.map((m) => ({
      carrier: m.carrier,
      carrierSlug: m.carrierSlug,
      matchedPattern: m.matchedPattern,
      checksumName: m.checksumName,
      checksumValid: m.checksumValid,
    })),
  }
}

// ---- Checksums --------------------------------------------------------------

function runChecksum(
  spec: ChecksumSpec,
  match: RegExpExecArray,
  full: string,
  serialFormat?: SerialFormatSpec,
): boolean {
  const serialRaw = match.groups?.SerialNumber ?? ''
  const checkRaw = match.groups?.CheckDigit ?? ''
  let serial = serialRaw.replace(/\s+/g, '')
  const check = checkRaw.replace(/\s+/g, '')
  if (serialFormat?.prependIfMatchesRegex && serialFormat.prependContent != null) {
    if (serialFormat.prependIfMatchesRegex.test(full.replace(/\s+/g, ''))) {
      serial = serialFormat.prependContent + serial
    }
  }
  switch (spec.name) {
    case 'mod10':
      return checkMod10(serial, check, spec)
    case 'luhn':
      return checkLuhn(serial, check)
    case 'mod7':
      return checkMod7(serial, check)
    case 's10':
      return checkS10(serial, check)
    case 'sum_product_with_weightings_and_modulo':
      return checkSumProduct(serial, check, spec)
    case 'mod_37_36':
      return checkMod37_36(serial, check)
    default:
      return false
  }
}

function digits(s: string): number[] {
  return s.split('').filter((c) => /[0-9]/.test(c)).map((c) => parseInt(c, 10))
}

// Konvertiert ein Zeichen in die mod10-Eingabe-Zahl. Nicht-Numerische
// Zeichen (z.B. UPS-1Z `SerialNumber` enthält Buchstaben) werden per
// `(ord-3) % 10` gemappt — A=2, B=3, …, Z=7 (Konvention aus jkeen).
function charValueForMod10(c: string): number {
  if (/[0-9]/.test(c)) return parseInt(c, 10)
  if (/[A-Za-z]/.test(c)) return (c.toUpperCase().charCodeAt(0) - 3) % 10
  return 0
}

function checkMod10(
  serial: string,
  check: string,
  spec: ChecksumSpec,
): boolean {
  // Whitespace strippen, aber Buchstaben behalten (für UPS-1Z).
  const seq = serial.replace(/\s+/g, '')
  let chars = seq.split('')
  if (spec.reverse) chars = chars.reverse()
  let sum = 0
  for (let i = 0; i < chars.length; i++) {
    let x = charValueForMod10(chars[i])
    // jkeen: i.odd? → odds_multiplier, i.even? → evens_multiplier.
    // i ist 0-indexiert: i=0,2,4… "even"; i=1,3,5… "odd".
    if ((i % 2 === 1) && spec.odds_multiplier != null) x *= spec.odds_multiplier
    else if ((i % 2 === 0) && spec.evens_multiplier != null) x *= spec.evens_multiplier
    sum += x
  }
  let calc = sum % 10
  if (calc !== 0) calc = 10 - calc
  return calc === parseInt(check, 10)
}

function checkLuhn(serial: string, check: string): boolean {
  // jkeen-luhn: serial reversed, i.even (0,2,4…) → ×2, dann ggf. -9 (für
  // Werte > 9). Sum → check = (10 - sum%10) % 10.
  const d = digits(serial)
  if (d.length === 0) return false
  const rev = d.slice().reverse()
  let sum = 0
  for (let i = 0; i < rev.length; i++) {
    let x = rev[i]
    if (i % 2 === 0) x *= 2
    if (x > 9) x -= 9
    sum += x
  }
  let calc = sum % 10
  if (calc !== 0) calc = 10 - calc
  return calc === parseInt(check, 10)
}

function checkMod7(serial: string, check: string): boolean {
  const num = BigInt(serial)
  return Number(num % 7n) === parseInt(check, 10)
}

// UPU S10: gewichtetes Summen-mod-11 mit Mapping {0:5,1:0,2:9,…,10:1}.
function checkS10(serial: string, check: string): boolean {
  if (serial.length !== 8) return false
  const weightings = [8, 6, 4, 2, 3, 5, 9, 7]
  const d = digits(serial)
  let sum = 0
  for (let i = 0; i < 8; i++) sum += d[i] * weightings[i]
  const rem = sum % 11
  const map: Record<number, number> = {
    0: 5,
    1: 0,
    2: 9,
    3: 8,
    4: 7,
    5: 6,
    6: 5,
    7: 4,
    8: 3,
    9: 2,
    10: 1,
  }
  return map[rem] === parseInt(check, 10)
}

function checkSumProduct(
  serial: string,
  check: string,
  spec: ChecksumSpec,
): boolean {
  const weightings = spec.weightings ?? []
  const mod1 = spec.modulo1 ?? spec.modulo ?? 11
  const mod2 = spec.modulo2 ?? 10
  const d = digits(serial)
  if (d.length !== weightings.length) return false
  let sum = 0
  for (let i = 0; i < d.length; i++) sum += d[i] * weightings[i]
  // jkeen-Konvention (FedEx): check = (sum % mod1) % mod2
  const calc = (sum % mod1) % mod2
  return calc === parseInt(check, 10)
}

/**
 * ISO 7064 MOD 37, 36 — Standard-Algorithmus für alphanumerische
 * Check-Digits (DPD nutzt das exakt so laut jkeen-Spec, ohne weitere
 * Parameter wie `weightings` — siehe `tracking_data/couriers/dpd.json`,
 * Feld `validation.checksum.name`).
 *
 * Algorithmus:
 *   - Zeichen-Alphabet: 0..9 (Wert 0..9), A..Z (Wert 10..35), '*' = 36
 *     (Pad-Char, nicht genutzt von DPD).
 *   - p := 36 (Initialwert)
 *   - Für jedes Zeichen c in BODY (ohne Check-Digit):
 *       v := charValue(c)
 *       s := (p + v) mod 36
 *       if s == 0 then s := 36
 *       p := (2 * s) mod 37
 *   - Final: erwartete Check-Digit-Value cd = (37 - p) mod 36
 *     → falls cd == 36, dann '*' (nicht relevant für DPD).
 *
 * Quelle: ISO/IEC 7064:2003 (System Pure MOD 37, 36). jkeen-DPD-JSON
 * referenziert den Algo nur per Name, ohne `weightings`-Array — daher
 * die parameterlose Standard-Variante.
 */
function checkMod37_36(serial: string, check: string): boolean {
  const body = serial.replace(/\s+/g, '').toUpperCase()
  const cd = check.replace(/\s+/g, '').toUpperCase()
  if (cd.length !== 1) return false
  const charVal = (c: string): number => {
    if (c >= '0' && c <= '9') return c.charCodeAt(0) - 48
    if (c >= 'A' && c <= 'Z') return c.charCodeAt(0) - 65 + 10
    return -1
  }
  let p = 36
  for (const ch of body) {
    const v = charVal(ch)
    if (v < 0) return false
    let s = (p + v) % 36
    if (s === 0) s = 36
    p = (2 * s) % 37
  }
  const expected = (37 - p) % 36
  const got = charVal(cd)
  if (got < 0) return false
  return expected === got
}

// Re-export für Helper, falls Adapter einzelne Checksum-Algos isoliert
// brauchen (z.B. für Confidence-Stufen).
export const _internal = {
  checkMod10,
  checkLuhn,
  checkMod7,
  checkS10,
  checkSumProduct,
  checkMod37_36,
}

// Stop unused-import warning für `dirname`/`fromFileUrl`/`join`.
void dirname
void fromFileUrl
void join
