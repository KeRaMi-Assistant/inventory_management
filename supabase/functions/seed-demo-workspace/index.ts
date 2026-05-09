// Supabase Edge Function: seed-demo-workspace
//
// Wipes the test@test.com workspace and re-seeds it with demo-quality data
// derived from the workspace's own parsed_messages of the last 90 days.
//
// HARD CONSTRAINTS (NICHT entfernen):
//   - Läuft nur, wenn der Caller-JWT zu auth.users.email = 'test@test.com'
//     gehört. Andernfalls 403.
//   - Schreibt NUR in den Personal-Workspace dieses Users (owner-Rolle).
//   - Verwendet die service_role NUR für DELETE/INSERT — die Workspace-ID
//     wird vorher per User-Session ermittelt und nie aus dem Request-Body
//     übernommen.
//
// Standard env (provided by the runtime):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ALLOWED_EMAIL = 'test@test.com'
const SOURCE_WINDOW_DAYS = 90
const ACTIVITY_WINDOW_DAYS = 7

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

interface ParsedPayload {
  shop_key?: string | null
  shop_label?: string | null
  order_id?: string | null
  product?: string | null
  quantity?: number | null
  total?: number | null
  currency?: string | null
  tracking?: string | null
  trackings?: string[] | null
  carrier?: string | null
  eta?: string | null
  status?: string | null
}

interface ParsedMessageRow {
  id: string
  workspace_id: string
  received_at: string
  shop_key: string | null
  parsed_payload: ParsedPayload | null
}

interface DealStatusBucket {
  status: string
  weight: number
}

const STATUS_MIX: DealStatusBucket[] = [
  { status: 'Bestellt', weight: 30 },
  { status: 'Unterwegs', weight: 25 },
  { status: 'Angekommen', weight: 15 },
  { status: 'Rechnung gestellt', weight: 10 },
  { status: 'Done', weight: 20 },
]

const BUYER_POOL: Array<{ name: string; row: number; cell: number; font: number }> = [
  { name: 'Reseller_DE_01', row: 0xFFE3F2FD, cell: 0xFF1976D2, font: 0xFFFFFFFF },
  { name: 'Reseller_DE_02', row: 0xFFFFF3E0, cell: 0xFFEF6C00, font: 0xFFFFFFFF },
  { name: 'ResellerKollege_München', row: 0xFFE8F5E9, cell: 0xFF2E7D32, font: 0xFFFFFFFF },
  { name: 'Discord_BountyClient', row: 0xFFF3E5F5, cell: 0xFF7B1FA2, font: 0xFFFFFFFF },
  { name: 'Direkt_Sneaker_Reseller', row: 0xFFFFEBEE, cell: 0xFFC62828, font: 0xFFFFFFFF },
]

const ACTIVITY_MESSAGES = [
  { type: 'deal_create', message: 'Demo: 3 neue Deals angelegt' },
  { type: 'inventory_arrival', message: 'Demo: Lager-Eingang verbucht' },
  { type: 'ticket_archive', message: 'Demo: Ticket archiviert (alle Deals Done)' },
  { type: 'inbox_match', message: 'Demo: Versandbestätigung gematcht' },
  { type: 'deal_update', message: 'Demo: Status-Update verbucht' },
]

