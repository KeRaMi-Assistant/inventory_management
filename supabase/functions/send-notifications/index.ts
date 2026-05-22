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
//
// Epic D / Task D5 — low_stock block:
//   Aggregates product_stock VIEW (GROUP BY workspace_id, product_id) vs.
//   products.min_stock. Sends one collective push per workspace to all active
//   workspace_members who have opted in (notification_preferences row).
//   Dedup key: ref_kind='low_stock', ref_id=<YYYY-MM-DD> (UTC date of run),
//   workspace_id written to notifications_sent.workspace_id.
//   PII-arm: push body contains only the count — no product names / quantities.

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
  ref_kind: 'mhd' | 'delivery' | 'payment' | 'low_stock'
  ref_id: string
}

interface PushPayload {
  title: string
  body: string
  data?: Record<string, string>
}

interface DueNotification extends PushPayload {
  refKind: 'mhd' | 'delivery' | 'payment' | 'low_stock'
  refId: string
}

// ── low_stock helpers ────────────────────────────────────────────────────────

/** One row from product_stock (aggregated per product over all warehouses). */
interface ProductStockRow {
  workspace_id: string
  product_id: string
  total_qty: number
}

/** One row from products with min_stock. */
interface ProductMinStockRow {
  id: string
  workspace_id: string
  min_stock: number
}

/** Active workspace member who has opted into notifications. */
interface WorkspaceMemberWithPrefs {
  workspace_id: string
  user_id: string
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

  // ── low_stock block (Epic D / Task D5) ──────────────────────────────────
  // Runs in the same function invocation as the per-user blocks above.
  // Workspace-partitioned: one collective push per workspace, never
  // cross-workspace. Service-Role is used here because this is a cron
  // context without a user session.
  const lowStockStats = await processLowStock(admin, sa.project_id, accessToken)
  sent += lowStockStats.sent
  skipped += lowStockStats.skipped

  return jsonResp({
    ok: true,
    users: userIds.length,
    sent,
    skipped,
    lowStockWorkspaces: lowStockStats.workspacesChecked,
  })
})

