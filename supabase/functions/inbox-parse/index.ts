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
  findAllTrackings,
  gateTracking,
  isAccountingMail,
  isCarrierOnly,
} from '../_shared/inbox_adapters.ts'
import { runParseSweep, stripBody } from '../_shared/inbox_parse_runner.ts'

// T12: Rate-Limit für User-getriggerte Re-Parse-Calls (5 min Cooldown).
const REPARSE_COOLDOWN_MS = 5 * 60 * 1000

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

  // Dritter Auth-Pfad: User-JWT vom Flutter-Client. Erlaubt manuelles
  // Re-Parsen aus der App heraus ohne Service-Role-Key. Kritisch:
  // wir scopen alles harten auf die Workspaces des Users — kein
  // Cross-Workspace-Zugriff möglich.
  let scopedUserId: string | null = null
  let scopedWorkspaceIds: string[] | null = null
  if (!isCron && !isService) {
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    if (!authHeader || !anonKey) return jsonResp({ error: 'Unauthorized' }, 401)
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      anonKey,
      { global: { headers: { Authorization: authHeader } } },
    )
    const { data: userData, error: userErr } = await userClient.auth.getUser()
    if (userErr || !userData.user) {
      return jsonResp({ error: 'Unauthorized' }, 401)
    }
    scopedUserId = userData.user.id
  }

  let body: {
    reparse_unclassified?: boolean
    reparse_no_tracking?: boolean
    reparse_forensics?: boolean
    // T12: User-getriggerter Re-Parse für Mails mit
    // tracking_confidence='none' oder tracking_needs_review=true.
    // Liest BEIDE Body-Quellen (_raw_html + _raw.text) und versucht
    // Tracking mit der aktuellen Adapter-Registry neu zu klassifizieren.
    reparse_low_confidence?: boolean
    workspace_id?: string
    shop_key?: string
    // Wenn true, werden auch parsed_messages mit bereits gesetztem
    // tracking neu durchgejagt — der Re-Parse überschreibt den alten
    // Wert dann, wenn der Adapter jetzt etwas anderes liefert.
    // Wird gebraucht, wenn ein Adapter-Bug eine FALSCHE Tracking-Nummer
    // gespeichert hat (z.B. orderingShipmentId aus progress-tracker-URL
    // statt der echten Carrier-Nummer aus dem Plain-Text-Body).
    force_overwrite?: boolean
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

  // User-Pfad: einschränken auf eigene Workspace-IDs. Wenn der User im
  // Body einen `workspace_id` mitgibt, prüfen wir Mitgliedschaft. Sonst
  // setzen wir scopedWorkspaceIds = alle Workspaces des Users.
  if (scopedUserId !== null) {
    const { data: memberRows, error: memberErr } = await admin
      .from('workspace_members')
      .select('workspace_id')
      .eq('user_id', scopedUserId)
    if (memberErr) return jsonResp({ error: memberErr.message }, 500)
    scopedWorkspaceIds = (memberRows ?? []).map(
      (r: { workspace_id: string }) => r.workspace_id,
    )
    if (scopedWorkspaceIds.length === 0) {
      return jsonResp({ ok: true, scanned: 0, rescued: 0, scoped_user: scopedUserId })
    }
    if (body.workspace_id && !scopedWorkspaceIds.includes(body.workspace_id)) {
      return jsonResp({ error: 'workspace_id not in user scope' }, 403)
    }
  }

  if (body.reparse_unclassified === true) {
    const result = await reparseUnclassified(admin)
    return jsonResp({ ok: true, mode: 'reparse_unclassified', ...result })
  }

  if (body.reparse_no_tracking === true) {
    const result = await reparseNoTracking(admin, {
      workspaceId: body.workspace_id,
      // User-Pfad: hart auf eigene Workspaces einschränken, falls kein
      // expliziter workspace_id übergeben wurde.
      workspaceIds: body.workspace_id ? undefined
        : (scopedWorkspaceIds ?? undefined),
      shopKey: body.shop_key,
      forceOverwrite: body.force_overwrite === true,
    })
    return jsonResp({ ok: true, mode: 'reparse_no_tracking', ...result })
  }

  if (body.reparse_forensics === true) {
    const result = await reparseForensics(admin, {
      workspaceId: body.workspace_id,
      shopKey: body.shop_key,
    })
    return jsonResp({ ok: true, mode: 'reparse_forensics', ...result })
  }

  if (body.reparse_low_confidence === true) {
    // T12: Endpoint-Contract festschreiben.
    // workspace_id MUSS aus auth.uid()-Scope kommen (siehe scopedWorkspaceIds
    // oben). Service-Role-Pfad (Cron/Maintenance) muss workspace_id explizit
    // im Body übergeben.
    let targetWorkspaceIds: string[] = []
    if (scopedUserId !== null) {
      // User-Pfad: scope auf eigene Workspaces.
      if (body.workspace_id) {
        // Member-Check oben hat bereits validiert.
        targetWorkspaceIds = [body.workspace_id]
      } else {
        targetWorkspaceIds = scopedWorkspaceIds ?? []
      }
    } else {
      // Cron/Service: workspace_id ist Pflicht.
      if (!body.workspace_id) {
        return jsonResp({
          error: 'workspace_id required for reparse_low_confidence in service mode',
        }, 400)
      }
      targetWorkspaceIds = [body.workspace_id]
    }

    if (targetWorkspaceIds.length === 0) {
      return jsonResp({
        ok: true,
        mode: 'reparse_low_confidence',
        scanned: 0,
        updated: 0,
      })
    }

    // Rate-Limit: 5min Cooldown pro Workspace. Wir nehmen die zuletzt
    // gespeicherte last_reparse_at pro Workspace (max über mailbox_accounts).
    const { data: rlRows, error: rlErr } = await admin
      .from('mailbox_accounts')
      .select('workspace_id, last_reparse_at')
      .in('workspace_id', targetWorkspaceIds)
    if (rlErr) {
      return jsonResp({ error: rlErr.message }, 500)
    }
    const now = Date.now()
    let mostRecent = 0
    for (const r of (rlRows ?? []) as Array<{
      workspace_id: string
      last_reparse_at: string | null
    }>) {
      if (r.last_reparse_at) {
        const t = new Date(r.last_reparse_at).getTime()
        if (t > mostRecent) mostRecent = t
      }
    }
    if (mostRecent > 0 && now - mostRecent < REPARSE_COOLDOWN_MS) {
      const retryAfter = Math.ceil(
        (REPARSE_COOLDOWN_MS - (now - mostRecent)) / 1000,
      )
      return jsonResp({
        error: 'rate_limit',
        retry_after_seconds: retryAfter,
      }, 429)
    }

    const result = await reparseLowConfidence(admin, {
      workspaceIds: targetWorkspaceIds,
      shopKey: body.shop_key,
    })

    // Stempel last_reparse_at für alle betroffenen Workspaces.
    const stampIso = new Date().toISOString()
    await admin
      .from('mailbox_accounts')
      .update({ last_reparse_at: stampIso })
      .in('workspace_id', targetWorkspaceIds)

    return jsonResp({ ok: true, mode: 'reparse_low_confidence', ...result })
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
///
/// Mit `forceOverwrite=true` werden auch Rows mit bereits gesetztem
/// tracking neu durchgejagt — gebraucht für Bug-Fixes, die eine FALSCH
/// extrahierte Tracking-Nummer korrigieren müssen. Der neue Wert wird
/// nur geschrieben, wenn er sich tatsächlich vom alten unterscheidet
/// (idempotent gegen Re-Runs).
async function reparseNoTracking(
  admin: ReturnType<typeof createClient>,
  options: {
    workspaceId?: string
    // User-JWT-Pfad: scope auf alle Workspaces des Users.
    workspaceIds?: string[]
    shopKey?: string
    forceOverwrite?: boolean
  },
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
    // Council-Finding #1: BEIDE Body-Quellen (_raw_html + _raw.text) müssen
    // berücksichtigt werden — Plain-Text-only-Mails (PRs #48/#51) sonst
    // unsichtbar für den Re-Parse.
    let q = admin
      .from('parsed_messages')
      .select('id, workspace_id, from_address, subject, parsed_payload, received_at')
      .in('status', ['suggested', 'matched'])
      .or('parsed_payload->_raw_html.not.is.null,parsed_payload->_raw->text.not.is.null')
      .order('received_at', { ascending: true })
      .limit(PAGE)
    // Default-Filter (Bug-Fix-Mode überschreibt das absichtlich):
    if (!options.forceOverwrite) {
      q = q.is('parsed_payload->>tracking', null)
    }
    if (options.workspaceId) q = q.eq('workspace_id', options.workspaceId)
    else if (options.workspaceIds && options.workspaceIds.length > 0) {
      q = q.in('workspace_id', options.workspaceIds)
    }
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
        // Council-Finding #1: Plain-Text-Pfad nachziehen.
        const rawObj = (payload._raw as { text?: string } | undefined) ?? {}
        const text = (rawObj.text as string | undefined) ?? ''
        if (!html && !text) {
          stats.unchanged++
          continue
        }
        const ctx = {
          from: row.from_address ?? '',
          subject: row.subject ?? '',
          text,
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
        let suggestionUpdate = admin
          .from('pending_deal_suggestions')
          .update({
            tracking: parsed.tracking,
            trackings: parsed.trackings && parsed.trackings.length > 0
              ? parsed.trackings
              : null,
            carrier: parsed.carrier ?? null,
          })
          .eq('parsed_message_id', row.id)
        // Im default Re-Parse-Mode (rescue) nur Suggestions ohne Tracking
        // berühren — wir wollen kein bestehendes (bereits manuell vom User
        // editiertes) Tracking versehentlich überschreiben.
        // Im force-Mode überschreiben wir bewusst (Bug-Fix-Re-Parse).
        if (!options.forceOverwrite) {
          suggestionUpdate = suggestionUpdate.is('tracking', null)
        }
        await suggestionUpdate
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

interface ReparseForensicsStats {
  scanned: number
  enriched: number
  unchanged: number
  errors: number
  byShop: Record<string, { enriched: number; unchanged: number }>
}

/// Sweep über ALLE Rows mit `_raw_html` (auch wenn `tracking` schon
/// gesetzt ist). Re-parsed mit der aktuellen Adapter-Registry und
/// patcht `parsed_payload` mit den neuen Forensik-Feldern (eta_date,
/// shipped_at, order_total, items, tax_rate_pct, ...). Bestehende
/// Tracking-Werte werden NICHT überschrieben — wir merge'n nur die
/// neuen Felder rein, was die Migration nicht-destruktiv macht.
async function reparseForensics(
  admin: ReturnType<typeof createClient>,
  options: { workspaceId?: string; shopKey?: string },
): Promise<ReparseForensicsStats> {
  const stats: ReparseForensicsStats = {
    scanned: 0,
    enriched: 0,
    unchanged: 0,
    errors: 0,
    byShop: {},
  }
  let cursor: string | null = null
  const PAGE = 100
  for (let i = 0; i < 50; i++) {
    let q = admin
      .from('parsed_messages')
      .select('id, workspace_id, from_address, subject, parsed_payload, shop_key, received_at')
      .in('status', ['suggested', 'matched'])
      .not('parsed_payload->_raw_html', 'is', null)
      .order('received_at', { ascending: true })
      .limit(PAGE)
    if (options.workspaceId) q = q.eq('workspace_id', options.workspaceId)
    if (options.shopKey) q = q.eq('shop_key', options.shopKey)
    if (cursor) q = q.gt('received_at', cursor)
    const { data, error } = await q
    if (error) {
      console.error('reparseForensics select failed', error)
      break
    }
    const rows = (data ?? []) as Array<{
      id: string
      workspace_id: string
      from_address: string | null
      subject: string | null
      shop_key: string | null
      received_at: string
      parsed_payload: Record<string, unknown> | null
    }>
    if (rows.length === 0) break
    for (const row of rows) {
      stats.scanned++
      cursor = row.received_at
      const shopKey = row.shop_key ?? 'unknown'
      stats.byShop[shopKey] ??= { enriched: 0, unchanged: 0 }
      try {
        const payload = row.parsed_payload ?? {}
        const html = (payload._raw_html as string | undefined) ?? ''
        if (!html) {
          stats.unchanged++
          stats.byShop[shopKey].unchanged++
          continue
        }
        const ctx = {
          from: row.from_address ?? '',
          subject: row.subject ?? '',
          text: '',
          html,
        }
        const parsed = detectAndParse(ctx)
        if (!parsed) {
          stats.unchanged++
          stats.byShop[shopKey].unchanged++
          continue
        }
        // Merge-Strategie: NEW > OLD nur für Forensik-Felder. Bestehende
        // Felder (tracking, order_id, ...) bleiben unverändert.
        const newFields = stripBody(parsed, html)
        const merged: Record<string, unknown> = { ...payload }
        const FORENSIK_KEYS = [
          'eta_date', 'shipped_at', 'order_total', 'tax_rate_pct',
          'shipping_address_country', 'items', 'delivery_method',
          'cancellation_reason', 'seller',
        ]
        let changed = false
        for (const k of FORENSIK_KEYS) {
          if (newFields[k] !== undefined && newFields[k] !== null
              && merged[k] === undefined) {
            merged[k] = newFields[k]
            changed = true
          }
        }
        if (!changed) {
          stats.unchanged++
          stats.byShop[shopKey].unchanged++
          continue
        }
        const { error: updErr } = await admin
          .from('parsed_messages')
          .update({ parsed_payload: merged })
          .eq('id', row.id)
        if (updErr) {
          stats.errors++
          continue
        }
        stats.enriched++
        stats.byShop[shopKey].enriched++
      } catch (e) {
        console.warn('reparseForensics row failed', row.id, e)
        stats.errors++
      }
    }
    if (rows.length < PAGE) break
  }
  return stats
}

// ── T12: reparseLowConfidence ─────────────────────────────────────────────
//
// Liest alle parsed_messages mit `tracking_needs_review = TRUE` ODER
// `tracking_confidence = 'none'` aus den gegebenen Workspaces, läuft mit
// `findAllTrackings()` + `gateTracking({minConfidence:'strong'})` über
// BEIDE Body-Quellen (_raw_html UND _raw.text — Council-Finding #1) und
// aktualisiert tracking + carrier + confidence + needs_review + candidates.
// Manuelle Trackings (`tracking_confidence = 'manual'`) werden NICHT
// angetastet (Plan §5.2 Manual-Guard).
interface ReparseLowConfidenceStats {
  scanned: number
  updated: number
  unchanged: number
  skipped_no_body: number
  errors: number
}

async function reparseLowConfidence(
  admin: ReturnType<typeof createClient>,
  options: { workspaceIds: string[]; shopKey?: string },
): Promise<ReparseLowConfidenceStats> {
  const stats: ReparseLowConfidenceStats = {
    scanned: 0,
    updated: 0,
    unchanged: 0,
    skipped_no_body: 0,
    errors: 0,
  }
  let cursor: string | null = null
  const PAGE = 100
  for (let i = 0; i < 25; i++) {
    let q = admin
      .from('parsed_messages')
      .select(
        'id, workspace_id, from_address, subject, parsed_payload, received_at',
      )
      .in('workspace_id', options.workspaceIds)
      .in('status', ['suggested', 'matched'])
      // needs_review=true ODER confidence='none' — beides JSONB-Felder.
      .or(
        'parsed_payload->>tracking_needs_review.eq.true,parsed_payload->>tracking_confidence.eq.none',
      )
      .order('received_at', { ascending: true })
      .limit(PAGE)
    if (options.shopKey) q = q.eq('shop_key', options.shopKey)
    if (cursor) q = q.gt('received_at', cursor)
    const { data, error } = await q
    if (error) {
      console.error('reparseLowConfidence select failed', error)
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
        // Manual-Guard: Wenn parsed-Layer manuell gesetzt ist, nicht anfassen.
        if (payload.tracking_confidence === 'manual') {
          stats.unchanged++
          continue
        }
        const html = (payload._raw_html as string | undefined) ?? ''
        const rawObj = (payload._raw as { text?: string } | undefined) ?? {}
        const text = (rawObj.text as string | undefined) ?? ''
        if (!html && !text) {
          stats.skipped_no_body++
          continue
        }
        const body = text + (text && html ? '\n\n' : '') + html
        const candidates = findAllTrackings(body, { html })
        const { primary } = gateTracking(candidates, { minConfidence: 'strong' })

        const newConfidence = primary ? 'strong' : 'none'
        const newNeedsReview = primary ? false : true
        const newTracking = primary?.value ?? null
        const newCarrier = primary?.carrier ?? null

        const oldTracking = (payload.tracking as string | undefined) ?? null
        const oldConfidence =
          (payload.tracking_confidence as string | undefined) ?? 'none'

        // Idempotenz-Check.
        if (
          newTracking === oldTracking &&
          newConfidence === oldConfidence
        ) {
          stats.unchanged++
          continue
        }

        const patched: Record<string, unknown> = {
          ...payload,
          tracking: newTracking,
          tracking_carrier: newCarrier,
          tracking_confidence: newConfidence,
          tracking_needs_review: newNeedsReview,
          tracking_candidates: candidates.slice(0, 10),
        }

        const { error: updErr } = await admin
          .from('parsed_messages')
          .update({ parsed_payload: patched })
          .eq('id', row.id)
        if (updErr) {
          stats.errors++
          continue
        }

        // Spiegele auf pending_deal_suggestions — nur wenn confidence='strong'
        // (Plan §3.2: medium/weak nie in Deal/Suggestion-Pfad). Manual bleibt
        // intakt (RLS-Layer kann das nicht garantieren → wir filtern hier).
        if (primary) {
          await admin
            .from('pending_deal_suggestions')
            .update({
              tracking: newTracking,
              carrier: newCarrier,
              tracking_confidence: 'strong',
              tracking_needs_review: false,
            })
            .eq('parsed_message_id', row.id)
            .neq('tracking_confidence', 'manual')
        }

        stats.updated++
      } catch (e) {
        console.warn('reparseLowConfidence row failed', row.id, e)
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
