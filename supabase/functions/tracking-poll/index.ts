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
import {
  type FcmToken,
  getGoogleAccessToken,
  parseServiceAccount,
  type PushPayload,
  sendToTokens,
} from '../_shared/fcm.ts'
import { DETECTION_ONLY_CARRIERS } from '../_shared/carriers.ts'

interface CredentialRow {
  workspace_id: string
  carrier_id: 'dhl' | 'dpd' | 'ups'
  enabled: boolean
  daily_call_count: number | null
  daily_call_date: string | null
}

interface DealRow {
  id: number
  workspace_id: string
  user_id: string
  product: string
  tracking: string | null
  carrier: 'dhl' | 'amazon' | 'dpd' | 'gls' | 'ups' | null
  tracking_confidence: 'strong' | 'manual' | 'none' | null
  tracking_needs_review: boolean | null
  status: string
  arrival_date: string | null
  order_date: string
  live_status: LiveStatus | null
  live_status_last_event: string | null
  live_status_updated_at: string | null
  live_eta: string | null
  last_polled_at: string | null
}

/// Carrier-übergreifender Live-Status, der dem Deal-Row beigeschrieben wird.
/// Mappt auf `ParsedTracking.status` (siehe tracking_adapters.ts) plus
/// `expired` (Reaper-Status, nur DB-seitig). CHECK-Enum in
/// `20260515000000_deals_live_status.sql`; 'unknown' wird NIE persistiert.
export type LiveStatus =
  | 'pending'
  | 'in_transit'
  | 'out_for_delivery'
  | 'delivered'
  | 'exception'
  | 'expired'
  | 'unknown'

interface PollStats {
  workspace_id: string
  checked: number
  delivered: number
  errors: number
  quota_skipped: number
}

const MAX_DEALS_PER_RUN = 200

/// Tages-Quota-Cap pro Workspace×Carrier. DHL Parcel-DE erlaubt 1.000
/// Queries/Tag (PR #115) — wir kappen bei 900, damit Event-Trigger-Polls und
/// manuelle Retracks immer Luft haben.
export const DAILY_QUOTA_CAP = 900

