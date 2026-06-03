// Detektor-Unit-Tests (Positiv-Korpus + Carrier-Klassifikation + Gating).
// Plan 2026-06-03 §5b/§6 (Task T2).
//
// Ausführen mit:
//   deno test --allow-read supabase/functions/_shared/tracking_detection_test.ts
//
// Deckt §6 Positiv-Korpus ab:
//   - DHL JJD (strong, ohne Anchor)
//   - DHL-20 mit Anchor (mod-10 3/1)
//   - DHL Identcode-12 mit Anchor (mod-10 4/9)
//   - S10-DE (mod-11 + ISO-Land)
//   - Amazon TBA mit Amazon-Anchor (strong) + ohne (medium → none + review)
//   - Amazon track-URL (html-href)
//   - DPD via URL + via „DPD"-Anchor
// Plus: Carrier-Klassifikation korrekt + lowercase, Cross-Carrier → none,
//       status ordered → none, Source-Priorität (href > body).

import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { detect, type DetectionInput } from './tracking_detection.ts'

function base(over: Partial<DetectionInput>): DetectionInput {
  return { subject: '', text: '', html: '', status: 'shipped', ...over }
}

// ── DHL JJD ────────────────────────────────────────────────────────────────
Deno.test('detect: DHL JJD strong, lowercase carrier', () => {
  const r = detect(base({ text: 'Sendungsnummer: JJD000390007299011234' }))
  assertEquals(r.tracking, 'JJD000390007299011234')
  assertEquals(r.carrier, 'dhl')
  assertEquals(r.confidence, 'strong')
  assertEquals(r.needsReview, false)
})

Deno.test('detect: DHL JJD braucht keinen Anchor', () => {
  const r = detect(base({ text: 'Hallo JJD000390007299011234 viele Grüße' }))
  assertEquals(r.tracking, 'JJD000390007299011234')
  assertEquals(r.carrier, 'dhl')
})

// ── DHL-20 (mod-10 3/1), Anchor-Pflicht ─────────────────────────────────────
Deno.test('detect: DHL-20 mit Anchor → strong dhl', () => {
  const r = detect(base({ text: 'Sendungsnummer 00340433836442636597' }))
  assertEquals(r.tracking, '00340433836442636597')
  assertEquals(r.carrier, 'dhl')
  assertEquals(r.confidence, 'strong')
})

Deno.test('detect: DHL-20 OHNE Anchor → none (Anchor-Pflicht)', () => {
  const r = detect(base({ text: 'Referenz 00340433836442636597 im Footer' }))
  assertEquals(r.tracking, null)
  assertEquals(r.confidence, 'none')
})

// ── DHL Identcode-12 (mod-10 4/9), Anchor-Pflicht ──────────────────────────
Deno.test('detect: Identcode-12 mit Anchor → strong dhl', () => {
  const r = detect(base({ text: 'Identcode 201298452277' }))
  assertEquals(r.tracking, '201298452277')
  assertEquals(r.carrier, 'dhl')
})

Deno.test('detect: Identcode-12 mit falscher Checksum → none', () => {
  // 201298452270: letzte Ziffer 7→0 geflippt.
  const r = detect(base({ text: 'Identcode 201298452270' }))
  assertEquals(r.tracking, null)
})

// ── DE-Prefix-Tracking (Amazon-Logistics-DE / DHL-National) — reales
//    dominantes Format dieses Postfachs (2026-06-03). DE+10–14 = Tracking,
//    DE+9 = USt-IdNr (Reject), DE+20 = IBAN (Reject). ───────────────────────
Deno.test('detect: DE-Prefix DE+10 → strong dhl (Amazon-DE-Tracking)', () => {
  const r = detect(base({ text: 'Sendungsnummer: DE5455279839' }))
  assertEquals(r.tracking, 'DE5455279839')
  assertEquals(r.carrier, 'dhl')
  assertEquals(r.confidence, 'strong')
})

Deno.test('detect: DE-Prefix braucht keinen Anchor (format-eindeutig)', () => {
  const r = detect(base({ text: 'Ihre Lieferung DE5455279839 ist unterwegs' }))
  assertEquals(r.tracking, 'DE5455279839')
  assertEquals(r.carrier, 'dhl')
})

