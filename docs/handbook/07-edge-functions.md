# 07 — Edge Functions

Die App hat **sechs** Supabase Edge Functions in
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
| [`tracking-poll`](#tracking-poll) | pg_cron alle 4h | Cron | Carrier-API für offene Deals |
| [`send-notifications`](#send-notifications) | pg_cron / manuell | Cron | Push via FCM HTTP v1 |
| [`seed-demo-workspace`](#seed-demo-workspace) | manuell aus App | User-JWT (`test@test.com` only!) | Demo-Daten in Test-Workspace |
| [`delete-account`](#delete-account) | manuell aus App | User-JWT | Account + alle Workspace-Daten löschen |

Shared-Code in [`supabase/functions/_shared/`](../../supabase/functions/_shared/):

- `inbox_adapters.ts` — Shop-Adapter-Registry (Amazon, MediaMarkt, Saturn,
  PCComponentes, X-kom).
- `inbox_parse_runner.ts` — Sweep-Logik (`runParseSweep`).
- `tracking_adapters.ts` — Carrier-Adapter (DHL, DPD, UPS).
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
abfragen.

### Auth

Cron-Secret. Keine anderen Pfade.

### Logik

1. Lade alle `workspace_carrier_credentials` mit `enabled=TRUE`.
2. Pro Workspace: lade alle offenen Deals (`status='Unterwegs'`,
   `tracking IS NOT NULL`, `arrival_date IS NULL`).
3. Pro Deal:
   - **Skip**, wenn `tracking_needs_review = TRUE` UND
     `tracking_confidence = 'none'` (T16, Strict-Tracking) — sonst
     würden API-Calls gegen leere/unsichere Trackings laufen.
   - Carrier-Adapter erkennen (Tracking-Pattern).
   - API-Call mit gespeichertem Key.
   - Bei `delivered`: setze Deal `status='Angekommen'`, `arrival_date`,
     schreib `activity_log`.
4. Cap: 200 Calls pro Lauf.

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
für die pg_cron-Schedule-Befehle.

### Deploy

```bash
supabase functions deploy tracking-poll --no-verify-jwt
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
4. Schreibe in `notifications_sent` (Dedup pro `(ref_kind, ref_id)`).
5. Sende FCM-Payload.

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
  "wiped": { "deals": 142, "tickets": 23, "items": 88 },
  "seeded": { "deals": 67, "tickets": 14, "items": 33 }
}
```

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
- [`supabase/functions/send-notifications/index.ts`](../../supabase/functions/send-notifications/index.ts) — Push
- [`supabase/functions/seed-demo-workspace/index.ts`](../../supabase/functions/seed-demo-workspace/index.ts) — Demo-Daten
- [`supabase/functions/delete-account/index.ts`](../../supabase/functions/delete-account/index.ts) — Account-Löschung
- [`supabase/functions/_shared/inbox_adapters.ts`](../../supabase/functions/_shared/inbox_adapters.ts) — Adapter-Registry
- [`supabase/functions/_shared/inbox_parse_runner.ts`](../../supabase/functions/_shared/inbox_parse_runner.ts) — Sweep-Logik
- [`supabase/functions/_shared/tracking_adapters.ts`](../../supabase/functions/_shared/tracking_adapters.ts) — Carrier-Adapter
- [`supabase/functions/tracking-poll/SETUP.md`](../../supabase/functions/tracking-poll/SETUP.md) — pg_cron-Setup
- [`supabase/functions/send-notifications/SETUP.md`](../../supabase/functions/send-notifications/SETUP.md) — FCM-Setup
- [Glossar](10-glossary.md) — Begriffsdefinitionen