/// DHL Parcel-DE-Tracking-API erlaubt max. 3 req/s pro API-Key (developer.dhl.com,
/// "DHL Parcel DE Tracking"; zusätzlich 1.000 Queries/Tag). Wir drosseln die
/// sequentiellen Carrier-Calls innerhalb eines Workspaces auf ≥350 ms Abstand
/// (≈2.85 req/s) → sicher unter dem Limit, kein 429-Spam. Per Workspace, weil das
/// Limit pro API-Key gilt und verschiedene Workspaces eigene Keys haben.
const MIN_MS_BETWEEN_TRACKING_CALLS = 350
const _trkSleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms))

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
  // Daily-Sweep-Steuerung (Plan §3.2). `mode='daily-sweep'` aktiviert den
  // Hour-Guard; alles andere (undefined/manual/service) läuft durch.
  let mode: string | undefined
  let targetBerlinHours: number[] | undefined
  try {
    if (req.headers.get('content-type')?.includes('application/json')) {
      const body = await req.json()
      if (typeof body?.workspace_id === 'string') {
        onlyWorkspace = body.workspace_id
      }
      // deal_id-Validierung zuerst (kann 400 werfen) — strikt getrennt von
      // der mode/target-Parse, damit es keine 400-Kollision gibt.
      const parsed = parseDealIdFromBody(body)
      if (parsed.error) return jsonResp({ error: parsed.error }, 400)
      if (parsed.dealId !== undefined) onlyDealId = parsed.dealId

      // mode/target_berlin_hours separat NACH der deal_id-Validierung parsen.
      // Diese Felder lösen NIE einen 400 aus: ungültige Werte werden ignoriert,
      // der Default greift (fail-closed bzw. [13]) — siehe dailySweepShouldRun.
      const m = (body as Record<string, unknown> | null)?.mode
      if (typeof m === 'string') mode = m
      const th = (body as Record<string, unknown> | null)?.target_berlin_hours
      if (Array.isArray(th)) {
        targetBerlinHours = th.filter(
          (h): h is number => typeof h === 'number' && Number.isInteger(h) && h >= 0 && h <= 23,
        )
      }
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
      .select('id, workspace_id, live_status_updated_at, last_polled_at')
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

    // Per-Deal-Cooldown: 30s seit dem letzten erfolgreichen Poll. Fallback
    // auf live_status_updated_at für Legacy-Rows ohne last_polled_at.
    const cooldownRow = dealRow as {
      live_status_updated_at: string | null
      last_polled_at: string | null
    }
    const lastIso = cooldownRow.last_polled_at ?? cooldownRow.live_status_updated_at
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

  // Off-Hour-Guard (Plan §3.2): Der pg_cron-Daily-Sweep feuert an BEIDEN
  // UTC-Kandidatenstunden (11/12), aber nur EINE entspricht 13:00 Berlin
  // (DST-abhängig). Wir gaten serverseitig auf die echte Berliner Wanduhr.
  // Nur der Daily-Sweep (mode='daily-sweep', kein deal_id) wird gegated;
  // Single-Deal-Trigger, manuelle Retracks und Service-Calls laufen durch.
  if (onlyDealId === undefined && !dailySweepShouldRun(mode, targetBerlinHours)) {
    return jsonResp({ ok: true, skipped: 'off-hour', berlin_hour: berlinHourNow() })
  }

  // Quiet-Hours-Guard für den stündlichen adaptive-sweep (Paket 1.5):
  // nachts (Berlin 22–05 Uhr) bewegt sich im Carrier-Netz fast nichts —
  // Polls wären reine Quota-Verschwendung.
  if (onlyDealId === undefined && !adaptiveSweepShouldRun(mode)) {
    return jsonResp({ ok: true, skipped: 'quiet-hours', berlin_hour: berlinHourNow() })
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  const credQuery = admin
    .from('workspace_carrier_credentials')
    .select('workspace_id, carrier_id, enabled, daily_call_count, daily_call_date')
    .eq('enabled', true)
  const { data: credRows, error: credErr } = onlyWorkspace
    ? await credQuery.eq('workspace_id', onlyWorkspace)
    : await credQuery
  if (credErr) {
    console.error('Failed to load workspace_carrier_credentials', credErr)
    return jsonResp({ error: credErr.message }, 500)
  }

  // Gruppiere Credentials pro Workspace + Tages-Quota-Restbudget pro
  // Workspace×Carrier (DHL: 1.000/Tag hart → Cap 900, Lesson PR #115).
  const todayUtc = new Date().toISOString().slice(0, 10)
  const byWorkspace = new Map<string, Set<'dhl' | 'dpd' | 'ups'>>()
  const quotaRemaining = new Map<string, number>()
  for (const row of (credRows ?? []) as CredentialRow[]) {
    let set = byWorkspace.get(row.workspace_id)
    if (!set) {
      set = new Set()
      byWorkspace.set(row.workspace_id, set)
    }
    set.add(row.carrier_id)
    quotaRemaining.set(
      `${row.workspace_id}:${row.carrier_id}`,
      remainingDailyQuota(row.daily_call_count, row.daily_call_date, todayUtc),
    )
  }

  // FCM-Kontext für Status-Wechsel-Pushes — lazy: OAuth-Token wird erst
  // geholt, wenn der erste Push tatsächlich ansteht.
  const pushCtx = createPushContext()

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
      mode,
      quotaRemaining,
      todayUtc,
      pushCtx,
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
  onlyDealId: number | undefined,
  mode: string | undefined,
  quotaRemaining: Map<string, number>,
  todayUtc: string,
  pushCtx: PushContext,
): Promise<PollStats> {
  const stat: PollStats = {
    workspace_id: workspaceId,
    checked: 0,
    delivered: 0,
    errors: 0,
    quota_skipped: 0,
  }

  // Offene Deals: Status "Unterwegs", tracking gesetzt, kein Arrival.
  // T16: Skip Deals mit needs_review=true UND confidence='none' (Legacy/Weak)
  //      → poll nur wenn (needs_review=false) ODER confidence IN ('strong','manual').
  let dealQuery = admin
    .from('deals')
    .select(
      'id, workspace_id, user_id, product, tracking, carrier, tracking_confidence, tracking_needs_review, status, arrival_date, order_date, live_status, live_status_last_event, live_status_updated_at, live_eta, last_polled_at',
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

  // Adaptive Frequenz (Paket 1.5): beim stündlichen adaptive-sweep wird pro
  // Deal anhand von live_status + last_polled_at entschieden, ob ein
  // erneuter Carrier-Call fällig ist (out_for_delivery stündlich,
  // in_transit ~4h, pending/exception 2×/Tag).
  const nowMs = Date.now()
  const dueDeals = mode === 'adaptive-sweep'
    ? eligible.filter((d) => isDuePoll(d, nowMs))
    : eligible

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

  // Quota-/Fehler-Tracking pro Carrier — wird NACH der Schleife in EINEM
  // Write pro Carrier geflusht (statt wie früher ein Credential-Write pro
  // Deal). last_error spiegelt das Ergebnis des letzten Calls.
  const callsMade = new Map<'dhl' | 'dpd' | 'ups', number>()
  const lastErrorByCarrier = new Map<'dhl' | 'dpd' | 'ups', string | null>()

  // Throttle-State: ≥350 ms zwischen echten Carrier-API-Calls (DHL 3 req/s).
  let madeApiCall = false
  for (const deal of dueDeals) {
    if (!deal.tracking || deal.tracking.trim().length === 0) continue
    // Detection-only-Carrier (amazon, gls — siehe carriers.ts): keine
    // öffentliche Status-API. Defensiver Short-Circuit VOR der Adapter-Wahl:
    // weder fetchStatus noch Error-Tracking noch checked-Increment. Greift
    // sowohl über den persistierten carrier ALS auch über das TBA-Pattern
    // (Backfill-Lücke). WICHTIG: ohne diesen Guard fiele z.B. ein
    // 12–14-stelliges GLS-Tracking via detectAdapter-Fallback auf DHL und
    // würde dort sinnlos (und quota-fressend) gepollt.
    if (
      (deal.carrier && DETECTION_ONLY_CARRIERS.has(deal.carrier)) ||
      /^TB[ACM]\d{12}$/i.test((deal.tracking ?? '').trim())
    ) {
      continue
    }
    // Carrier-Routing (Plan §3.1): persistierter `deal.carrier` ist primär,
    // `detectAdapter` nur Fallback (Legacy-Rows ohne carrier). `'amazon'`
    // wurde oben per Short-Circuit aussortiert → `deal.carrier` ist hier nur
    // noch `'dhl' | 'dpd' | null`, also ein gültiger ADAPTERS-Key oder null
    // (→ Fallback). Das `!== 'amazon'`-Gate aus §3.1 ist damit bereits
    // erfüllt; eine erneute Prüfung wäre toter Code (TS narrowt amazon weg).
    const adapter =
      (deal.carrier ? ADAPTERS[deal.carrier] : undefined) ??
      detectAdapter(deal.tracking)
    if (!adapter) continue
    if (!carriers.has(adapter.id)) continue

    // Tages-Quota-Guard: Cap erreicht → kein Call mehr für diesen Carrier
    // heute (DHL sperrt bei >1.000/Tag mit 429, Lesson PR #115).
    const quotaKey = `${workspaceId}:${adapter.id}`
    if ((quotaRemaining.get(quotaKey) ?? DAILY_QUOTA_CAP) <= 0) {
      stat.quota_skipped++
      continue
    }

    const apiKey = await getKey(adapter.id)
    if (!apiKey) continue

    // Rate-Limit-Schutz: ≥350 ms seit dem letzten echten API-Call (DHL 3 req/s).
    if (madeApiCall) await _trkSleep(MIN_MS_BETWEEN_TRACKING_CALLS)
    madeApiCall = true

    stat.checked++
    quotaRemaining.set(quotaKey, (quotaRemaining.get(quotaKey) ?? DAILY_QUOTA_CAP) - 1)
    callsMade.set(adapter.id, (callsMade.get(adapter.id) ?? 0) + 1)

    let parsed: ParsedTracking | null = null
    try {
      parsed = await adapter.fetchStatus(deal.tracking, apiKey)
      lastErrorByCarrier.set(adapter.id, null)
    } catch (e) {
      console.warn('adapter.fetchStatus failed', adapter.id, deal.id, (e as Error).message)
      stat.errors++
      lastErrorByCarrier.set(adapter.id, ((e as Error).message ?? 'fetch failed').slice(0, 500))
      continue
    }
    if (!parsed) continue

    // Klarna-style Live-Visibility: bei JEDEM erfolgreichen Parse den
    // Live-Status persistieren — nicht nur bei 'delivered'. Duplikate (gleicher
    // Status wie zuletzt) werden geskippt (Spam-Schutz).
    const ok = await persistLiveStatus(admin, deal, adapter, parsed, pushCtx)
    if (ok && parsed.status === 'delivered') stat.delivered++
  }

  // Credential-Flush: EIN atomarer Bump pro Carrier (Review-Fix: ein
  // absolutes daily_call_count-Write wäre ein Lost-Update-Race zwischen
  // parallelem Sweep + Event-Trigger-Polls — der RPC inkrementiert
  // server-seitig in einem Statement).
  for (const [carrierId, calls] of callsMade.entries()) {
    const { error: bumpErr } = await admin.rpc('bump_carrier_daily_calls', {
      _workspace_id: workspaceId,
      _carrier_id: carrierId,
      _calls: calls,
      _today: todayUtc,
      _last_error: lastErrorByCarrier.get(carrierId) ?? null,
    })
    if (bumpErr) {
      console.warn(
        'bump_carrier_daily_calls failed',
        workspaceId,
        carrierId,
        bumpErr.message,
      )
    }
  }

  return stat
}

async function persistLiveStatus(
  admin: ReturnType<typeof createClient>,
  deal: DealRow,
  adapter: TrackingAdapter,
  parsed: ParsedTracking,
  pushCtx: PushContext,
): Promise<boolean> {
  const nowIso = new Date().toISOString()
  const patch = buildLiveStatusUpdate(deal, parsed, nowIso)

  // last_polled_at wird IMMER gestempelt — auch bei Duplicate-Status. Das
  // steuert die adaptive Poll-Frequenz (isDuePoll) + den Retrack-Cooldown.
  const update: Record<string, unknown> = patch ?? {}
  update.last_polled_at = nowIso

  // ETA: nur schreiben, wenn der Carrier eine liefert und sie sich ändert.
  if (parsed.etaDate && parsed.etaDate !== (deal.live_eta ?? null)) {
    update.live_eta = parsed.etaDate
  }

  // Race-Schutz für den Delivered-Pfad: nur wenn Deal noch im erwarteten
  // Zustand ist. Für reine live_status-Updates entfällt der Schutz, dann
  // ist der Update idempotent über die Duplicate-Check.
  let query = admin
    .from('deals')
    .update(update)
    .eq('id', deal.id)
    .eq('workspace_id', deal.workspace_id)
  if (patch && parsed.status === 'delivered') {
    query = query.eq('status', 'Unterwegs').is('arrival_date', null)
  }
  const { error: updErr } = await query
  if (updErr) {
    console.warn('deal update failed', deal.id, updErr.message)
    return false
  }

  // Event-Timeline (Paket 1): kompletten Carrier-Event-Verlauf idempotent
  // upserten. Der synthetische Fallback-Event (nur lastEvent, kein Array)
  // wird NUR bei echtem Status-/Event-Wechsel eingefügt — sonst würde er
  // mit frischem occurred_at jede Stunde ein Duplikat erzeugen.
  const eventRows = buildTrackingEventRows(
    deal,
    adapter.id,
    parsed,
    nowIso,
    patch !== null,
  )
  if (eventRows.length > 0) {
    const { error: evErr } = await admin
      .from('tracking_events')
      .upsert(eventRows, {
        onConflict: 'deal_id,tracking,occurred_at,description',
        ignoreDuplicates: true,
      })
    if (evErr) {
      console.warn('tracking_events upsert failed', deal.id, evErr.message)
    }
  }

  if (!patch) {
    // Duplicate (live_status unverändert) → kein Activity-Log, kein Push.
    return false
  }

  // Status-Wechsel-Push (Klarna-Moment): bei jedem echten Übergang außer
  // nach 'pending'. Dedup über notifications_sent (ref 'tracking_status',
  // `${dealId}:${status}`) — pro Deal+Status maximal EIN Push, je Lauf
  // race-safe über Claim-then-Send.
  const newStatus = parsed.status !== 'unknown' ? (parsed.status as LiveStatus) : null
  if (newStatus && newStatus !== deal.live_status && newStatus !== 'pending') {
    await maybeSendStatusPush(admin, pushCtx, deal, newStatus, parsed)
  }

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

// ─── Paket 1: Event-Timeline, adaptive Frequenz, Quota, Status-Push ───────

/// Reine Funktion: mappt einen Parser-Output auf `tracking_events`-Rows.
/// Events ohne parsbaren Timestamp werden verworfen. Liefert der Carrier
/// keine Event-Liste, wird (nur bei `includeSynthetic`, d.h. echtem
/// Status-Wechsel) ein synthetischer Event aus `lastEvent` gebaut, damit
/// die Timeline nie leer bleibt. Exportiert für Unit-Tests.
export function buildTrackingEventRows(
  deal: Pick<DealRow, 'id' | 'workspace_id' | 'tracking'>,
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
      // Review-Fix: Carrier-Status-Timestamp bevorzugen — Poll-Zeit nur als
      // letzter Fallback, sonst zeigt die Timeline falsche Event-Zeiten.
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

/// Reine Funktion: verbleibendes Tages-Quota-Budget für einen Carrier.
/// Datum ≠ heute (UTC) → Zähler gilt als zurückgesetzt. Exportiert für Tests.
export function remainingDailyQuota(
  count: number | null | undefined,
  dateStr: string | null | undefined,
  todayUtc: string,
  cap: number = DAILY_QUOTA_CAP,
): number {
  if (!dateStr || dateStr !== todayUtc) return cap
  return Math.max(0, cap - (count ?? 0))
}

/// Reine Funktion: ist dieser Deal beim stündlichen adaptive-sweep fällig?
///   out_for_delivery → jede Stunde (≥50 min)
///   in_transit       → alle ~4 h (≥230 min)
///   pending/exception/null → 2×/Tag (≥660 min)
///   delivered/expired → nie
/// Nie gepollte Deals (last_polled_at null) sind immer fällig.
export function isDuePoll(
  deal: Pick<DealRow, 'live_status' | 'last_polled_at'>,
  nowMs: number,
): boolean {
  if (deal.live_status === 'delivered' || deal.live_status === 'expired') {
    return false
  }
  if (!deal.last_polled_at) return true
  const last = Date.parse(deal.last_polled_at)
  if (!Number.isFinite(last)) return true
  const elapsedMin = (nowMs - last) / 60_000
  switch (deal.live_status) {
    case 'out_for_delivery':
      return elapsedMin >= 50
    case 'in_transit':
      return elapsedMin >= 230
    default:
      return elapsedMin >= 660
  }
}

/// Quiet-Hours-Gate für den stündlichen adaptive-sweep: Berlin 22–05 Uhr
/// wird geskippt (nachts keine Carrier-Scans → Quota-Verschwendung).
/// Andere Modi (daily-sweep, single-deal, manual) laufen immer durch.
export const ADAPTIVE_ACTIVE_FROM_HOUR = 6
export const ADAPTIVE_ACTIVE_UNTIL_HOUR = 22 // exklusiv

export function adaptiveSweepShouldRun(
  mode: string | undefined,
  nowMs: number = Date.now(),
): boolean {
  if (mode !== 'adaptive-sweep') return true
  const h = berlinHourNow(nowMs)
  return h >= ADAPTIVE_ACTIVE_FROM_HOUR && h < ADAPTIVE_ACTIVE_UNTIL_HOUR
}

/// Reine Funktion: Push-Payload für einen Status-Wechsel. PII-bewusst: nur
/// Produktname (wie der bestehende delivery-Push) + Status — keine
/// Tracking-Nummer, keine Adresse. data.route für künftiges Deep-Linking.
export function buildStatusPushPayload(
  deal: Pick<DealRow, 'id' | 'product'>,
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
/// still übersprungen, der Poll-Lauf bleibt erfolgreich.
export interface PushContext {
  ensure(): Promise<{ projectId: string; accessToken: string } | null>
}

function createPushContext(): PushContext {
  let resolved: { projectId: string; accessToken: string } | null | undefined
  return {
    async ensure() {
      if (resolved !== undefined) return resolved
      const sa = parseServiceAccount()
      if (!sa) {
        console.log('tracking-poll: FCM env fehlt — Status-Push übersprungen')
        resolved = null
        return null
      }
      try {
        const accessToken = await getGoogleAccessToken(sa)
        resolved = { projectId: sa.project_id, accessToken }
      } catch (e) {
        console.warn('tracking-poll: FCM OAuth failed', (e as Error).message)
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
async function maybeSendStatusPush(
  admin: ReturnType<typeof createClient>,
  pushCtx: PushContext,
  deal: DealRow,
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
    // Push ist Best-Effort — nie den Poll-Lauf reißen.
    console.warn('tracking-poll: status push failed', deal.id, (e as Error).message)
  }
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

/// Default-Zielstunde des Daily-Sweeps (Berlin-Wanduhr). Server-seitig hart
/// verdrahtet (User-Spec: exakt 13:00 Europe/Berlin). Das Body-Feld
/// `target_berlin_hours` ist nur ein Override.
export const DEFAULT_TARGET_BERLIN_HOURS: readonly number[] = [13]

/// Aktuelle Stunde (0–23) auf der Berliner Wanduhr — DST-sicher via
/// `Intl.DateTimeFormat('Europe/Berlin')`. Reine Funktion, unit-getestet.
export function berlinHourNow(nowMs: number = Date.now()): number {
  return Number(
    new Intl.DateTimeFormat('en-GB', {
      timeZone: 'Europe/Berlin',
      hour: '2-digit',
      hour12: false,
    }).format(new Date(nowMs)),
  )
}

/// Entscheidet, ob der Daily-Sweep in diesem Aufruf laufen darf (Plan §3.2).
///
/// Semantik (klar dokumentiert, getestet):
///   - `mode !== 'daily-sweep'`  → IMMER true (Bypass: single-deal/manual/
///     service-Calls werden NIE gegated).
///   - `mode === 'daily-sweep'`:
///       * `targetHours` ist ein nicht-leeres, gültiges Array
///         → `targetHours.includes(berlinHourNow())`.
///       * `targetHours` ist undefined / kein Array (Body lieferte kein
///         gültiges Override) → Default `[13]` wird verwendet (NICHT
///         fail-closed): `DEFAULT_TARGET_BERLIN_HOURS.includes(...)`.
///       * `targetHours` ist ein LEERES Array (explizit `[]` übergeben, z.B.
///         nach Filtern aller invaliden Werte) → **FAIL-CLOSED → false**
///         (Plan-Direktive: leere/invalide targetHours bei daily-sweep
///         laufen nicht, damit ein Konfig-Fehler nie einen ungewollten
///         Sweep auslöst).
export function dailySweepShouldRun(
  mode: string | undefined,
  targetHours: number[] | undefined,
  nowMs: number = Date.now(),
): boolean {
  if (mode !== 'daily-sweep') return true // single-deal/manual/service → bypass
  // Body lieferte gar kein Array → Server-Default [13].
  if (targetHours === undefined) {
    return DEFAULT_TARGET_BERLIN_HOURS.includes(berlinHourNow(nowMs))
  }
  // Explizit leeres (oder vollständig aussortiertes) Array → fail-closed.
  if (targetHours.length === 0) return false
  return targetHours.includes(berlinHourNow(nowMs))
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

/// Auth-Typ: bestimmt aus Request-Header + Env-Secrets, welcher Caller-Typ
/// vorliegt. Reine Funktion, kein I/O — testbar ohne Netzwerk.
///
///   'cron'    — gültiges CRON_SECRET im Authorization-Header.
///   'service' — SUPABASE_SERVICE_ROLE_KEY im Authorization-Header.
///   'jwt'     — Bearer-Token vorhanden, aber keines der Backend-Secrets.
///   'none'    — kein Authorization-Header (leer oder fehlt).
///
/// Priorität: cron vor service (beide könnten zufällig identisch sein — in
/// der Praxis sind sie es nie, aber die Reihenfolge ist dokumentiert).
export type AuthType = 'cron' | 'service' | 'jwt' | 'none'

export function resolveAuthType(
  authHeader: string,
  cronSecret: string | undefined,
  serviceKey: string | undefined,
): AuthType {
  if (!authHeader) return 'none'
  if (cronSecret && authHeader === `Bearer ${cronSecret}`) return 'cron'
  if (serviceKey && authHeader === `Bearer ${serviceKey}`) return 'service'
  if (authHeader.startsWith('Bearer ')) return 'jwt'
  return 'none'
}

/// Auth-Gate-Entscheidung für den HTTP-Handler. Reine Funktion — kein
/// DB-Lookup, kein I/O. Gibt die erforderliche Weiterverarbeitung zurück:
///
///   'allow-full'        — Backend-Pfad (cron/service): kein weiterer Check.
///   'allow-single-deal' — JWT-User + deal_id gesetzt: Membership-Check nötig.
///   'deny-401'          — kein Auth, kein deal_id → 401.
///   'deny-no-deal'      — JWT-User, aber kein deal_id → 401 (kein Bulk-Zugriff
///                         für JWT-User erlaubt).
export type AuthGateResult =
  | 'allow-full'
  | 'allow-single-deal'
  | 'deny-401'
  | 'deny-no-deal'

export function authGateDecision(
  authType: AuthType,
  hasDealId: boolean,
): AuthGateResult {
  if (authType === 'cron' || authType === 'service') return 'allow-full'
  // JWT oder none — ohne deal_id kein Zugriff.
  if (!hasDealId) return authType === 'jwt' ? 'deny-no-deal' : 'deny-401'
  if (authType === 'jwt') return 'allow-single-deal'
  // none + deal_id → kein gültiges Token vorhanden → 401.
  return 'deny-401'
}
