// Plan 2026-05-16 §D2 — DHL-API-Validation als Wrapper NACH
// `parseInboxMessage`/`detectAndParse`. Filtert die Pattern-Candidates
// (`parsed.trackingCandidates`) gegen die DHL-API und behaelt nur die
// Kandidaten, die von DHL als bekannte Sendung bestaetigt werden.
//
// Architektur-Entscheidung (Plan §D2): Wrapper laeuft EINMAL pro Mail
// im Parse-Runner, NICHT inline in `resolveTrackingForAdapter`. Dadurch
// bleibt `parseInboxMessage` synchron und unit-testbar; nur der Runner
// hat die eine neue async-Site.
//
// Cache-Logik:
//   * `valid`   → 7 Tage TTL
//   * `invalid` → 30 Tage TTL
//   * `unknown` → 1 Stunde TTL (Network-Errors / 429-Sim — selbstheilend)
// Cache-PK = `tracking_norm` (global, kein workspace_id). Begruendung:
// eine Tracking-Nr ist objektiv valide oder nicht — Cross-Workspace-
// Reuse spart massiv API-Calls (DHL Free-Tier: 1 Call / 5s, 250/Tag).
//
// Rate-Limit-Resilienz (Plan §D2.9):
//   * Spike-Arrest: 5100ms zwischen API-Calls (DHL Free-Tier 1/5s).
//   * Hard-Limit: max 5 API-Calls pro Mail. Ueberschuss → strukturiertes
//     Warn-Log + Drop.
//   * Network-Exception (fetch wirft) → `unknown` mit 1h-TTL.
//   * `fetchStatus` liefert `null` (HTTP != 200 inkl. 404) → `invalid`.
//     DHL-API kann aus `null` allein 429 nicht von 404 unterscheiden —
//     pragmatischer Trade-Off, 1h-Reaper via `unknown` wuerde Cache
//     vergiften. Bei echten Outages (5xx) wirft das `fetch` typischerweise
//     eine Exception (DNS / Timeout) und wird korrekt als `unknown`
//     klassifiziert.

import { dhlAdapter } from './tracking_adapters.ts'

const SPIKE_ARREST_MS = 5100  // DHL Free-Tier: 1 Call / 5s
const HARD_LIMIT_CALLS_PER_MAIL = 5

const TTL_MS = {
  valid: 7 * 24 * 60 * 60 * 1000,
  invalid: 30 * 24 * 60 * 60 * 1000,
  unknown: 1 * 60 * 60 * 1000,
} as const

export type ResultState = 'valid' | 'invalid' | 'unknown'

interface CacheRow {
  tracking_norm: string
  is_valid: boolean
  result_state: ResultState
  last_checked_at: string
}

// Minimal-Shape, was wir aus `parseInboxMessage`/`ParsedOrder` brauchen.
// Bewusst lose getypt (vs. ParsedOrder importieren), damit der Wrapper
// auch fuer `pending_deal_suggestions`-Rows oder kuenftige
// Re-Parse-Payloads wiederverwendbar bleibt.
export interface ParsedMessageLike {
  tracking?: string | null
  trackings?: string[] | null
  tracking_confidence?: 'strong' | 'none' | null
  tracking_needs_review?: boolean | null
  trackingCandidates?: Array<{
    value: string
    confidence: 'strong' | 'medium' | 'weak' | 'none'
    carrier?: string
  }>
}

// Minimaler Supabase-Client-Shape, ohne `@supabase/supabase-js` zu
// importieren — vermeidet Typ-Zyklus mit dem Runner.
interface SupabaseAdminLike {
  from(table: string): {
    select(cols: string): {
      eq(col: string, val: string): {
        maybeSingle(): Promise<{ data: CacheRow | null; error: unknown }>
      }
    }
    upsert(
      row: Record<string, unknown>,
      opts?: { onConflict?: string },
    ): Promise<{ error: unknown }>
  }
}

export interface EnrichOptions {
  status?: 'ordered' | 'shipped' | 'delivered' | 'cancelled' | 'refunded'
  workspaceId: string
  apiKey: string | null
  supabaseAdmin: SupabaseAdminLike
  /** Sleep-injectable fuer Tests (Default: setTimeout). */
  sleep?: (ms: number) => Promise<void>
  /** dhlAdapter-Override fuer Tests (Default: importierter dhlAdapter). */
  dhlAdapterOverride?: typeof dhlAdapter
}

const _defaultSleep = (ms: number): Promise<void> =>
  new Promise<void>((r) => setTimeout(r, ms))

export function normalizeTracking(v: string): string {
  return v.replace(/\s+/g, '').toUpperCase()
}

