// Shared Live-Status-Persistenz (extrahiert aus tracking-poll, 2026-06-11).
//
// EINE Quelle für alle Kanäle, die Carrier-Status in Deals schreiben:
//   * tracking-poll  — Pull-Polling (DHL & Co., adaptive Frequenz)
//   * dpd-push       — DPD Tracking Push Service Webhook
//
// Enthält ausschließlich reine Funktionen + den Push-Versand-Helper;
// kein Deno.serve, keine Cron-/Auth-Logik.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import type { ParsedTracking } from './tracking_adapters.ts'
import {
  type FcmToken,
  getGoogleAccessToken,
  parseServiceAccount,
  type PushPayload,
  sendToTokens,
} from './fcm.ts'

/// Carrier-übergreifender Live-Status, der dem Deal-Row beigeschrieben wird.
/// Mappt auf `ParsedTracking.status` plus `expired` (Reaper-Status, nur
/// DB-seitig). CHECK-Enum in `20260515000000_deals_live_status.sql`;
/// 'unknown' wird NIE persistiert.
export type LiveStatus =
  | 'pending'
  | 'in_transit'
  | 'out_for_delivery'
  | 'delivered'
  | 'exception'
  | 'expired'
  | 'unknown'

/// Deal-Felder, die die Status-Persistenz braucht. tracking-poll erweitert
/// das um seine Poll-Steuerfelder (confidence/needs_review/order_date).
export interface PollDealRow {
  id: number
  workspace_id: string
  user_id: string
  product: string
  tracking: string | null
  carrier: string | null
  status: string
  arrival_date: string | null
  live_status: LiveStatus | null
  live_status_last_event: string | null
  live_status_updated_at: string | null
  live_eta: string | null
  last_polled_at: string | null
}

/// Reine Funktion: berechnet das `UPDATE`-Patch für einen Deal anhand des
/// Parser-Outputs. Gibt `null` zurück, wenn nichts zu schreiben ist
/// (Duplicate-Status, ohne neue Information). Exportiert für Unit-Tests.
export function buildLiveStatusUpdate(
  deal: Pick<PollDealRow, 'live_status' | 'live_status_last_event'>,
  parsed: ParsedTracking,
  nowIso: string,
): Record<string, unknown> | null {
  // 'unknown' niemals persistieren — würde echte Status überschreiben.
  if (parsed.status === 'unknown') return null

  const newLiveStatus = parsed.status as LiveStatus
  const newLastEvent = parsed.lastEvent ?? null

  const sameStatus = deal.live_status === newLiveStatus
  const sameEvent = (deal.live_status_last_event ?? null) === newLastEvent

  // Duplicate: identischer Status UND identischer Last-Event → skip.
  // (Bei 'delivered' trotzdem updaten, falls arrival_date noch fehlt.)
  if (sameStatus && sameEvent && newLiveStatus !== 'delivered') {
    return null
  }

  const update: Record<string, unknown> = {
    live_status: newLiveStatus,
    live_status_last_event: newLastEvent,
    live_status_updated_at: nowIso,
  }

  if (parsed.status === 'delivered') {
    update.status = 'Angekommen'
    update.arrival_date = parsed.deliveredAt ?? nowIso
  }

  return update
}

/// Reine Funktion: mappt einen Parser-Output auf `tracking_events`-Rows.
/// Events ohne parsbaren Timestamp werden verworfen. Liefert der Carrier
/// keine Event-Liste, wird (nur bei `includeSynthetic`, d.h. echtem
/// Status-Wechsel) ein synthetischer Event aus `lastEvent` gebaut, damit
/// die Timeline nie leer bleibt. Exportiert für Unit-Tests.
export function buildTrackingEventRows(
  deal: Pick<PollDealRow, 'id' | 'workspace_id' | 'tracking'>,
  carrierId: string,
  parsed: ParsedTracking,
  nowIso: string,
  includeSynthetic: boolean,
): Record<string, unknown>[] {
  const tracking = (deal.tracking ?? '').trim()
  if (!tracking) return []

  const rows: Record<string, unknown>[] = []
  for (const ev of parsed.events ?? []) {
    if (!ev.occurredAt) continue
    rows.push({
      deal_id: deal.id,
      workspace_id: deal.workspace_id,
      tracking,
      carrier: carrierId,
      occurred_at: ev.occurredAt,
      status: ev.status === 'unknown' ? null : ev.status,
      raw_code: ev.rawCode ?? null,
      description: (ev.text ?? '').slice(0, 500),
      location: ev.location ? ev.location.slice(0, 200) : null,
      source: 'poll',
    })
  }

  if (rows.length === 0 && includeSynthetic && parsed.lastEvent) {
    rows.push({
      deal_id: deal.id,
      workspace_id: deal.workspace_id,
      tracking,
      carrier: carrierId,
      // Carrier-Status-Timestamp bevorzugen — Poll-Zeit nur als letzter
      // Fallback, sonst zeigt die Timeline falsche Event-Zeiten.
      occurred_at: parsed.statusTimestamp ?? parsed.deliveredAt ?? nowIso,
      status: parsed.status === 'unknown' ? null : parsed.status,
      raw_code: parsed.rawStatusCode ?? null,
      description: parsed.lastEvent.slice(0, 500),
      location: null,
      source: 'poll',
    })
  }

  return rows
}

