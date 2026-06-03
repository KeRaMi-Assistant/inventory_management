// T4: Pure-Function-Tests für den Daily-Sweep-Hour-Guard (Plan §3.2).
//
// Getestet werden `berlinHourNow` + `dailySweepShouldRun` aus index.ts:
//   - DST-Korrektheit: 13:00 Europe/Berlin = 12:00 UTC (Winter) /
//     11:00 UTC (Sommer). Cron `0 11,12` feuert beide; genau eine Stunde
//     passiert den Guard ganzjährig.
//   - Bypass-Pfade: mode=undefined / mode!='daily-sweep' / deal_id-Pfad
//     (im Caller geprüft) laufen IMMER durch.
//   - Default vs. Fail-Closed: kein Body-Array → Default [13]; explizit
//     leeres Array → fail-closed (false).
//
// Diese Tests importieren NUR die reinen Helper — kein DB-/Netzwerk-Pfad.

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { berlinHourNow, dailySweepShouldRun } from './index.ts'

// ── Helper: feste UTC-Zeitpunkte als Epoch-ms ──────────────────────────────
const utc = (iso: string): number => Date.parse(iso)

// Winter (CET = UTC+1): 12:00 UTC == 13:00 Berlin.
const WINTER_12_UTC = utc('2026-01-15T12:00:00Z')
// Winter: 11:00 UTC == 12:00 Berlin (die "andere" Cron-Feuerung).
const WINTER_11_UTC = utc('2026-01-15T11:00:00Z')
// Sommer (CEST = UTC+2): 11:00 UTC == 13:00 Berlin.
const SUMMER_11_UTC = utc('2026-07-15T11:00:00Z')
// Sommer: 12:00 UTC == 14:00 Berlin (die "andere" Cron-Feuerung).
const SUMMER_12_UTC = utc('2026-07-15T12:00:00Z')

// ── berlinHourNow: DST-Korrektheit ─────────────────────────────────────────

Deno.test('berlinHourNow: Winter 12:00 UTC → 13 Berlin', () => {
  assertEquals(berlinHourNow(WINTER_12_UTC), 13)
})

Deno.test('berlinHourNow: Winter 11:00 UTC → 12 Berlin', () => {
  assertEquals(berlinHourNow(WINTER_11_UTC), 12)
})

Deno.test('berlinHourNow: Sommer 11:00 UTC → 13 Berlin', () => {
  assertEquals(berlinHourNow(SUMMER_11_UTC), 13)
})

Deno.test('berlinHourNow: Sommer 12:00 UTC → 14 Berlin', () => {
  assertEquals(berlinHourNow(SUMMER_12_UTC), 14)
})

Deno.test('berlinHourNow: Mitternacht-Wraparound (00 Berlin, nicht 24)', () => {
  // Winter: 23:00 UTC == 00:00 Berlin (nächster Tag).
  assertEquals(berlinHourNow(utc('2026-01-15T23:00:00Z')), 0)
})

// ── dailySweepShouldRun: DST-Guard mit Default [13] ────────────────────────

Deno.test('dailySweepShouldRun: daily-sweep + default [13], Winter 12 UTC → run', () => {
  assertEquals(dailySweepShouldRun('daily-sweep', [13], WINTER_12_UTC), true)
})

Deno.test('dailySweepShouldRun: daily-sweep + default [13], Winter 11 UTC → skip', () => {
  // 11 UTC == 12 Berlin im Winter → off-hour, die "falsche" Cron-Feuerung.
  assertEquals(dailySweepShouldRun('daily-sweep', [13], WINTER_11_UTC), false)
})

Deno.test('dailySweepShouldRun: daily-sweep + default [13], Sommer 11 UTC → run', () => {
  assertEquals(dailySweepShouldRun('daily-sweep', [13], SUMMER_11_UTC), true)
})