// --- kleines deterministisches PRNG, damit Reseeds reproduzierbar sind ----
function mulberry32(seed: number): () => number {
  let a = seed >>> 0
  return () => {
    a = (a + 0x6D2B79F5) >>> 0
    let t = a
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function pickWeighted<T extends { weight: number }>(rng: () => number, items: T[]): T {
  const total = items.reduce((s, it) => s + it.weight, 0)
  let r = rng() * total
  for (const it of items) {
    if (r < it.weight) return it
    r -= it.weight
  }
  return items[items.length - 1]
}

function pickN<T>(rng: () => number, items: T[], n: number): T[] {
  if (items.length <= n) return [...items]
  const copy = [...items]
  const out: T[] = []
  for (let i = 0; i < n; i++) {
    const idx = Math.floor(rng() * copy.length)
    out.push(copy.splice(idx, 1)[0])
  }
  return out
}

function jsonResp(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') {
    return jsonResp({ error: 'Method not allowed' }, 405)
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return jsonResp({ error: 'Unauthorized' }, 401)
  }

  // Schritt 1: User-Identität aus JWT prüfen — niemals aus dem Body.
  const userClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } },
  )
  const { data: userData, error: userErr } = await userClient.auth.getUser()
  if (userErr || !userData?.user) {
    return jsonResp({ error: 'Unauthorized' }, 401)
  }
  const user = userData.user
  if ((user.email ?? '').toLowerCase() !== ALLOWED_EMAIL) {
    return jsonResp(
      { error: `Forbidden — only ${ALLOWED_EMAIL} may invoke this function` },
      403,
    )
  }

  // Schritt 2: Workspace dieses Users ermitteln (owner-Rolle).
  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  const { data: wsRow, error: wsErr } = await admin
    .from('workspaces')
    .select('id, owner_id, name')
    .eq('owner_id', user.id)
    .is('deleted_at', null)
    .order('created_at', { ascending: true })
    .limit(1)
    .maybeSingle()
  if (wsErr || !wsRow) {
    return jsonResp({ error: 'Workspace not found for caller' }, 404)
  }
  const workspaceId = wsRow.id as string

  // Belt-and-Suspenders: Owner-Match double-checken. Falls jemand das
  // owner_id-Feld manipuliert haben sollte, kommt dieser Check trotzdem.
  if ((wsRow.owner_id as string) !== user.id) {
    return jsonResp({ error: 'Workspace ownership mismatch' }, 403)
  }

  try {
    const schema = await detectSchema(admin)
    // Demo-Amazon-Inbox VOR cleanup einsetzen — parsed_messages bleiben
    // erhalten (kein cleanup-Eintrag), pending_deal_suggestions schreibt
    // runSeed selbst. So sieht der Browser-Tester nach jedem Re-Seed
    // verlässlich Tracking-Chips auf den Mail-Cards (Inbox-Vorschläge).
    const inbox = await ensureDemoAmazonInbox(admin, workspaceId, user.id)
    const cleanup = await runCleanup(admin, workspaceId, schema)
    const seed = await runSeed(admin, workspaceId, user.id, schema)
    return jsonResp({
      ok: true,
      email: user.email,
      workspace_id: workspaceId,
      schema,
      cleanup,
      seed,
      demo_inbox: inbox,
    })
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e)
    console.error('seed-demo-workspace failed', msg)
    return jsonResp({ error: msg }, 500)
  }
})

// --------------------------------------------------------------------------
// Schema detection
// --------------------------------------------------------------------------

interface SchemaInfo {
  hasTickets: boolean
  hasDealTicketId: boolean
  hasDealShippedAt: boolean
  hasInventoryPublicCols: boolean
}

async function detectSchema(
  admin: ReturnType<typeof createClient>,
): Promise<SchemaInfo> {
  // Probing via "limit(0)" — billiger als information_schema und respektiert
  // RLS nicht (service_role), funktioniert aber, weil Postgres bei einer
  // unbekannten Tabelle einen Schema-Cache-Fehler wirft, den wir hier
  // abfangen und als "feature missing" interpretieren.
  const hasTickets = await probeTable(admin, 'tickets')
  const hasDealTicketId = await probeColumn(admin, 'deals', 'ticket_id')
  const hasDealShippedAt = await probeColumn(admin, 'deals', 'shipped_at')
  const hasInventoryPublicCols = await probeColumn(
    admin,
    'inventory_items',
    'is_public',
  )
  return {
    hasTickets,
    hasDealTicketId,
    hasDealShippedAt,
    hasInventoryPublicCols,
  }
}

async function probeTable(
  admin: ReturnType<typeof createClient>,
  table: string,
): Promise<boolean> {
  const { error } = await admin.from(table).select('*').limit(0)
  return !error
}

async function probeColumn(
  admin: ReturnType<typeof createClient>,
  table: string,
  column: string,
): Promise<boolean> {
  const { error } = await admin.from(table).select(column).limit(0)
  return !error
}

