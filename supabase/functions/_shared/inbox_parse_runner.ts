// Shared Parse-Runner für inbox-poll + inbox-parse.
//
// Hintergrund: inbox-poll holt Mails per IMAP und schreibt sie als
// `parsed_messages.status='pending'` in die DB. Daraufhin musste früher
// die separate Edge Function `inbox-parse` per HTTP getriggert werden,
// um die Pending-Rows durch die Adapter-Registry zu schicken. Dieser
// Cross-Function-Call hatte chronische Auth-Probleme (401 trotz
// Service-Role-Key + verify_jwt:false). Lösung: Parse-Logik wird
// in-process aus inbox-poll aufgerufen — kein HTTP, keine Auth-Kette.
//
// `inbox-parse` bleibt als Edge Function bestehen, importiert dieselbe
// Logik und ist nur noch für manuelle Re-Parse-Requests relevant.

import type { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  detectAndParse,
  detectShop,
  type ParsedOrder,
} from './inbox_adapters.ts'

export interface PendingMessage {
  id: string
  workspace_id: string
  account_id: string
  from_address: string | null
  subject: string | null
  message_id: string | null
  received_at: string
  parsed_payload: { _raw?: { text?: string; html?: string } } | null
}

export interface ParseRunStats {
  processed: number
  matched: number
  suggested: number
  unclassified: number
}

// Reihenfolge des Deal-Lifecycles. Verhindert Status-Downgrades bei
// verspäteten Mails (Versand-Bestätigung trifft erst nach Zustell-Mail
// ein → Deal soll nicht von "Angekommen" zurück auf "Unterwegs").
const STATUS_RANK: Record<string, number> = {
  'Bestellt': 1,
  'Unterwegs': 2,
  'Angekommen': 3,
  'Rechnung gestellt': 4,
  'Done': 5,
}

function mapShipStatusToDeal(s?: string): string | null {
  switch (s) {
    case 'shipped': return 'Unterwegs'
    case 'delivered': return 'Angekommen'
    case 'cancelled':
    case 'refunded': return 'Done'
    default: return null
  }
}

interface DealRow {
  status: string
  tracking: string | null
  arrival_date: string | null
}

type SbClient = ReturnType<typeof createClient>

/// Holt bis zu [limit] Pending-Rows (workspaceId-gefiltert wenn gesetzt)
/// und jagt sie durch die Adapter-Registry. Schreibt status, shop_key,
/// pending_deal_suggestions, ggf. deal-Updates + activity_log.
export async function runParseSweep(
  admin: SbClient,
  options: { workspaceId?: string; limit?: number } = {},
): Promise<ParseRunStats> {
  const limit = options.limit ?? 200
  let query = admin
    .from('parsed_messages')
    .select(
      'id, workspace_id, account_id, from_address, subject, message_id, received_at, parsed_payload',
    )
    .eq('status', 'pending')
    .order('received_at', { ascending: true })
    .limit(limit)
  if (options.workspaceId) {
    query = query.eq('workspace_id', options.workspaceId)
  }
  const { data, error } = await query
  if (error) {
    console.error('parsed_messages select failed', error)
    return { processed: 0, matched: 0, suggested: 0, unclassified: 0 }
  }
  const rows = (data ?? []) as PendingMessage[]
  const stats: ParseRunStats = {
    processed: rows.length,
    matched: 0,
    suggested: 0,
    unclassified: 0,
  }
  for (const row of rows) {
    const result = await processOne(admin, row)
    if (result === 'matched') stats.matched++
    else if (result === 'suggested') stats.suggested++
    else stats.unclassified++
  }
  return stats
}

export async function processOne(
  admin: SbClient,
  row: PendingMessage,
): Promise<'matched' | 'suggested' | 'unclassified'> {
  const text = row.parsed_payload?._raw?.text ?? ''
  const html = row.parsed_payload?._raw?.html ?? ''
  const ctx = {
    from: row.from_address ?? '',
    subject: row.subject ?? '',
    text,
    html,
  }
  const parsed = detectAndParse(ctx)

  if (!parsed) {
    const shop = detectShop(ctx)
    await admin
      .from('parsed_messages')
      .update({
        status: 'unclassified',
        shop_key: shop?.key ?? null,
        parsed_payload: {
          from: ctx.from,
          subject: ctx.subject,
          shop_label: shop?.label,
        },
        processed_at: new Date().toISOString(),
      })
      .eq('id', row.id)
    return 'unclassified'
  }

  const dealId = await findMatchingDeal(admin, row.workspace_id, parsed)

  if (dealId) {
    await applyUpdateToDeal(admin, dealId, parsed, row)
    await admin
      .from('parsed_messages')
      .update({
        status: 'matched',
        shop_key: parsed.shopKey,
        match_deal_id: dealId,
        parsed_payload: stripBody(parsed),
        processed_at: new Date().toISOString(),
      })
      .eq('id', row.id)
    return 'matched'
  }

  const { error: insErr } = await admin.from('pending_deal_suggestions').insert({
    workspace_id: row.workspace_id,
    parsed_message_id: row.id,
    message_id: row.message_id,
    received_at: row.received_at,
    shop_key: parsed.shopKey,
    shop_label: parsed.shopLabel,
    order_id: parsed.orderId,
    product: parsed.product,
    quantity: parsed.quantity,
    total: parsed.total,
    currency: parsed.currency,
    tracking: parsed.tracking,
    trackings: parsed.trackings && parsed.trackings.length > 0
      ? parsed.trackings
      : null,
    carrier: parsed.carrier,
    eta: parsed.eta,
    status: parsed.status ?? 'ordered',
    raw: stripBody(parsed),
  })
  if (insErr) console.warn('pending_deal_suggestions insert failed', row.id, insErr)

  await admin
    .from('parsed_messages')
    .update({
      status: 'suggested',
      shop_key: parsed.shopKey,
      parsed_payload: stripBody(parsed),
      processed_at: new Date().toISOString(),
    })
    .eq('id', row.id)
  return 'suggested'
}