/// Reine Funktion: Push-Payload für einen Status-Wechsel. PII-bewusst: nur
/// Produktname (wie der bestehende delivery-Push) + Status — keine
/// Tracking-Nummer, keine Adresse. data.route für Deep-Linking.
export function buildStatusPushPayload(
  deal: Pick<PollDealRow, 'id' | 'product'>,
  status: LiveStatus,
  parsed: Pick<ParsedTracking, 'lastEvent'>,
): PushPayload {
  const titles: Partial<Record<LiveStatus, string>> = {
    in_transit: 'Paket unterwegs 📦',
    out_for_delivery: 'Paket in Zustellung 🚚',
    delivered: 'Paket zugestellt ✅',
    exception: 'Problem mit deiner Sendung ⚠️',
  }
  const title = titles[status] ?? 'Sendungs-Update'
  const body = parsed.lastEvent
    ? `${deal.product}: ${parsed.lastEvent}`
    : deal.product
  return {
    title,
    body,
    data: {
      kind: 'tracking_status',
      dealId: String(deal.id),
      status,
      route: `/deals?deal=${deal.id}`,
    },
  }
}

/// Lazy FCM-Kontext: OAuth-Token wird erst geholt, wenn der erste Push
/// tatsächlich ansteht. Fehlende FCM-Env (lokaler Stack) → Pushes werden
/// still übersprungen, der Aufrufer-Lauf bleibt erfolgreich.
export interface PushContext {
  ensure(): Promise<{ projectId: string; accessToken: string } | null>
}

export function createPushContext(logLabel: string): PushContext {
  let resolved: { projectId: string; accessToken: string } | null | undefined
  return {
    async ensure() {
      if (resolved !== undefined) return resolved
      const sa = parseServiceAccount()
      if (!sa) {
        console.log(`${logLabel}: FCM env fehlt — Status-Push übersprungen`)
        resolved = null
        return null
      }
      try {
        const accessToken = await getGoogleAccessToken(sa)
        resolved = { projectId: sa.project_id, accessToken }
      } catch (e) {
        console.warn(`${logLabel}: FCM OAuth failed`, (e as Error).message)
        resolved = null
      }
      return resolved
    },
  }
}

/// Status-Wechsel-Push mit Opt-out (notification_preferences.delivery_enabled,
/// Default true wie in send-notifications) und race-safem Dedup: erst die
/// notifications_sent-Row claimen (ignoreDuplicates + select), nur der
/// Gewinner sendet. FCM-Fehler nach Claim = verlorener Push (benign).
export async function maybeSendStatusPush(
  admin: ReturnType<typeof createClient>,
  pushCtx: PushContext,
  deal: Pick<PollDealRow, 'id' | 'workspace_id' | 'user_id' | 'product'>,
  status: LiveStatus,
  parsed: ParsedTracking,
): Promise<void> {
  try {
    const { data: pref } = await admin
      .from('notification_preferences')
      .select('delivery_enabled')
      .eq('user_id', deal.user_id)
      .maybeSingle()
    if (pref && (pref as { delivery_enabled: boolean }).delivery_enabled === false) {
      return
    }

    const refId = `${deal.id}:${status}`
    const { data: claimed, error: claimErr } = await admin
      .from('notifications_sent')
      .upsert(
        {
          user_id: deal.user_id,
          ref_kind: 'tracking_status',
          ref_id: refId,
          workspace_id: deal.workspace_id,
        },
        { onConflict: 'user_id,ref_kind,ref_id', ignoreDuplicates: true },
      )
      .select('ref_id')
    if (claimErr || !claimed || claimed.length === 0) return // schon gesendet

    const fcm = await pushCtx.ensure()
    if (!fcm) return

    const { data: tokenRows } = await admin
      .from('fcm_tokens')
      .select('token, platform')
      .eq('user_id', deal.user_id)
    const tokens = (tokenRows ?? []) as FcmToken[]
    if (tokens.length === 0) return

    await sendToTokens(
      fcm.projectId,
      fcm.accessToken,
      tokens,
      buildStatusPushPayload(deal, status, parsed),
    )
  } catch (e) {
    // Push ist Best-Effort — nie den Aufrufer-Lauf reißen.
    console.warn('status push failed', deal.id, (e as Error).message)
  }
}