// --------------------------------------------------------------------------
// Demo Amazon Inbox
// --------------------------------------------------------------------------
//
// Stellt sicher, dass die Demo-Workspace mindestens 5 realistische
// Amazon-Versandbestätigungen als parsed_messages hat. Das ist nötig,
// damit der Browser-Tester (`smoke-inbox`) nach jedem Re-Seed verlässlich
// Tracking-Chips in Mail-Cards sieht — sonst wäre das Demo-Workspace
// inbox leer und die Tracking-Render-Pfade unverifizierbar.
//
// Die Mails enthalten ein realistisches `_raw_html` mit dem echten
// Amazon-Click-Tracker-URL-Format
// (`amazon.<tld>/gp/f.html?C=...&U=...%26orderingShipmentId%3D...`),
// damit der Adapter (`inbox_adapters.ts`) sie ohne Sonderbehandlung
// als Amazon-Logistics-Tracking erkennt.

interface DemoAmazonFixture {
  orderId: string
  shipmentId: string
  product: string
  tld: string
  fromAddress: string
  subject: string
}

const DEMO_AMAZON_FIXTURES: DemoAmazonFixture[] = [
  {
    orderId: '306-4234293-3555528',
    shipmentId: '106121425175302',
    product: 'Samsung 870 EVO SSD 1TB',
    tld: 'de',
    fromAddress: 'versandbestaetigung@amazon.de',
    subject: 'Deine Amazon.de-Bestellung mit "Samsung 870 EVO SSD..." wurde versandt!',
  },
  {
    orderId: '306-5580998-3956325',
    shipmentId: '108834567890123',
    product: 'Samsung 9100 PRO NVMe M.2 SSD 2TB',
    tld: 'de',
    fromAddress: 'versandbestaetigung@amazon.de',
    subject: 'Deine Amazon.de-Bestellung mit 2 x "Samsung 9100 PRO NVMe..." wurde versandt!',
  },
  {
    orderId: '404-5127739-1289903',
    shipmentId: '109555111222333',
    product: 'Samsung 990 PRO NVMe SSD 1TB',
    tld: 'it',
    fromAddress: 'conferma-spedizione@amazon.it',
    subject: 'Your Amazon.it order of "Samsung 990 PRO NVMe..." has been dispatched!',
  },
  {
    orderId: '405-4447968-7281969',
    shipmentId: '110123456789012',
    product: 'Seagate BarraCuda 2TB HDD',
    tld: 'es',
    fromAddress: 'confirmar-envio@amazon.es',
    subject: 'Your Amazon.es order of "Seagate BarraCuda 2TB..." has been dispatched!',
  },
  {
    orderId: '402-4004849-1316335',
    shipmentId: '111777888999000',
    product: '2 x Samsung SSD 870 EVO 500GB',
    tld: 'fr',
    fromAddress: 'confirmation-commande@amazon.fr',
    subject: 'Your Amazon.fr order of 2 x "Samsung SSD 870 EVO..." has been dispatched!',
  },
]

interface DemoInboxResult {
  mailbox_account_id: string
  parsed_messages_inserted: number
  parsed_messages_existed: number
}

function buildDemoAmazonHtml(f: DemoAmazonFixture): string {
  // Realistisches Amazon-Click-Tracker-Format, das echten Live-Mails
  // entspricht: doppelt URL-encoded Ziel-URL mit `orderingShipmentId%3D`.
  // Wenn der Adapter dieses Pattern matchen kann, matcht er auch echte
  // Live-Mails (siehe test/fixtures/amazon_live/*).
  return [
    '<!DOCTYPE html>',
    '<html><body><table><tr><td>',
    '<span class="rio_sc_headline">Versandbestätigung</span>',
    `<p><span>Bestellung <a href="https://www.amazon.${f.tld}/gp/f.html?C=AAAA000AAAA&K=BBBB000BBBB&M=urn:rtn:msg:demo&R=CCCC000CCCC&T=C&U=https%3A%2F%2Fbusiness.amazon.${f.tld}%2Fabredir%2Fgp%2Fcss%2Fsummary%2Fedit.html%3Fie%3DUTF8%26orderID%3D${f.orderId}&H=DDDDDDDDDDDD" class="rio_link">${f.orderId}</a></span></p>`,
    `<p><span>Item(s): ${f.product}</span></p>`,
    `<a class="rio_btn rio_bg_yellow" href="https://www.amazon.${f.tld}/gp/f.html?C=AAAA000AAAA&K=BBBB000BBBB&M=urn:rtn:msg:demo&R=DDDD000DDDD&T=C&U=https%3A%2F%2Fbusiness.amazon.${f.tld}%2Fabredir%2Fgp%2Fcss%2Fshiptrack%2Fview.html%2Fref%3Dpe_demo%3Fie%3DUTF8%26addressID%3DREDACTED%26orderID%3D${f.orderId}%26shipmentDate%3D1770594703%26orderingShipmentId%3D${f.shipmentId}%26packageId%3D1&H=EEEEEEEEEEEE">Lieferung verfolgen</a>`,
    '<p><span>Voraussichtlich in 2-3 Tagen.</span></p>',
    '</td></tr></table></body></html>',
  ].join('\n')
}

