// Supabase Edge Function: inbox-parse
//
// Hauptpfad: inbox-poll ruft `runParseSweep` jetzt INLINE auf (siehe
// `_shared/inbox_parse_runner.ts`). Diese Function existiert weiter für:
//   1) Re-Parse-Mode: alte unklassifizierte Mails gegen die neue Adapter-
//      Registry sweepen (`{reparse_unclassified: true}`).
//   2) Manueller Sweep, wenn jemand pending-Rows ohne neuen Poll
//      verarbeiten will (Cron-Backup falls Poll mal failed).
//
// Required env (set with `supabase secrets set`):
//   CRON_SECRET               – optional, only used when chained from inbox-poll
//
// Standard env (provided by the runtime):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  detectAndParse,
  detectShop,
  isAccountingMail,
  isCarrierOnly,
} from '../_shared/inbox_adapters.ts'
import { runParseSweep, stripBody } from '../_shared/inbox_parse_runner.ts'

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

  let body: {
    reparse_unclassified?: boolean
    reparse_no_tracking?: boolean
    workspace_id?: string
    shop_key?: string
  } = {}
  if (req.method === 'POST') {
    try {
      const text = await req.text()
      if (text.trim().length > 0) body = JSON.parse(text)
    } catch {
      return jsonResp({ error: 'Invalid JSON body' }, 400)
    }
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  if (body.reparse_unclassified === true) {
    const result = await reparseUnclassified(admin)
    return jsonResp({ ok: true, mode: 'reparse_unclassified', ...result })
  }

  if (body.reparse_no_tracking === true) {
    const result = await reparseNoTracking(admin, {
      workspaceId: body.workspace_id,
      shopKey: body.shop_key,
    })
    return jsonResp({ ok: true, mode: 'reparse_no_tracking', ...result })
  }

  const stats = await runParseSweep(admin, { limit: 200 })
  return jsonResp({ ok: true, ...stats })
})

interface ReparseStats {
  scanned: number
  dismissed_carrier: number
  dismissed_accounting: number
  reshopped: number
}

/// Sweep über alle status='unclassified' Mails:
///   - Carrier-/Accounting-Sender → status='dismissed' (Inbox-Cleanup).
///   - Sender, der jetzt in der Adapter-Registry existiert → shop_key
///     aktualisieren, Mail bleibt 'unclassified' (Body ist weg).
async function reparseUnclassified(
  admin: ReturnType<typeof createClient>,
): Promise<ReparseStats> {
  const stats: ReparseStats = {
    scanned: 0,
    dismissed_carrier: 0,
    dismissed_accounting: 0,
    reshopped: 0,
  }
  let cursor: string | null = null
  const PAGE = 200
  for (let i = 0; i < 25; i++) {
    let q = admin
      .from('parsed_messages')
      .select('id, from_address, subject, shop_key, received_at')
      .eq('status', 'unclassified')
      .order('received_at', { ascending: true })
      .limit(PAGE)
    if (cursor) q = q.gt('received_at', cursor)
    const { data, error } = await q
    if (error) {
      console.error('reparse select failed', error)
      break
    }
    const rows = (data ?? []) as Array<{
      id: string
      from_address: string | null
      subject: string | null
      shop_key: string | null
      received_at: string
    }>
    if (rows.length === 0) break

    for (const row of rows) {
      stats.scanned++
      cursor = row.received_at
      const ctx = {
        from: row.from_address ?? '',
        subject: row.subject ?? '',
        text: '',
        html: '',
      }
      if (isCarrierOnly(ctx)) {
        await admin
          .from('parsed_messages')
          .update({ status: 'dismissed' })
          .eq('id', row.id)
        stats.dismissed_carrier++
        continue
      }
      if (isAccountingMail(ctx)) {
        await admin
          .from('parsed_messages')
          .update({ status: 'dismissed' })
          .eq('id', row.id)
        stats.dismissed_accounting++
        continue
      }
      const shop = detectShop(ctx)
      if (shop && shop.key !== row.shop_key) {
        await admin
          .from('parsed_messages')
          .update({ shop_key: shop.key })
          .eq('id', row.id)
        stats.reshopped++
      }
    }
    if (rows.length < PAGE) break
  }
  return stats
}

interface ReparseNoTrackingStats {
  scanned: number
  rescued: number
  unchanged: number
  errors: number
}

/// Sweep über alle status='suggested' / 'matched' Mails, deren
/// `parsed_payload._raw_html` noch da ist und tracking==null. Wird
/// genutzt, wenn die Adapter-Registry verbessert wurde (z.B. neuer
/// Carrier-URL-Pattern) und bestehende Mails neu durchgejagt werden
/// sollen, ohne erneut über IMAP zu fetchen.
async function reparseNoTracking(
  admin: ReturnType<typeof createClient>,
  options: { workspaceId?: string; shopKey?: string },
): Promise<ReparseNoTrackingStats> {
  const stats: ReparseNoTrackingStats = {
    scanned: 0,
    rescued: 0,
    unchanged: 0,
    errors: 0,
  }
  let cursor: string | null = null
  const PAGE = 100
  for (let i = 0; i < 25; i++) {
    let q = admin
      .from('parsed_messages')
      .select('id, workspace_id, from_address, subject, parsed_payload, received_at')
      .in('status', ['suggested', 'matched'])
      .not('parsed_payload->_raw_html', 'is', null)
      .is('parsed_payload->>tracking', null)
      .order('received_at', { ascending: true })
      .limit(PAGE)
    if (options.workspaceId) q = q.eq('workspace_id', options.workspaceId)
    if (options.shopKey) q = q.eq('shop_key', options.shopKey)
    if (cursor) q = q.gt('received_at', cursor)
    const { data, error } = await q
    if (error) {
      console.error('reparseNoTracking select failed', error)
      break
    }
    const rows = (data ?? []) as Array<{
      id: string
      workspace_id: string
      from_address: string | null
      subject: string | null
      received_at: string
      parsed_payload: Record<string, unknown> | null
    }>
    if (rows.length === 0) break
    for (const row of rows) {
      stats.scanned++
      cursor = row.received_at
      try {
        const payload = row.parsed_payload ?? {}
        const html = (payload._raw_html as string | undefined) ?? ''
        if (!html) {
          stats.unchanged++
          continue
        }
        const ctx = {
          from: row.from_address ?? '',
          subject: row.subject ?? '',
          text: '',
          html,
        }
        const parsed = detectAndParse(ctx)
        if (!parsed || !parsed.tracking) {
          stats.unchanged++
          continue
        }
        // Patch parsed_payload mit neuem tracking. Falls die Mail an
        // einen Deal gematcht ist, propagieren wir die Tracking-Nr
        // ebenfalls — sonst nur in pending_deal_suggestions.
        const newPayload = stripBody(parsed, html)
        const { error: updErr } = await admin
          .from('parsed_messages')
          .update({ parsed_payload: newPayload })
          .eq('id', row.id)
        if (updErr) {
          stats.errors++
          continue
        }
        await admin
          .from('pending_deal_suggestions')
          .update({
            tracking: parsed.tracking,
            trackings: parsed.trackings && parsed.trackings.length > 0
              ? parsed.trackings
              : null,
            carrier: parsed.carrier ?? null,
          })
          .eq('parsed_message_id', row.id)
          .is('tracking', null)
        stats.rescued++
      } catch (e) {
        console.warn('reparseNoTracking row failed', row.id, e)
        stats.errors++
      }
    }
    if (rows.length < PAGE) break
  }
  return stats
}

function jsonResp(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