async function findMatchingDeal(
  admin: SbClient,
  workspaceId: string,
  parsed: ParsedOrder,
): Promise<number | null> {
  if (parsed.orderId) {
    const { data } = await admin
      .from('deals')
      .select('id')
      .eq('workspace_id', workspaceId)
      .eq('ticket_number', parsed.orderId)
      .is('deleted_at', null)
      .limit(1)
    const row = (data ?? [])[0]
    if (row) return (row as { id: number }).id
  }
  const candidates = parsed.trackings && parsed.trackings.length > 0
    ? parsed.trackings
    : parsed.tracking ? [parsed.tracking] : []
  for (const tn of candidates) {
    if (!tn) continue
    const { data } = await admin
      .from('deals')
      .select('id')
      .eq('workspace_id', workspaceId)
      .eq('tracking', tn)
      .is('deleted_at', null)
      .limit(1)
    const row = (data ?? [])[0]
    if (row) return (row as { id: number }).id
  }
  return null
}

async function applyUpdateToDeal(
  admin: SbClient,
  dealId: number,
  parsed: ParsedOrder,
  row: PendingMessage,
): Promise<void> {
  const { data: dealData, error: readErr } = await admin
    .from('deals')
    .select('status, tracking, arrival_date')
    .eq('id', dealId)
    .maybeSingle()
  if (readErr || !dealData) {
    console.warn('deal read for update failed', dealId, readErr)
    return
  }
  const before = dealData as DealRow
  const update: Record<string, unknown> = {}
  const changes: string[] = []

  if (parsed.tracking && !before.tracking) {
    update.tracking = parsed.tracking
    changes.push(`Tracking ${parsed.tracking}`)
  }

  const targetStatus = mapShipStatusToDeal(parsed.status)
  if (targetStatus
      && (STATUS_RANK[targetStatus] ?? 0) > (STATUS_RANK[before.status] ?? 0)) {
    update.status = targetStatus
    changes.push(`Status ${before.status} → ${targetStatus}`)
  }

  let arrivalIso = parsed.eta
  if (parsed.status === 'delivered' && !arrivalIso) {
    arrivalIso = row.received_at ?? new Date().toISOString()
  }
  if (arrivalIso && !before.arrival_date) {
    update.arrival_date = arrivalIso
    changes.push(`Lieferdatum ${arrivalIso.slice(0, 10)}`)
  }

  if (Object.keys(update).length === 0) return

  const { error } = await admin.from('deals').update(update).eq('id', dealId)
  if (error) {
    console.warn('deal update failed', dealId, error)
    return
  }

  await writeInboxActivityLog(admin, row, dealId, changes)
}

async function writeInboxActivityLog(
  admin: SbClient,
  row: PendingMessage,
  dealId: number,
  changes: string[],
): Promise<void> {
  if (changes.length === 0) return
  try {
    const { data } = await admin
      .from('mailbox_accounts')
      .select('user_id')
      .eq('id', row.account_id)
      .maybeSingle()
    const userId = (data as { user_id?: string } | null)?.user_id
    if (!userId) return
    const subject = (row.subject ?? '').trim().slice(0, 80)
    const message = subject.length > 0
      ? `Mail-Update Deal #${dealId}: ${changes.join(', ')} (Mail: ${subject})`
      : `Mail-Update Deal #${dealId}: ${changes.join(', ')}`
    await admin.from('activity_log').insert({
      user_id: userId,
      workspace_id: row.workspace_id,
      type: 'inbox_match',
      message,
    })
  } catch (e) {
    console.warn('activity_log insert failed', dealId, e)
  }
}

export function stripBody(parsed: ParsedOrder): Record<string, unknown> {
  return {
    shop_key: parsed.shopKey,
    shop_label: parsed.shopLabel,
    order_id: parsed.orderId,
    product: parsed.product,
    quantity: parsed.quantity,
    total: parsed.total,
    currency: parsed.currency,
    tracking: parsed.tracking,
    trackings: parsed.trackings,
    carrier: parsed.carrier,
    eta: parsed.eta,
    status: parsed.status,
  }
}