async function ensureDemoAmazonInbox(
  admin: ReturnType<typeof createClient>,
  workspaceId: string,
  userId: string,
): Promise<DemoInboxResult> {
  // 1) Sicherstellen, dass ein mailbox_account existiert (FK-Pflicht).
  const { data: existingAccount, error: accSelErr } = await admin
    .from('mailbox_accounts')
    .select('id')
    .eq('workspace_id', workspaceId)
    .limit(1)
    .maybeSingle()
  if (accSelErr) throw new Error(`mailbox_account select failed: ${accSelErr.message}`)
  let accountId = (existingAccount as { id: string } | null)?.id ?? null
  if (!accountId) {
    const { data: created, error: accInsErr } = await admin
      .from('mailbox_accounts')
      .insert({
        workspace_id: workspaceId,
        user_id: userId,
        label: 'Demo-Inbox (Amazon-Fixtures)',
        imap_host: 'demo.local',
        imap_port: 993,
        use_ssl: true,
        username: 'demo-inbox@amazon-fixtures.local',
        folder: 'INBOX',
        enabled: false,
      })
      .select('id')
      .single()
    if (accInsErr) throw new Error(`mailbox_account insert failed: ${accInsErr.message}`)
    accountId = (created as { id: string }).id
  }

  // 2) Pro Fixture: nur einfügen, wenn message_hash noch nicht existiert.
  let inserted = 0
  let existed = 0
  const baseUid = 8000000000n // bigint message_uid platzhalter
  const now = new Date()
  for (let i = 0; i < DEMO_AMAZON_FIXTURES.length; i++) {
    const f = DEMO_AMAZON_FIXTURES[i]
    const hash = `demo-amazon-${f.shipmentId}`
    const { data: existing, error: existErr } = await admin
      .from('parsed_messages')
      .select('id')
      .eq('workspace_id', workspaceId)
      .eq('message_hash', hash)
      .limit(1)
      .maybeSingle()
    if (existErr) throw new Error(`parsed_messages probe failed: ${existErr.message}`)
    if (existing) { existed++; continue }
    const html = buildDemoAmazonHtml(f)
    const receivedAt = new Date(now.getTime() - (i + 1) * 24 * 3600 * 1000).toISOString()
    const { error: insErr } = await admin.from('parsed_messages').insert({
      workspace_id: workspaceId,
      account_id: accountId,
      message_uid: Number(baseUid + BigInt(i)),
      message_hash: hash,
      from_address: f.fromAddress,
      subject: f.subject,
      received_at: receivedAt,
      shop_key: 'amazon',
      status: 'suggested',
      processed_at: receivedAt,
      parsed_payload: {
        shop_key: 'amazon',
        shop_label: 'Amazon',
        order_id: f.orderId,
        product: f.product,
        quantity: 1,
        currency: 'EUR',
        status: 'shipped',
        tracking: f.shipmentId,
        trackings: [f.shipmentId],
        carrier: 'Amazon Logistics',
        _raw_html: html,
      },
    })
    if (insErr) throw new Error(`parsed_messages insert failed: ${insErr.message}`)
    inserted++
  }

  return {
    mailbox_account_id: accountId,
    parsed_messages_inserted: inserted,
    parsed_messages_existed: existed,
  }
}

// --------------------------------------------------------------------------
// Cleanup
// --------------------------------------------------------------------------

interface CleanupResult {
  deleted: Record<string, number>
}