/**
 * Run-scoped Heartbeat: stempelt `workspace_carrier_credentials.last_polled_at`
 * fuer den DHL-Key des Workspace, wenn ein Key gesetzt ist. Wird vom
 * Parse-Runner einmal pro Run aufgerufen — damit der User in Settings →
 * Versand "Zuletzt geprueft: vor X" sieht, auch wenn keine Mail einen
 * Tracking-Kandidaten hatte (z.B. weil alle Mails noch ordered sind).
 *
 * Plan 2026-05-16 Phase C. Best-Effort: bei Fehler still loggen, kein
 * Pipeline-Stop. Caller muss apiKey != null geprueft haben.
 */
export async function stampPipelineHeartbeat(
  supabaseAdmin: SupabaseAdminLike,
  workspaceId: string,
): Promise<void> {
  try {
    // deno-lint-ignore no-explicit-any
    await (supabaseAdmin as any)
      .from('workspace_carrier_credentials')
      .update({ last_polled_at: new Date().toISOString() })
      .eq('workspace_id', workspaceId)
      .eq('carrier_id', 'dhl')
  } catch (_e) {
    // deno-lint-ignore no-console
    console.warn(JSON.stringify({
      event: 'heartbeat_stamp_failed',
      workspace_id: workspaceId,
    }))
  }
}

export function isCacheFresh(row: CacheRow, nowMs: number): boolean {
  const ts = new Date(row.last_checked_at).getTime()
  if (!Number.isFinite(ts)) return false
  const ageMs = nowMs - ts
  return ageMs < TTL_MS[row.result_state]
}

const _CONFIDENCE_ORDER: Record<'strong' | 'medium' | 'weak' | 'none', number> = {
  strong: 3,
  medium: 2,
  weak: 1,
  none: 0,
}

/**
 * Filtert die Tracking-Candidates eines geparsten Mail-Payloads gegen
 * die DHL-API und mutiert `parsed` so, dass `trackings`, `tracking`,
 * `tracking_confidence` und `tracking_needs_review` nur noch valide
 * Treffer reflektieren.
 *
 * Mutiert das uebergebene Objekt und gibt es zur Bequemlichkeit zurueck.
 * `parsed.trackingCandidates` bleibt unveraendert (Forensik-Liste).
 */
