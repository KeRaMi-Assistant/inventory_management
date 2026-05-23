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
import { runParseSweep, type ParseRunStats } from '../_shared/inbox_parse_runner.ts'

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
  // True wenn es nach diesem Lauf noch ungesehene UIDs gibt (UID-Cap getroffen
  // ODER Time-Budget-Stop). Der Client liest das aggregiert über alle Accounts
  // und entscheidet ob er sofort einen Folge-Call macht (Bootstrap-Pump).
  more?: boolean
  error?: string
}

// Hard cap pro Lauf, damit ein voller Posteingang nicht das 150MB-Memory-
// Limit der Edge Function sprengt. Restliche Mails fängt der nächste Tick.
// 100 ist mit unserer Lightweight-Parser-Pipeline (ohne mailparser) safe;
// erlaubt aber ein zügiges Backfill von >1k Mails in akzeptabler Zeit.
const MAX_FETCH_PER_RUN = 100

// Bootstrap-Lookback in Tagen: beim allerersten Poll eines Accounts ziehen
// wir alle UIDs der letzten N Tage rein (IMAP SEARCH SINCE). Datums-basiert
// statt UID-basiert, weil 100 UIDs für viel-Mail-Postfächer nur ~2 Tage,
// für sparse-Postfächer 6 Monate sind — beides war vorher kaputt.
//
// 2026-05-23: Default wird PRO MAILBOX dynamisch aus dem Plan-Tier des
// Workspace-Owners ermittelt (Team=30, Business=60, Enterprise=90 — siehe
// `lookbackDaysForPlan` weiter unten). Das ENV-Secret `BOOTSTRAP_LOOKBACK_DAYS`
// bleibt als manueller Override erhalten (z.B. zum Debug oder gezielten
// Re-Bootstrap mit längerem Fenster).
const FALLBACK_BOOTSTRAP_DAYS = 90
const BOOTSTRAP_LOOKBACK_DAYS_OVERRIDE: number | null = (() => {
  const raw = Deno.env.get('BOOTSTRAP_LOOKBACK_DAYS')
  if (!raw) return null
  const n = Number.parseInt(raw, 10)
  if (!Number.isFinite(n) || n < 1 || n > 365) return null
  return n
})()

/// Plan-spezifischer Inbox-Verlauf in Tagen. Spiegelt
/// `lib/models/pricing_plan.dart#inboxVisibilityDays` 1:1.
/// Mailboxen von Workspaces mit `inboxVisibilityDays === 0` (Free/Solo/
/// Solo Pro — Postfach ist Premium-Feature) sollten in der App gar nicht
/// erst angelegt werden können. Falls doch (z.B. weil der User vom
/// Enterprise auf Solo downgegradet hat und seine Mailbox stehengeblieben
/// ist), fallen wir auf 30 Tage — sonst würde der Bootstrap exakt 0
/// Mails ziehen und das Postfach wirkt kaputt.
function lookbackDaysForPlan(plan: string | null | undefined): number {
  switch (plan) {
    case 'team':
      return 30
    case 'business':
      return 60
    case 'enterprise':
      return 90
    // Legacy / unbekannte Werte → ergibt 90 (Maximum unter den
    // bezahlten Tiers, sicherer Default damit nichts verschluckt wird).
    default:
      return FALLBACK_BOOTSTRAP_DAYS
  }
}