Deno.test('dailySweepShouldRun: daily-sweep + default [13], Sommer 12 UTC → skip', () => {
  // 12 UTC == 14 Berlin im Sommer → off-hour.
  assertEquals(dailySweepShouldRun('daily-sweep', [13], SUMMER_12_UTC), false)
})

Deno.test('dailySweepShouldRun: ganzjährig feuert genau EINE Cron-Stunde', () => {
  // Winter: nur 12 UTC trifft 13 Berlin.
  assertEquals(dailySweepShouldRun('daily-sweep', [13], WINTER_11_UTC), false)
  assertEquals(dailySweepShouldRun('daily-sweep', [13], WINTER_12_UTC), true)
  // Sommer: nur 11 UTC trifft 13 Berlin.
  assertEquals(dailySweepShouldRun('daily-sweep', [13], SUMMER_11_UTC), true)
  assertEquals(dailySweepShouldRun('daily-sweep', [13], SUMMER_12_UTC), false)
})

// ── Bypass-Pfade (mode != 'daily-sweep') ───────────────────────────────────

Deno.test('dailySweepShouldRun: mode=undefined → IMMER true (Service/Manual)', () => {
  // Auch zu einer off-hour, auch mit beliebigen targetHours.
  assertEquals(dailySweepShouldRun(undefined, [13], WINTER_11_UTC), true)
  assertEquals(dailySweepShouldRun(undefined, undefined, SUMMER_12_UTC), true)
  assertEquals(dailySweepShouldRun(undefined, [], WINTER_11_UTC), true)
})

Deno.test('dailySweepShouldRun: mode="manual" → IMMER true', () => {
  assertEquals(dailySweepShouldRun('manual', [13], WINTER_11_UTC), true)
})

Deno.test('dailySweepShouldRun: deal_id-Pfad bypasst Guard (Caller-Kontrakt)', () => {
  // Der single-deal-Pfad ruft mode=undefined (Trigger sendet nur {deal_id}).
  // Der Guard-Aufruf im Handler ist zusätzlich an onlyDealId===undefined
  // gekoppelt — hier verifizieren wir die Helper-Semantik (mode undefined
  // → true), die diesen Bypass trägt.
  assertEquals(dailySweepShouldRun(undefined, undefined, SUMMER_12_UTC), true)
})

// ── Default vs. Fail-Closed (die zentrale dokumentierte Semantik) ──────────

Deno.test('dailySweepShouldRun: daily-sweep + targetHours undefined → Default [13]', () => {
  // Kein gültiges Body-Array → Server-Default [13], NICHT fail-closed.
  assertEquals(dailySweepShouldRun('daily-sweep', undefined, WINTER_12_UTC), true)
  assertEquals(dailySweepShouldRun('daily-sweep', undefined, SUMMER_11_UTC), true)
  assertEquals(dailySweepShouldRun('daily-sweep', undefined, WINTER_11_UTC), false)
})

Deno.test('dailySweepShouldRun: daily-sweep + LEERES Array → FAIL-CLOSED (false)', () => {
  // Explizit [] (z.B. alle Body-Werte als invalide aussortiert) → niemals
  // laufen, auch zur korrekten Stunde.
  assertEquals(dailySweepShouldRun('daily-sweep', [], WINTER_12_UTC), false)
  assertEquals(dailySweepShouldRun('daily-sweep', [], SUMMER_11_UTC), false)
})

Deno.test('dailySweepShouldRun: daily-sweep + Custom-Override [13,19]', () => {
  // Opt-in zweiter Sweep um 19:00 Berlin.
  // Winter: 18 UTC == 19 Berlin.
  assertEquals(dailySweepShouldRun('daily-sweep', [13, 19], utc('2026-01-15T18:00:00Z')), true)
  assertEquals(dailySweepShouldRun('daily-sweep', [13, 19], WINTER_12_UTC), true)
  // 15 Berlin (14 UTC Winter) ist in keiner Liste.
  assertEquals(dailySweepShouldRun('daily-sweep', [13, 19], utc('2026-01-15T14:00:00Z')), false)
})
