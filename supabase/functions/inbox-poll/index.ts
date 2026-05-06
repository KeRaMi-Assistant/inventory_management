// Supabase Edge Function: inbox-poll
//
// Triggered every 5 min by pg_cron. Iterates over enabled mailbox_accounts,
// connects to IMAP via ImapFlow, fetches messages newer than `last_uid`, and
// writes header + plaintext digest into `parsed_messages` with status='pending'.
// inbox-parse picks up the pending rows, runs the adapter registry and either
// matches them to existing deals or creates pending_deal_suggestions.
//
// Required env (set with `supabase secrets set`):
//   CRON_SECRET               – Shared secret matching the pg_cron Authorization
//
// Standard env (provided by the runtime):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { ImapFlow } from 'npm:imapflow@1.0.156'
import { shouldStore, detectShop } from '../_shared/inbox_adapters.ts'

interface MailboxAccount {
  id: string
  workspace_id: string
  imap_host: string
  imap_port: number
  use_ssl: boolean
  username: string
  folder: string
  last_uid: number | null
}

interface PollStats {
  account_id: string
  fetched: number
  stored: number
  bootstrapped?: boolean
  error?: string
}

// Hard cap pro Lauf, damit ein voller Posteingang nicht das 150MB-Memory-
// Limit der Edge Function sprengt. Restliche Mails fängt der nächste Tick.
// 100 ist mit unserer Lightweight-Parser-Pipeline (ohne mailparser) safe;
// erlaubt aber ein zügiges Backfill von >1k Mails in akzeptabler Zeit.
const MAX_FETCH_PER_RUN = 100

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
  if (!isCron && !isService) return jsonResp({ error: 'Unauthorized' }, 401)

  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  const { data: rows, error } = await admin
    .from('mailbox_accounts')
    .select('id, workspace_id, imap_host, imap_port, use_ssl, username, folder, last_uid')
    .eq('enabled', true)
    .order('last_polled_at', { ascending: true, nullsFirst: true })
    .limit(20)
  if (error) {
    console.error('Failed to load mailbox_accounts', error)
    return jsonResp({ error: error.message }, 500)
  }

  const stats: PollStats[] = []
  for (const account of (rows ?? []) as MailboxAccount[]) {
    const stat = await pollAccount(admin, account)
    stats.push(stat)
    await admin
      .from('mailbox_accounts')
      .update({
        last_polled_at: new Date().toISOString(),
        last_error: stat.error ?? null,
      })
      .eq('id', account.id)
  }

  // Trigger parser sweep so users see results in the next UI tick.
  triggerParse().catch((e) => console.warn('triggerParse failed', e))

  return jsonResp({ ok: true, accounts: stats.length, stats })
})

async function pollAccount(
  admin: ReturnType<typeof createClient>,
  account: MailboxAccount,
): Promise<PollStats> {
  const stat: PollStats = { account_id: account.id, fetched: 0, stored: 0 }

  const { data: pwData, error: pwErr } = await admin.rpc('get_mailbox_password', {
    _account_id: account.id,
  })
  if (pwErr || !pwData) {
    stat.error = pwErr?.message ?? 'Passwort fehlt'
    return stat
  }

  const client = new ImapFlow({
    host: account.imap_host,
    port: account.imap_port,
    secure: account.use_ssl,
    auth: { user: account.username, pass: pwData as string },
    logger: false,
  })

  try {
    await client.connect()
    const lock = await client.getMailboxLock(account.folder)
    try {
      // Bootstrap: beim allerersten Poll laden wir NICHTS herunter, sondern
      // setzen last_uid auf den aktuellen Höchststand. Erst ab dem nächsten
      // Tick fließen neue Mails rein. Verhindert, dass ein voller Inbox-Archiv
      // die Edge Function kippt.
      if (account.last_uid === null) {
        const status = await client.status(account.folder, { uidNext: true })
        const baseline = Math.max(0, (status.uidNext ?? 1) - 1)
        await admin
          .from('mailbox_accounts')
          .update({ last_uid: baseline })
          .eq('id', account.id)
        stat.bootstrapped = true
        return stat
      }

      // UID-Range = (last_uid + 1) bis "*" (= aktueller Höchststand).
      // IMAP-Gotcha: wenn keine Mail > last_uid existiert, liefert `n:*`
      // trotzdem die höchste vorhandene UID — daher hart auf > last_uid
      // filtern, sonst pollen wir endlos dieselbe Top-Mail.
      const sinceUid = account.last_uid + 1
      const rawUids =
        (await client.search({ uid: `${sinceUid}:*` }, { uid: true })) ?? []
      const newUids = rawUids.filter((u: number) => u > account.last_uid!)
      if (newUids.length === 0) return stat

      const slice = newUids.slice(0, MAX_FETCH_PER_RUN)
      // Wichtig: maxUid wird PRO behandelter UID hochgezählt — auch wenn die
      // Mail durch den Whitelist/Promo-Filter rausfliegt oder fetchOne null
      // liefert. Sonst läuft der Poll in eine Endlosschleife auf derselben
      // Junk-Mail.
      let maxUid = account.last_uid

      for (const uid of slice) {
        stat.fetched++
        if (uid > maxUid) maxUid = uid
        try {
          const msg = await client.fetchOne(
            String(uid),
            { uid: true, envelope: true, source: true, internalDate: true },
            { uid: true },
          )
          if (!msg || !msg.uid) continue
          const stored = await storeMessage(admin, account, msg)
          if (stored) stat.stored++
        } catch (e) {
          console.warn('fetch/store failed', account.id, uid, e)
        }
      }

      if (maxUid > account.last_uid) {
        await admin
          .from('mailbox_accounts')
          .update({ last_uid: maxUid })
          .eq('id', account.id)
      }
    } finally {
      lock.release()
    }
    await client.logout()
  } catch (e) {
    console.error(`IMAP error account=${account.id}`, e)
    stat.error = (e as Error).message ?? 'IMAP-Fehler'
    try { await client.close() } catch { /* ignore */ }
  }

  return stat
}

