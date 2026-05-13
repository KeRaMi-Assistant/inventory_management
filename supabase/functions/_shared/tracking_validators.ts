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

export async function validateTrackingNumber(
  value: string,
): Promise<ValidationResult> {
  const specs = await loadCarrierSpecs()
  // KEINE harte Whitespace-Normalisierung: viele Patterns enthalten bereits
  // `\s*` zwischen Zeichen. Wir testen 2 Formen: roh + ohne Whitespace.
  const trimmed = value.trim()
  const stripped = trimmed.replace(/\s+/g, '')

  for (const spec of specs) {
    for (const pattern of spec.patterns) {
      const candidates = [trimmed, stripped]
      for (const candidate of candidates) {
        const m = pattern.regex.exec(candidate)
        if (!m) continue
        // Checksum prüfen, falls vorhanden.
        if (!pattern.validation) {
          return {
            isValid: true,
            carrier: spec.carrier,
            carrierSlug: spec.carrierSlug,
            matchedPattern: pattern.description,
            serial: m.groups?.SerialNumber?.replace(/\s+/g, ''),
          }
        }
        const csValid = runChecksum(pattern.validation, m, candidate, pattern.serialFormat)
        if (csValid) {
          return {
            isValid: true,
            carrier: spec.carrier,
            carrierSlug: spec.carrierSlug,
            matchedPattern: pattern.description,
            checksumName: pattern.validation.name,
            checksumValid: true,
            serial: m.groups?.SerialNumber?.replace(/\s+/g, ''),
          }
        }
        // Match aber Checksum schlägt fehl → nicht als valid akzeptieren,
        // andere Patterns dürfen weiter probieren.
      }
    }
  }
  return { isValid: false }
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
      // Followup: Alphanumerisches Modulo. Nicht im ersten Wurf — DPD-Tests
      // werden als known-fail markiert.
      return false
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

// Re-export für Helper, falls Adapter einzelne Checksum-Algos isoliert
// brauchen (z.B. für Confidence-Stufen).
export const _internal = {
  checkMod10,
  checkLuhn,
  checkMod7,
  checkS10,
  checkSumProduct,
}

// Stop unused-import warning für `dirname`/`fromFileUrl`/`join`.
void dirname
void fromFileUrl
void join
