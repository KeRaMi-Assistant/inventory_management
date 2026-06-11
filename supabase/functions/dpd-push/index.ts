// Supabase Edge Function: dpd-push
//
// Webhook für den offiziellen **DPD Tracking Push Service** (Geschäftskunden-
// Feature, Antrag via Formular "Tracking Push Service"). DPD sendet pro
// Scan-Ereignis einen GET-Request mit Query-Parametern an diese URL und
// erwartet ein XML-Acknowledgement mit der pushid:
//
//   GET /dpd-push?token=<DPD_PUSH_TOKEN>&pushid=335165&pnr=01476810375209
//       &status=delivery_carload&statusdate=09072014095100&depot=0134&...
//   → 200  <push><pushid>335165</pushid><status>OK</status></push>
//
// Warum Push statt Pull: DPDs öffentliche Tracking-Endpoints blocken
// serverseitige Requests auf TLS-Ebene (Bot-Schutz, verifiziert 2026-06-11)
// — Pull-Polling à la DHL ist für DPD nicht zuverlässig möglich. Der Push
// Service ist der offizielle Echtzeit-Kanal (~15 min Latenz, keine Quota).
//
// Sicherheit:
//   * verify_jwt=false (DPD kann kein Supabase-JWT senden) — stattdessen
//     PFLICHT-Token `token=<DPD_PUSH_TOKEN>` (Secret via
//     `supabase secrets set DPD_PUSH_TOKEN=...`). FAIL-CLOSED: ohne/mit
//     falschem Token → 403, ohne gesetztes Secret → 503.
//   * DPD dokumentiert die Absender-IP 213.95.42.108 — wird SOFT geprüft
//     (Mismatch wird nur gezählt/geloggt, nicht geblockt: Infra-IPs können
//     sich ändern, das Token ist die harte Wand).
//   * PII: `receiver=`/`pod=` werden NICHT persistiert und NICHT geloggt.
//     Tracking-Nummern erscheinen nur redacted in Logs (letzte 4 Zeichen).
//   * Unmatched pnr (kein Deal mit diesem Tracking im System) wird trotzdem
//     mit OK beantwortet — sonst retried DPD 48h lang und mailt Fehler.
//
// Status-Mapping (Quelle: "Tracking Push Service — Ihr Schnelleinstieg",
// 04/2023, Abschnitt URL-Parameter):
//   start_order            → pending          (Auftragsdaten erfasst)
//   pickup_driver          → in_transit       (vom Fahrer abgeholt)
//   pickup_depot           → in_transit       (Eingangsdepot)
//   delivery_depot         → in_transit       (Ausgangsdepot)
//   delivery_carload       → out_for_delivery (auf Zustelltour) ← Klarna-Moment
//   delivery_nab           → exception        (NAB-Scan)
//   delivery_notification  → exception        (Zustellhindernis)
//   delivery_customer      → delivered
//   delivery_shop          → delivered        (Zustellung im Paketshop)
//   pickup_by_consignee    → delivered        (im Shop abgeholt)
//   no_pickup_by_consignee → exception        (nicht abgeholt)
//   error_pickup           → exception
//   error_return           → exception        (System-Retoure)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  buildLiveStatusUpdate,
  buildTrackingEventRows,
  createPushContext,
  type LiveStatus,
  maybeSendStatusPush,
  type PollDealRow,
} from '../_shared/live_status.ts'
import type { ParsedTracking } from '../_shared/tracking_adapters.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

/// DPD-Status → unser normalisierter LiveStatus + menschenlesbarer
/// Event-Text (deutsch, wie die übrigen Carrier-Texte der App).
export const DPD_STATUS_MAP: Readonly<Record<string, { status: LiveStatus; text: string }>> = {
  start_order: { status: 'pending', text: 'Auftragsdaten erfasst' },
  pickup_driver: { status: 'in_transit', text: 'Vom Fahrer abgeholt' },
  pickup_depot: { status: 'in_transit', text: 'Im Eingangsdepot angekommen' },
  delivery_depot: { status: 'in_transit', text: 'Im Ausgangsdepot angekommen' },
  delivery_carload: { status: 'out_for_delivery', text: 'Auf Zustelltour' },
  delivery_nab: { status: 'exception', text: 'Empfänger nicht angetroffen (NAB)' },
  delivery_notification: { status: 'exception', text: 'Zustellhindernis (z. B. Adressklärung)' },
  delivery_customer: { status: 'delivered', text: 'Zugestellt' },
  delivery_shop: { status: 'delivered', text: 'Im Pickup-Paketshop zugestellt' },
  pickup_by_consignee: { status: 'delivered', text: 'Im Pickup-Paketshop abgeholt' },
  no_pickup_by_consignee: { status: 'exception', text: 'Im Pickup-Paketshop nicht abgeholt' },
  error_pickup: { status: 'exception', text: 'Problem bei der Abholung' },
  error_return: { status: 'exception', text: 'Retoure an den Versender' },
}