interface FetchedMessage {
  uid?: number
  envelope?: {
    from?: Array<{ address?: string }>
    subject?: string
    date?: Date
    messageId?: string
  }
  source?: Uint8Array
  internalDate?: Date
}

async function storeMessage(
  admin: ReturnType<typeof createClient>,
  account: MailboxAccount,
  msg: FetchedMessage,
): Promise<boolean> {
  if (!msg.uid) return false

  const env = msg.envelope ?? {}
  const fromAddr = env.from?.[0]?.address ?? null
  const subject = env.subject ?? null
  const receivedAt = (env.date ?? msg.internalDate ?? new Date()).toISOString()

  // Whitelist + Promo-Filter: nur Mails bekannter Shops mit Order-/Versand-
  // /Storno-Subjects landen in der DB. Werbung und unbekannte Absender
  // werden früh verworfen, damit der Inbox-Tab nicht zumüllt.
  const ctxHeader = { from: fromAddr ?? '', subject: subject ?? '', text: '', html: '' }
  if (!shouldStore(ctxHeader)) return false
  const shop = detectShop(ctxHeader)

  // Body schlank extrahieren: nur text/plain + text/html als Strings, keine
  // Attachments. Das spart RAM gegenüber mailparser.
  let text = ''
  let html = ''
  if (msg.source) {
    const raw = new TextDecoder('utf-8', { fatal: false }).decode(msg.source)
    const extracted = extractTextAndHtml(raw)
    text = extracted.text
    html = extracted.html
  }

  const hashSource = `${account.id}|${msg.uid}|${env.messageId ?? subject ?? ''}|${receivedAt}`
  const hash = await sha256Hex(hashSource)

  const { error } = await admin.from('parsed_messages').insert({
    workspace_id: account.workspace_id,
    account_id: account.id,
    message_uid: msg.uid,
    message_hash: hash,
    message_id: env.messageId ?? null,
    from_address: fromAddr,
    subject,
    received_at: receivedAt,
    shop_key: shop?.key ?? null,
    status: 'pending',
    parsed_payload: { _raw: { text, html }, shop_label: shop?.label },
  })
  if (error) {
    if ((error as { code?: string }).code === '23505') return false
    console.warn('parsed_messages insert failed', account.id, msg.uid, error)
    return false
  }
  return true
}