async function runCleanup(
  admin: ReturnType<typeof createClient>,
  workspaceId: string,
  schema: SchemaInfo,
): Promise<CleanupResult> {
  // Reihenfolge: Kinder vor Eltern (FKs sind ON DELETE CASCADE/SET NULL,
  // aber wir wollen exakte Counts pro Tabelle für die Antwort).
  const tables: string[] = [
    'pending_deal_suggestions',
    'inventory_movements',
    'inventory_batches',
    'deal_comments',
    'inventory_items',
    'deals',
  ]
  if (schema.hasTickets) tables.push('tickets')
  tables.push('activity_log', 'buyers', 'shops', 'suppliers')

  const deleted: Record<string, number> = {}
  for (const t of tables) {
    const { error, count } = await admin
      .from(t)
      .delete({ count: 'exact' })
      .eq('workspace_id', workspaceId)
    if (error) {
      throw new Error(`cleanup ${t} failed: ${error.message}`)
    }
    deleted[t] = count ?? 0
  }
  return { deleted }
}

// --------------------------------------------------------------------------
// Seed
// --------------------------------------------------------------------------

interface SeedResult {
  source_messages: number
  buyers: number
  shops: number
  suppliers: number
  tickets: number
  deals: number
  inventory_items: number
  activity_log: number
}

