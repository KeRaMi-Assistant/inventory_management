// Supabase Edge Function: tracking-poll
//
// Wird via pg_cron alle 4h getriggert (siehe SETUP.md). Ablauf:
//   1. Lade alle aktiven workspace_carrier_credentials (enabled=true) und
//      gruppiere nach workspace_id.
//   2. Pro Workspace: lade alle offenen Deals (status='Unterwegs',
//      tracking IS NOT NULL, arrival_date IS NULL).
//   3. Pro Deal: erkenne Carrier aus Tracking-Nummer; wenn ein Adapter +
//      gespeicherter API-Key existieren, ruf die Carrier-API ab.
//   4. Bei 'delivered': update Deal (status='Angekommen', arrival_date),
//      schreibe activity_log-Eintrag, optional Push.
//
// Rate-Limiting: pro Lauf max 200 Tracking-Calls (Cap), Reihenfolge nach
// `arrival_date IS NULL` + ältestem `order_date`. So fängt der nächste Tick
// die Reste, falls ein Workspace sehr viele offene Sendungen hat.
//
// Required env (Secrets):
//   CRON_SECRET                 – Shared secret für pg_cron-Aufrufe.
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY – Standard.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  ADAPTERS,
  detectAdapter,
  type ParsedTracking,
  type TrackingAdapter,
} from '../_shared/tracking_adapters.ts'

interface CredentialRow {
  workspace_id: string
  carrier_id: 'dhl' | 'dpd' | 'ups'
  enabled: boolean
}

interface DealRow {
  id: number
  workspace_id: string
  user_id: string
  product: string
  tracking: string | null
  status: string
  arrival_date: string | null
  order_date: string
}

interface PollStats {
  workspace_id: string
  checked: number
  delivered: number
  errors: number
}

const MAX_DEALS_PER_RUN = 200

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
  const isCron = !!cronSecret && authHeader === `Bearer ${cronSecret}`
  const isService =
    authHeader === `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`
  if (!isCron && !isService) return jsonResp({ error: 'Unauthorized' }, 401)

  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  // Optional: gegen einen einzelnen Workspace gezielt pollen (Debug/Manual).
  let onlyWorkspace: string | undefined
  try {
    if (req.headers.get('content-type')?.includes('application/json')) {
      const body = await req.json()
      if (typeof body?.workspace_id === 'string') {
        onlyWorkspace = body.workspace_id
      }
    }
  } catch {
    // body optional
  }

  const credQuery = admin
    .from('workspace_carrier_credentials')
    .select('workspace_id, carrier_id, enabled')
    .eq('enabled', true)
  const { data: credRows, error: credErr } = onlyWorkspace
    ? await credQuery.eq('workspace_id', onlyWorkspace)
    : await credQuery
  if (credErr) {
    console.error('Failed to load workspace_carrier_credentials', credErr)
    return jsonResp({ error: credErr.message }, 500)
  }

  // Gruppiere Credentials pro Workspace.
  const byWorkspace = new Map<string, Set<'dhl' | 'dpd' | 'ups'>>()
  for (const row of (credRows ?? []) as CredentialRow[]) {
    let set = byWorkspace.get(row.workspace_id)
    if (!set) {
      set = new Set()
      byWorkspace.set(row.workspace_id, set)
    }
    set.add(row.carrier_id)
  }

  let totalBudget = MAX_DEALS_PER_RUN
  const stats: PollStats[] = []
  for (const [workspaceId, carriers] of byWorkspace.entries()) {
    if (totalBudget <= 0) break
    const stat = await pollWorkspace(admin, workspaceId, carriers, totalBudget)
    stats.push(stat)
    totalBudget -= stat.checked
  }

  return jsonResp({ ok: true, workspaces: stats.length, stats })
})

