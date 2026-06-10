// Tests für die Paket-1-Pure-Functions des tracking-poll:
//   * isDuePoll              — adaptive Frequenz pro live_status
//   * remainingDailyQuota    — Tages-Quota-Guard (Rollover, Cap)
//   * adaptiveSweepShouldRun — Quiet-Hours-Gate (Berlin 22–05)
//   * buildTrackingEventRows — Parser-Events → tracking_events-Rows
//   * buildStatusPushPayload — Status-Wechsel-Push-Inhalt
//
//   deno test --no-check supabase/functions/tracking-poll/adaptive_poll_test.ts

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/assert_equals.ts'
import { assert } from 'https://deno.land/std@0.224.0/assert/assert.ts'
import {
  adaptiveSweepShouldRun,
  buildStatusPushPayload,
  buildTrackingEventRows,
  DAILY_QUOTA_CAP,
  isDuePoll,
  remainingDailyQuota,
} from './index.ts'
import type { ParsedTracking } from '../_shared/tracking_adapters.ts'

const NOW = Date.parse('2026-06-10T10:00:00Z')
const minAgo = (min: number) => new Date(NOW - min * 60_000).toISOString()

// ── isDuePoll ───────────────────────────────────────────────────────────

Deno.test('isDuePoll: nie gepollte Deals sind immer fällig', () => {
  assertEquals(isDuePoll({ live_status: null, last_polled_at: null }, NOW), true)
  assertEquals(
    isDuePoll({ live_status: 'in_transit', last_polled_at: null }, NOW),
    true,
  )
})

Deno.test('isDuePoll: delivered/expired nie fällig', () => {
  assertEquals(
    isDuePoll({ live_status: 'delivered', last_polled_at: null }, NOW),
    false,
  )
  assertEquals(
    isDuePoll({ live_status: 'expired', last_polled_at: minAgo(9999) }, NOW),
    false,
  )
})

Deno.test('isDuePoll: out_for_delivery stündlich (≥50 min)', () => {
  assertEquals(
    isDuePoll({ live_status: 'out_for_delivery', last_polled_at: minAgo(49) }, NOW),
    false,
  )
  assertEquals(
    isDuePoll({ live_status: 'out_for_delivery', last_polled_at: minAgo(51) }, NOW),
    true,
  )
})

Deno.test('isDuePoll: in_transit alle ~4h (≥230 min)', () => {
  assertEquals(
    isDuePoll({ live_status: 'in_transit', last_polled_at: minAgo(229) }, NOW),
    false,
  )
  assertEquals(
    isDuePoll({ live_status: 'in_transit', last_polled_at: minAgo(231) }, NOW),
    true,
  )
})

Deno.test('isDuePoll: pending/exception/null 2×/Tag (≥660 min)', () => {
  for (const status of ['pending', 'exception', null] as const) {
    assertEquals(
      isDuePoll({ live_status: status, last_polled_at: minAgo(659) }, NOW),
      false,
      `status=${status} 659min`,
    )
    assertEquals(
      isDuePoll({ live_status: status, last_polled_at: minAgo(661) }, NOW),
      true,
      `status=${status} 661min`,
    )
  }
})

Deno.test('isDuePoll: unparsbarer Timestamp → fällig (fail-open)', () => {
  assertEquals(
    isDuePoll({ live_status: 'in_transit', last_polled_at: 'garbage' }, NOW),
    true,
  )
})

// ── remainingDailyQuota ─────────────────────────────────────────────────

Deno.test('remainingDailyQuota: frischer Tag → volles Budget', () => {
  assertEquals(remainingDailyQuota(null, null, '2026-06-10'), DAILY_QUOTA_CAP)
  assertEquals(
    remainingDailyQuota(850, '2026-06-09', '2026-06-10'),
    DAILY_QUOTA_CAP,
    'Datums-Rollover resettet den Zähler',
  )
})

