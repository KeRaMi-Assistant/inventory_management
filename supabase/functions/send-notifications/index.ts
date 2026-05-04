// Supabase Edge Function: send-notifications
//
// Triggered by pg_cron (or manually via `supabase functions invoke`). Iterates
// over every user's fcm_tokens, computes which notifications are due based on
// their notification_preferences, and posts to FCM HTTP v1.
//
// Required env (set with `supabase secrets set`):
//   FCM_SERVICE_ACCOUNT_JSON  – Service account JSON for FCM HTTP v1
//   CRON_SECRET               – Shared secret matching the pg_cron Authorization
//
// Standard env (provided by the runtime):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface ServiceAccount {
  client_email: string
  private_key: string
  project_id: string
}

interface NotificationPrefs {
  user_id: string
  mhd_warning_enabled: boolean
  mhd_warning_days: number
  delivery_enabled: boolean
  payment_enabled: boolean
  payment_overdue_days: number
}

interface FcmToken {
  token: string
  platform: string
}

interface SentRow {
  ref_kind: 'mhd' | 'delivery' | 'payment'
  ref_id: string
}

interface PushPayload {
  title: string
  body: string
  data?: Record<string, string>
}

interface DueNotification extends PushPayload {
  refKind: 'mhd' | 'delivery' | 'payment'
  refId: string
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Auth: cron sends Bearer <CRON_SECRET>; manual invoke can bypass via service role
  const cronSecret = Deno.env.get('CRON_SECRET')
  const authHeader = req.headers.get('Authorization') ?? ''
  const isCron = cronSecret && authHeader === `Bearer ${cronSecret}`
  const isService =
    authHeader === `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`

  if (!isCron && !isService) {
    return jsonResp({ error: 'Unauthorized' }, 401)
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  const sa = parseServiceAccount()
  if (!sa) {
    return jsonResp({ error: 'FCM_SERVICE_ACCOUNT_JSON missing or invalid' }, 500)
  }

  const accessToken = await getGoogleAccessToken(sa).catch((e) => {
    console.error('OAuth failed', e)
    return null
  })
  if (!accessToken) return jsonResp({ error: 'OAuth token failed' }, 500)

  // Distinct user_ids that have at least one device token
  const { data: userRows, error: usersErr } = await admin
    .from('fcm_tokens')
    .select('user_id')
  if (usersErr) {
    console.error('fcm_tokens query failed', usersErr)
    return jsonResp({ error: usersErr.message }, 500)
  }
  const userIds = Array.from(new Set((userRows ?? []).map((r) => r.user_id as string)))

  let sent = 0
  let skipped = 0
  for (const userId of userIds) {
    const stats = await processUser(admin, userId, sa.project_id, accessToken)
    sent += stats.sent
    skipped += stats.skipped
  }

  return jsonResp({ ok: true, users: userIds.length, sent, skipped })
})

async function processUser(
  admin: ReturnType<typeof createClient>,
  userId: string,
  projectId: string,
  accessToken: string,
): Promise<{ sent: number; skipped: number }> {
  const prefs = await loadPrefs(admin, userId)
  const { data: tokenRows } = await admin
    .from('fcm_tokens')
    .select('token, platform')
    .eq('user_id', userId)
  const tokens: FcmToken[] = (tokenRows ?? []) as FcmToken[]
  if (tokens.length === 0) return { sent: 0, skipped: 0 }

  const { data: sentRows } = await admin
    .from('notifications_sent')
    .select('ref_kind, ref_id')
    .eq('user_id', userId)
  const alreadySent = new Set(
    ((sentRows ?? []) as SentRow[]).map((r) => `${r.ref_kind}:${r.ref_id}`),
  )

  const due: DueNotification[] = []
  if (prefs.mhd_warning_enabled) {
    due.push(...(await computeMhd(admin, userId, prefs.mhd_warning_days)))
  }
  if (prefs.delivery_enabled) {
    due.push(...(await computeDelivery(admin, userId)))
  }
  if (prefs.payment_enabled) {
    due.push(...(await computePayment(admin, userId, prefs.payment_overdue_days)))
  }

  let sent = 0
  let skipped = 0
  for (const note of due) {
    if (alreadySent.has(`${note.refKind}:${note.refId}`)) {
      skipped++
      continue
    }
    const ok = await sendToTokens(projectId, accessToken, tokens, note)
    if (!ok) continue
    await admin.from('notifications_sent').insert({
      user_id: userId,
      ref_kind: note.refKind,
      ref_id: note.refId,
    })
    sent++
  }
  return { sent, skipped }
}

async function loadPrefs(
  admin: ReturnType<typeof createClient>,
  userId: string,
): Promise<NotificationPrefs> {
  const { data } = await admin
    .from('notification_preferences')
    .select('*')
    .eq('user_id', userId)
    .maybeSingle()
  if (data) return data as NotificationPrefs
  return {
    user_id: userId,
    mhd_warning_enabled: true,
    mhd_warning_days: 14,
    delivery_enabled: true,
    payment_enabled: true,
    payment_overdue_days: 7,
  }
}