// 2026-05-23: Default für BOOTSTRAP_NEWEST_LIMIT massiv erhöht — der alte
// 80-Cap stammt aus dem DHL-Free-Tier (1 Call/5s = 17 280 Calls/Tag). Seit
// dem Switch auf die Parcel-DE-Tracking-API (PR #103, 10 000 000 Calls/Tag)
// ist der Spike-Arrest der einzige Bottleneck, und der ist linear in der
// Anzahl Kandidaten — kein Grund mehr, das Bootstrap auf 80 zu deckeln.
// 10 000 entspricht effektiv „alles im Lookback-Fenster nehmen" für
// realistische Postfächer; der Hard-Cap pro Lauf (MAX_FETCH_PER_RUN=100)
// drosselt sowieso noch.
const DEFAULT_BOOTSTRAP_NEWEST_LIMIT = 10000
const BOOTSTRAP_NEWEST_LIMIT = (() => {
  const raw = Deno.env.get('BOOTSTRAP_NEWEST_LIMIT')
  if (!raw) return DEFAULT_BOOTSTRAP_NEWEST_LIMIT
  const n = Number.parseInt(raw, 10)
  if (!Number.isFinite(n) || n < 1 || n > 100000) {
    return DEFAULT_BOOTSTRAP_NEWEST_LIMIT
  }
  return n
})()

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

  // Dritter Auth-Pfad: User-JWT vom Flutter-Client (Inbox-Header
  // "Jetzt pollen"-Button). Wir validieren das JWT mit anon-Client und
  // beschränken den Lauf auf Postfächer der Workspaces, in denen der User
  // Mitglied ist — RLS-konforme Untermenge des Cron-Verhaltens.
  let scopedUserId: string | null = null
  if (!isCron && !isService) {
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    if (!authHeader || !anonKey) {
      return jsonResp({ error: 'Unauthorized' }, 401)
    }
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

  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  // Wenn ein User pollt: nur seine eigenen Workspace-Mailboxen.
  // Cron/Service: alle aktiven Postfächer (existing behavior).
  let allowedWorkspaceIds: string[] | null = null
  if (scopedUserId !== null) {
    const { data: memberRows, error: memberErr } = await admin
      .from('workspace_members')
      .select('workspace_id')
      .eq('user_id', scopedUserId)
    if (memberErr) {
      return jsonResp({ error: memberErr.message }, 500)
    }
    allowedWorkspaceIds = (memberRows ?? []).map(
      (r: { workspace_id: string }) => r.workspace_id,
    )
    if (allowedWorkspaceIds.length === 0) {
      return jsonResp({ ok: true, accounts: 0, stats: [], scoped_user: scopedUserId })
    }
  }

  let query = admin
    .from('mailbox_accounts')
    .select('id, workspace_id, imap_host, imap_port, use_ssl, username, folder, last_uid')
    .eq('enabled', true)
    .order('last_polled_at', { ascending: true, nullsFirst: true })
    .limit(20)
  if (allowedWorkspaceIds) {
    query = query.in('workspace_id', allowedWorkspaceIds)
  }
  const { data: rows, error } = await query
  if (error) {
    console.error('Failed to load mailbox_accounts', error)
    return jsonResp({ error: error.message }, 500)
  }

  const stats: PollStats[] = []
  let totalFetched = 0
  let totalStored = 0
  for (const account of (rows ?? []) as MailboxAccount[]) {
    const stat = await pollAccount(admin, account)
    stats.push(stat)
    totalFetched += stat.fetched
    totalStored += stat.stored
    await admin
      .from('mailbox_accounts')
      .update({
        last_polled_at: new Date().toISOString(),
        last_error: stat.error ?? null,
      })
      .eq('id', account.id)
  }

  // Inline-Parse: direkt nach dem Polling die 'pending'-Rows durch die
  // Adapter-Registry jagen. Kein HTTP-Roundtrip nach inbox-parse mehr —
  // der separate Cross-Function-Call hatte chronische 401-Probleme
  // (verify_jwt-Plattform-Layer rejected Service-Role-Key).
  //
  // Wir laufen IMMER (auch wenn totalStored=0), damit Pending-Rows aus
  // einem vorherigen, timeout-bedingt abgebrochenen Poll nachgezogen
  // werden. runParseSweep ist gegen leeren Pending-Set No-Op.
  // Limit 100 schützt vor Wallclock-Timeout — verbleibende Pending
  // werden vom nächsten Tick abgeholt.
  let parseStats: ParseRunStats = { processed: 0, matched: 0, suggested: 0, unclassified: 0 }
  try {
    if (allowedWorkspaceIds && allowedWorkspaceIds.length > 0) {
      for (const ws of allowedWorkspaceIds) {
        const partial = await runParseSweep(admin, { workspaceId: ws, limit: 100 })
        parseStats.processed += partial.processed
        parseStats.matched += partial.matched
        parseStats.suggested += partial.suggested
        parseStats.unclassified += partial.unclassified
      }
    } else {
      parseStats = await runParseSweep(admin, { limit: 500 })
    }
  } catch (e) {
    console.warn('inline parse failed', e)
  }

  // Aggregiertes "more": true wenn IRGENDEIN Account noch UIDs offen hat.
  // Der Client schickt dann sofort einen Folge-Call (Bootstrap-Pump), bis
  // alle Accounts more=false melden oder das Client-seitige Cap greift.
  const aggregateMore = stats.some((s) => s.more === true)

  return jsonResp({
    ok: true,
    accounts: stats.length,
    accounts_processed: stats.length,
    total_fetched: totalFetched,
    total_stored: totalStored,
    more: aggregateMore,
    parse: { ok: true, ...parseStats },
    stats,
  })
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

  // Lookback-Days: Override-Secret first, sonst Plan-spezifisch via
  // billing_profiles.plan des Workspace-Owners. Workspace-Owner-Lookup
  // via workspaces.owner_id → billing_profiles.plan.
  let lookbackDays = BOOTSTRAP_LOOKBACK_DAYS_OVERRIDE ?? FALLBACK_BOOTSTRAP_DAYS
  if (BOOTSTRAP_LOOKBACK_DAYS_OVERRIDE === null) {
    try {
      const { data: wsRow } = await admin
        .from('workspaces')
        .select('owner_id')
        .eq('id', account.workspace_id)
        .maybeSingle()
      const ownerId = (wsRow as { owner_id?: string } | null)?.owner_id
      if (ownerId) {
        const { data: bpRow } = await admin
          .from('billing_profiles')
          .select('plan')
          .eq('user_id', ownerId)
          .maybeSingle()
        const plan = (bpRow as { plan?: string } | null)?.plan
        lookbackDays = lookbackDaysForPlan(plan)
      }
    } catch (_e) {
      // Plan-Lookup-Fehler → Fallback bleibt 90 Tage.
    }
  }

  try {
    await client.connect()
    const lock = await client.getMailboxLock(account.folder)
    try {
      // Bootstrap: beim allerersten Poll fragen wir IMAP per
      // `SEARCH SINCE <date>` nach allen UIDs aus dem Lookback-Fenster.
      // Datums-basiert statt UID-basiert: 90 Tage Mail sind für ein
      // ult-Plan-Postfach garantiert >50 Order-Mails (Empirie aus
      // dem zweiten Test-Account: 8 Monate ≈ 700 shop-relevante Mails).
      //
      // Fallback wenn SEARCH SINCE 0 UIDs liefert (sehr leeres oder
      // brandneues Postfach): UID-Lookback von 100 — verhindert
      // Endlosschleife auf last_uid=null bei sterilen Inboxen.
      let bootstrapped = false
      if (account.last_uid === null) {
        const sinceDate = new Date(
          Date.now() - lookbackDays * 86_400_000,
        )
        let bootstrapUids: number[] = []
        try {
          bootstrapUids =
            ((await client.search({ since: sinceDate }, { uid: true })) ??
              []) as number[]
        } catch (e) {
          console.warn('SEARCH SINCE failed, falling back to UID lookback', e)
        }
        if (bootstrapUids.length > 0) {
          // Plan 2026-05-16: nicht den ganzen Lookback-Range importieren,
          // sondern nur die NEUESTEN BOOTSTRAP_NEWEST_LIMIT (Default 80).
          // Begruendung: DHL-API-Spike-Arrest 5.1s/Call macht Voll-Import
          // unrealistisch lang. last_uid wird so gewaehlt, dass der
          // regulaere Fetch-Loop genau die Top-N UIDs sieht.
          // Reduce statt `Math.max(...arr)` → kein Argument-Stack-Limit
          // bei 100k+-Mail-Inboxen.
          let maxUid = 0
          let minUid = Number.MAX_SAFE_INTEGER
          for (const u of bootstrapUids) {
            if (u > maxUid) maxUid = u
            if (u < minUid) minUid = u
          }
          // Wenn weniger als Limit verfuegbar: alle nehmen. Sonst die
          // hoechsten Limit-vielen.
          const threshold = bootstrapUids.length > BOOTSTRAP_NEWEST_LIMIT
            ? maxUid - BOOTSTRAP_NEWEST_LIMIT
            : minUid - 1
          account.last_uid = Math.max(0, threshold)
        } else {
          // SINCE-Suche kam leer zurück → UID-Range fallback. Auch hier
          // Limit auf BOOTSTRAP_NEWEST_LIMIT.
          const status = await client.status(account.folder, { uidNext: true })
          const uidNext = status.uidNext ?? 1
          account.last_uid = Math.max(0, uidNext - 1 - BOOTSTRAP_NEWEST_LIMIT)
        }
        await admin
          .from('mailbox_accounts')
          .update({ last_uid: account.last_uid })
          .eq('id', account.id)
        bootstrapped = true
        stat.bootstrapped = true
      }

      // UID-Range = (last_uid + 1) bis "*" (= aktueller Höchststand).
      // IMAP-Gotcha: wenn keine Mail > last_uid existiert, liefert `n:*`
      // trotzdem die höchste vorhandene UID — daher hart auf > last_uid
      // filtern, sonst pollen wir endlos dieselbe Top-Mail.
      const sinceUid = account.last_uid + 1
      const rawUids =
        (await client.search({ uid: `${sinceUid}:*` }, { uid: true })) ?? []
      // Aufsteigend sortieren: storeMessage + maxUid-Tracking gehen davon
      // aus, dass wir von alt zu neu fetchen. Die meisten IMAP-Server
      // liefern bereits sortiert, aber Belt-and-Suspenders.
      const newUids = rawUids
        .filter((u: number) => u > account.last_uid!)
        .sort((a: number, b: number) => a - b)
      if (newUids.length === 0) {
        // Bootstrap kam ohne Hits zurück: das ist OK (leeres Postfach im
        // Lookback-Fenster). Wir haben last_uid bereits gesetzt, der
        // nächste Tick beginnt inkrementell ab dort.
        if (bootstrapped) return stat
        return stat
      }

      // Bootstrap pullt einen größeren Batch in einem Lauf, damit der
      // User direkt nach dem "Jetzt pollen"-Klick eine sinnvolle
      // Inbox-Population sieht. Hard-Cap 200 (≈20–35s mit Netz-/Parse-
      // Overhead, gut unter dem 60s-Edge-Function-Timeout); zusätzliche
      // Time-Budget-Bremse bricht raus bevor wir das Limit reißen.
      // Reguläre Polls bleiben bei 100 (Memory-Schutz, schnelle Cron-Ticks).
      const fetchCap = bootstrapped
        ? Math.min(newUids.length, MAX_FETCH_PER_RUN * 2)
        : Math.min(newUids.length, MAX_FETCH_PER_RUN)
      const slice = newUids.slice(0, fetchCap)
      // Wichtig: maxUid wird PRO behandelter UID hochgezählt — auch wenn die
      // Mail durch den Whitelist/Promo-Filter rausfliegt oder fetchOne null
      // liefert. Sonst läuft der Poll in eine Endlosschleife auf derselben
      // Junk-Mail.
      let maxUid = account.last_uid
      // Inkrementelles Persistieren von last_uid: alle 50 verarbeiteten
      // UIDs schreiben wir den Fortschritt zurück. Wenn die Function
      // zwischen den Batches gekillt wird (CPU/Memory/Timeout), ist der
      // bisherige Fortschritt nicht verloren — der nächste Tick übernimmt.
      const PERSIST_EVERY = 50
      let processedSinceFlush = 0
      // Hard-stop wenn das Edge-Function-Wallclock-Limit (60s) näher rückt.
      // 45s lässt 15s Slack für inline-parse + finalen DB-Update + Logout.
      const TIME_BUDGET_MS = 45_000
      const startedAt = Date.now()
      let timeBudgetExhausted = false

      for (const uid of slice) {
        if (Date.now() - startedAt > TIME_BUDGET_MS) {
          timeBudgetExhausted = true
          break
        }
        stat.fetched++
        if (uid > maxUid) maxUid = uid
        try {
          const msg = await client.fetchOne(
            String(uid),
            { uid: true, envelope: true, source: true, internalDate: true },
            { uid: true },
          )
          if (!msg || !msg.uid) {
            // continue zählt trotzdem als processed (UID übersprungen),
            // sonst kommt der nächste Lauf wieder hier vorbei.
          } else {
            const stored = await storeMessage(admin, account, msg)
            if (stored) stat.stored++
          }
        } catch (e) {
          console.warn('fetch/store failed', account.id, uid, e)
        }
        processedSinceFlush++
        if (processedSinceFlush >= PERSIST_EVERY && maxUid > account.last_uid) {
          await admin
            .from('mailbox_accounts')
            .update({ last_uid: maxUid })
            .eq('id', account.id)
          account.last_uid = maxUid
          processedSinceFlush = 0
        }
      }
      if (timeBudgetExhausted) {
        console.log(
          `time-budget hit account=${account.id} fetched=${stat.fetched}/${slice.length} (rest holt nächster Tick)`,
        )
      }

      if (maxUid > account.last_uid) {
        await admin
          .from('mailbox_accounts')
          .update({ last_uid: maxUid })
          .eq('id', account.id)
      }

      // "more": signalisiere dem Client, dass es noch ungesehene UIDs gibt.
      // Trifft zu wenn:
      //  a) wir ein Slice unter newUids.length geholt haben (UID-Cap), ODER
      //  b) das Time-Budget mid-loop gerissen wurde (slice unfinished), ODER
      //  c) ein Bootstrap-Lauf mit fetchCap=200 trotzdem die volle Schiene
      //     gefüllt hat — dann ist es plausibel dass im 90-Tage-Fenster
      //     weitere UIDs > maxUid existieren (kann nur ein Folge-Call klären).
      // Der Client pumpt solange `more=true` zurückkommt — Cap dort
      // verhindert Endlos-Loop bei pathologischen Postfächern.
      const cappedSlice = slice.length < newUids.length
      const filledFully = stat.fetched >= fetchCap && bootstrapped
      stat.more = cappedSlice || timeBudgetExhausted || filledFully
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