/// `statusdate=ddMMyyyyHHmmss` (lokale DPD-Zeit, de facto Europe/Berlin) →
/// ISO-8601. Ungültige/fehlende Werte → undefined (Caller nutzt now()).
/// Wir interpretieren den Stempel als Berlin-Wanduhr und hängen den im
/// Sommer/Winter passenden Offset NICHT an (kein TZ-Datenbank-Zugriff in
/// Edge-Runtime nötig): stattdessen UTC-naiv parsen — der maximale Fehler
/// (±2 h) ist für Timeline-Sortierung unkritisch und konsistent.
export function parseDpdStatusDate(raw: string | null | undefined): string | undefined {
  if (!raw || !/^\d{14}$/.test(raw)) return undefined
  const dd = Number(raw.slice(0, 2))
  const mm = Number(raw.slice(2, 4))
  const yyyy = Number(raw.slice(4, 8))
  const hh = Number(raw.slice(8, 10))
  const mi = Number(raw.slice(10, 12))
  const ss = Number(raw.slice(12, 14))
  if (mm < 1 || mm > 12 || dd < 1 || dd > 31 || hh > 23 || mi > 59 || ss > 59) {
    return undefined
  }
  const d = new Date(Date.UTC(yyyy, mm - 1, dd, hh, mi, ss))
  if (Number.isNaN(d.getTime())) return undefined
  return d.toISOString()
}

