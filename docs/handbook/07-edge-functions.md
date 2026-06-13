# 07 — Edge Functions

Die App hat **acht** Supabase Edge Functions und eine SECURITY-DEFINER-RPC in
[`supabase/functions/`](../../supabase/functions/). Sie laufen auf Deno und
sind in TypeScript geschrieben. Dieses Kapitel beschreibt jede Function:
Trigger, Auth, Inputs, Outputs, Secrets und das Deploy-Kommando.

> Begriffe wie *Edge Function*, *service_role*, *pg_cron*, *Vault*, *Adapter*
> sind im [Glossar](10-glossary.md) erklärt.

## Funktions-Übersicht

| Function | Trigger | Wer ruft auf? | Erläuterung |
|---|---|---|---|
| [`inbox-poll`](#inbox-poll) | pg_cron alle 5min + UI-Button | Cron / User-JWT / service_role | IMAP holen + parsed_messages befüllen |
| [`inbox-parse`](#inbox-parse) | inline aus inbox-poll + UI | Cron / service_role | Pending-Mails klassifizieren |
| [`tracking-poll`](#tracking-poll) | pg_cron stündlich (`tracking-poll-adaptive`, Minute :07) + UI-Retrack | Cron / User-JWT | Carrier-API für offene Deals (adaptive Frequenz) |
| [`dpd-push`](#dpd-push) | DPD Tracking Push Service (extern, ~15 min) | DPD-Server (`token=`-Wand) | Webhook: DPD-Scans → live_status + tracking_events |
| [`support-request`](#support-request) | UI-Button (Settings → Support) | User-JWT (`verify_jwt=true`) | Support-Anfrage persistieren + 3-stufig zustellen |
| [`send-notifications`](#send-notifications) | pg_cron / manuell | Cron | Push via FCM HTTP v1 |
| [`seed-demo-workspace`](#seed-demo-workspace) | manuell aus App | User-JWT (`test@test.com` only!) | Demo-Daten in Test-Workspace |
| [`delete-account`](#delete-account) | manuell aus App | User-JWT | Account + alle Workspace-Daten löschen |

Shared-Code in [`supabase/functions/_shared/`](../../supabase/functions/_shared/):

- `inbox_adapters.ts` — Shop-Adapter-Registry (Amazon, MediaMarkt, Saturn,
  PCComponentes, X-kom).
- `inbox_parse_runner.ts` — Sweep-Logik (`runParseSweep`).
- `tracking_adapters.ts` — Carrier-Adapter (DHL, DPD, UPS).
- `tracking_detection.ts` — algorithmische Mail-Detection (Carrier + Tracking,
  siehe [04 — Inbox-Pipeline](04-inbox-mail-pipeline.md#carrier-registry-detection-only-carrier)).
- `carriers.ts` — kanonische Carrier-Registry (eine Quelle der Wahrheit über
  Carrier + ihre Fähigkeiten).
- `fcm.ts` — FCM-HTTP-v1-Helpers (aus `send-notifications` extrahiert, von
  `tracking-poll` für Status-Wechsel-Pushes mitgenutzt).
- `live_status.ts` — Status-Persistenz-Helfer (`buildLiveStatusUpdate`,
  `buildTrackingEventRows`, `maybeSendStatusPush`, …) — EINE Quelle für
  alle Kanäle, die Carrier-Status schreiben (`tracking-poll` + `dpd-push`).
- Tests: `*_test.ts` (Deno-Test-Pattern).

## inbox-poll

Datei:
[`supabase/functions/inbox-poll/index.ts`](../../supabase/functions/inbox-poll/index.ts)

**Aufgabe:** IMAP-Postfächer abfragen, neue Mails extrahieren, in
`parsed_messages` speichern. Im selben Lauf inline `runParseSweep`
aufrufen.

### Auth-Pfade

Drei Pfade:

1. **pg_cron** — `Authorization: Bearer <CRON_SECRET>`. Sweept ALLE
   `mailbox_accounts WHERE enabled = TRUE`.
2. **service_role** — `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`.
   Selbes Verhalten wie Cron.
3. **User-JWT** (UI-Button "Jetzt pollen") — Token wird gegen Anon-Client
   validiert (`auth.getUser()`), dann auf `workspace_members` des Users
   beschränkt.

### Inputs

POST-Body wird ignoriert — Function nimmt alle aktivierten Postfächer.

### Konfiguration via Secrets

| Secret | Default | Beschreibung |
|---|---|---|
| `CRON_SECRET` | — | Shared Secret für pg_cron-Aufrufe |
| `SUPABASE_URL` | runtime | von Supabase gesetzt |
| `SUPABASE_SERVICE_ROLE_KEY` | runtime | von Supabase gesetzt |
| `SUPABASE_ANON_KEY` | runtime | für JWT-Validation |
| `BOOTSTRAP_LOOKBACK_DAYS` | 90 | Backfill-Tage beim ersten Poll |
| `MAX_FETCH_PER_RUN` | 100 (hardcoded) | Mail-Cap pro Account & Lauf |

### Outputs

JSON mit Stats pro Account:

```json
{
  "ok": true,
  "polled": 3,
  "stats": [
    { "account_id": "...", "fetched": 42, "stored": 7, "more": false },
    { "account_id": "...", "fetched": 0, "stored": 0, "error": "TLS handshake failed" }
  ],
  "parse": { "scanned": 7, "matched": 2, "suggested": 4, "unclassified": 1 }
}
```

### Deploy

```bash
supabase functions deploy inbox-poll --no-verify-jwt
```

`--no-verify-jwt` ist Pflicht, weil die Function selbst Auth übernimmt.

## inbox-parse

Datei:
[`supabase/functions/inbox-parse/index.ts`](../../supabase/functions/inbox-parse/index.ts)

**Aufgabe:** Pending-Mails klassifizieren. Hauptpfad ist mittlerweile
inline aus `inbox-poll`; diese Function existiert für:

- **Re-Parse-Mode** — alte unklassifizierte Mails gegen die neue Adapter-
  Registry sweepen.
- **Manueller Sweep** — Backup, falls Poll mal failed und pending Rows
  liegenbleiben.

### Auth

Cron-Secret oder service_role. Keine User-JWT-Pfade.

### Inputs (POST-Body)

```ts
{
  reparse_unclassified?: boolean
  reparse_no_tracking?: boolean
  reparse_forensics?: boolean
  reparse_low_confidence?: boolean     // T12, Strict-Tracking
  workspace_id?: string  // bei reparse_no_tracking + reparse_forensics + reparse_low_confidence
  shop_key?: string      // optional, beschränkt auf einen Shop
}
```

Ohne Body: normaler `runParseSweep(limit=200)` über pending Rows.

### Endpoint-Contract (Strict-Tracking-Re-Parse)

- `workspace_id` wird AUSSCHLIESSLICH aus `auth.uid()` →
  `mailbox_accounts`-Lookup abgeleitet. Body-`workspace_id` darf nur
  INNERHALB des User-Scopes filtern, niemals erweitern.
- Service-Role-Bearer-Pfad nur für Cron / Maintenance.
- KEINE `message_id` im Body — Scope ist immer Workspace, nicht
  Einzel-Message.
- Rate-Limit: `mailbox_accounts.last_reparse_at < NOW() - INTERVAL '5
  min'` (per Workspace-Owner-Account). Sonst `429`.
- Body-Quellen beim Re-Parse: liest **beide** Quellen (`_raw_html`
  UND `_raw.text`) — sonst Regression auf Plain-Text-only-Mails aus
  PRs #48/#51.

### Outputs

```json
{ "ok": true, "scanned": 200, "matched": 14, "suggested": 32, "unclassified": 154 }
```

oder beim Re-Parse:

```json
{
  "ok": true,
  "mode": "reparse_unclassified",
  "scanned": 1240,
  "dismissed_carrier": 312,
  "dismissed_accounting": 98,
  "reshopped": 14
}
```

### Deploy

```bash
supabase functions deploy inbox-parse --no-verify-jwt
```

## tracking-poll

Datei:
[`supabase/functions/tracking-poll/index.ts`](../../supabase/functions/tracking-poll/index.ts)

**Aufgabe:** Tracking-API der Carrier (DHL, DPD, UPS) für offene Deals
abfragen, den **vollständigen Event-Verlauf** in `tracking_events`
persistieren, `deals.live_status`/`live_eta`/`last_polled_at` pflegen und
bei einem Status-Wechsel sofort einen Push senden.

### Auth & Modi

Zwei Pfade:

1. **Cron-Secret** — Sweep-Mode. Body `{ "mode": "adaptive-sweep" }`
   (stündlicher `tracking-poll-adaptive`-Job, Minute :07) mit
   In-Function-Frequenz-Gating; ohne `mode` läuft der klassische
   Daily-Sweep über alle fälligen Deals.
2. **User-JWT** mit `body.deal_id` — Single-Deal-Re-Track aus der UI
   (Refresh-Button im
   [`TrackingStatusBlock`](../../lib/widgets/tracking_status_block.dart),
   siehe [03 — Screens](03-screens-walkthrough.md#deals)). User muss
   Mitglied des Deal-Workspaces sein (`workspace_members`-Check).

### Logik (Sweep-Mode)

1. **Quiet-Hours-Guard** (nur `adaptive-sweep`): zwischen **22–05 Uhr
   Berlin** wird der ganze Lauf geskippt (`skipped: 'quiet-hours'`) —
   nachts bewegt sich im Carrier-Netz fast nichts, Polls wären reine
   Quota-Verschwendung.
2. Lade alle `workspace_carrier_credentials` mit `enabled=TRUE`, gruppiere
   pro Workspace und berechne das **Tages-Quota-Restbudget** pro
   Workspace×Carrier (`remainingDailyQuota`).
3. Pro Workspace: lade alle offenen Deals (`status='Unterwegs'`,
   `tracking IS NOT NULL`, `arrival_date IS NULL`).
4. **Adaptive Fälligkeit** (`adaptive-sweep`, `isDuePoll` anhand
   `last_polled_at` + `live_status`):
   - `out_for_delivery` → jede Stunde (≥ 50 min),
   - `in_transit` → alle ~4 h (≥ 230 min),
   - `pending`/`exception`/`null` → 2×/Tag (≥ 660 min),
   - `delivered`/expired → nie — **Ausnahme Multi-Parcel**: ist das
     Primary `delivered`, der Deal aber noch `status='Unterwegs'` (also
     [Aggregat-Completion](#tracking-poll) noch nicht erreicht, Sekundäre
     offen), bleibt der Deal fällig (`isDuePoll`), damit die übrigen
     Pakete nicht verhungern.
5. Pro fälligem Deal:
   - **Skip**, wenn `tracking_needs_review = TRUE` UND
     `tracking_confidence = 'none'` (T16, Strict-Tracking) — sonst
     würden API-Calls gegen leere/unsichere Trackings laufen.
   - **Quota-Guard**: ist das Restbudget für `workspace:carrier`
     erschöpft (`≤ 0`, Cap `DAILY_QUOTA_CAP = 900`), wird der Deal
     übersprungen (`quota_skipped++`).
   - **Multi-Parcel** ([`deals.trackings`](06-database.md#deals)):
     jede Nummer des Deals wird gepollt (Primary zuerst). Nur das
     **Primary** (`deals.tracking`) schreibt `live_status`/Push/Activity;
     **Sekundär**-Pakete schreiben ausschließlich `tracking_events`
     (`persistSecondaryEvents`).
   - Carrier-Adapter erkennen (Tracking-Pattern bzw. `deals.carrier`).
   - API-Call mit gespeichertem Key; Quota-Restbudget dekrementieren.
   - **Event-Persistenz**: kompletten Carrier-Event-Array in
     `tracking_events` upserten (`ON CONFLICT DO NOTHING` über den
     Dedup-Key, `description` auf 500 Zeichen gekürzt).
   - `deals.live_status`/`live_status_last_event`/`live_eta`
     aktualisieren; `last_polled_at = NOW()` auch ohne Status-Wechsel.
   - **Status-Wechsel-Push** (`newStatus !== live_status &&
     newStatus !== 'pending'`): Push via `_shared/fcm.ts`, dedupliziert
     über `notifications_sent` (`ref_kind='tracking_status'`,
     **Claim-then-Send** = erst die Dedup-Row claimen, dann senden,
     race-safe). Opt-out via `notification_preferences.delivery_enabled`.
   - **Aggregat-Completion** (Multi-Parcel): ein Mehrpaket-Deal schließt
     erst, wenn **ALLE** Pakete `delivered` sind. Beim Primary-Poll wird
     `suppressCompletion` gesetzt (es setzt `live_status='delivered'`,
     aber **nicht** `status='Angekommen'`); erst der Aggregat-Block
     vergibt `status='Angekommen'` + `arrival_date` + `activity_log`,
     sobald jede Nummer zugestellt ist. Bei Single-Tracking-Deals
     unverändert: `delivered` → sofort `status='Angekommen'`.
6. Nach der Schleife: ein atomarer `bump_carrier_daily_calls`-RPC-Aufruf
   pro Carrier schreibt den Tageszähler + ggf. `last_error` zurück.
7. Cap: weiterhin max. Calls pro Lauf; Reihenfolge ältester `order_date`
   zuerst.

### Logik (Single-Deal-Mode, PR #74)

POST mit `{ "deal_id": <int> }` + User-JWT:

- Pure Body-Validierung via `parseDealIdFromBody()`.
- Membership-Check: `workspace_members.user_id = auth.uid()` für den
  Workspace des Deals.
- **30s-Cooldown** via `deals.live_status_updated_at`
  (`computeRetrackCooldown()`). Schon vor `< 30s` zurückgegeben → HTTP
  `429` mit `Retry-After`-Header (Sekunden bis Cooldown-Ende).
- Sonst: gleicher Adapter-Lookup wie im Sweep, danach
  `live_status_updated_at = NOW()` als Cooldown-Marker. Kein extra
  Schema nötig — die Spalten kamen mit Migration
  [`20260515000000_deals_live_status.sql`](../../supabase/migrations/20260515000000_deals_live_status.sql).
- Cron-Polls nehmen diesen Pfad nie und sind vom Cooldown nicht
  betroffen.

### Konfiguration

| Secret | Beschreibung |
|---|---|
| `CRON_SECRET` | Shared Secret |
| `SUPABASE_SERVICE_ROLE_KEY` | service_role |

API-Keys liegen NICHT als Secret, sondern verschlüsselt in
`workspace_carrier_credentials` (siehe
[06-database.md](06-database.md)).

### Setup

Siehe [`tracking-poll/SETUP.md`](../../supabase/functions/tracking-poll/SETUP.md)
für die pg_cron-Schedule-Befehle. Das stündliche Schedule legt Migration
[`20260610090100_tracking_poll_adaptive_cron.sql`](../../supabase/migrations/20260610090100_tracking_poll_adaptive_cron.sql)
ENV-portabel an (Secret + URL werden aus dem bestehenden Cron-Job
extrahiert, kein Secret-Literal im Git; auf frischem `db reset` ohne
Quell-Job → NOTICE + Skip, Reset bleibt grün).

Für die Status-Wechsel-Pushes braucht die Function dasselbe
`FCM_SERVICE_ACCOUNT_JSON`-Secret wie `send-notifications` (siehe dort).

### Deploy

```bash
supabase functions deploy tracking-poll --no-verify-jwt
```

## dpd-push

Datei: [`supabase/functions/dpd-push/index.ts`](../../supabase/functions/dpd-push/index.ts)

Webhook für den offiziellen **DPD Tracking Push Service** (DPD-Geschäfts-
kunden-Feature, Antragsformular bei DPD). Hintergrund: DPDs öffentliche
Tracking-Endpoints blocken serverseitige Requests auf TLS-Ebene
(Bot-Schutz, verifiziert 2026-06-11) — Pull-Polling à la DHL ist für DPD
nicht zuverlässig möglich. Stattdessen sendet DPD pro Scan-Ereignis einen
GET-Request (~15 min Latenz) an diese Function.

- **Auth:** `verify_jwt=false` + PFLICHT-Query-Token `token=<DPD_PUSH_TOKEN>`
  (`supabase secrets set DPD_PUSH_TOKEN=…`, fail-closed: 503 ohne Secret,
  403 bei Mismatch). DPD-Absender-IP (213.95.42.108) wird soft geprüft.
- **pnr-Validierung:** `pnr` wird normalisiert (Whitespace raus, uppercase)
  und an der Validierungsgrenze hart auf `/^[A-Z0-9]+$/` begrenzt — die pnr
  fließt später in einen Array-Containment-Filter, der hart alphanumerisch
  bleiben muss.
- **Ablauf:** `pnr` normalisieren → Deal via `deals.tracking` **oder**
  `deals.trackings @> {pnr}` matchen ([Multi-Parcel](10-glossary.md#multi-parcel-deal),
  GIN-Index, `cs`-Containment) → Status-Map
  (`delivery_carload`→`out_for_delivery`, `delivery_customer`→
  `delivered`, …) → `live_status` + `tracking_events` via
  `_shared/live_status.ts` → Status-Wechsel-Push (FCM) → XML-ACK
  `<push><pushid>…</pushid><status>OK</status></push>`.
- **Cross-Tenant-Schutz:** der Service-Role-Lookup kennt keinen Workspace
  (der Webhook hat nur pnr + Token). Trägt dieselbe pnr in zwei Workspaces,
  ist der Treffer mehrdeutig → es wird **nichts** geschrieben (kein
  Cross-Tenant-Leak), fail-safe ACK. Trifft die pnr nur ein
  **Sekundär**-Paket aus `trackings[]`, werden ausschließlich
  Timeline-Events unter der eigenen Nummer geschrieben (kein Primary-
  Status-Update).
- **Unmatched pnr / unbekannter Status:** trotzdem ACK (sonst retried DPD
  48 h und mailt Fehler) — nur Telemetrie-Log (pnr redacted).
- **PII:** `receiver=`/`pod=` werden weder persistiert noch geloggt.
- **Formular-Werte für den DPD-Antrag:** Push-URL =
  `https://<ref>.functions.supabase.co/dpd-push?token=<DPD_PUSH_TOKEN>`,
  Antwort = XML wie oben, Verzögerung 500 ms, max. Antwortzeit 5000 ms.

## support-request

Datei:
[`supabase/functions/support-request/index.ts`](../../supabase/functions/support-request/index.ts)

**Aufgabe:** Support-Anfragen aus dem Kontaktformular (Settings → Support,
siehe [03 — Screens](03-screens-walkthrough.md#settings)) entgegennehmen
und dem Betreiber **dreistufig** zustellen.

### Auth

`verify_jwt=true` (Standard-Gateway-Check) + zusätzlich `auth.getUser()`.
Die User-Identität und die Absender-**E-Mail** kommen ausschließlich aus
dem Token, **nie** aus dem Body (kein Spoofing). Membership des optionalen
`workspace_id` wird gegen `workspace_members` geprüft; Nicht-Mitglieder →
Workspace still ignoriert (kein Enumeration-Kanal). Der `plan` kommt aus
`billing_profiles.plan` (user-keyed).

### Inputs (POST-Body)

```ts
{
  subject: string       // 3–150 Zeichen, single-line (kein CRLF)
  message: string       // 10–5000 Zeichen
  workspace_id?: string // optional, nur wenn Member
  app_version?: string  // optional, auf 50 Zeichen gekappt
}
```

Validierung (`validateSupportPayload`) ist zod-artig per Hand und
deckungsgleich mit den DB-CHECKs. Der Betreff darf kein `\r`/`\n`
enthalten (Header-Injection-Wand, weil er u.a. in den ntfy-HTTP-Header
fließt).

### Drei-stufige Zustellung

1. **INSERT** via RPC `insert_support_request` — die
   [`support_requests`](06-database.md#support_requests)-Row ist die
   **Quelle der Wahrheit** und nie verlierbar. Der RPC erzwingt atomar
   das **Rate-Limit von 5 Anfragen/User/Stunde** (NULL = Limit erreicht
   → HTTP `429 rate_limited`).
2. **ntfy-Push** (Best-Effort, env `NTFY_SUPPORT_TOPIC`) — sofort aufs
   Handy. Sicherheits-Kontrakt: ntfy-Topics sind öffentlich lesbar, also
   wird der Kanal geskippt, wenn der Topic-Name `< 16` Zeichen Zufall hat.
3. **E-Mail via Resend** (Best-Effort, env `RESEND_API_KEY`) — formatierte
   Betreiber-Mail mit Titel, Kunden-Kontext (E-Mail/Plan/Workspace/
   App-Version) und Anliegen. `reply_to` = Kunden-Mail aus dem JWT,
   Empfänger aus env `SUPPORT_EMAIL` (Fallback im Code). Subject/Message
   werden HTML-escaped (`escapeHtml`).

Kanäle 2+3 sind Best-Effort: Fehler landen nur in `mail_sent`/`push_sent`
auf der Row, der Request bleibt erfolgreich. **PII:** Logs enthalten nur
Request-Id + Kanal-Status, nie Inhalt oder E-Mail.

### Konfiguration via Secrets

| Secret | Pflicht | Beschreibung |
|---|---|---|
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` | runtime | von Supabase gesetzt |
| `NTFY_SUPPORT_TOPIC` | optional | ntfy-Topic (≥ 16 Zeichen Zufall, sonst Skip) |
| `RESEND_API_KEY` | optional | Resend-API-Key für den Mail-Kanal |
| `SUPPORT_EMAIL` | optional | Empfänger-Adresse (Fallback im Code) |
| `SUPPORT_FROM` | optional | Absender-Adresse der Resend-Mail |

### Outputs

```json
{ "ok": true, "id": 42, "mailSent": true, "pushSent": false }
```

### Deploy

```bash
supabase functions deploy support-request
```

## send-notifications

Datei:
[`supabase/functions/send-notifications/index.ts`](../../supabase/functions/send-notifications/index.ts)

**Aufgabe:** Push-Notifications via FCM HTTP v1 senden.

### Auth

Cron-Secret oder service_role.

### Logik

1. Iteriere über alle `fcm_tokens`.
2. Pro User: lade `notification_preferences`.
3. Berechne, was fällig ist:
   - **MHD-Warnung** — Items mit `expires_at < NOW() + N days`.
   - **Delivery** — Deals, die heute zugestellt wurden.
   - **Payment-overdue** — Deals mit `internal_invoice_paid=false` und
     Rechnung älter als N Tage.
   - **Low-Stock** (Epic D / Task D5) — Produkte, deren Bestand laut
     `product_stock`-View unter `products.min_stock` liegt. Dedup:
     max. ein Push pro Workspace + Kalendertag
     (`ref_kind='low_stock'`, `ref_id=<YYYY-MM-DD>`). Workspace-scoped
     über die neue `notifications_sent.workspace_id`-Spalte (siehe
     [06 — Datenbank](06-database.md#notifications_sent-erweiterung)).
     Opt-in via bestehender `notification_preferences` (kein neues Flag).
4. Schreibe in `notifications_sent` (Dedup pro `(ref_kind, ref_id)`).
5. Sende FCM-Payload.

> Die FCM-HTTP-v1-Helpers (OAuth-Token, Payload-Build, Versand) sind seit
> Paket 1 nach [`_shared/fcm.ts`](../../supabase/functions/_shared/fcm.ts)
> extrahiert, damit auch `tracking-poll` die Status-Wechsel-Pushes über
> denselben Code sendet. `send-notifications` bleibt der Cron-Pfad für
> `mhd`/`delivery`/`payment`/`low_stock`.

### Konfiguration

| Secret | Beschreibung |
|---|---|
| `FCM_SERVICE_ACCOUNT_JSON` | Pflicht. Service-Account-JSON für FCM HTTP v1 |
| `CRON_SECRET` | Shared Secret |
| `SUPABASE_SERVICE_ROLE_KEY` | service_role |

### Setup

Siehe [`send-notifications/SETUP.md`](../../supabase/functions/send-notifications/SETUP.md):

```bash
# Service-Account-JSON aus Firebase Console laden
supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat fcm-sa.json)"
supabase secrets set CRON_SECRET="$(openssl rand -hex 32)"
```

### Deploy

```bash
supabase functions deploy send-notifications --no-verify-jwt
```

## seed-demo-workspace

Datei:
[`supabase/functions/seed-demo-workspace/index.ts`](../../supabase/functions/seed-demo-workspace/index.ts)

**Aufgabe:** Den Personal-Workspace eines Test-Users **leeren** und mit
echten Daten aus seinen `parsed_messages` der letzten 90 Tage neu
befüllen.

### Hard-Constraints (NICHT entfernen!)

- Läuft NUR, wenn der Caller-JWT zu `auth.users.email = 'test@test.com'`
  gehört. Sonst 403.
- Schreibt NUR in den Personal-Workspace dieses Users (Owner-Rolle).
- Nutzt service_role nur für DELETE/INSERT — die `workspace_id` wird vor
  dem Schreiben aus der User-Session gelesen, **niemals aus dem
  Request-Body übernommen** (sonst Workspace-Hijack möglich).

### Inputs

POST ohne Body. JWT im `Authorization`-Header.

### Outputs

```json
{
  "ok": true,
  "wiped": { "deals": 142, "tickets": 23, "items": 88, "products": 0 },
  "seeded": { "deals": 67, "tickets": 14, "items": 33, "products": 5 }
}
```

Seit Epic A-full erkennt die Function via `probeTable('products')`, ob
die Tabelle existiert, und befüllt sie mit Demo-Artikeln (je ein
`products`-Row pro Demo-Item-Typ). `inventory_items.product_id` wird
für die geseedeten Items entsprechend verknüpft. Die Seeding-Logik ist
tablecheck-gated — fehlt die `products`-Tabelle (z. B. in alten
Branches), wird das Seeding graceful übersprungen.

### Deploy

```bash
supabase functions deploy seed-demo-workspace
```

## delete-account

Datei:
[`supabase/functions/delete-account/index.ts`](../../supabase/functions/delete-account/index.ts)

**Aufgabe:** Account + alle Daten löschen. Kompakt (~50 LoC):

1. JWT validieren via Anon-Client.
2. `auth.admin.deleteUser(user.id)` (service_role).
3. Alle `ON DELETE CASCADE`-FK-Beziehungen sorgen für Aufräumen
   (`workspaces.owner_id` → workspaces löschen → alle abhängigen Daten
   inkl. parsed_messages).

### Auth

User-JWT.

### Outputs

```json
{ "ok": true }
```

### Deploy

```bash
supabase functions deploy delete-account
```

> Diese Function ist intentional simpel — alles "echte" Aufräumen passiert
> über `ON DELETE CASCADE` im Schema.

## Shared-Code

### `_shared/inbox_adapters.ts`

Die größte Shared-Datei (~1600 LoC). Enthält:

- `ParsedOrder`, `MailContext`, `Adapter`-Interfaces.
- Pro Shop ein Adapter-Object mit `matches`, `looksLikeOrder`, `parse`.
- Helper: `STRONG_TRACKING_PATTERNS`, `moneyRe`, `detectShop`,
  `detectAndParse`, `shouldStore`, `isAccountingMail`, `isCarrierOnly`.

Tests:

- `inbox_adapters_test.ts` — Unit-Tests pro Adapter.
- `inbox_forensics_test.ts` — End-to-End-Tests mit echten Mail-HTMLs aus
  `docs/inbox-forensics/`.
- `amazon_html_test.ts` — Spezielle Edge-Cases für Amazon-HTML.

### `_shared/inbox_parse_runner.ts`

`runParseSweep(admin, opts)` und `stripBody()`. `stripBody` entfernt aus
einem Body alle nicht relevanten Teile (Signature, Quoted-Reply, …),
bevor er an `parsed_payload` weitergegeben wird.

### `_shared/tracking_adapters.ts`

Tracking-API-Adapter (DHL, DPD, UPS). Pro Carrier:

- `matches(tracking)` — erkennt Carrier aus der Nummer.
- `lookup(tracking, apiKey)` — ruft API auf, parst Response.
- Returns: `{ status, deliveredAt?, eta?, raw? }`.

### `_shared/tracking_validators.ts` (PR #73)

Strukturelle Validierung (Länge + Charset + Checksum) für Tracking-
Nummern aus dem strict-Tracking-Pfad. Wichtige Eigenschaft seit PR #73:

- **Multi-Candidate-Disambiguation.** `validateTrackingNumber()` sammelt
  ALLE matchenden Pattern-Kandidaten statt First-Match. Auflösung:
  - 1 Kandidat → eindeutig.
  - N Kandidaten, genau 1 mit gültiger Checksum → Checksum-Winner.
  - N Kandidaten, alle Checksum-valid → `{ ambiguous: true,
    candidates: [...] }`, `isValid = false`. Konsumenten nehmen in dem
    Fall **keinen** Carrier an (lieber „kein Tracking" als falscher
    Carrier). Konkret betroffen: USPS-22 vs. DHL-20 auf reinen
    Ziffernfolgen (z.B. `420…`-Partner-Numbers aus DHL-eCommerce↔USPS-
    Cross-Refs).
- **DPD MOD 37,36 Checksum** implementiert (ISO 7064, parameter-less
  Form). 14- und 28-stellige DPD-Patterns laufen jetzt durch alle vier
  `valid`-Samples und rejecten alle drei `invalid`-Samples.

Tests: `tracking_validators_test.ts` + `tracking_disambiguation_test.ts`
(23/23 grün).

### `_shared/carriers.ts`

Kanonische **Carrier-Registry** (Paket 2, Audit-Fix „Carrier 3-fach
inkonsistent"). Eine Quelle der Wahrheit über alle Carrier und ihre
Fähigkeiten (`detection`, `pollAdapter`, `requiresApiKey`, `uiEnabled`,
`publicTrackingPage`). Konsumenten: `tracking_detection.ts` (CarrierIds),
`tracking_adapters.ts` (Poll-Adapter), `tracking-poll/index.ts`
(`DETECTION_ONLY_CARRIERS`) sowie die Dart-Spiegel
`carrier_credential.dart` + `carrier_links.dart` (Konsistenz per
`carriers_test.ts` mit `--allow-read` geprüft). Die `deals.carrier`-CHECK-
Constraint ist die Obermenge dieser Ids. Siehe
[04 — Inbox-Pipeline](04-inbox-mail-pipeline.md#carrier-registry-detection-only-carrier).

### `_shared/fcm.ts`

FCM-HTTP-v1-Helpers (Paket 1, aus `send-notifications` extrahiert):
`parseServiceAccount`, `getGoogleAccessToken` (RS256-JWT → OAuth-Token),
Payload-Build und Token-Versand. Wird von `send-notifications` (Cron-
Push) **und** `tracking-poll` (Status-Wechsel-Push) genutzt. Keine
Secret-Leaks: `FCM_SERVICE_ACCOUNT_JSON` nur via `Deno.env`, Caller loggen
nur Status-Codes.

## increment_po_item_received (RPC)

Keine Edge-Function, sondern eine SECURITY-DEFINER-Postgres-Funktion.
Datei:
[`supabase/migrations/20260522032123_po_receive_increment.sql`](../../supabase/migrations/20260522032123_po_receive_increment.sql)

**Aufgabe:** Atomar `purchase_order_items.quantity_received` inkrementieren,
ohne Client-seitiges Read-modify-write.

### Warum RPC statt direktem UPDATE?

Der Supabase-Dart-Client unterstützt in `.update({...})` nur literal
values — ein `quantity_received = quantity_received + x` ist über REST
nicht möglich. Die RPC ist der einzige sichere Pfad.

### Aufruf (Dart)

```dart
await supabase.rpc('increment_po_item_received', params: {
  'p_item_id': itemId,
  'p_qty':     deltaQty,
});
```

### Sicherheits-Design

- `SECURITY DEFINER`, `SET search_path = public, pg_temp`.
- Workspace-Rollen-Check im Body (mind. `member`).
- Über-Buchungs-Schranke: `quantity_received + p_qty ≤ quantity_ordered`.
- `GRANT EXECUTE` nur an `authenticated` (kein `anon`).
- Nach dem UPDATE feuert `purchase_order_items_status_trg` → aktualisiert
  `purchase_orders.status` automatisch. Kein manueller Status-Update
  nötig. Siehe [06 — Datenbank](06-database.md#rpc-increment_po_item_received).

## Lokal testen

```bash
# Stack starten
supabase start

# Function lokal serven
supabase functions serve inbox-poll --no-verify-jwt --env-file ./supabase/functions/.env.local

# In zweitem Tab anrufen
curl -i http://127.0.0.1:54321/functions/v1/inbox-poll \
  -H "Authorization: Bearer $LOCAL_CRON_SECRET" \
  -H "Content-Type: application/json"
```

`.env.local` (gitignored) hält `CRON_SECRET=...` und ggf.
`BOOTSTRAP_LOOKBACK_DAYS=...`.

## Deno-Tests

```bash
cd supabase/functions
deno test --allow-read _shared/inbox_adapters_test.ts
deno test --allow-read _shared/inbox_forensics_test.ts
deno test --allow-read _shared/tracking_adapters_test.ts
```

## Logs

```bash
supabase functions logs inbox-poll --follow
supabase functions logs send-notifications --tail 200
```

Keine Tokens, Mails oder PII in Logs schreiben — siehe
[CLAUDE.md](../../CLAUDE.md). Adapter zeigen das Pattern.

## Quelle im Code

- [`supabase/functions/inbox-poll/index.ts`](../../supabase/functions/inbox-poll/index.ts) — IMAP-Polling
- [`supabase/functions/inbox-parse/index.ts`](../../supabase/functions/inbox-parse/index.ts) — Klassifizierung
- [`supabase/functions/tracking-poll/index.ts`](../../supabase/functions/tracking-poll/index.ts) — Carrier-Refresh
- [`supabase/functions/support-request/index.ts`](../../supabase/functions/support-request/index.ts) — Support-Kontaktformular
- [`supabase/functions/send-notifications/index.ts`](../../supabase/functions/send-notifications/index.ts) — Push
- [`supabase/functions/seed-demo-workspace/index.ts`](../../supabase/functions/seed-demo-workspace/index.ts) — Demo-Daten
- [`supabase/functions/delete-account/index.ts`](../../supabase/functions/delete-account/index.ts) — Account-Löschung
- [`supabase/functions/_shared/inbox_adapters.ts`](../../supabase/functions/_shared/inbox_adapters.ts) — Adapter-Registry
- [`supabase/functions/_shared/inbox_parse_runner.ts`](../../supabase/functions/_shared/inbox_parse_runner.ts) — Sweep-Logik
- [`supabase/functions/_shared/tracking_adapters.ts`](../../supabase/functions/_shared/tracking_adapters.ts) — Carrier-Adapter
- [`supabase/functions/tracking-poll/SETUP.md`](../../supabase/functions/tracking-poll/SETUP.md) — pg_cron-Setup
- [`supabase/functions/send-notifications/SETUP.md`](../../supabase/functions/send-notifications/SETUP.md) — FCM-Setup
- [`supabase/migrations/20260522032123_po_receive_increment.sql`](../../supabase/migrations/20260522032123_po_receive_increment.sql) — RPC increment_po_item_received
- [Glossar](10-glossary.md) — Begriffsdefinitionen