Deno.test('remainingDailyQuota: heutiger Zähler wird abgezogen', () => {
  assertEquals(remainingDailyQuota(100, '2026-06-10', '2026-06-10'), DAILY_QUOTA_CAP - 100)
  assertEquals(remainingDailyQuota(DAILY_QUOTA_CAP, '2026-06-10', '2026-06-10'), 0)
  assertEquals(
    remainingDailyQuota(DAILY_QUOTA_CAP + 50, '2026-06-10', '2026-06-10'),
    0,
    'nie negativ',
  )
})

// ── adaptiveSweepShouldRun ──────────────────────────────────────────────

Deno.test('adaptiveSweepShouldRun: andere Modi laufen immer durch', () => {
  const night = Date.parse('2026-06-10T01:00:00Z') // 03:00 Berlin (CEST)
  assertEquals(adaptiveSweepShouldRun(undefined, night), true)
  assertEquals(adaptiveSweepShouldRun('daily-sweep', night), true)
})

Deno.test('adaptiveSweepShouldRun: tagsüber aktiv, nachts quiet', () => {
  // 2026-06-10 ist CEST (UTC+2).
  const noonBerlin = Date.parse('2026-06-10T10:00:00Z') // 12:00 Berlin
  const sixBerlin = Date.parse('2026-06-10T04:00:00Z') // 06:00 Berlin (inkl.)
  const tenPmBerlin = Date.parse('2026-06-10T20:00:00Z') // 22:00 Berlin (exkl.)
  const threeAmBerlin = Date.parse('2026-06-10T01:00:00Z') // 03:00 Berlin
  assertEquals(adaptiveSweepShouldRun('adaptive-sweep', noonBerlin), true)
  assertEquals(adaptiveSweepShouldRun('adaptive-sweep', sixBerlin), true)
  assertEquals(adaptiveSweepShouldRun('adaptive-sweep', tenPmBerlin), false)
  assertEquals(adaptiveSweepShouldRun('adaptive-sweep', threeAmBerlin), false)
})

// ── buildTrackingEventRows ──────────────────────────────────────────────

const DEAL = { id: 42, workspace_id: 'ws-1', tracking: 'DE5455279839' }
const NOW_ISO = '2026-06-10T10:00:00.000Z'

Deno.test('buildTrackingEventRows: mappt Carrier-Events vollständig', () => {
  const parsed: ParsedTracking = {
    status: 'out_for_delivery',
    lastEvent: 'In Zustellung',
    events: [
      {
        occurredAt: '2026-06-09T18:00:00.000Z',
        text: 'Im Paketzentrum eingetroffen',
        location: 'Hamburg',
        rawCode: 'ba',
        status: 'in_transit',
      },
      {
        occurredAt: '2026-06-10T08:00:00.000Z',
        text: 'In Zustellung',
        rawCode: 'iz',
        status: 'out_for_delivery',
      },
    ],
  }
  const rows = buildTrackingEventRows(DEAL, 'dhl', parsed, NOW_ISO, true)
  assertEquals(rows.length, 2)
  assertEquals(rows[0].deal_id, 42)
  assertEquals(rows[0].workspace_id, 'ws-1')
  assertEquals(rows[0].tracking, 'DE5455279839')
  assertEquals(rows[0].carrier, 'dhl')
  assertEquals(rows[0].status, 'in_transit')
  assertEquals(rows[0].location, 'Hamburg')
  assertEquals(rows[0].source, 'poll')
  assertEquals(rows[1].status, 'out_for_delivery')
  assertEquals(rows[1].location, null)
})

Deno.test('buildTrackingEventRows: Events ohne Timestamp werden verworfen', () => {
  const parsed: ParsedTracking = {
    status: 'in_transit',
    events: [{ text: 'kein Timestamp', status: 'in_transit' }],
  }
  const rows = buildTrackingEventRows(DEAL, 'dhl', parsed, NOW_ISO, false)
  assertEquals(rows.length, 0)
})

