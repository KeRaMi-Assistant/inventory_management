// Checksum-Primitiven für die Tracking-Detection (Plan 2026-06-03 §2 / Audit
// chore/audit-sustainability-1).
//
// Schlankes, self-contained Modul: enthält NUR die drei Checksum-Algorithmen,
// die `tracking_detection.ts` (live) bzw. `checksums_test.ts` brauchen:
//   - `checkMod10`     — DHL-20 (mod-10 3/1) + DHL-Identcode-12 (mod-10 4/9).
//   - `checkS10`       — UPU S10 (gewichtetes mod-11), z.B. RB…DE.
//   - `checkMod37_36`  — DPD ISO 7064 MOD 37,36 (alphanumerischer Check).
//
// Vorher lagen diese Primitiven im JSON-Spec-getriebenen `tracking_validators.ts`
// (zusammen mit `loadCarrierSpecs`/`validateTrackingNumber`). Dieser
// jkeen-Loader wurde im Dead-Code-Cleanup entfernt (prod-tot — Detection läuft
// ausschliesslich über `tracking_detection.detect()`). Die drei live genutzten
// Checksums sind hierher extrahiert worden, damit die Detection ohne den
// schweren JSON-Loader + die `tracking_data/couriers/*.json`-Vendor-Dateien
// auskommt.
//
// Keine I/O, kein Network — reine Arithmetik.

/// Minimaler Spec-Shape für `checkMod10`. Vorher Teil von `ChecksumSpec` im
/// JSON-Loader; hier auf die live genutzten Felder reduziert. `name` ist
/// optional + nur kosmetisch (Call-Sites in `tracking_detection.ts` setzen
/// es noch, der Algorithmus liest es nicht).
export interface Mod10Spec {
  name?: 'mod10'
  evens_multiplier?: number
  odds_multiplier?: number
  reverse?: boolean
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

/**
 * Generisches mod-10 (jkeen `sum_product`-Variante mit getrennten
 * even/odd-Multiplikatoren). DHL nutzt zwei Parametrierungen:
 *   - 20-stellige Sendungsnummer: evens_multiplier 3, odds_multiplier 1.
 *   - 12-stelliger Identcode:      evens_multiplier 4, odds_multiplier 9.
 *
 * @param serial alle Ziffern AUSSER der Prüfziffer
 * @param check  die Prüfziffer (als String)
 */
export function checkMod10(
  serial: string,
  check: string,
  spec: Mod10Spec,
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

/**
 * UPU S10: gewichtetes Summen-mod-11 mit Mapping {0:5,1:0,2:9,…,10:1}.
 *
 * @param serial exakt 8 Ziffern (zwischen den 2 Service-Buchstaben + 2 Land)
 * @param check  die 9. Ziffer (Prüfziffer)
 */
export function checkS10(serial: string, check: string): boolean {
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

/**
 * ISO 7064 MOD 37, 36 — Standard-Algorithmus für alphanumerische
 * Check-Digits (DPD nutzt das exakt so laut jkeen-Spec, ohne weitere
 * Parameter wie `weightings`).
 *
 * Algorithmus:
 *   - Zeichen-Alphabet: 0..9 (Wert 0..9), A..Z (Wert 10..35).
 *   - p := 36 (Initialwert)
 *   - Für jedes Zeichen c in BODY (ohne Check-Digit):
 *       v := charValue(c)
 *       s := (p + v) mod 36
 *       if s == 0 then s := 36
 *       p := (2 * s) mod 37
 *   - Final: erwartete Check-Digit-Value cd = (37 - p) mod 36.
 *
 * Quelle: ISO/IEC 7064:2003 (System Pure MOD 37, 36).
 *
 * @param serial Body (ohne Prüfzeichen)
 * @param check  1 Prüfzeichen
 */
export function checkMod37_36(serial: string, check: string): boolean {
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

// Sammel-Export für Konsumenten, die die Primitiven gebündelt brauchen
// (Detection-Modul + Checksum-Tests). Spiegelt die frühere
// `tracking_validators._internal`-Schnittstelle für die drei überlebenden
// Algorithmen.
export const _internal = {
  checkMod10,
  checkS10,
  checkMod37_36,
}
