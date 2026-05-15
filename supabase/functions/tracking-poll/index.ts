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
  tracking_confidence: 'strong' | 'manual' | 'none' | null
  tracking_needs_review: boolean | null
  status: string
  arrival_date: string | null
  order_date: string
  live_status: LiveStatus | null
  live_status_last_event: string | null
  live_status_updated_at: string | null
}

/// Carrier-übergreifender Live-Status, der dem Deal-Row beigeschrieben wird.
/// Mappt 1:1 auf `ParsedTracking.status` (siehe tracking_adapters.ts).
/// CHECK-Enum in `20260515000000_deals_live_status.sql`.
export type LiveStatus =
  | 'pending'
  | 'in_transit'
  | 'out_for_delivery'
  | 'delivered'
  | 'exception'
  | 'unknown'

interface PollStats {
  workspace_id: string
  checked: number
  delivered: number
  errors: number
}

const MAX_DEALS_PER_RUN = 200

/// Re-Track-Cooldown pro Deal: ein User darf einen einzelnen Deal höchstens
/// alle 30 Sekunden manuell re-tracken. Wir nutzen `deals.live_status_updated_at`
/// als implizites Cooldown-Feld — kein extra Schema nötig. Cron-Polls (alle
/// 4h) sind davon nicht betroffen, weil sie nie den deal_id-Pfad nehmen.
const SINGLE_DEAL_COOLDOWN_MS = 30_000

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

  // Body-Parsing zuerst, damit wir wissen, ob dies ein User-Single-Deal-Call
  // ist (dann erlauben wir JWT-User-Auth als Alternative zu cron/service).
  let onlyWorkspace: string | undefined
  let onlyDealId: number | undefined
  try {
    if (req.headers.get('content-type')?.includes('application/json')) {
      const body = await req.json()
      if (typeof body?.workspace_id === 'string') {
        onlyWorkspace = body.workspace_id
      }
      const parsed = parseDealIdFromBody(body)
      if (parsed.error) return jsonResp({ error: parsed.error }, 400)
      if (parsed.dealId !== undefined) onlyDealId = parsed.dealId
    }
  } catch {
    // body optional
  }

  // Auth-Resolution:
  //   - cron / service-role:      immer erlaubt (Backend-Pfad).
  //   - JWT-User + deal_id gesetzt: erlaubt, wenn User Workspace-Mitglied
  //     ist UND der Deal zu diesem Workspace gehört.
  //   - alles andere:             401 / 403.
  if (!isCron && !isService) {
    if (onlyDealId === undefined) {
      return jsonResp({ error: 'Unauthorized' }, 401)
    }
    // JWT-User-Pfad: Token muss gültig sein, sonst 401.
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } },
    )
    const { data: userData, error: userErr } = await userClient.auth.getUser()
    if (userErr || !userData?.user) {
      return jsonResp({ error: 'Unauthorized' }, 401)
    }
    const userId = userData.user.id

    // Admin-Client für die Lookup-Queries (Service-Role umgeht RLS — wir
    // prüfen Membership selbst).
    const adminLookup = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )
    const { data: dealRow, error: dealErr } = await adminLookup
      .from('deals')
      .select('id, workspace_id, live_status_updated_at')
      .eq('id', onlyDealId)
      .maybeSingle()
    if (dealErr || !dealRow) {
      // 403 statt 404 — verrät keine Existenz fremder Deals.
      return jsonResp({ error: 'Forbidden' }, 403)
    }
    const dealWorkspaceId = (dealRow as { workspace_id: string }).workspace_id

    const { data: memberRow } = await adminLookup
      .from('workspace_members')
      .select('workspace_id')
      .eq('workspace_id', dealWorkspaceId)
      .eq('user_id', userId)
      .maybeSingle()
    if (!memberRow) {
      return jsonResp({ error: 'Forbidden' }, 403)
    }

    // Per-Deal-Cooldown: 30s seit dem letzten live_status_updated_at.
    const lastIso =
      (dealRow as { live_status_updated_at: string | null })
        .live_status_updated_at
    const retryAfterSec = computeRetrackCooldown(lastIso, Date.now())
    if (retryAfterSec !== null) {
      return new Response(
        JSON.stringify({
          error: 'rate_limited',
          retry_after_s: retryAfterSec,
        }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
            'Retry-After': String(retryAfterSec),
          },
        },
      )
    }

    // Workspace auf den Deal-Workspace pinnen — kein Cross-Workspace-Poll.
    onlyWorkspace = dealWorkspaceId
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

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
    const stat = await pollWorkspace(
      admin,
      workspaceId,
      carriers,
      totalBudget,
      onlyDealId,
    )
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
  onlyDealId?: number,
): Promise<PollStats> {
  const stat: PollStats = {
    workspace_id: workspaceId,
    checked: 0,
    delivered: 0,
    errors: 0,
  }

  // Offene Deals: Status "Unterwegs", tracking gesetzt, kein Arrival.
  // T16: Skip Deals mit needs_review=true UND confidence='none' (Legacy/Weak)
  //      → poll nur wenn (needs_review=false) ODER confidence IN ('strong','manual').
  let dealQuery = admin
    .from('deals')
    .select(
      'id, workspace_id, user_id, product, tracking, tracking_confidence, tracking_needs_review, status, arrival_date, order_date, live_status, live_status_last_event, live_status_updated_at',
    )
    .eq('workspace_id', workspaceId)
    .eq('status', 'Unterwegs')
    .is('arrival_date', null)
    .not('tracking', 'is', null)
    .or(
      'tracking_needs_review.is.false,tracking_needs_review.is.null,tracking_confidence.eq.strong,tracking_confidence.eq.manual',
    )
    .order('order_date', { ascending: true })
    .limit(Math.min(budget, MAX_DEALS_PER_RUN))
  if (onlyDealId !== undefined) {
    dealQuery = dealQuery.eq('id', onlyDealId)
  }
  const { data: dealRows, error: dealsErr } = await dealQuery
  if (dealsErr) {
    console.error('Failed to load deals', workspaceId, dealsErr)
    stat.errors++
    return stat
  }

  // Belt-and-Suspenders: Post-Filter, falls Spalten in der DB noch nicht
  // existieren (Migration T5 nicht angewandt) oder die OR-Query unerwartete
  // Rows zurückgibt. Logik identisch zur Query-Bedingung.
  const allRows = (dealRows ?? []) as DealRow[]
  const eligible = allRows.filter((d) => {
    if (d.tracking_needs_review !== true) return true
    return d.tracking_confidence === 'strong' || d.tracking_confidence === 'manual'
  })
  const skipped = allRows.length - eligible.length
  if (skipped > 0) {
    console.log(
      `tracking-poll: skipped ${skipped} deals (needs_review + confidence weak/none) in workspace`,
    )
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

  for (const deal of eligible) {
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

    // Klarna-style Live-Visibility: bei JEDEM erfolgreichen Parse den
    // Live-Status persistieren — nicht nur bei 'delivered'. Duplikate (gleicher
    // Status wie zuletzt) werden geskippt (Spam-Schutz).
    const ok = await persistLiveStatus(admin, deal, adapter, parsed)
    if (ok && parsed.status === 'delivered') stat.delivered++
  }

  return stat
}

async function persistLiveStatus(
  admin: ReturnType<typeof createClient>,
  deal: DealRow,
  adapter: TrackingAdapter,
  parsed: ParsedTracking,
): Promise<boolean> {
  const nowIso = new Date().toISOString()
  const update = buildLiveStatusUpdate(deal, parsed, nowIso)
  if (!update) {
    // Duplicate (live_status unverändert) → kein DB-Roundtrip, kein
    // activity_log-Spam.
    return false
  }

  // Race-Schutz für den Delivered-Pfad: nur wenn Deal noch im erwarteten
  // Zustand ist. Für reine live_status-Updates entfällt der Schutz, dann
  // ist der Update idempotent über die Duplicate-Check.
  let query = admin
    .from('deals')
    .update(update)
    .eq('id', deal.id)
    .eq('workspace_id', deal.workspace_id)
  if (parsed.status === 'delivered') {
    query = query.eq('status', 'Unterwegs').is('arrival_date', null)
  }
  const { error: updErr } = await query
  if (updErr) {
    console.warn('deal update failed', deal.id, updErr.message)
    return false
  }

  // Activity-Log + Push: bisher nur bei 'delivered'. Intermediate-Status
  // werden vorerst still in deals.live_status persistiert (UI zeigt sie an).
  // TODO future: push on transition in_transit → out_for_delivery.
  if (parsed.status === 'delivered') {
    const message = parsed.lastEvent
      ? `Sendung "${deal.product}" via ${adapter.label} angekommen: ${parsed.lastEvent}`
      : `Sendung "${deal.product}" via ${adapter.label} angekommen`
    await admin.from('activity_log').insert({
      workspace_id: deal.workspace_id,
      user_id: deal.user_id,
      type: 'tracking_delivered',
      message,
      date: update.arrival_date ?? nowIso,
    })
  }

  return true
}

/// Reine Funktion: berechnet das `UPDATE`-Patch für einen Deal anhand des
/// Parser-Outputs. Gibt `null` zurück, wenn nichts zu schreiben ist
/// (Duplicate-Status, ohne neue Information). Exportiert für Unit-Tests.
export function buildLiveStatusUpdate(
  deal: Pick<DealRow, 'live_status' | 'live_status_last_event'>,
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

/// Reine Cooldown-Berechnung für den Single-Deal-Re-Track-Pfad. Gibt
/// `null` zurück, wenn der Cooldown abgelaufen / nie gesetzt ist; sonst
/// die Anzahl ganzer Sekunden, die der Caller noch warten muss (für
/// `Retry-After` Header).
export function computeRetrackCooldown(
  lastUpdatedAtIso: string | null,
  nowMs: number,
  cooldownMs: number = SINGLE_DEAL_COOLDOWN_MS,
): number | null {
  if (!lastUpdatedAtIso) return null
  const last = new Date(lastUpdatedAtIso).getTime()
  if (!Number.isFinite(last)) return null
  const elapsed = nowMs - last
  if (elapsed < 0) return null // future timestamp → ignore
  if (elapsed >= cooldownMs) return null
  return Math.ceil((cooldownMs - elapsed) / 1000)
}

/// Reine Body-Validierung für `deal_id`. Gibt entweder die geparste
/// Integer-ID zurück oder einen Fehler-String (für 400-Response).
export function parseDealIdFromBody(
  body: unknown,
): { dealId?: number; error?: string } {
  if (body === null || typeof body !== 'object') return {}
  const raw = (body as Record<string, unknown>).deal_id
  if (raw === undefined || raw === null) return {}
  const n = Number(raw)
  if (!Number.isInteger(n) || n <= 0) return { error: 'invalid deal_id' }
  return { dealId: n }
}

// T16: pure helper, exported for tests. Returns true if a deal-row may be
// polled against carrier APIs. Skip when needs_review=true AND confidence
// is not strong/manual (i.e. legacy 'none' or weak/null).
export function isPollEligible(deal: {
  tracking_needs_review?: boolean | null
  tracking_confidence?: 'strong' | 'manual' | 'none' | null
}): boolean {
  if (deal.tracking_needs_review !== true) return true
  return (
    deal.tracking_confidence === 'strong' || deal.tracking_confidence === 'manual'
  )
}
