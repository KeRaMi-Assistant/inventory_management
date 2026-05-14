// Tests für die Live-Status-Persistierung (Plan-Task A2, radikale
// Simplifikation): tracking-poll schreibt intermediate-Status (in_transit,
// out_for_delivery, exception, pending) in deals.live_status, nicht nur
// 'delivered'. Duplicate-Avoidance: identischer Status + Event → kein
// DB-Update.
//
// Pure-Function-Tests gegen `buildLiveStatusUpdate` aus index.ts. Keine
// HTTP-/Supabase-Mocks nötig — der Helper ist reine Logik.

import {
  assertEquals,
  assertNotEquals,
} from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { buildLiveStatusUpdate } from './index.ts'
import type { ParsedTracking } from '../_shared/tracking_adapters.ts'

const NOW = '2026-05-15T10:00:00.000Z'

const baseDeal = {
  live_status: null as
    | 'pending'
    | 'in_transit'
    | 'out_for_delivery'
    | 'delivered'
    | 'exception'
    | 'unknown'
    | null,
  live_status_last_event: null as string | null,
}

Deno.test('buildLiveStatusUpdate: in_transit → schreibt live_status, kein status-Update', () => {
  const parsed: ParsedTracking = {
    status: 'in_transit',
    lastEvent: 'In Zustellung',
  }
  const upd = buildLiveStatusUpdate(baseDeal, parsed, NOW)
  assertEquals(upd, {
    live_status: 'in_transit',
    live_status_last_event: 'In Zustellung',
    live_status_updated_at: NOW,
  })
  assertEquals((upd as Record<string, unknown>).status, undefined)
  assertEquals((upd as Record<string, unknown>).arrival_date, undefined)
})

Deno.test('buildLiveStatusUpdate: duplicate in_transit → null (kein DB-Roundtrip)', () => {
  const parsed: ParsedTracking = {
    status: 'in_transit',
    lastEvent: 'In Zustellung',
  }
  const first = buildLiveStatusUpdate(baseDeal, parsed, NOW)
  assertNotEquals(first, null)

  // Zweiter Poll: Deal hat jetzt schon den Status, neuer Parse identisch.
  const dealAfter = {
    live_status: 'in_transit' as const,
    live_status_last_event: 'In Zustellung',
  }
  const second = buildLiveStatusUpdate(dealAfter, parsed, NOW)
  assertEquals(second, null)
})

Deno.test('buildLiveStatusUpdate: in_transit mit neuem lastEvent → Update (Event-Wechsel)', () => {
  const dealAfter = {
    live_status: 'in_transit' as const,
    live_status_last_event: 'Im Paketzentrum',
  }
  const parsed: ParsedTracking = {
    status: 'in_transit',
    lastEvent: 'In Zustellung',
  }
  const upd = buildLiveStatusUpdate(dealAfter, parsed, NOW)
  assertEquals(upd, {
    live_status: 'in_transit',
    live_status_last_event: 'In Zustellung',
    live_status_updated_at: NOW,
  })
})

Deno.test('buildLiveStatusUpdate: delivered → status=Angekommen + arrival_date', () => {
  const parsed: ParsedTracking = {
    status: 'delivered',
    deliveredAt: '2026-05-15T08:30:00.000Z',
    lastEvent: 'Zugestellt',
  }
  const upd = buildLiveStatusUpdate(baseDeal, parsed, NOW)
  assertEquals(upd, {
    live_status: 'delivered',
    live_status_last_event: 'Zugestellt',
    live_status_updated_at: NOW,
    status: 'Angekommen',
    arrival_date: '2026-05-15T08:30:00.000Z',
  })
})

Deno.test('buildLiveStatusUpdate: delivered ohne deliveredAt → fallback auf nowIso', () => {
  const parsed: ParsedTracking = {
    status: 'delivered',
    lastEvent: 'Zugestellt',
  }
  const upd = buildLiveStatusUpdate(baseDeal, parsed, NOW)
  assertEquals((upd as Record<string, unknown>).arrival_date, NOW)
})

Deno.test('buildLiveStatusUpdate: exception → live_status=exception, status bleibt unverändert', () => {
  const parsed: ParsedTracking = {
    status: 'exception',
    lastEvent: 'Zustellung fehlgeschlagen',
  }
  const upd = buildLiveStatusUpdate(baseDeal, parsed, NOW)
  assertEquals(upd, {
    live_status: 'exception',
    live_status_last_event: 'Zustellung fehlgeschlagen',
    live_status_updated_at: NOW,
  })
  assertEquals((upd as Record<string, unknown>).status, undefined)
  assertEquals((upd as Record<string, unknown>).arrival_date, undefined)
})

Deno.test('buildLiveStatusUpdate: unknown → null (niemals persistieren)', () => {
  const parsed: ParsedTracking = {
    status: 'unknown',
    lastEvent: 'Unbekannt',
  }
  const upd = buildLiveStatusUpdate(baseDeal, parsed, NOW)
  assertEquals(upd, null)
})

Deno.test('buildLiveStatusUpdate: lastEvent fehlt → speichert null', () => {
  const parsed: ParsedTracking = {
    status: 'in_transit',
  }
  const upd = buildLiveStatusUpdate(baseDeal, parsed, NOW)
  assertEquals((upd as Record<string, unknown>).live_status_last_event, null)
})

Deno.test('buildLiveStatusUpdate: duplicate delivered → schreibt trotzdem (arrival_date möglicherweise fehlt)', () => {
  // Edge-Case: ein vorheriger Poll hat live_status='delivered' gesetzt, aber
  // status='Unterwegs' war race-geschützt → der nächste Poll soll den
  // delivered-Pfad nochmal versuchen (idempotent + race-Schutz im Query).
  const dealAfter = {
    live_status: 'delivered' as const,
    live_status_last_event: 'Zugestellt',
  }
  const parsed: ParsedTracking = {
    status: 'delivered',
    lastEvent: 'Zugestellt',
    deliveredAt: '2026-05-15T08:30:00.000Z',
  }
  const upd = buildLiveStatusUpdate(dealAfter, parsed, NOW)
  assertNotEquals(upd, null)
  assertEquals((upd as Record<string, unknown>).status, 'Angekommen')
})

Deno.test('buildLiveStatusUpdate: status-Übergang in_transit → delivered', () => {
  const dealAfter = {
    live_status: 'in_transit' as const,
    live_status_last_event: 'In Zustellung',
  }
  const parsed: ParsedTracking = {
    status: 'delivered',
    lastEvent: 'Zugestellt',
    deliveredAt: '2026-05-15T08:30:00.000Z',
  }
  const upd = buildLiveStatusUpdate(dealAfter, parsed, NOW)
  assertEquals((upd as Record<string, unknown>).live_status, 'delivered')
  assertEquals((upd as Record<string, unknown>).status, 'Angekommen')
})