// ── low_stock: workspace-level aggregation + push (Epic D / Task D5) ────────
//
// Security guarantees:
//   - All queries run with Service-Role key (cron context, no user session).
//   - Aggregation is strictly partitioned by workspace_id via GROUP BY —
//     no cross-workspace totals are ever computed.
//   - The FCM push body contains only a count integer. No product names,
//     quantities, supplier data or any PII are included in the push payload.
//   - console.log is restricted to counts and workspace IDs (no product data).
//
// Dedup strategy:
//   - ref_kind = 'low_stock'
//   - ref_id   = UTC calendar date of this run (YYYY-MM-DD)
//   - workspace_id written to notifications_sent.workspace_id
//   => Each workspace receives at most one low_stock push per calendar day.
//
// Recipients: active workspace_members who have a notification_preferences row
// (opt-in signal). The notification_preferences table has no low_stock-specific
// toggle yet — existence of the row signals the user has enabled notifications.
// deno-lint-ignore no-explicit-any
async function processLowStock(
  admin: any,
  projectId: string,
  accessToken: string,
): Promise<{ sent: number; skipped: number; workspacesChecked: number }> {
  // Dedup key: UTC date of this run (max one alert per workspace per day).
  const todayUtc = new Date().toISOString().slice(0, 10) // "YYYY-MM-DD"

  // ── Step 1: aggregate product_stock per (workspace_id, product_id) ──────
  // product_stock VIEW is security_invoker=true; running with Service-Role
  // bypasses RLS and gives a full cross-workspace view intentionally — we
  // then partition strictly by workspace_id in all subsequent steps.
  //
  // We pull the raw view rows (per warehouse) and aggregate in TS to avoid
  // a raw SQL RPC dependency. Volume is bounded by number of products *
  // number of warehouses — acceptable for a cron run.
  const { data: stockRows, error: stockErr } = await admin
    .from('product_stock')
    .select('workspace_id, product_id, qty_in_warehouse')

  if (stockErr) {
    console.error('low_stock: product_stock query failed', stockErr.message)
    return { sent: 0, skipped: 0, workspacesChecked: 0 }
  }

  // Aggregate: total qty per (workspace_id, product_id) over all warehouses.
  const totalQtyMap = new Map<string, number>()
  for (const row of (stockRows ?? []) as Array<{
    workspace_id: string
    product_id: string
    qty_in_warehouse: number
  }>) {
    const key = `${row.workspace_id}:${row.product_id}`
    totalQtyMap.set(key, (totalQtyMap.get(key) ?? 0) + (row.qty_in_warehouse ?? 0))
  }

  if (totalQtyMap.size === 0) {
    return { sent: 0, skipped: 0, workspacesChecked: 0 }
  }

  // ── Step 2: load min_stock for all products that appear in product_stock ─
  const productIds = Array.from(
    new Set(
      [...totalQtyMap.keys()].map((k) => k.split(':')[1]),
    ),
  )

  const { data: productRows, error: productErr } = await admin
    .from('products')
    .select('id, workspace_id, min_stock')
    .in('id', productIds)
    .is('deleted_at', null)
    .eq('is_active', true)

  if (productErr) {
    console.error('low_stock: products query failed', productErr.message)
    return { sent: 0, skipped: 0, workspacesChecked: 0 }
  }

  // ── Step 3: identify workspaces with at least one under-stock product ────
  // Count per workspace — strictly partitioned, no cross-workspace mixing.
  const workspaceUnderStockCount = new Map<string, number>()
  for (const p of (productRows ?? []) as ProductMinStockRow[]) {
    const key = `${p.workspace_id}:${p.id}`
    const totalQty = totalQtyMap.get(key) ?? 0
    if (totalQty < p.min_stock) {
      workspaceUnderStockCount.set(
        p.workspace_id,
        (workspaceUnderStockCount.get(p.workspace_id) ?? 0) + 1,
      )
    }
  }

  const affectedWorkspaceIds = [...workspaceUnderStockCount.keys()]
  if (affectedWorkspaceIds.length === 0) {
    return { sent: 0, skipped: 0, workspacesChecked: workspaceUnderStockCount.size }
  }

  // ── Step 4: dedup check — which workspaces already got today's alert? ────
  const { data: alreadySentRows } = await admin
    .from('notifications_sent')
    .select('workspace_id')
    .eq('ref_kind', 'low_stock')
    .eq('ref_id', todayUtc)
    .in('workspace_id', affectedWorkspaceIds)

  const alreadySentWorkspaces = new Set(
    ((alreadySentRows ?? []) as Array<{ workspace_id: string }>).map(
      (r) => r.workspace_id,
    ),
  )

  // ── Step 5: per affected workspace — find opted-in members + send push ───
  let sent = 0
  let skipped = 0

  for (const workspaceId of affectedWorkspaceIds) {
    if (alreadySentWorkspaces.has(workspaceId)) {
      skipped++
      continue
    }

    const count = workspaceUnderStockCount.get(workspaceId) ?? 0

    // Find active workspace members who have opted in (have a prefs row).
    // Finding 2 fix: filter on role IN ('owner','admin','member') to exclude
    // 'viewer' — viewers cannot trigger reorders, so the CTA is a dead end for
    // them. Column name verified as `role` in 20260504000200_workspaces.sql.
    const { data: memberRows, error: memberErr } = await admin
      .from('workspace_members')
      .select('user_id')
      .eq('workspace_id', workspaceId)
      .in('role', ['owner', 'admin', 'member'])

    if (memberErr) {
      console.error('low_stock: workspace_members query failed', memberErr.message)
      continue
    }

    const memberUserIds = ((memberRows ?? []) as Array<{ user_id: string }>).map(
      (r) => r.user_id,
    )
    if (memberUserIds.length === 0) continue

    // Filter to members who have a notification_preferences row (opt-in).
    const { data: prefsRows } = await admin
      .from('notification_preferences')
      .select('user_id')
      .in('user_id', memberUserIds)

    const optedInUserIds = new Set(
      ((prefsRows ?? []) as Array<{ user_id: string }>).map((r) => r.user_id),
    )
    if (optedInUserIds.size === 0) continue

    // Finding 1 fix: per-user dedup check BEFORE sending — mirrors the
    // processUser pattern. Any user already marked for today is removed from
    // the send set so a parallel cron run cannot cause a double-push.
    const { data: userAlreadySentRows } = await admin
      .from('notifications_sent')
      .select('user_id')
      .eq('ref_kind', 'low_stock')
      .eq('ref_id', todayUtc)
      .in('user_id', [...optedInUserIds])

    const alreadySentUserIds = new Set(
      ((userAlreadySentRows ?? []) as Array<{ user_id: string }>).map((r) => r.user_id),
    )
    const pendingUserIds = [...optedInUserIds].filter((uid) => !alreadySentUserIds.has(uid))
    if (pendingUserIds.length === 0) {
      skipped++
      continue
    }

    // Resolve FCM tokens for opted-in, not-yet-notified members.
    const { data: tokenRows } = await admin
      .from('fcm_tokens')
      .select('user_id, token, platform')
      .in('user_id', pendingUserIds)

    const tokens: FcmToken[] = ((tokenRows ?? []) as Array<FcmToken & { user_id: string }>)

    if (tokens.length === 0) continue

    // PII-arm push payload: body contains only the count, no product names.
    const payload: PushPayload = {
      title: 'Niedriger Bestand',
      body: `${count} Artikel unter Mindestbestand`,
      data: { kind: 'low_stock' },
    }

    const ok = await sendToTokens(projectId, accessToken, tokens, payload)
    if (!ok) continue

    // Finding 1 fix: record dedup rows with upsert + ignoreDuplicates so a
    // parallel cron run that races past the per-user check above does not
    // produce a 23505 PK error. workspace_id written for workspace-scoped
    // dedup lookups (Step 4). PK is (user_id, ref_kind, ref_id).
    for (const userId of pendingUserIds) {
      await admin.from('notifications_sent').upsert(
        {
          user_id: userId,
          ref_kind: 'low_stock',
          ref_id: todayUtc,
          workspace_id: workspaceId,
        },
        { onConflict: 'user_id,ref_kind,ref_id', ignoreDuplicates: true },
      )
    }

    console.log(
      `low_stock: sent alert for workspace ${workspaceId} (${count} products, ${pendingUserIds.length} recipients)`,
    )
    sent++
  }

  return { sent, skipped, workspacesChecked: affectedWorkspaceIds.length }
}

// deno-lint-ignore no-explicit-any
async function processUser(
  admin: any,
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

// deno-lint-ignore no-explicit-any
async function loadPrefs(
  admin: any,
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

// deno-lint-ignore no-explicit-any
async function computeMhd(
  admin: any,
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

// deno-lint-ignore no-explicit-any
async function computeDelivery(
  admin: any,
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

// deno-lint-ignore no-explicit-any
async function computePayment(
  admin: any,
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
