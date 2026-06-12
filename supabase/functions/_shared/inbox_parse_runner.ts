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
import {
  stampPipelineHeartbeat,
} from './tracking_validation.ts'

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
  trackings?: string[] | null
  arrival_date: string | null
  carrier?: string | null
  tracking_confidence?: 'strong' | 'manual' | 'none' | null
  tracking_needs_review?: boolean | null
}

// Plan 2026-06-03 §3.4 / §2.8 Amazon-Seed: Amazon Logistics hat keine
// öffentliche Status-API → wird nie gepollt. Beim Deal-Write setzen wir
// daher einen stabilen l10n-KEY (kein hardcoded DE/EN-String) als
// `live_status_last_event`; die Auflösung in einen Anzeige-Text macht der
// Client (T7). `live_status='pending'` bleibt DB-konform (im CHECK-Enum).
const AMAZON_NO_LIVE_STATUS_KEY = 'amazon_no_live_status'

type SbClient = ReturnType<typeof createClient>

/// Run-scoped Cache: DHL-API-Key pro Workspace, einmal pro Run gelesen.
/// Verhindert pro-Mail Roundtrips zum `get_carrier_api_key`-RPC.
/// Plan 2026-05-16 §D3.
type DhlKeyCache = Map<string, string | null>

async function getDhlKeyForWorkspace(
  admin: SbClient,
  workspaceId: string,
  cache: DhlKeyCache,
): Promise<string | null> {
  if (cache.has(workspaceId)) return cache.get(workspaceId) ?? null
  // deno-lint-ignore no-explicit-any
  const { data, error } = await (admin as any).rpc('get_carrier_api_key', {
    _workspace_id: workspaceId,
    _carrier_id: 'dhl',
  })
  if (error) {
    // Kein Klartext-Key in Logs — nur Workspace-ID + Event-Name.
    console.warn(JSON.stringify({
      event: 'validation_key_lookup_failed',
      workspace_id: workspaceId,
    }))
    cache.set(workspaceId, null)
    return null
  }
  const key = (data as string | null) ?? null
  if (!key) {
    console.warn(JSON.stringify({
      event: 'validation_skipped_no_key',
      workspace_id: workspaceId,
    }))
  }
  cache.set(workspaceId, key)
  return key
}

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
  // Plan 2026-05-16 §D3: API-Key pro Workspace einmal pro Run holen.
  // Bei `workspaceId`-Option im Single-Workspace-Mode = 1 Lookup.
  // Im All-Workspaces-Mode (Cron) = 1 Lookup pro distinct workspace.
  const keyCache: DhlKeyCache = new Map()
  const heartbeatStamped = new Set<string>()
  for (const row of rows) {
    // Plan 2026-05-16 Phase C: einmal pro Workspace einen
    // Heartbeat-Stempel setzen, sobald wir wissen dass ein DHL-Key
    // gesetzt ist. Auch wenn keine Mail einen Kandidaten enthielt.
    const apiKey = await getDhlKeyForWorkspace(admin, row.workspace_id, keyCache)
    if (apiKey && !heartbeatStamped.has(row.workspace_id)) {
      // deno-lint-ignore no-explicit-any
      await stampPipelineHeartbeat(admin as any, row.workspace_id)
      heartbeatStamped.add(row.workspace_id)
    }
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

  // Plan 2026-06-03, T3: KEIN DHL-API-Gate mehr. Die Detection ist rein
  // algorithmisch (`tracking_detection.detect()` via `resolveTrackingForAdapter`)
  // und persistiert IMMER — auch ohne konfigurierten Carrier-API-Key. Der
  // Live-Status wird vom täglichen Poll (§3) nachgezogen. Der frühere
  // `applyDhlValidation`-Call (löschte Trackings ohne API-Key) ist entfernt.
  const dealId = await findMatchingDeal(admin, row.workspace_id, parsed)

  if (dealId) {
    await applyUpdateToDeal(admin, dealId, parsed, row)
    await admin
      .from('parsed_messages')
      .update({
        status: 'matched',
        shop_key: parsed.shopKey,
        match_deal_id: dealId,
        parsed_payload: stripBody(parsed, html),
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
    // Plan 2026-06-03 §2.8: Carrier lowercase ('dhl'|'amazon'|'dpd'); detect()
    // emittiert das bereits lowercase, normalizeCarrierForDeal ist Defense.
    carrier: normalizeCarrierForDeal(parsed.carrier),
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
      parsed_payload: stripBody(parsed, html),
      processed_at: new Date().toISOString(),
    })
    .eq('id', row.id)
  return 'suggested'
}

// Plan 2026-06-03, T3: `applyDhlValidation` ist ENTFERNT (beide Call-Sites:
// hier + inbox-parse/index.ts Re-Parse). Es koppelte die Detection an eine
// Live-DHL-API-Probe und löschte JEDES Tracking, wenn kein API-Key gesetzt war
// — die Hauptursache, warum „nichts ankam". Die Detection ist jetzt rein
// algorithmisch (`tracking_detection.detect()`); Carrier kommt lowercase
// ('dhl'|'amazon'|'dpd') direkt aus `parsed.carrier`.

/// Normalisiert einen Carrier-Wert auf lowercase, bevor er nach
/// `deals.carrier`/`pending_deal_suggestions.carrier` geschrieben wird.
/// Der DB-CHECK erlaubt nur `('dhl','amazon','dpd')` (lowercase) — ein
/// uppercase-Write würde `check_violation` werfen und den Deal-Write
/// komplett rollbacken (Plan §2.8 Casing-Fix). Unbekannte Werte → null.
/// Re-Parse-Korrektur (Paket 2, Audit-Roadmap-Rest): darf ein strictly-
/// stronger Kandidat ein bestehendes falsches Tracking ERSETZEN? Bedingungen:
///   * neue Detection ist 'strong' (validiert),
///   * alter Wert ist NICHT manual (User-Eingabe nie überschreiben),
///   * alter Wert ist needs_review ODER nicht-strong (none/null/Legacy).
/// Ein strong→strong-Konflikt bleibt unangetastet (kein Ping-Pong zwischen
/// zwei validierten Werten — das wäre Cross-Mail-Mehrdeutigkeit).
/// Reine Funktion, exportiert für Unit-Tests.
export function shouldReplaceTracking(
  before: Pick<DealRow, 'tracking' | 'tracking_confidence' | 'tracking_needs_review'>,
  parsed: Pick<ParsedOrder, 'tracking' | 'trackingConfidence'>,
): boolean {
  const newIsStrong = (parsed.trackingConfidence ?? 'none') === 'strong'
  const oldIsManual = before.tracking_confidence === 'manual'
  const oldIsWeak = before.tracking_needs_review === true ||
    (before.tracking_confidence ?? 'none') !== 'strong'
  return !!parsed.tracking && !!before.tracking &&
    parsed.tracking !== before.tracking &&
    newIsStrong && !oldIsManual && oldIsWeak
}

/// Multi-Parcel (2026-06-12): vereinigt die Paketnummern eines Deals mit den
/// frisch geparsten Nummern einer Mail. Primary steht immer an Index 0.
/// `droppedOldPrimary=true` (Tracking-Replace): der alte — als falsch
/// erkannte — Primary fliegt aus der Liste. Gibt `null` zurück, wenn die
/// gespeicherte Liste bereits identisch ist (kein Write nötig).
/// Reine Funktion, exportiert für Unit-Tests.
export function mergeDealTrackings(
  before: Pick<DealRow, 'tracking' | 'trackings'>,
  parsed: Pick<ParsedOrder, 'tracking' | 'trackings'>,
  opts: { newPrimary: string | null; droppedOldPrimary: boolean },
): string[] | null {
  const stored = before.trackings && before.trackings.length > 0
    ? before.trackings
    : before.tracking ? [before.tracking] : []

  const merged: string[] = []
  const seen = new Set<string>()
  const push = (tn: string | null | undefined) => {
    const t = (tn ?? '').trim()
    if (!t || seen.has(t)) return
    seen.add(t)
    merged.push(t)
  }
  push(opts.newPrimary ?? before.tracking)
  for (const t of stored) {
    if (opts.droppedOldPrimary && t === before.tracking) continue
    push(t)
  }
  for (const t of parsed.trackings ?? (parsed.tracking ? [parsed.tracking] : [])) {
    push(t)
  }

  if (merged.length === 0) return null
  const unchanged = before.trackings !== null &&
    before.trackings !== undefined &&
    merged.length === before.trackings.length &&
    merged.every((v, i) => v === before.trackings![i])
  return unchanged ? null : merged
}

function normalizeCarrierForDeal(carrier?: string | null): string | null {
  if (!carrier || typeof carrier !== 'string') return null
  const c = carrier.trim().toLowerCase()
  if (
    c === 'dhl' || c === 'amazon' || c === 'dpd' || c === 'gls' ||
    c === 'ups' || c === 'hermes'
  ) {
    return c
  }
  return null
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
    // Multi-Parcel (2026-06-12): auch Deals matchen, die die Nummer als
    // SEKUNDÄR-Paket in trackings[] tragen (cs = Array-Containment, nutzt
    // den GIN-Index deals_trackings_gin). Detect()-Nummern sind normalisiert
    // alphanumerisch — der Guard schützt die PostgREST-or-Syntax defensiv.
    let query = admin
      .from('deals')
      .select('id')
      .eq('workspace_id', workspaceId)
      .is('deleted_at', null)
      .limit(1)
    query = /^[A-Za-z0-9-]+$/.test(tn)
      ? query.or(`tracking.eq.${tn},trackings.cs.{${tn}}`)
      : query.eq('tracking', tn)
    const { data } = await query
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
    .select(
      'status, tracking, trackings, arrival_date, note, carrier, tracking_confidence, tracking_needs_review',
    )
    .eq('id', dealId)
    .maybeSingle()
  if (readErr || !dealData) {
    console.warn('deal read for update failed', dealId, readErr)
    return
  }
  const before = dealData as DealRow & { note?: string | null }
  const update: Record<string, unknown> = {}
  const changes: string[] = []

  // Plan 2026-06-03 §2.8 / §3.1 [Council-Fix]: Carrier (lowercase) IMMER mit
  // dem Tracking schreiben. Ohne expliziten carrier-Write landet der Deal mit
  // carrier=NULL → Poller fällt auf detectAdapter zurück → DPD→DHL-Fehlrouting.
  const carrierLc = normalizeCarrierForDeal(parsed.carrier)

  const canReplaceTracking = shouldReplaceTracking(before, parsed)

  if (parsed.tracking && (!before.tracking || canReplaceTracking)) {
    update.tracking = parsed.tracking
    if (canReplaceTracking) {
      // Flags des alten (unsicheren) Werts mitkorrigieren.
      update.tracking_confidence = 'strong'
      update.tracking_needs_review = false
      // Review-Fix (Workflow 2026-06-11): Live-Status-Felder des ALTEN
      // Trackings sind nach dem Replace bedeutungslos (anderer Carrier /
      // andere Sendung) → nullen, damit die UI keinen stale Status zeigt
      // und der adaptive Poller (last_polled_at=null → sofort fällig) die
      // neue Nummer beim nächsten Tick frisch bewertet. tracking_events
      // bleiben erhalten — die Timeline ist per Dedup-Key an die
      // Tracking-Nummer gebunden und filtert sich selbst.
      update.live_status = null
      update.live_status_last_event = null
      update.live_status_updated_at = null
      update.live_eta = null
      update.last_polled_at = null
      changes.push(
        `Tracking korrigiert ${before.tracking} → ${parsed.tracking}`,
      )
    } else {
      changes.push(`Tracking ${parsed.tracking}`)
    }
    // Carrier setzen, wenn frisch zugewiesen und Deal noch keinen Carrier
    // trägt — ODER wenn wir gerade das Tracking ersetzen (alter Carrier
    // gehörte zum alten, falschen Wert).
    if (carrierLc && (!before.carrier || canReplaceTracking)) {
      update.carrier = carrierLc
      changes.push(`Carrier ${carrierLc}`)
      // Amazon-Seed (§3.4): Amazon Logistics wird nie gepollt → Live-Status
      // sofort als 'pending' + stabiler l10n-Key seeden, damit die UI nicht
      // ewig „Wird vorbereitet" zeigt (Client-Resolution in T7).
      if (carrierLc === 'amazon') {
        update.live_status = 'pending'
        update.live_status_last_event = AMAZON_NO_LIVE_STATUS_KEY
      }
    }
  }

  // Multi-Parcel (2026-06-12): trackings[] mit den geparsten Nummern
  // vereinigen. Greift in zwei Fällen:
  //   a) Primary wird gerade geschrieben (fresh oder Replace) — dann gehören
  //      alle Mail-Nummern mit ins Array.
  //   b) Primary bleibt, aber die Mail bringt ZUSÄTZLICHE starke Nummern
  //      desselben Carriers (gesplittete Bestellung, zweite Versand-Mail) —
  //      bisher gingen die still verloren. Carrier-Gate: deals.carrier ist
  //      Single-Column, ein fremder Carrier würde vom Poll gegen die falsche
  //      API geprüft → nur mergen, wenn Carrier passt oder noch keiner steht.
  const primaryWritten = typeof update.tracking === 'string'
  const carrierCompatible = !!carrierLc && (!before.carrier || before.carrier === carrierLc)
  if (primaryWritten ||
      ((parsed.trackingConfidence ?? 'none') === 'strong' && carrierCompatible)) {
    const mergedTrackings = mergeDealTrackings(before, parsed, {
      newPrimary: primaryWritten ? (update.tracking as string) : null,
      droppedOldPrimary: canReplaceTracking,
    })
    if (mergedTrackings) {
      update.trackings = mergedTrackings
      const storedBefore = before.trackings ?? (before.tracking ? [before.tracking] : [])
      const added = mergedTrackings.filter((t) =>
        t !== (primaryWritten ? update.tracking : before.tracking) &&
        !storedBefore.includes(t))
      if (added.length > 0) changes.push(`Weitere Pakete: ${added.join(', ')}`)
    }
  }

  const targetStatus = mapShipStatusToDeal(parsed.status)
  if (targetStatus
      && (STATUS_RANK[targetStatus] ?? 0) > (STATUS_RANK[before.status] ?? 0)) {
    update.status = targetStatus
    changes.push(`Status ${before.status} → ${targetStatus}`)
  }

  // ETA / Arrival-Date-Hierarchie: explizites `parsed.etaDate` (ISO-Date
  // aus Forensik-Helpers) hat Vorrang vor altem `parsed.eta`-Free-Form-
  // Feld; bei `delivered` fallback auf Mail-Empfangs-Zeitpunkt.
  let arrivalIso: string | undefined = parsed.etaDate
    ? `${parsed.etaDate}T00:00:00.000Z`
    : parsed.eta
  if (parsed.status === 'delivered' && !arrivalIso) {
    arrivalIso = row.received_at ?? new Date().toISOString()
  }
  if (arrivalIso && !before.arrival_date) {
    update.arrival_date = arrivalIso
    changes.push(`Lieferdatum ${arrivalIso.slice(0, 10)}`)
  }

  // Storno-Grund in Deal-Note hängen — der User soll im Activity-Log
  // sehen WARUM das gecancelt wurde.
  if (parsed.status === 'cancelled' && parsed.cancellationReason) {
    const noteLine = `Storniert: ${parsed.cancellationReason}`
    const existing = (before.note ?? '').trim()
    if (!existing.includes(noteLine)) {
      update.note = existing.length > 0
        ? `${existing}\n${noteLine}`
        : noteLine
      changes.push(`Storno-Grund: ${parsed.cancellationReason}`)
    }
  }

  if (Object.keys(update).length === 0) return

  const { error } = await admin.from('deals').update(update).eq('id', dealId)
  if (error) {
    console.warn('deal update failed', dealId, error)
    return
  }

  // Reiner trackings[]-Backfill (Array-Sync ohne inhaltliche Änderung)
  // verdient keinen Activity-Log-Eintrag.
  if (changes.length > 0) {
    await writeInboxActivityLog(admin, row, dealId, changes)
  }
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

// HTML-Body wird (kompakt) im parsed_payload aufbewahrt, damit der
// /reparse-Mode bei Adapter-Verbesserungen erneut Tracking-Nrn extrahieren
// kann. Hard-Cap bei 60KB, damit eine 100KB-Mail mit eingebetteten Bildern
// nicht jede Row aufbläht.
const HTML_RAW_CAP_BYTES = 60_000

export function stripBody(
  parsed: ParsedOrder,
  rawHtml?: string,
): Record<string, unknown> {
  const out: Record<string, unknown> = {
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
    // ── Forensik-Erweiterungen (alle optional). Ein leeres / undefined
    //    Feld bleibt undefined und wird von Postgres als JSON-null
    //    gespeichert — bestehende Konsumenten lesen diese Keys nicht
    //    und sind davon nicht betroffen.
    eta_date: parsed.etaDate,
    shipped_at: parsed.shippedAt,
    order_total: parsed.orderTotal,
    tax_rate_pct: parsed.taxRatePct,
    shipping_address_country: parsed.shippingAddressCountry,
    items: parsed.items,
    delivery_method: parsed.deliveryMethod,
    cancellation_reason: parsed.cancellationReason,
    seller: parsed.seller,
    // ── T3c: Strict-Tracking Felder ────────────────────────────────────
    tracking_confidence: parsed.trackingConfidence ?? 'none',
    tracking_candidates: parsed.trackingCandidates,
    tracking_needs_review: parsed.trackingNeedsReview ?? false,
  }
  // Re-Parse-Quelle: nur wenn KEIN tracking extrahiert werden konnte und
  // die Mail aussieht wie ein Versand-Update. Sonst Speicher sparen.
  if (!parsed.tracking
      && (parsed.status === 'shipped' || parsed.status === 'delivered')
      && rawHtml && rawHtml.length > 0) {
    out._raw_html = rawHtml.slice(0, HTML_RAW_CAP_BYTES)
  }
  return out
}