/// XML-Acknowledgement laut DPD-Spec. pushid ist numerisch-validiert —
/// trotzdem escapen wir defensiv (kein XML-Injection über den Echo-Pfad).
export function buildAckXml(pushid: string): string {
  const safe = pushid.replace(/[<>&"']/g, '')
  return `<push><pushid>${safe}</pushid><status>OK</status></push>`
}

/// Monotonie-Guard für den PUSH-Kanal (Out-of-Order-Schutz): DPD liefert
/// Scans einzeln in ~15-min-Batches — ein verspäteter `pickup_depot` darf
/// einen bereits gesetzten `out_for_delivery`/`delivered` NICHT zurückdrehen.
/// (Der Poll-Kanal braucht das nicht: Polls holen immer den Gesamtzustand.)
/// Regeln:
///   * delivered ist terminal — nichts überschreibt es (auch exception nicht).
///   * exception überschreibt jeden Nicht-delivered-Status (echtes Problem).
///   * echter Fortschritt überschreibt exception (Problem gelöst).
///   * sonst: nur ranggleich/aufwärts (pending<in_transit<out_for_delivery<delivered).
/// Events werden davon NICHT betroffen — die Timeline bekommt jeden Scan.
const STATUS_RANK: Readonly<Record<string, number>> = {
  pending: 0,
  in_transit: 1,
  out_for_delivery: 2,
  delivered: 3,
}

export function isStatusRegression(
  current: LiveStatus | null,
  incoming: LiveStatus,
): boolean {
  if (!current || current === 'unknown' || current === 'expired') return false
  if (current === 'delivered') return incoming !== 'delivered'
  if (incoming === 'exception') return false
  if (current === 'exception') return false
  return (STATUS_RANK[incoming] ?? 0) < (STATUS_RANK[current] ?? 0)
}

/// PII-armes Redaction-Pattern (identisch zu tracking_detection.ts).
function redact(value: string): string {
  if (!value) return '∅'
  if (value.length <= 4) return `…${value}`
  return `…${value.slice(-4)}`
}

/// Pure: Query-Parameter → ParsedTracking-Äquivalent fürs Shared-Modul.
export function dpdPushToParsed(params: URLSearchParams): {
  parsed: ParsedTracking
  pnr: string
} | null {
  const pnr = (params.get('pnr') ?? '').replace(/\s+/g, '').toUpperCase()
  const statusRaw = (params.get('status') ?? '').toLowerCase()
  if (!pnr || !statusRaw) return null
  const mapped = DPD_STATUS_MAP[statusRaw]
  if (!mapped) return null
  const occurredAt = parseDpdStatusDate(params.get('statusdate'))
  const depot = params.get('depot') ?? undefined
  return {
    pnr,
    parsed: {
      status: mapped.status === 'expired' ? 'unknown' : mapped.status,
      deliveredAt: mapped.status === 'delivered' ? occurredAt : undefined,
      statusTimestamp: occurredAt,
      lastEvent: mapped.text,
      rawStatusCode: statusRaw,
      events: [
        {
          occurredAt,
          text: mapped.text,
          location: depot ? `Depot ${depot}` : undefined,
          rawCode: statusRaw,
          status: mapped.status === 'expired' ? 'unknown' : mapped.status,
        },
      ],
    },
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const url = new URL(req.url)
  const params = url.searchParams

  // ── Token-Wand (fail-closed) ────────────────────────────────────────────
  const expected = Deno.env.get('DPD_PUSH_TOKEN')
  if (!expected || expected.length < 16) {
    console.error('dpd-push: DPD_PUSH_TOKEN nicht/zu kurz gesetzt — Webhook deaktiviert')
    return new Response('service unavailable', { status: 503, headers: corsHeaders })
  }
  if (params.get('token') !== expected) {
    return new Response('forbidden', { status: 403, headers: corsHeaders })
  }

  // Soft-IP-Check (DPD-Doku: 213.95.42.108). Nur Telemetrie, kein Block.
  const fwd = req.headers.get('x-forwarded-for') ?? ''
  if (fwd && !fwd.split(',').some((ip) => ip.trim() === '213.95.42.108')) {
    console.log(JSON.stringify({ event: 'dpd_push_ip_mismatch' }))
  }

  // DPD-Spec: ohne pushid KEIN Antwort-XML.
  const pushid = params.get('pushid')
  if (!pushid || !/^\d{1,20}$/.test(pushid)) {
    return new Response('missing pushid', { status: 400, headers: corsHeaders })
  }

  const ackHeaders = {
    ...corsHeaders,
    'Content-Type': 'text/xml; charset=utf-8',
  }
  const ack = () => new Response(buildAckXml(pushid), { status: 200, headers: ackHeaders })

  const converted = dpdPushToParsed(params)
  if (!converted) {
    // Unbekannter Status / fehlende pnr: ACK trotzdem (sonst 48h-Retry),
    // aber zählbar loggen.
    console.log(JSON.stringify({ event: 'dpd_push_unparsable', status: params.get('status') ?? null }))
    return ack()
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  // Deal-Lookup über die normalisierte Tracking-Nummer. DPD-pnr ist
  // 13–14-stellig; Detection persistiert normalisiert (uppercase, spaceless).
  const { data: dealRows, error: dealErr } = await admin
    .from('deals')
    .select(
      'id, workspace_id, user_id, product, tracking, carrier, status, arrival_date, live_status, live_status_last_event, live_status_updated_at, live_eta, last_polled_at',
    )
    .eq('tracking', converted.pnr)
    .is('deleted_at', null)
    .limit(2)
  if (dealErr) {
    console.error('dpd-push: deal lookup failed', dealErr.message)
    // 500 → DPD puffert + retried (gewollt bei DB-Hickup).
    return new Response('lookup failed', { status: 500, headers: corsHeaders })
  }
  const deals = (dealRows ?? []) as PollDealRow[]
  if (deals.length === 0) {
    console.log(JSON.stringify({ event: 'dpd_push_no_deal', pnr: redact(converted.pnr) }))
    return ack()
  }

  const pushCtx = createPushContext('dpd-push')
  const nowIso = new Date().toISOString()
  for (const deal of deals) {
    // Out-of-Order-Schutz: regressive Status-Pushes patchen den Deal nicht
    // (Timeline-Event unten wird trotzdem geschrieben).
    const incoming = converted.parsed.status as LiveStatus
    const regression = incoming !== 'unknown' &&
      isStatusRegression(deal.live_status, incoming)
    const patch = regression
      ? null
      : buildLiveStatusUpdate(deal, converted.parsed, nowIso)
    const update: Record<string, unknown> = patch ?? {}
    update.last_polled_at = nowIso
    // Carrier ggf. nachziehen: ein Push beweist, dass es DPD ist.
    if (deal.carrier !== 'dpd') update.carrier = 'dpd'

    let query = admin
      .from('deals')
      .update(update)
      .eq('id', deal.id)
      .eq('workspace_id', deal.workspace_id)
    if (patch && converted.parsed.status === 'delivered') {
      query = query.eq('status', 'Unterwegs').is('arrival_date', null)
    }
    const { error: updErr } = await query
    if (updErr) {
      console.warn('dpd-push: deal update failed', deal.id, updErr.message)
      continue
    }

    const eventRows = buildTrackingEventRows(
      deal,
      'dpd',
      converted.parsed,
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
      if (evErr) console.warn('dpd-push: tracking_events upsert failed', deal.id, evErr.message)
    }

    const newStatus = converted.parsed.status !== 'unknown'
      ? (converted.parsed.status as LiveStatus)
      : null
    if (patch && newStatus && newStatus !== deal.live_status && newStatus !== 'pending') {
      await maybeSendStatusPush(admin, pushCtx, deal, newStatus, converted.parsed)
    }

    if (patch && converted.parsed.status === 'delivered') {
      await admin.from('activity_log').insert({
        workspace_id: deal.workspace_id,
        user_id: deal.user_id,
        type: 'tracking_delivered',
        message: `Sendung "${deal.product}" via DPD angekommen: ${converted.parsed.lastEvent}`,
        date: (update.arrival_date as string | undefined) ?? nowIso,
      })
    }
  }

  return ack()
})