// Sehr simpler MIME-Splitter: zieht text/plain und text/html aus einer
// raw-RFC-822-Mail. Reicht für Bestellbestätigungen, die selten mehr als
// zwei Body-Parts mitbringen. Quoted-printable / base64 werden best-effort
// dekodiert, damit Adapter-Regex anschlägt.
function extractTextAndHtml(raw: string): { text: string; html: string } {
  // Manche Mailer (oder Gateway-Konvertierungen) liefern bare LFs statt
  // CRLF. Wir akzeptieren beides als Header/Body-Separator und normalisieren
  // intern alles auf CRLF, damit die nachfolgenden Splits stabil sind.
  const normalized = raw.replace(/\r\n/g, '\n').replace(/\n/g, '\r\n')
  const headerEnd = normalized.indexOf('\r\n\r\n')
  if (headerEnd < 0) return { text: normalized, html: '' }
  const rawHeaders = normalized.slice(0, headerEnd)
  const body = normalized.slice(headerEnd + 4)

  // RFC 822 / 5322 erlaubt gefaltete Headers: ein Header kann über
  // mehrere Zeilen gehen, wenn die Folgezeilen mit Whitespace beginnen.
  // MediaMarkt + viele andere Mailer bauen so:
  //   Content-Type: multipart/alternative;
  //   \tboundary="...."
  // Vor dem Regex-Match unfolden, sonst verpassen wir den boundary-
  // Parameter und der ganze Body landet als Plaintext.
  const headers = rawHeaders.replace(/\r?\n[\t ]+/g, ' ')

  // Multiline-Mode + Anchor auf Zeilenanfang ist wichtig: DKIM-Signaturen
  // listen Header-Namen wie "Content-Type" in ihrem `h=`-Parameter — ohne
  // Anchor matcht unser Regex DAS und holt sich Müll als Content-Type.
  const ctMatch = /^content-type:\s*([^;\r\n]+)(.*)/im.exec(headers)
  const contentType = ctMatch?.[1]?.trim().toLowerCase() ?? 'text/plain'
  const params = ctMatch?.[2] ?? ''
  const boundaryMatch = /boundary="?([^";\r\n]+)"?/i.exec(params)
  const cteMatch = /^content-transfer-encoding:\s*([^\r\n]+)/im.exec(headers)
  const cte = cteMatch?.[1]?.trim().toLowerCase() ?? '7bit'

  const decodeQP = (chunk: string): string => {
    const cleaned = chunk.replace(/=\r?\n/g, '')
    const bytes: number[] = []
    for (let i = 0; i < cleaned.length; i++) {
      if (cleaned[i] === '=' && i + 2 < cleaned.length
          && /[0-9A-Fa-f]/.test(cleaned[i + 1])
          && /[0-9A-Fa-f]/.test(cleaned[i + 2])) {
        bytes.push(parseInt(cleaned.substring(i + 1, i + 3), 16))
        i += 2
      } else {
        bytes.push(cleaned.charCodeAt(i) & 0xff)
      }
    }
    return new TextDecoder('utf-8', { fatal: false }).decode(
      new Uint8Array(bytes),
    )
  }
  // Heuristik: QP-Pattern auch bei fehlendem/falschem CTE-Header anwenden.
  // Viele reale Mails deklarieren 7bit, schmuggeln aber =HH-Sequenzen für
  // Umlaute durch. Threshold von 3+ Sequenzen schützt vor False-Positives
  // bei Code-Snippets oder URLs mit zufälligen "="-Zeichen.
  const looksLikeQP = (s: string): boolean =>
    (s.match(/=[0-9A-Fa-f]{2}/g) ?? []).length >= 3

  const decode = (chunk: string, enc: string): string => {
    const e = enc.toLowerCase()
    try {
      if (e === 'base64') {
        const cleaned = chunk.replace(/\s+/g, '')
        return new TextDecoder('utf-8', { fatal: false }).decode(
          Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0)),
        )
      }
      if (e === 'quoted-printable' || looksLikeQP(chunk)) {
        return decodeQP(chunk)
      }
    } catch { /* fall through */ }
    return chunk
  }

  if (boundaryMatch) {
    const boundary = boundaryMatch[1]
    const parts = body.split(`--${boundary}`)
    let text = ''
    let html = ''
    for (const part of parts) {
      const trimmed = part.replace(/^\r?\n/, '').replace(/\r?\n--$/, '')
      if (!trimmed.trim() || trimmed.startsWith('--')) continue
      const partHeaderEnd = trimmed.indexOf('\r\n\r\n')
      if (partHeaderEnd < 0) continue
      const partHeaders = trimmed.slice(0, partHeaderEnd)
        // Gleiche Header-Unfolding-Regel wie oben — nested parts haben
        // genauso oft gefaltete Headers.
        .replace(/\r?\n[\t ]+/g, ' ')
      const partBody = trimmed.slice(partHeaderEnd + 4)
      const partCt = (/^content-type:\s*([^;\r\n]+)/im.exec(partHeaders)?.[1] ?? '')
        .trim().toLowerCase()
      const partCte = (/^content-transfer-encoding:\s*([^\r\n]+)/im.exec(partHeaders)?.[1] ?? '7bit')
        .trim()
      const decoded = decode(partBody, partCte)
      if (partCt === 'text/plain' && !text) text = decoded
      else if (partCt === 'text/html' && !html) html = decoded
      else if (partCt.startsWith('multipart/')) {
        // Verschachtelt — rekursiv. `trimmed` enthält bereits die Headers
        // dieses Parts (Content-Type: multipart/related; boundary=...).
        // Vorher haben wir hier `X:Y\r\n\r\n${trimmed}` vorne drangehängt,
        // wodurch der rekursive Call den Content-Type nicht mehr im
        // Header-Slice fand — Resultat: nested multipart wurde komplett
        // als Plaintext behandelt und html blieb leer. (MediaMarkt/Saturn
        // versenden multipart/alternative → multipart/related → text/html.)
        const inner = extractTextAndHtml(trimmed)
        if (!text && inner.text) text = inner.text
        if (!html && inner.html) html = inner.html
      }
    }
    return {
      text: text.slice(0, 100_000),
      html: html.slice(0, 100_000),
    }
  }

  const decoded = decode(body, cte)
  if (contentType === 'text/html') {
    return { text: '', html: decoded.slice(0, 100_000) }
  }
  return { text: decoded.slice(0, 100_000), html: '' }
}

async function triggerParse(): Promise<void> {
  const url = `${Deno.env.get('SUPABASE_URL')}/functions/v1/inbox-parse`
  await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
      'Content-Type': 'application/json',
    },
    body: '{}',
  })
}

async function sha256Hex(input: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input))
  const bytes = Array.from(new Uint8Array(buf))
  return bytes.map((b) => b.toString(16).padStart(2, '0')).join('')
}

function jsonResp(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
