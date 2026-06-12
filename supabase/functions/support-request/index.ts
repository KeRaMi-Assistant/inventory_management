// Supabase Edge Function: support-request
//
// Nimmt Support-Anfragen aus Settings → Support entgegen (JWT-Pflicht,
// verify_jwt=true — Standard-Gateway-Check) und stellt sie dem Betreiber
// dreistufig zu:
//   1. INSERT in `support_requests` (Quelle der Wahrheit, nie verlierbar)
//   2. ntfy.sh-Push (env NTFY_SUPPORT_TOPIC, optional) — sofort aufs Handy
//   3. E-Mail via Resend (env RESEND_API_KEY, optional;
//      Empfänger env SUPPORT_EMAIL, Fallback unten) — formatierte Mail mit
//      Titel, Kunde (E-Mail/Plan/Workspace/App-Version) und Anliegen
// Kanäle 2+3 sind Best-Effort: Fehler werden in mail_sent/push_sent
// reflektiert, der Request bleibt erfolgreich (Row existiert).
//
// Sicherheit:
//   * Auth: Gateway-JWT + auth.getUser() — User-Identität/E-Mail kommen aus
//     dem Token, NICHT aus dem Body (kein Spoofing des Absenders).
//   * Validation: subject 3–150, message 10–5000 (zod-artig per Hand,
//     deckungsgleich mit den DB-CHECKs).
//   * Rate-Limit: max. 5 Anfragen pro User pro Stunde (DB-Count) → 429.
//   * PII: Logs enthalten nur Request-Id + Kanal-Status, nie Inhalt/E-Mail.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

/// Fallback-Empfänger, wenn SUPPORT_EMAIL nicht gesetzt ist (Betreiber-
/// Adresse — bewusst im Code: kein Secret, nur ein Briefkasten).
const FALLBACK_SUPPORT_EMAIL = 'keremo.business2025@gmail.com'

const MAX_REQUESTS_PER_HOUR = 5

interface SupportPayload {
  subject: string
  message: string
  workspaceId?: string
  appVersion?: string
}

/// Reine Validierung — exportiert für Tests. Gibt Fehlertext oder null.
export function validateSupportPayload(
  body: unknown,
): { error: string } | { payload: SupportPayload } {
  if (body === null || typeof body !== 'object') {
    return { error: 'invalid body' }
  }
  const b = body as Record<string, unknown>
  const subject = typeof b.subject === 'string' ? b.subject.trim() : ''
  const message = typeof b.message === 'string' ? b.message.trim() : ''
  if (subject.length < 3 || subject.length > 150) {
    return { error: 'subject must be 3-150 chars' }
  }
  // Review-Fix: kein CRLF im Betreff — er landet u.a. im ntfy-HTTP-Header
  // (Header-Injection-Wand; JSON-Pfade wären safe, defense-in-depth).
  if (/[\r\n]/.test(subject)) {
    return { error: 'subject must be a single line' }
  }
  if (message.length < 10 || message.length > 5000) {
    return { error: 'message must be 10-5000 chars' }
  }
  const workspaceId =
    typeof b.workspace_id === 'string' && b.workspace_id.length > 0
      ? b.workspace_id
      : undefined
  const appVersion =
    typeof b.app_version === 'string' && b.app_version.length > 0
      ? b.app_version.slice(0, 50)
      : undefined
  return { payload: { subject, message, workspaceId, appVersion } }
}

/// HTML-Escape für die Mail (Subject/Message sind User-Input).
export function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

