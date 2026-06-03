// Plan 2026-06-03, T3 — Reduziert auf die überlebenden Helper nach dem
// Wegfall des DHL-API-Detection-Gates.
//
// ENTFERNT (Plan §2.8 [Council-Fix]):
//   * `enrichWithDhlValidation` + `EnrichOptions` + der DHL-Probe-/Cache-Loop:
//     dieses Konstrukt koppelte die Sendungsnummer-Detection an eine Live-DHL-
//     API-Probe und löschte JEDES Tracking, wenn kein API-Key gesetzt war
//     (Short-Circuit) — die Hauptursache, warum „nichts ankam". Die Detection
//     ist jetzt rein algorithmisch in `tracking_detection.ts` (`detect()`).
//   * `ParsedMessageLike`-Bridge (nur vom Wrapper benutzt).
//   * `dhlAdapter`-Import (nur für den Probe-Loop).
//
// BEHALTEN (weiterhin von der Pipeline gebraucht):
//   * `normalizeTracking` — Whitespace-strip + uppercase.
//   * `stampPipelineHeartbeat` — stempelt `workspace_carrier_credentials.
//     last_polled_at`, damit der User in Settings „Zuletzt geprüft" sieht.
//   * `isCacheFresh` / `CacheRow` / `ResultState` / TTL — TTL-Helper für den
//     (separat in T6 abzubauenden) `tracking_validation_cache`-Lese-Pfad.

const TTL_MS = {
  valid: 7 * 24 * 60 * 60 * 1000,
  invalid: 30 * 24 * 60 * 60 * 1000,
  unknown: 1 * 60 * 60 * 1000,
} as const

export type ResultState = 'valid' | 'invalid' | 'unknown'

export interface CacheRow {
  tracking_norm: string
  is_valid: boolean
  result_state: ResultState
  last_checked_at: string
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
 * Best-Effort: bei Fehler still loggen, kein Pipeline-Stop. Caller muss
 * apiKey != null geprueft haben.
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