Deno.test('detect: DE+14 → strong (nicht fälschlich als IBAN gerejected)', () => {
  const r = detect(base({ text: 'Sendungsnummer DE54552798391234' }))
  assertEquals(r.tracking, 'DE54552798391234')
  assertEquals(r.carrier, 'dhl')
})

Deno.test('detect: DE+9 (USt-IdNr) bleibt VAT → none', () => {
  const r = detect(base({ text: 'USt-IdNr.: DE123456789 — vielen Dank' }))
  assertEquals(r.tracking, null)
  assertEquals(r.confidence, 'none')
})

Deno.test('detect: DE-IBAN (DE+20) → none (kein Tracking)', () => {
  const r = detect(base({ text: 'Bankverbindung DE89370400440532013000' }))
  assertEquals(r.tracking, null)
})

Deno.test('detect: ordered-Status → kein DE-Tracking', () => {
  const r = detect(base({ text: 'Bestellung DE5455279839', status: 'ordered' }))
  assertEquals(r.tracking, null)
})

// ── S10 international ────────────────────────────────────────────────────────
Deno.test('detect: S10 RB123456785DE mit Anchor → strong dhl', () => {
  const r = detect(base({ text: 'Sendungsnummer RB123456785DE' }))
  assertEquals(r.tracking, 'RB123456785DE')
  assertEquals(r.carrier, 'dhl')
})

Deno.test('detect: S10 CC473124829DE mit Anchor → strong dhl', () => {
  const r = detect(base({ text: 'Tracking CC473124829DE' }))
  assertEquals(r.tracking, 'CC473124829DE')
  assertEquals(r.carrier, 'dhl')
})

Deno.test('detect: S10 OHNE Anchor → none', () => {
  const r = detect(base({ text: 'Code RB123456785DE irgendwo' }))
  assertEquals(r.tracking, null)
})

// ── Amazon TBA ───────────────────────────────────────────────────────────────
Deno.test('detect: TBA mit Amazon-Kontext + Anchor → strong amazon', () => {
  const r = detect(base({
    subject: 'Ihre Amazon-Bestellung wurde versandt',
    text: 'Tracking ID: TBA651782912737 (Amazon Logistics)',
  }))
  assertEquals(r.tracking, 'TBA651782912737')
  assertEquals(r.carrier, 'amazon')
  assertEquals(r.confidence, 'strong')
})

Deno.test('detect: TBA via Amazon-Absender-Domain → strong amazon', () => {
  const r = detect(base({
    text: 'Tracking ID: TBA651782912737',
    senderDomain: 'amazon.de',
  }))
  assertEquals(r.tracking, 'TBA651782912737')
  assertEquals(r.carrier, 'amazon')
})

Deno.test('detect: bare TBA ohne Amazon-Kontext → none + needsReview', () => {
  const r = detect(base({ text: 'Tracking ID: TBA651782912737' }))
  assertEquals(r.tracking, null)
  assertEquals(r.confidence, 'none')
  assertEquals(r.needsReview, true)
  // Kandidat bleibt forensisch sichtbar (medium).
  assert(r.candidates.some((c) => c.value === 'TBA651782912737' && c.confidence === 'medium'))
})

// ── Amazon track-URL (html-href) ────────────────────────────────────────────
Deno.test('detect: Amazon track-URL → strong amazon', () => {
  const r = detect(base({
    html: '<a href="https://track.amazon.de/tracking/TBA651782912737">Sendung verfolgen</a>',
  }))
  assertEquals(r.tracking, 'TBA651782912737')
  assertEquals(r.carrier, 'amazon')
  assertEquals(r.confidence, 'strong')
})

Deno.test('detect: Amazon trackingId=-Param → strong amazon', () => {
  const r = detect(base({
    html: '<a href="https://www.amazon.de/gp/css/...?trackingId=TBA651782912737">Verfolgen</a>',
  }))
  assertEquals(r.tracking, 'TBA651782912737')
  assertEquals(r.carrier, 'amazon')
})