async function runSeed(
  admin: ReturnType<typeof createClient>,
  workspaceId: string,
  userId: string,
  schema: SchemaInfo,
): Promise<SeedResult> {
  const cutoff = new Date(Date.now() - SOURCE_WINDOW_DAYS * 24 * 3600 * 1000).toISOString()
  const { data: srcRows, error: srcErr } = await admin
    .from('parsed_messages')
    .select('id, workspace_id, received_at, shop_key, parsed_payload')
    .eq('workspace_id', workspaceId)
    .in('status', ['suggested', 'matched'])
    .gte('received_at', cutoff)
    .order('received_at', { ascending: false })
    .limit(150)
  if (srcErr) throw new Error(`source select failed: ${srcErr.message}`)

  const messages = (srcRows ?? []) as ParsedMessageRow[]
  const usable = messages.filter((m) => {
    const p = m.parsed_payload
    if (!p) return false
    return Boolean(p.product || p.shop_label || p.order_id)
  })

  const rng = mulberry32(hashString(workspaceId))

  // ---- Buyers (5 fix) ----------------------------------------------------
  const buyersPayload = BUYER_POOL.map((b, idx) => ({
    workspace_id: workspaceId,
    user_id: userId,
    name: b.name,
    row_fill_color: b.row,
    buyer_cell_color: b.cell,
    font_color: b.font,
    sort_order: idx,
    active: true,
    discord_server_ids: [],
    payment_status: 'OK',
  }))
  const { data: buyersInserted, error: buyersErr } = await admin
    .from('buyers')
    .insert(buyersPayload)
    .select('id, name')
  if (buyersErr) throw new Error(`buyers insert failed: ${buyersErr.message}`)
  const buyers = (buyersInserted ?? []) as Array<{ id: string; name: string }>

  // ---- Shops (aus parsed_messages) --------------------------------------
  const shopLabelCount = new Map<string, number>()
  for (const m of usable) {
    const lbl = (m.parsed_payload?.shop_label ?? m.shop_key ?? 'Unbekannt').trim()
    if (!lbl) continue
    shopLabelCount.set(lbl, (shopLabelCount.get(lbl) ?? 0) + 1)
  }
  const topShops = Array.from(shopLabelCount.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 12)
    .map(([name]) => name)
  if (topShops.length === 0) topShops.push('Demo-Shop')
  const shopsPayload = topShops.map((name) => ({
    workspace_id: workspaceId,
    user_id: userId,
    name,
    region: 'DE',
    channel: '',
    active: true,
  }))
  const { data: shopsInserted, error: shopsErr } = await admin
    .from('shops')
    .insert(shopsPayload)
    .select('id, name')
  if (shopsErr) throw new Error(`shops insert failed: ${shopsErr.message}`)
  const shops = (shopsInserted ?? []) as Array<{ id: string; name: string }>

  // ---- Suppliers (5-8 aus den Top-Shops) --------------------------------
  const supplierCount = Math.min(8, Math.max(5, Math.floor(shops.length * 0.7)))
  const supplierSeeds = pickN(rng, shops, supplierCount)
  const suppliersPayload = supplierSeeds.map((s) => ({
    workspace_id: workspaceId,
    user_id: userId,
    name: s.name,
    contact_name: 'Demo-Kontakt',
    email: null,
    phone: null,
    website: null,
    note: 'Demo-Lieferant (auto-seed)',
    active: true,
  }))
  const { data: suppliersInserted, error: suppliersErr } = await admin
    .from('suppliers')
    .insert(suppliersPayload)
    .select('id, name')
  if (suppliersErr) throw new Error(`suppliers insert failed: ${suppliersErr.message}`)
  const suppliers = (suppliersInserted ?? []) as Array<{ id: string; name: string }>

  // ---- Tickets (5-10) — nur falls die Tabelle existiert ------------------
  const ticketCount = Math.min(10, Math.max(5, Math.floor(usable.length / 4)))
  let tickets: Array<{ id: number | null; ticket_number: string }> = []
  if (schema.hasTickets) {
    const ticketsPayload = Array.from({ length: ticketCount }, (_, i) => ({
      workspace_id: workspaceId,
      ticket_number: `TK-DEMO-${String(i + 1).padStart(3, '0')}`,
    }))
    const { data: ticketsInserted, error: ticketsErr } = await admin
      .from('tickets')
      .insert(ticketsPayload)
      .select('id, ticket_number')
    if (ticketsErr) throw new Error(`tickets insert failed: ${ticketsErr.message}`)
    tickets = (ticketsInserted ?? []) as Array<{ id: number; ticket_number: string }>
  } else {
    // Fallback: ticket_number-only Strings, kein FK. Reicht für Listen-Demo.
    tickets = Array.from({ length: ticketCount }, (_, i) => ({
      id: null,
      ticket_number: `TK-DEMO-${String(i + 1).padStart(3, '0')}`,
    }))
  }

  // ---- Deals -------------------------------------------------------------
  const dealCount = Math.min(50, Math.max(30, usable.length))
  const dealSources = usable.slice(0, dealCount)
  // Falls weniger Mails als 30 da sind, mit Wiederholungen auffüllen.
  while (dealSources.length < 30 && usable.length > 0) {
    dealSources.push(usable[dealSources.length % usable.length])
  }

  const dealsPayload = dealSources.map((m, idx) => {
    const p = m.parsed_payload ?? {}
    const shopLabel = (p.shop_label ?? m.shop_key ?? 'Demo-Shop').trim() || 'Demo-Shop'
    const product = sanitizeProduct(p.product) ?? 'Demo-Artikel'
    const quantity = Math.max(1, Math.min(20, Number(p.quantity ?? 1) || 1))
    const ekTotal = sanitizeMoney(p.total) ?? randomEk(rng)
    const ekUnit = ekTotal / quantity
    const vkUnit = round2(ekUnit * 1.18)
    const status = pickWeighted(rng, STATUS_MIX).status
    const ticket = tickets[idx % tickets.length]
    const buyer = buyers[idx % buyers.length]
    const orderDate = m.received_at
    const arrivalIso = ['Angekommen', 'Rechnung gestellt', 'Done'].includes(status)
      ? shiftDate(orderDate, 2 + Math.floor(rng() * 4))
      : null
    const shippedIso = arrivalIso ?? (status === 'Unterwegs'
      ? shiftDate(orderDate, 1 + Math.floor(rng() * 2))
      : null)
    const dealRow: Record<string, unknown> = {
      workspace_id: workspaceId,
      user_id: userId,
      product,
      quantity,
      shop: shopLabel,
      order_date: orderDate,
      ek_brutto: round2(ekTotal),
      vk: round2(vkUnit * quantity),
      buyer: buyer.name,
      ticket_number: ticket.ticket_number,
      tracking: p.tracking ?? null,
      arrival_date: arrivalIso,
      status,
      is_dropship: rng() < 0.3,
      has_receipt: status === 'Done' || status === 'Rechnung gestellt',
      currency: p.currency || 'EUR',
      tax_rate: 0.19,
      note: 'Demo-Eintrag (auto-seed aus parsed_messages)',
    }
    if (schema.hasDealTicketId && ticket.id != null) {
      dealRow.ticket_id = ticket.id
    }
    if (schema.hasDealShippedAt) {
      dealRow.shipped_at = shippedIso
    }
    return dealRow
  })

  // Falls usable leer ist (Edge Case): wenigstens einen synthetischen Deal anlegen,
  // damit die App nicht völlig leer wirkt.
  if (dealsPayload.length === 0) {
    const fallback: Record<string, unknown> = {
      workspace_id: workspaceId,
      user_id: userId,
      product: 'Demo-Artikel',
      quantity: 1,
      shop: 'Demo-Shop',
      order_date: new Date().toISOString(),
      ek_brutto: 99.99,
      vk: 117.99,
      buyer: buyers[0]?.name ?? null,
      ticket_number: tickets[0]?.ticket_number ?? null,
      tracking: null,
      arrival_date: null,
      status: 'Bestellt',
      is_dropship: false,
      has_receipt: false,
      currency: 'EUR',
      tax_rate: 0.19,
      note: 'Demo-Fallback',
    }
    if (schema.hasDealTicketId && tickets[0]?.id != null) {
      fallback.ticket_id = tickets[0].id
    }
    if (schema.hasDealShippedAt) {
      fallback.shipped_at = null
    }
    dealsPayload.push(fallback)
  }

  const { data: dealsInserted, error: dealsErr } = await admin
    .from('deals')
    .insert(dealsPayload)
    .select('id, product, ek_brutto, shop')
  if (dealsErr) throw new Error(`deals insert failed: ${dealsErr.message}`)
  const deals = (dealsInserted ?? []) as Array<{
    id: number; product: string; ek_brutto: number | null; shop: string
  }>

  // ---- pending_deal_suggestions für die Demo-Amazon-Inbox ---------------
  // Cleanup wipes pending_deal_suggestions, daher müssen wir sie pro
  // Re-Seed neu erzeugen. Quelle: die parsed_messages, die
  // ensureDemoAmazonInbox angelegt hat (status='suggested', shop_key='amazon').
  // Diese Suggestions zeigt der Inbox-Tab "Vorschläge" mit Tracking-Chip.
  const { data: amazonInbox } = await admin
    .from('parsed_messages')
    .select('id, message_id, received_at, parsed_payload, shop_key')
    .eq('workspace_id', workspaceId)
    .eq('shop_key', 'amazon')
    .eq('status', 'suggested')
  const inboxRows = (amazonInbox ?? []) as Array<{
    id: string
    message_id: string | null
    received_at: string
    parsed_payload: ParsedPayload | null
    shop_key: string | null
  }>
  if (inboxRows.length > 0) {
    const suggPayload = inboxRows.map((row) => {
      const p = row.parsed_payload ?? {}
      return {
        workspace_id: workspaceId,
        parsed_message_id: row.id,
        message_id: row.message_id,
        received_at: row.received_at,
        shop_key: row.shop_key ?? 'amazon',
        shop_label: p.shop_label ?? 'Amazon',
        order_id: p.order_id ?? null,
        product: p.product ?? null,
        quantity: p.quantity ?? 1,
        total: null,
        currency: p.currency ?? 'EUR',
        tracking: p.tracking ?? null,
        trackings: p.trackings ?? null,
        carrier: p.carrier ?? null,
        eta: null,
        status: p.status ?? 'shipped',
        raw: { _demo: true },
      }
    })
    const { error: suggErr } = await admin
      .from('pending_deal_suggestions')
      .insert(suggPayload)
    if (suggErr) {
      console.warn('demo amazon suggestions insert failed', suggErr.message)
    }
  }

  // ---- Inventory items (8-12 aus Top-Produkten) -------------------------
  const productCount = new Map<string, number>()
  for (const d of deals) {
    productCount.set(d.product, (productCount.get(d.product) ?? 0) + 1)
  }
  const topProducts = Array.from(productCount.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 12)
    .map(([name]) => name)
  while (topProducts.length < 8) {
    topProducts.push(`Demo-Lagerartikel ${topProducts.length + 1}`)
  }
  const itemCount = Math.min(12, Math.max(8, topProducts.length))
  const itemSources = topProducts.slice(0, itemCount)

  const inventoryPayload = itemSources.map((name, idx) => {
    const supplier = suppliers[idx % suppliers.length]
    const dealMatch = deals.find((d) => d.product === name)
    const cost = dealMatch?.ek_brutto ?? round2(40 + rng() * 200)
    const inStockQty = 1 + Math.floor(rng() * 6)
    const itemRow: Record<string, unknown> = {
      workspace_id: workspaceId,
      user_id: userId,
      name,
      sku: `DEMO-${String(idx + 1).padStart(3, '0')}`,
      quantity: inStockQty,
      min_stock: 1,
      location: idx % 2 === 0 ? 'Lager A' : 'Lager B',
      cost_price: cost,
      arrival_date: shiftDate(new Date().toISOString(), -7 + Math.floor(rng() * 14)),
      supplier_id: supplier?.id ?? null,
      ticket_number: null,
      ticket_url: null,
      note: 'Demo-Lagerartikel (auto-seed)',
      status: 'Im Lager' as const,
    }
    if (schema.hasInventoryPublicCols) {
      itemRow.is_public = idx < 3
      itemRow.public_price = idx < 3 ? round2(cost * 1.25) : null
      itemRow.public_description = idx < 3 ? `Sofort verfügbar — ${name}` : null
    }
    return itemRow
  })

  const { data: itemsInserted, error: itemsErr } = await admin
    .from('inventory_items')
    .insert(inventoryPayload)
    .select('id')
  if (itemsErr) throw new Error(`inventory_items insert failed: ${itemsErr.message}`)
  const items = (itemsInserted ?? []) as Array<{ id: string }>

  // ---- Activity log (3-5 Einträge der letzten 7 Tage) -------------------
  const activityNow = Date.now()
  const activityCount = Math.min(5, Math.max(3, ACTIVITY_MESSAGES.length))
  const activityPayload = ACTIVITY_MESSAGES.slice(0, activityCount).map((entry, idx) => ({
    workspace_id: workspaceId,
    user_id: userId,
    date: new Date(
      activityNow - Math.floor(rng() * ACTIVITY_WINDOW_DAYS * 24 * 3600 * 1000),
    ).toISOString(),
    type: entry.type,
    message: entry.message,
  }))
  const { data: activityInserted, error: activityErr } = await admin
    .from('activity_log')
    .insert(activityPayload)
    .select('id')
  if (activityErr) throw new Error(`activity_log insert failed: ${activityErr.message}`)

  return {
    source_messages: usable.length,
    buyers: buyers.length,
    shops: shops.length,
    suppliers: suppliers.length,
    tickets: tickets.length,
    deals: deals.length,
    inventory_items: items.length,
    activity_log: (activityInserted ?? []).length,
  }
}