export async function enrichWithDhlValidation(
  parsed: ParsedMessageLike,
  opts: EnrichOptions,
): Promise<ParsedMessageLike> {
  const sleep = opts.sleep ?? _defaultSleep
  const adapter = opts.dhlAdapterOverride ?? dhlAdapter
  const status = opts.status
  const shippedLike = status === 'shipped' || status === 'delivered'

  // 1. Short-circuit: kein API-Key → kein Auto-Tracking, manuelles
  //    Review nur fuer shipped/delivered.
  if (!opts.apiKey) {
    parsed.trackings = []
    parsed.tracking = null
    parsed.tracking_confidence = 'none'
    parsed.tracking_needs_review = shippedLike
    return parsed
  }

  // 2. Kandidaten filtern: strong + medium akzeptiert (DHL-Pattern oder
  //    anchor-gated permissive). Carrier 'DHL' oder undefined. Dedupe
  //    via normalize() — gleicher Wert nur einmal pruefen.
  //
  //    Plan 2026-05-16 Phase A: medium-Kandidaten (anchor-gated
  //    context-numeric) durchlaufen die DHL-API genauso, weil die API
  //    der finale Gate ist. False-Positives werden als `invalid`
  //    gecached (30 Tage TTL) — kein UI-Spam.
  const raw = Array.isArray(parsed.trackingCandidates)
    ? parsed.trackingCandidates
    : []
  const dedup = new Map<string, { value: string; carrier?: string; confidence: 'strong' | 'medium' | 'weak' | 'none' }>()
  for (const c of raw) {
    if (!c || typeof c.value !== 'string') continue
    if (c.confidence !== 'strong' && c.confidence !== 'medium') continue
    const carrier = c.carrier
    const carrierOk = carrier === undefined || carrier === null || carrier === 'DHL'
    if (!carrierOk) continue
    const norm = normalizeTracking(c.value)
    if (norm.length === 0) continue
    if (dedup.has(norm)) continue
    dedup.set(norm, { value: norm, carrier: carrier ?? undefined, confidence: c.confidence })
  }

  // Sort: stable nach Confidence-Order (alle 'strong' → effektiv input-
  // Reihenfolge, weil Map.iteration einfuegungs-stabil ist).
  const sortedCandidates = Array.from(dedup.values()).sort(
    (a, b) => _CONFIDENCE_ORDER[b.confidence] - _CONFIDENCE_ORDER[a.confidence],
  )

  let candidates = sortedCandidates
  if (candidates.length > HARD_LIMIT_CALLS_PER_MAIL) {
    const dropped = candidates.length - HARD_LIMIT_CALLS_PER_MAIL
    // deno-lint-ignore no-console
    console.warn(JSON.stringify({
      event: 'validation_capped',
      workspace_id: opts.workspaceId,
      candidate_count: candidates.length,
      dropped_count: dropped,
    }))
    candidates = candidates.slice(0, HARD_LIMIT_CALLS_PER_MAIL)
  }

  // 3. Per Kandidat: Cache-Lookup, dann ggf. API-Call mit Spike-Arrest.
  const validValues: string[] = []
  let hadPriorApiCall = false
  let madeAnyApiCall = false
  let lastApiError: string | null = null
  const nowMs = Date.now()

  for (const cand of candidates) {
    const norm = cand.value
    let isValid = false
    let usedCache = false

    // Cache-Lookup.
    try {
      const sel = await opts.supabaseAdmin
        .from('tracking_validation_cache')
        .select('tracking_norm, is_valid, result_state, last_checked_at')
        .eq('tracking_norm', norm)
        .maybeSingle()
      const row = sel.data
      if (row && isCacheFresh(row, nowMs)) {
        isValid = row.is_valid === true
        usedCache = true
      }
    } catch (_e) {
      // Cache-Lookup-Fehler → wie Miss behandeln.
      usedCache = false
    }

    if (!usedCache) {
      // Spike-Arrest: nur, wenn vorheriger API-Call in diesem Run.
      if (hadPriorApiCall) {
        await sleep(SPIKE_ARREST_MS)
      }
      hadPriorApiCall = true
      madeAnyApiCall = true

      let resultState: ResultState = 'invalid'
      let statusRaw: unknown = null
      try {
        const result = await adapter.fetchStatus(norm, opts.apiKey)
        if (result !== null && result !== undefined) {
          resultState = 'valid'
          isValid = true
          statusRaw = result
        } else {
          resultState = 'invalid'
          isValid = false
          statusRaw = null
        }
      } catch (err) {
        // Network-/Fetch-Exception → unknown mit 1h-TTL.
        resultState = 'unknown'
        isValid = false
        statusRaw = null
        lastApiError = (err instanceof Error) ? err.message.slice(0, 200) : 'fetch failed'
      }

      // Cache-Upsert. tracking_norm ist Primary-Key.
      try {
        const upsertRow: Record<string, unknown> = {
          tracking_norm: norm,
          is_valid: isValid,
          result_state: resultState,
          status_raw: statusRaw,
          first_seen_workspace_id: opts.workspaceId,
          last_checked_at: new Date().toISOString(),
        }
        const res = await opts.supabaseAdmin
          .from('tracking_validation_cache')
          .upsert(upsertRow, { onConflict: 'tracking_norm' })
        if (res.error) {
          // deno-lint-ignore no-console
          console.warn(JSON.stringify({
            event: 'validation_cache_upsert_failed',
            workspace_id: opts.workspaceId,
          }))
        }
      } catch (_e) {
        // deno-lint-ignore no-console
        console.warn(JSON.stringify({
          event: 'validation_cache_upsert_failed',
          workspace_id: opts.workspaceId,
        }))
      }
    }

    if (isValid) {
      validValues.push(norm)
    }
  }

  // 3b. User-Feedback in Settings → Versand: wenn wir tatsaechlich die
  //     DHL-API angesprochen haben, last_polled_at auf den Credential-
  //     Eintrag stempeln. Sonst sieht der User "Noch nicht gepollt",
  //     obwohl der Key im Inbox-Sweep laufend benutzt wird.
  if (madeAnyApiCall) {
    try {
      // deno-lint-ignore no-explicit-any
      await (opts.supabaseAdmin as any)
        .from('workspace_carrier_credentials')
        .update({
          last_polled_at: new Date().toISOString(),
          last_error: lastApiError,
        })
        .eq('workspace_id', opts.workspaceId)
        .eq('carrier_id', 'dhl')
    } catch (_e) {
      // deno-lint-ignore no-console
      console.warn(JSON.stringify({
        event: 'validation_credential_stamp_failed',
        workspace_id: opts.workspaceId,
      }))
    }
  }

  // 4. Output zusammenstellen — Original-Reihenfolge der validen
  //    Kandidaten bleibt erhalten (validValues haengt im Loop-Order an).
  if (validValues.length > 0) {
    const primary = validValues[0]
    parsed.trackings = [primary]
    parsed.tracking = primary
    parsed.tracking_confidence = 'strong'
    parsed.tracking_needs_review = false
  } else {
    parsed.trackings = []
    parsed.tracking = null
    parsed.tracking_confidence = 'none'
    parsed.tracking_needs_review = shippedLike
  }

  // 5. `trackingCandidates` bleibt unveraendert (Forensik-Liste).
  return parsed
}