Deno.test('detect: orderingShipmentId bleibt medium, NIE primary', () => {
  const r = detect(base({
    html: '<a href="https://amazon.de/track?orderingShipmentId=12345678901234">x</a>',
  }))
  // Kein strong-Primary (nur amazon-shipment-id medium).
  assertEquals(r.tracking, null)
  assert(r.candidates.some((c) => c.source === 'amazon-shipment-id'))
})

// ── Amazon Redirect-Wrapper: doppelt URL-encodete Ziel-URL (Recall-Fix T6) ──
Deno.test('detect: Amazon &U=-Redirect mit encodeter track.amazon-URL → strong amazon', () => {
  // amazon.de/gp/f.html?...&U=https%3A%2F%2Ftrack.amazon.de%2Ftracking%2FTBA…
  // Die Ziel-URL steht URL-encoded — nur via einmaligem Decode matchbar.
  const r = detect(base({
    html: '<a href="https://www.amazon.de/gp/f.html?C=ABC&R=XYZ&H=hash&U=https%3A%2F%2Ftrack.amazon.de%2Ftracking%2FTBA651782912737">Sendung verfolgen</a>',
  }))
  assertEquals(r.tracking, 'TBA651782912737')
  assertEquals(r.carrier, 'amazon')
  assertEquals(r.confidence, 'strong')
  assertEquals(r.needsReview, false)
})

Deno.test('detect: Amazon &U=-Redirect mit encodetem trackingId=-Param → strong amazon', () => {
  const r = detect(base({
    html: '<a href="https://www.amazon.de/gp/f.html?U=https%3A%2F%2Fwww.amazon.de%2Fprogress-tracker%3FtrackingId%3DTBA651782912737">Verfolgen</a>',
  }))
  assertEquals(r.tracking, 'TBA651782912737')
  assertEquals(r.carrier, 'amazon')
  assertEquals(r.confidence, 'strong')
})

Deno.test('detect: encodete orderingShipmentId im &U=-Redirect → medium, NIE primary', () => {
  // ...&U=https%3A%2F%2Famazon.de%2Ftrack%3ForderingShipmentId%3D12345678901234
  const r = detect(base({
    html: '<a href="https://www.amazon.de/gp/f.html?U=https%3A%2F%2Famazon.de%2Ftrack%3ForderingShipmentId%3D12345678901234">x</a>',
  }))
  assertEquals(r.tracking, null)
  assert(
    r.candidates.some((c) => c.source === 'amazon-shipment-id' && c.confidence === 'medium'),
    'orderingShipmentId bleibt medium / amazon-shipment-id',
  )
})

Deno.test('detect: encoded + raw Treffer derselben TBA → genau ein strong Candidate (dedupe)', () => {
  // track.amazon.de-URL liegt sowohl unencodet als auch im &U=-Wrapper vor.
  // Der Doppel-Scan (raw + decoded) darf den TBA-Wert nur EINMAL liefern.
  const r = detect(base({
    html: [
      '<a href="https://track.amazon.de/tracking/TBA651782912737">A</a>',
      '<a href="https://www.amazon.de/gp/f.html?U=https%3A%2F%2Ftrack.amazon.de%2Ftracking%2FTBA651782912737">B</a>',
    ].join(''),
  }))
  assertEquals(r.tracking, 'TBA651782912737')
  assertEquals(r.carrier, 'amazon')
  const tbaCands = r.candidates.filter((c) => c.value === 'TBA651782912737')
  assertEquals(tbaCands.length, 1, `erwartet 1 deduped Candidate, got ${tbaCands.length}`)
})

// ── DPD ──────────────────────────────────────────────────────────────────────
Deno.test('detect: DPD via parcelstatus?query=-URL → strong dpd', () => {
  const r = detect(base({
    html: '<a href="https://tracking.dpd.de/parcelstatus?lang=de&query=01234567890123">Verfolgen</a>',
  }))
  assertEquals(r.tracking, '01234567890123')
  assertEquals(r.carrier, 'dpd')
  assertEquals(r.confidence, 'strong')
})