async function computeMhd(
  admin: ReturnType<typeof createClient>,
  userId: string,
  days: number,
): Promise<DueNotification[]> {
  const cutoff = new Date()
  cutoff.setDate(cutoff.getDate() + days)
  const cutoffIso = cutoff.toISOString().slice(0, 10)
  const { data } = await admin
    .from('inventory_batches')
    .select('id, batch_number, mhd, item_id')
    .eq('user_id', userId)
    .is('deleted_at', null)
    .not('mhd', 'is', null)
    .lte('mhd', cutoffIso)
  return ((data ?? []) as Array<Record<string, unknown>>).map((b) => ({
    title: 'MHD läuft ab',
    body: `Charge ${b.batch_number ?? ''} läuft am ${formatDate(b.mhd as string)} ab.`,
    data: { kind: 'mhd', batchId: String(b.id), itemId: String(b.item_id) },
    refKind: 'mhd',
    refId: String(b.id),
  }))
}

async function computeDelivery(
  admin: ReturnType<typeof createClient>,
  userId: string,
): Promise<DueNotification[]> {
  const today = new Date().toISOString().slice(0, 10)
  const { data } = await admin
    .from('deals')
    .select('id, product, arrival_date, status')
    .eq('user_id', userId)
    .is('deleted_at', null)
    .eq('status', 'Unterwegs')
    .eq('arrival_date', today)
  return ((data ?? []) as Array<Record<string, unknown>>).map((d) => ({
    title: 'Lieferung heute erwartet',
    body: `${d.product ?? ''} sollte heute ankommen.`,
    data: { kind: 'delivery', dealId: String(d.id) },
    refKind: 'delivery',
    refId: String(d.id),
  }))
}

async function computePayment(
  admin: ReturnType<typeof createClient>,
  userId: string,
  overdueDays: number,
): Promise<DueNotification[]> {
  const cutoff = new Date()
  cutoff.setDate(cutoff.getDate() - overdueDays)
  const cutoffIso = cutoff.toISOString().slice(0, 10)
  const { data } = await admin
    .from('deals')
    .select('id, product, buyer, vk, quantity, order_date, status')
    .eq('user_id', userId)
    .is('deleted_at', null)
    .neq('status', 'Done')
    .lte('order_date', cutoffIso)
    .not('buyer', 'is', null)
    .not('vk', 'is', null)
  return ((data ?? []) as Array<Record<string, unknown>>).map((d) => ({
    title: 'Zahlung ausstehend',
    body: `${d.buyer ?? ''} schuldet noch für ${d.product ?? ''} (${d.quantity} Stk.).`,
    data: { kind: 'payment', dealId: String(d.id) },
    refKind: 'payment',
    refId: String(d.id),
  }))
}

async function sendToTokens(
  projectId: string,
  accessToken: string,
  tokens: FcmToken[],
  payload: PushPayload,
): Promise<boolean> {
  let anySuccess = false
  for (const t of tokens) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: t.token,
            notification: { title: payload.title, body: payload.body },
            data: payload.data ?? {},
            apns: { payload: { aps: { sound: 'default' } } },
            android: { priority: 'high', notification: { sound: 'default' } },
          },
        }),
      },
    )
    if (res.ok) {
      anySuccess = true
    } else {
      console.warn('FCM send failed', t.platform, res.status, await res.text())
    }
  }
  return anySuccess
}

function parseServiceAccount(): ServiceAccount | null {
  try {
    const raw = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON') ?? ''
    if (!raw) return null
    const obj = JSON.parse(raw)
    if (!obj.client_email || !obj.private_key || !obj.project_id) return null
    return obj as ServiceAccount
  } catch {
    return null
  }
}

async function getGoogleAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const claim = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }
  const header = { alg: 'RS256', typ: 'JWT' }
  const enc = (o: unknown) =>
    btoa(JSON.stringify(o)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
  const unsigned = `${enc(header)}.${enc(claim)}`

  const pem = sa.private_key.replace(/\\n/g, '\n')
  const key = await importPkcs8(pem)
  const sigBuf = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    key,
    new TextEncoder().encode(unsigned),
  )
  const sig = arrayBufferToBase64Url(sigBuf)
  const jwt = `${unsigned}.${sig}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })
  if (!res.ok) throw new Error(`oauth ${res.status}: ${await res.text()}`)
  const data = await res.json()
  return data.access_token as string
}

async function importPkcs8(pem: string): Promise<CryptoKey> {
  const b64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '')
  const buf = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))
  return crypto.subtle.importKey(
    'pkcs8',
    buf,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
}

function arrayBufferToBase64Url(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf)
  let binary = ''
  for (let i = 0; i < bytes.byteLength; i++) binary += String.fromCharCode(bytes[i])
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function formatDate(iso: string): string {
  const d = new Date(iso)
  if (isNaN(d.getTime())) return iso
  return d.toLocaleDateString('de-DE')
}

function jsonResp(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
