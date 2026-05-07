// Supabase Edge Function: inbox-parse
//
// Picks up parsed_messages with status='pending', runs the adapter registry
// against the stashed body, and either:
//   1) Updates an existing deal whose ticket_number equals the order_id
//      (status='matched'), OR
//   2) Inserts a pending_deal_suggestions row for user review (status='suggested'), OR
//   3) Falls back to status='unclassified' if no adapter matched.
//
// After processing, the raw body is removed from parsed_payload — only the
// adapter result + headers remain. parsed_messages is later auto-deleted by
// the cleanup_inbox_history cron job (30 days).
//
// Required env (set with `supabase secrets set`):
//   CRON_SECRET               – optional, only used when chained from inbox-poll
//
// Standard env (provided by the runtime):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { detectAndParse, detectShop, type ParsedOrder } from '../_shared/inbox_adapters.ts'

interface PendingMessage {
  id: string
  workspace_id: string
  account_id: string
  from_address: string | null
  subject: string | null
  message_id: string | null
  received_at: string
  parsed_payload: { _raw?: { text?: string; html?: string } } | null
}

// Reihenfolge des Deal-Lifecycles. Wird genutzt um Status-Downgrades
// bei Mail-Race-Conditions zu verhindern: Wenn der Deal lokal schon auf
// "Angekommen" steht, soll eine später eintreffende Versand-Bestätigung
// ihn nicht zurück auf "Unterwegs" werfen.
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

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const cronSecret = Deno.env.get('CRON_SECRET')
  const authHeader = req.headers.get('Authorization') ?? ''
  const isCron = cronSecret && authHeader === `Bearer ${cronSecret}`
  const isService =
    authHeader === `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`
  if (!isCron && !isService) return jsonResp({ error: 'Unauthorized' }, 401)

  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  const { data: pending, error } = await admin
    .from('parsed_messages')
    .select('id, workspace_id, account_id, from_address, subject, message_id, received_at, parsed_payload')
    .eq('status', 'pending')
    .order('received_at', { ascending: true })
    .limit(200)
  if (error) {
    console.error('parsed_messages select failed', error)
    return jsonResp({ error: error.message }, 500)
  }

  let matched = 0, suggested = 0, unclassified = 0
  for (const row of (pending ?? []) as PendingMessage[]) {
    const result = await processOne(admin, row)
    if (result === 'matched') matched++
    else if (result === 'suggested') suggested++
    else unclassified++
  }

  return jsonResp({
    ok: true,
    processed: (pending ?? []).length,
    matched,
    suggested,
    unclassified,
  })
})

async function processOne(
  admin: ReturnType<typeof createClient>,
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

  // Try to match an existing deal first.
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

  // No match → suggestion.
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

/// Findet den passenden Deal für eine Mail. Match-Strategie:
///   1. Order-ID == ticket_number — der Hauptfall (Bestellbestätigung
///      schreibt ticket_number, alle Folge-Mails referenzieren sie).
///   2. Tracking-Nr == deals.tracking — Fallback für Versand- oder
///      Zustell-Updates, deren Body die Order-ID nicht (oder im falschen
///      Format) wiederholt, aber die Tracking-Nr aus einer früheren
///      gematchten Mail bereits am Deal hängt.
async function findMatchingDeal(
  admin: ReturnType<typeof createClient>,
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

/// Wendet die Mail-Erkenntnisse forward-only auf den Deal an:
///   - Status nur upgraden (Bestellt → Unterwegs → Angekommen → Done),
///     kein Downgrade durch verspätete Mails.
///   - Tracking nur setzen wenn aktuell leer; nie überschreiben (User
///     könnte manuell eine andere Nummer gepflegt haben).
///   - arrival_date aus Adapter-eta oder — bei "delivered" ohne eta —
///     aus dem received_at der Mail. Ebenfalls nur wenn aktuell leer.
///   - Bei jeder echten Änderung: Activity-Log-Eintrag, damit der User
///     im Aktivitäten-Tab sieht, woher das Update kam.
async function applyUpdateToDeal(
  admin: ReturnType<typeof createClient>,
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

/// activity_log braucht zwingend eine user_id. Die Edge Function selbst
/// läuft als service_role; wir leiten den User aus dem zugehörigen
/// mailbox_account ab (User, der die Mailbox eingerichtet hat — auch der
/// Owner aus User-Sicht). Wenn das fehlschlägt, schlucken wir den Log-
/// Fehler still: das Deal-Update ist wichtiger als der Audit-Eintrag.
async function writeInboxActivityLog(
  admin: ReturnType<typeof createClient>,
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
    // workspace_id ist seit 20260504000500_data_workspace_scope NOT NULL
    // und RLS filtert reads über workspace_id — ohne wäre der Eintrag
    // weder schreibbar noch im UI sichtbar.
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

function stripBody(parsed: ParsedOrder): Record<string, unknown> {
  // Persist the adapter result, never the raw body.
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

function jsonResp(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