Deno.test('detect: DPD via parcelno=-URL → strong dpd', () => {
  const r = detect(base({
    html: '<a href="https://my.dpd.de/track?parcelno=01234567890123">x</a>',
  }))
  assertEquals(r.tracking, '01234567890123')
  assertEquals(r.carrier, 'dpd')
})

Deno.test('detect: DPD via „DPD"-Name + Anchor im Fenster → strong dpd', () => {
  const r = detect(base({ text: 'Ihre DPD Sendungsnummer 01234567890123 ist unterwegs' }))
  assertEquals(r.tracking, '01234567890123')
  assertEquals(r.carrier, 'dpd')
})

Deno.test('detect: bare 14-stellig mit Anchor aber OHNE „DPD" → none', () => {
  // Kein „DPD" im Fenster → fällt NICHT automatisch auf DPD (Research R3).
  const r = detect(base({ text: 'Sendungsnummer 01234567890123' }))
  assertEquals(r.tracking, null)
})

// ── Cross-Carrier-Ambiguität → none ─────────────────────────────────────────
Deno.test('detect: Cross-Carrier (DHL JJD + Amazon TBA) → none + needsReview', () => {
  const r = detect(base({
    subject: 'Amazon Versand',
    text: 'Sendungsnummer JJD000390007299011234 und Amazon Tracking TBA651782912737',
  }))
  assertEquals(r.tracking, null)
  assertEquals(r.confidence, 'none')
  assertEquals(r.needsReview, true)
})

// ── Status-Gating ────────────────────────────────────────────────────────────
Deno.test('detect: status ordered → none (trotz validem JJD)', () => {
  const r = detect(base({
    status: 'ordered',
    text: 'Sendungsnummer JJD000390007299011234',
  }))
  assertEquals(r.tracking, null)
  assertEquals(r.confidence, 'none')
  assertEquals(r.needsReview, false)
})

Deno.test('detect: status cancelled → none', () => {
  const r = detect(base({ status: 'cancelled', text: 'Sendungsnummer JJD000390007299011234' }))
  assertEquals(r.tracking, null)
})

Deno.test('detect: status refunded → none', () => {
  const r = detect(base({ status: 'refunded', text: 'Sendungsnummer JJD000390007299011234' }))
  assertEquals(r.tracking, null)
})

Deno.test('detect: status delivered → akzeptiert', () => {
  const r = detect(base({ status: 'delivered', text: 'Sendungsnummer JJD000390007299011234' }))
  assertEquals(r.tracking, 'JJD000390007299011234')
})

// ── Source-Priorität (html-href > body strong-pattern) ──────────────────────
Deno.test('detect: gleicher Wert in href + Body → primary aus href', () => {
  const r = detect(base({
    text: 'Sendungsnummer 00340433836442636597',
    html: '<a href="https://nolp.dhl.de/?idc=00340433836442636597">Verfolgen</a>',
  }))
  assertEquals(r.tracking, '00340433836442636597')
  assertEquals(r.carrier, 'dhl')
  const primaryCand = r.candidates.find((c) => c.value === '00340433836442636597')
  assert(primaryCand, 'primary candidate present')
})

// ── trackings[] enthält mehrere same-carrier-strong-Werte ───────────────────
Deno.test('detect: zwei DHL-Strong-Werte → beide in trackings[]', () => {
  const r = detect(base({
    text: 'Sendungsnummer JJD000390007299011234 sowie Identcode 201298452277',
  }))
  assertEquals(r.carrier, 'dhl')
  assertEquals(r.confidence, 'strong')
  assert(r.trackings.includes('JJD000390007299011234'))
  assert(r.trackings.includes('201298452277'))
})

// ── candidates ≤ 10 ──────────────────────────────────────────────────────────
Deno.test('detect: candidates auf 10 gekappt', () => {
  // Erzeuge >10 valide-anchored JJDs.
  const parts: string[] = []
  for (let i = 0; i < 14; i++) {
    parts.push(`Sendungsnummer JJD0003900072990112${(10 + i).toString()}`)
  }
  const r = detect(base({ text: parts.join('\n') }))
  assert(r.candidates.length <= 10, `expected ≤10 candidates, got ${r.candidates.length}`)
})
