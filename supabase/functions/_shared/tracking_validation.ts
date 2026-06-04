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
//
// ENTFERNT (Dead-Code-Cleanup, chore/audit-sustainability-1):
//   * `isCacheFresh` / `CacheRow` / `ResultState` / `TTL_MS` — TTL-Lese-Helper
//     für die `tracking_validation_cache`-Tabelle. Die Tabelle wurde mit
//     Migration `20260603081508_drop_tracking_validation_cache.sql` gedroppt;
//     die Helper waren prod-tot. `SupabaseAdminLike` ist auf den schlanken
//     `.from().update().eq()`-Shape reduziert, den `stampPipelineHeartbeat`
//     noch braucht (Cache-Read-Methoden `select`/`maybeSingle`/`upsert` weg).

// Minimaler Supabase-Client-Shape, ohne `@supabase/supabase-js` zu
// importieren — vermeidet Typ-Zyklus mit dem Runner.
interface SupabaseAdminLike {
  from(table: string): unknown
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