/// Baut die Betreiber-Mail (HTML + Text). Exportiert für Tests.
export function buildSupportMail(args: {
  subject: string
  message: string
  email: string
  plan: string | null
  workspaceId: string | null
  appVersion: string | null
  requestId: number
}): { subject: string; html: string; text: string } {
  const subj = `[Support #${args.requestId}] ${args.subject}`
  const meta = [
    `Kunde: ${args.email}`,
    `Plan: ${args.plan ?? 'unbekannt'}`,
    `Workspace: ${args.workspaceId ?? '—'}`,
    `App-Version: ${args.appVersion ?? '—'}`,
  ]
  const text = `${meta.join('\n')}\n\n— Anliegen —\n${args.message}`
  const html = `
    <h2>${escapeHtml(args.subject)}</h2>
    <table cellpadding="4" style="border-collapse:collapse;color:#333">
      <tr><td><b>Kunde</b></td><td>${escapeHtml(args.email)}</td></tr>
      <tr><td><b>Plan</b></td><td>${escapeHtml(args.plan ?? 'unbekannt')}</td></tr>
      <tr><td><b>Workspace</b></td><td>${escapeHtml(args.workspaceId ?? '—')}</td></tr>
      <tr><td><b>App-Version</b></td><td>${escapeHtml(args.appVersion ?? '—')}</td></tr>
      <tr><td><b>Request</b></td><td>#${args.requestId}</td></tr>
    </table>
    <h3>Anliegen</h3>
    <p style="white-space:pre-wrap">${escapeHtml(args.message)}</p>`
  return { subject: subj, html, text }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') {
    return jsonResp({ error: 'method not allowed' }, 405)
  }

  // ── Auth: User aus dem JWT (Gateway hat Signatur schon geprüft) ────────
  const authHeader = req.headers.get('Authorization') ?? ''
  const userClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } },
  )
  const { data: userData, error: userErr } = await userClient.auth.getUser()
  if (userErr || !userData?.user) {
    return jsonResp({ error: 'unauthorized' }, 401)
  }
  const user = userData.user
  const email = user.email ?? 'unbekannt'

  // ── Body-Validierung ────────────────────────────────────────────────────
  let body: unknown = null
  try {
    body = await req.json()
  } catch {
    return jsonResp({ error: 'invalid json' }, 400)
  }
  const v = validateSupportPayload(body)
  if ('error' in v) return jsonResp({ error: v.error }, 400)
  const payload = v.payload

  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  // ── Workspace-Membership + Plan (Kontext für die Mail) ─────────────────
  let plan: string | null = null
  let workspaceId: string | null = null
  if (payload.workspaceId) {
    const { data: member } = await admin
      .from('workspace_members')
      .select('workspace_id')
      .eq('workspace_id', payload.workspaceId)
      .eq('user_id', user.id)
      .maybeSingle()
    if (member) {
      workspaceId = payload.workspaceId
      const { data: ws } = await admin
        .from('workspaces')
        .select('plan')
        .eq('id', workspaceId)
        .maybeSingle()
      plan = (ws as { plan?: string } | null)?.plan ?? null
    }
    // Nicht-Mitglied → Workspace still ignorieren (kein Enumeration-Kanal).
  }

  // ── 1) Quelle der Wahrheit: atomarer Insert MIT Rate-Limit ─────────────
  // Review-Fix (TOCTOU): Count + Insert laufen in EINEM SQL-Statement
  // (RPC insert_support_request) — parallele Requests können das
  // 5/h-Limit nicht mehr per Race aufhebeln. NULL = Limit erreicht.
  const { data: insertedId, error: insErr } = await admin.rpc(
    'insert_support_request',
    {
      _workspace_id: workspaceId,
      _user_id: user.id,
      _email: email,
      _plan: plan,
      _subject: payload.subject,
      _message: payload.message,
      _app_version: payload.appVersion ?? null,
      _max_per_hour: MAX_REQUESTS_PER_HOUR,
    },
  )
  if (insErr) {
    console.error('support-request: insert failed', insErr.message)
    return jsonResp({ error: 'persist failed' }, 500)
  }
  if (insertedId === null || insertedId === undefined) {
    return jsonResp({ error: 'rate_limited' }, 429)
  }
  const requestId = Number(insertedId)

  // ── 2) ntfy-Push (Best-Effort) ──────────────────────────────────────────
  // SICHERHEITS-KONTRAKT (Review): ntfy.sh-Topics sind öffentlich lesbar
  // für jeden, der den Topic-Namen kennt — der Payload enthält Kunden-Mail
  // + Anliegen. Deshalb: Topic MUSS ≥16 Zeichen Zufall sein (z.B.
  // `openssl rand -hex 12`-Suffix), sonst wird der Kanal geskippt.
  let pushSent = false
  const ntfyTopic = Deno.env.get('NTFY_SUPPORT_TOPIC')
  if (ntfyTopic && ntfyTopic.length < 16) {
    console.warn('support-request: NTFY_SUPPORT_TOPIC zu kurz (<16) — Push-Kanal deaktiviert')
  } else if (ntfyTopic) {
    try {
      // CRLF ist durch die Validierung schon raus; Header-Sanitizing
      // trotzdem defensiv (defense-in-depth).
      const safeTitle = `Support #${requestId}: ${payload.subject.slice(0, 80)}`
        .replace(/[\r\n]/g, ' ')
      const res = await fetch(`https://ntfy.sh/${encodeURIComponent(ntfyTopic)}`, {
        method: 'POST',
        headers: {
          'Title': safeTitle,
          'Tags': 'envelope',
          'Priority': 'high',
        },
        body: `${email} (${plan ?? 'kein Plan'})\n\n${payload.message.slice(0, 500)}`,
      })
      pushSent = res.ok
    } catch (e) {
      console.warn('support-request: ntfy failed', (e as Error).message)
    }
  }

  // ── 3) Mail via Resend (Best-Effort) ────────────────────────────────────
  let mailSent = false
  const resendKey = Deno.env.get('RESEND_API_KEY')
  if (resendKey) {
    try {
      const to = Deno.env.get('SUPPORT_EMAIL') ?? FALLBACK_SUPPORT_EMAIL
      const mail = buildSupportMail({
        subject: payload.subject,
        message: payload.message,
        email,
        plan,
        workspaceId,
        appVersion: payload.appVersion ?? null,
        requestId,
      })
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${resendKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: Deno.env.get('SUPPORT_FROM') ?? 'InventoryOS Support <onboarding@resend.dev>',
          to: [to],
          reply_to: email,
          subject: mail.subject,
          html: mail.html,
          text: mail.text,
        }),
      })
      mailSent = res.ok
      if (!res.ok) {
        console.warn('support-request: resend status', res.status)
      }
    } catch (e) {
      console.warn('support-request: resend failed', (e as Error).message)
    }
  }

  // Telemetrie auf der Row nachziehen (Best-Effort).
  if (pushSent || mailSent) {
    await admin
      .from('support_requests')
      .update({ mail_sent: mailSent, push_sent: pushSent })
      .eq('id', requestId)
  }

  console.log(JSON.stringify({
    event: 'support_request',
    id: requestId,
    mailSent,
    pushSent,
  }))

  return jsonResp({ ok: true, id: requestId, mailSent, pushSent })
})

function jsonResp(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
