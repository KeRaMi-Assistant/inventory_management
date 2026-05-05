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
  from_address: string | null
  subject: string | null
  parsed_payload: { _raw?: { text?: string; html?: string } } | null
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
    .select('id, workspace_id, from_address, subject, parsed_payload')
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
  const dealId = parsed.orderId
    ? await findMatchingDeal(admin, row.workspace_id, parsed.orderId)
    : null

  if (dealId) {
    await applyUpdateToDeal(admin, dealId, parsed)
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
    shop_key: parsed.shopKey,
    shop_label: parsed.shopLabel,
    order_id: parsed.orderId,
    product: parsed.product,
    quantity: parsed.quantity,
    total: parsed.total,
    currency: parsed.currency,
    tracking: parsed.tracking,
    carrier: parsed.carrier,
    eta: parsed.eta,
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
  admin: ReturnType<typeof createClient>,
  workspaceId: string,
  orderId: string,
): Promise<number | null> {
  const { data } = await admin
    .from('deals')
    .select('id')
    .eq('workspace_id', workspaceId)
    .eq('ticket_number', orderId)
    .is('deleted_at', null)
    .limit(1)
  const row = (data ?? [])[0]
  return row ? (row as { id: number }).id : null
}

async function applyUpdateToDeal(
  admin: ReturnType<typeof createClient>,
  dealId: number,
  parsed: ParsedOrder,
): Promise<void> {
  const update: Record<string, unknown> = {}
  if (parsed.tracking) update.tracking = parsed.tracking
  if (parsed.eta) update.arrival_date = parsed.eta
  if (parsed.status === 'shipped') update.status = 'Unterwegs'
  else if (parsed.status === 'delivered') update.status = 'Angekommen'
  if (Object.keys(update).length === 0) return
  const { error } = await admin.from('deals').update(update).eq('id', dealId)
  if (error) console.warn('deal update failed', dealId, error)
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