async function pollWorkspace(
  admin: ReturnType<typeof createClient>,
  workspaceId: string,
  carriers: Set<'dhl' | 'dpd' | 'ups'>,
  budget: number,
): Promise<PollStats> {
  const stat: PollStats = {
    workspace_id: workspaceId,
    checked: 0,
    delivered: 0,
    errors: 0,
  }

  // Offene Deals: Status "Unterwegs", tracking gesetzt, kein Arrival.
  const { data: dealRows, error: dealsErr } = await admin
    .from('deals')
    .select('id, workspace_id, user_id, product, tracking, status, arrival_date, order_date')
    .eq('workspace_id', workspaceId)
    .eq('status', 'Unterwegs')
    .is('arrival_date', null)
    .not('tracking', 'is', null)
    .order('order_date', { ascending: true })
    .limit(Math.min(budget, MAX_DEALS_PER_RUN))
  if (dealsErr) {
    console.error('Failed to load deals', workspaceId, dealsErr)
    stat.errors++
    return stat
  }

  // Cache decrypted API-Keys pro Carrier (max 3 Aufrufe pro Workspace).
  const keyCache = new Map<'dhl' | 'dpd' | 'ups', string | null>()
  const getKey = async (carrierId: 'dhl' | 'dpd' | 'ups') => {
    if (keyCache.has(carrierId)) return keyCache.get(carrierId) ?? null
    const { data, error } = await admin.rpc('get_carrier_api_key', {
      _workspace_id: workspaceId,
      _carrier_id: carrierId,
    })
    if (error) {
      console.warn('get_carrier_api_key failed', workspaceId, carrierId, error.message)
      keyCache.set(carrierId, null)
      return null
    }
    const key = (data as string | null) ?? null
    keyCache.set(carrierId, key)
    return key
  }

  for (const deal of (dealRows ?? []) as DealRow[]) {
    if (!deal.tracking || deal.tracking.trim().length === 0) continue
    const adapter = detectAdapter(deal.tracking)
    if (!adapter) continue
    if (!carriers.has(adapter.id)) continue
    const apiKey = await getKey(adapter.id)
    if (!apiKey) continue

    stat.checked++
    let parsed: ParsedTracking | null = null
    try {
      parsed = await adapter.fetchStatus(deal.tracking, apiKey)
    } catch (e) {
      console.warn('adapter.fetchStatus failed', adapter.id, deal.id, (e as Error).message)
      stat.errors++
      await markCarrierError(admin, workspaceId, adapter.id, (e as Error).message)
      continue
    }
    if (!parsed) continue

    // Erfolgreicher Call → Fehler-Spalte zurücksetzen + last_polled_at touch.
    await admin
      .from('workspace_carrier_credentials')
      .update({ last_polled_at: new Date().toISOString(), last_error: null })
      .eq('workspace_id', workspaceId)
      .eq('carrier_id', adapter.id)

    if (parsed.status === 'delivered') {
      const ok = await markDealDelivered(admin, deal, adapter, parsed)
      if (ok) stat.delivered++
    }
  }

  return stat
}

async function markDealDelivered(
  admin: ReturnType<typeof createClient>,
  deal: DealRow,
  adapter: TrackingAdapter,
  parsed: ParsedTracking,
): Promise<boolean> {
  const arrivalDate = parsed.deliveredAt ?? new Date().toISOString()
  const { error: updErr } = await admin
    .from('deals')
    .update({ status: 'Angekommen', arrival_date: arrivalDate })
    .eq('id', deal.id)
    .eq('workspace_id', deal.workspace_id)
    // Race-Schutz: nur updaten, wenn der Deal noch im erwarteten Zustand ist.
    .eq('status', 'Unterwegs')
    .is('arrival_date', null)
  if (updErr) {
    console.warn('deal update failed', deal.id, updErr.message)
    return false
  }

  // Activity-Log-Eintrag (workspace + user_id beibehalten — user_id=Erfasser).
  const message = parsed.lastEvent
    ? `Sendung "${deal.product}" via ${adapter.label} angekommen: ${parsed.lastEvent}`
    : `Sendung "${deal.product}" via ${adapter.label} angekommen`
  await admin.from('activity_log').insert({
    workspace_id: deal.workspace_id,
    user_id: deal.user_id,
    type: 'tracking_delivered',
    message,
    date: arrivalDate,
  })

  return true
}

async function markCarrierError(
  admin: ReturnType<typeof createClient>,
  workspaceId: string,
  carrierId: 'dhl' | 'dpd' | 'ups',
  message: string,
): Promise<void> {
  await admin
    .from('workspace_carrier_credentials')
    .update({
      last_polled_at: new Date().toISOString(),
      last_error: message.slice(0, 500),
    })
    .eq('workspace_id', workspaceId)
    .eq('carrier_id', carrierId)
}

function jsonResp(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// Re-exports für Tests (Deno-Test importiert den Edge-Fn-Code, ruft aber
// nur die reinen Adapter-Funktionen auf).
export { ADAPTERS }