// --------------------------------------------------------------------------
// Helpers
// --------------------------------------------------------------------------

function sanitizeProduct(raw: string | null | undefined): string | null {
  if (!raw) return null
  const trimmed = raw.replace(/\s+/g, ' ').trim()
  if (trimmed.length < 2) return null
  // Auf 80 Zeichen kürzen, damit Listen nicht überlaufen.
  return trimmed.length > 80 ? trimmed.slice(0, 77) + '...' : trimmed
}

function sanitizeMoney(raw: number | null | undefined): number | null {
  if (raw == null) return null
  const n = Number(raw)
  if (!Number.isFinite(n) || n < 0 || n > 100_000) return null
  return n
}

function randomEk(rng: () => number): number {
  // Deals zwischen 50 und 600€, gleichverteilt — gibt eine plausible Spreizung
  // in den Statistiken.
  return round2(50 + rng() * 550)
}

function round2(n: number): number {
  return Math.round(n * 100) / 100
}

function shiftDate(iso: string, days: number): string {
  const d = new Date(iso)
  d.setUTCDate(d.getUTCDate() + days)
  return d.toISOString()
}

function hashString(s: string): number {
  let h = 0
  for (let i = 0; i < s.length; i++) {
    h = ((h << 5) - h + s.charCodeAt(i)) | 0
  }
  return h >>> 0
}