Deno.test('buildTrackingEventRows: unknown-Event-Status → null', () => {
  const parsed: ParsedTracking = {
    status: 'in_transit',
    events: [
      {
        occurredAt: '2026-06-10T08:00:00.000Z',
        text: 'Irgendwas',
        status: 'unknown',
      },
    ],
  }
  const rows = buildTrackingEventRows(DEAL, 'dhl', parsed, NOW_ISO, false)
  assertEquals(rows.length, 1)
  assertEquals(rows[0].status, null)
})

Deno.test('buildTrackingEventRows: synthetischer Fallback nur bei Status-Wechsel', () => {
  const parsed: ParsedTracking = {
    status: 'in_transit',
    lastEvent: 'Sendung unterwegs',
  }
  // includeSynthetic=false (Duplicate-Poll) → keine Row.
  assertEquals(buildTrackingEventRows(DEAL, 'dhl', parsed, NOW_ISO, false).length, 0)
  // includeSynthetic=true (echter Wechsel) → eine synthetische Row.
  const rows = buildTrackingEventRows(DEAL, 'dhl', parsed, NOW_ISO, true)
  assertEquals(rows.length, 1)
  assertEquals(rows[0].description, 'Sendung unterwegs')
  assertEquals(rows[0].occurred_at, NOW_ISO)
})

Deno.test('buildTrackingEventRows: synthetischer Event nutzt Carrier-Timestamp', () => {
  // Review-Fix: occurred_at muss der Carrier-Status-Zeitpunkt sein, nicht
  // die Poll-Zeit — sonst zeigt die Timeline falsche Event-Zeiten.
  const parsed: ParsedTracking = {
    status: 'in_transit',
    lastEvent: 'Sendung unterwegs',
    statusTimestamp: '2026-06-10T07:42:00.000Z',
  }
  const rows = buildTrackingEventRows(DEAL, 'dhl', parsed, NOW_ISO, true)
  assertEquals(rows.length, 1)
  assertEquals(rows[0].occurred_at, '2026-06-10T07:42:00.000Z')
})

Deno.test('buildTrackingEventRows: leeres Tracking → keine Rows', () => {
  const parsed: ParsedTracking = { status: 'in_transit', lastEvent: 'x' }
  const rows = buildTrackingEventRows(
    { id: 1, workspace_id: 'ws', tracking: '  ' },
    'dhl',
    parsed,
    NOW_ISO,
    true,
  )
  assertEquals(rows.length, 0)
})

// ── buildStatusPushPayload ──────────────────────────────────────────────

Deno.test('buildStatusPushPayload: Klarna-Style-Titel pro Status', () => {
  const deal = { id: 7, product: 'PS5 Slim' }
  const ofd = buildStatusPushPayload(deal, 'out_for_delivery', {
    lastEvent: 'In Zustellung',
  })
  assertEquals(ofd.title, 'Paket in Zustellung 🚚')
  assertEquals(ofd.body, 'PS5 Slim: In Zustellung')
  assertEquals(ofd.data?.kind, 'tracking_status')
  assertEquals(ofd.data?.dealId, '7')
  assertEquals(ofd.data?.status, 'out_for_delivery')
  assert(ofd.data?.route?.includes('7'))

  const delivered = buildStatusPushPayload(deal, 'delivered', {})
  assertEquals(delivered.title, 'Paket zugestellt ✅')
  assertEquals(delivered.body, 'PS5 Slim')

  const exception = buildStatusPushPayload(deal, 'exception', {})
  assertEquals(exception.title, 'Problem mit deiner Sendung ⚠️')
})

Deno.test('buildStatusPushPayload: keine Tracking-Nummer im Payload (PII)', () => {
  const payload = buildStatusPushPayload({ id: 7, product: 'X' }, 'in_transit', {
    lastEvent: 'Unterwegs',
  })
  const flat = JSON.stringify(payload)
  assert(!flat.includes('DE5455279839'))
})
