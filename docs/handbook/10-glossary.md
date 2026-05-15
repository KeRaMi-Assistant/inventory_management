# 10 — Glossar

Kompakte Definitionen aller Fachbegriffe, die im Rest des Handbuchs
verwendet werden. Jeder Eintrag verlinkt auf das Kapitel, in dem der
Begriff im Kontext erklärt ist.

> Die Einträge sind alphabetisch geordnet (deutsche Begriffe zuerst,
> englische in den Klammern). Bei Synonymen ist der Hauptbegriff fett, das
> Synonym kursiv.

## A

### Akzent-Palette

Eine von fünf vordefinierten Farbpaletten (`blue`, `indigo`, `violet`,
`teal`, `rose`), die der User in den Settings auswählt. Persistenz via
`AppPreferencesProvider`. Die `AppTheme.accent*`-Tokens sind seit PR #68
runtime-getter (kein `const Color` mehr). Siehe
[03 — Screens](03-screens-walkthrough.md#settings) und
[05 — Architektur](05-architecture.md#akzent-paletten-pr-68).

### Ambiguous-Tracking

Auflösungs-Outcome von `validateTrackingNumber()` (in
[`tracking_validators.ts`](../../supabase/functions/_shared/tracking_validators.ts)):
mehrere Carrier-Pattern matchen, alle haben gültige Checksum → kein
Carrier wird angenommen, `isValid = false`. Beispiel: USPS-22 vs.
DHL-20 auf `420…`-Partner-Numbers. Siehe
[07 — Edge Functions](07-edge-functions.md#_sharedtracking_validatorsts-pr-73).

### Adapter

Eine Mini-Klasse pro Quell-Shop in
[`inbox_adapters.ts`](../../supabase/functions/_shared/inbox_adapters.ts),
die `matches`, `looksLikeOrder` und `parse` zur Verfügung stellt. Pro
Tracking-Carrier ein Adapter in `tracking_adapters.ts`. Siehe
[04 — Inbox-Pipeline](04-inbox-mail-pipeline.md#adapter-registry).

### Activity-Log

Tabelle `activity_log`, eine UI-Heatmap der letzten User-Aktionen. Pro
Workspace auf 50 Einträge limitiert. Nicht zu verwechseln mit
[Audit-Log](#audit-log). Siehe [02 — Konzepte](02-concepts.md#activity-log).

### Anchor-Wort

Sprach-spezifisches Schlüsselwort (`Sendungsnummer`, `Tracking`,
`Sendungsverfolgung`, `numéro de suivi`, …), das im Sentence-Window
direkt vor einer Tracking-Kandidaten-Nummer stehen muss, damit die
Strict-Tracking-Extraction sie als Strong-Pattern akzeptiert.
Eingebettet in `TrackingCandidate.anchorMatched` (max 50 Zeichen,
PII-Schutz). Siehe
[04 — Inbox-Pipeline](04-inbox-mail-pipeline.md#strict-tracking-extraction-confidence-modell).

### Anon-Key

Der öffentliche Supabase-Schlüssel, mit dem die Flutter-App Requests an
Supabase macht. Liegt in `lib/config/supabase_config.dart`. Hat nur die
Rechte, die [RLS](#rls) erlaubt. Sicher zu publizieren.

### Audit-Log

Tabelle `audit_log`, append-only, workspace-scoped. Schreibt
Compliance-Aktionen (`create`, `update`, `invite`, …). Wird von Triggern
oder Edge-Functions geschrieben, nie direkt durch User. Siehe
[06 — Datenbank](06-database.md#audit_log-vs-activity_log).

### Auto-Merge

Pre-Launch-Verfahren: PRs werden nach grünen CI-Gates automatisch
gemerged. `gh pr merge --auto --squash --delete-branch`. Setup via
[`.claude/scripts/setup-branch-protection.sh`](../../.claude/scripts/setup-branch-protection.sh).

## B

### Backlog (Headless-Loop)

Verzeichnis `.claude/backlog/inbox/` mit nummerierten Markdown-Items, die
der Headless-Runner nacheinander abarbeitet. Siehe
[CLAUDE.md](../../CLAUDE.md).

### Buyer

Endkunde / Käufer. Datentabelle `buyers` mit Farbcodierung, Discord-
Server-IDs und Payment-Status. Im [Deal](#deal) als freier Textstring.
Siehe [02 — Konzepte](02-concepts.md#buyer).

### Bootstrap (Inbox)

Erstes Pollen eines Postfachs. Statt UID-basiert zieht der Poll datums-
basiert per IMAP `SEARCH SINCE` `BOOTSTRAP_LOOKBACK_DAYS` (Default 90).
Siehe [04 — Inbox-Pipeline](04-inbox-mail-pipeline.md#inbox-poll--imap-holzhammer).

## C

### Carrier

Versanddienstleister (DHL, DPD, UPS). Pro Workspace API-Keys in
`workspace_carrier_credentials`. Wird vom [Tracking-Poll](#tracking-poll)
abgefragt. Siehe [02 — Konzepte](02-concepts.md#carrier-credentials).

### ChangeNotifier

Flutter-Klasse aus `provider`, die `notifyListeners()`-basierten Rebuild
ermöglicht. Alle stateful Provider in `lib/providers/` sind
ChangeNotifier-Subklassen. Siehe [05 — Architektur](05-architecture.md#provider-verantwortlichkeiten).

### Cron-Secret

`CRON_SECRET`-Env-Variable, gemeinsamer Bearer-Token zwischen pg_cron und
den Edge-Functions. Wird mit `supabase secrets set` gesetzt.

## D

### Deal

Kern-Entity der App. Bestellung beim Shop, die an einen Buyer
weiterverkauft (oder direkt geliefert) wird. Tabelle `deals`. Siehe
[02 — Konzepte](02-concepts.md#deal).

### Demo-Daten

Über die Edge-Function
[`seed-demo-workspace`](07-edge-functions.md#seed-demo-workspace)
generierte Datensätze, nur für `test@test.com`-Account. Siehe
[02 — Konzepte](02-concepts.md#demo-daten).

### Drain (Headless)

Skript [`.claude/scripts/drain.sh`](../../.claude/scripts/drain.sh), das
das Backlog so lange abarbeitet, bis es leer ist. Wird vom LaunchAgent
periodisch gerufen.

### Dropship

Versandart eines Deals: Ware geht direkt vom Shop zum Buyer, Reseller
ist nur Vermittler. Gegenstück: [Reship](#reship).

## E

### Edge Function

Serverless-Function, die auf Supabase-Infrastruktur in Deno läuft. Liegen
in [`supabase/functions/`](../../supabase/functions/). Sechs Stück:
`inbox-poll`, `inbox-parse`, `tracking-poll`, `send-notifications`,
`seed-demo-workspace`, `delete-account`. Siehe
[07 — Edge Functions](07-edge-functions.md).

## F

### FCM (Firebase Cloud Messaging)

Push-Notification-Service von Google. Service-Account-JSON liegt als
Supabase-Secret `FCM_SERVICE_ACCOUNT_JSON`. Wird von
[`send-notifications`](07-edge-functions.md#send-notifications) genutzt.

### Forensik (HTML-Forensik)

Verfahren, das aus dem HTML-Body einer Mail Tracking-IDs, ETA, Items,
Versandadresse extrahiert — wo Plaintext nicht reicht. Tests in
[`inbox_forensics_test.ts`](../../supabase/functions/_shared/inbox_forensics_test.ts).
Siehe [04 — Inbox-Pipeline](04-inbox-mail-pipeline.md#html-forensik).

## H

### Heartbeat-Daemon

LaunchAgent `com.inventory.heartbeat`
([`heartbeat.sh`](../../.claude/scripts/heartbeat.sh)) — pulsed alle
10 min an ntfy, aber **nur**, wenn ein Worker läuft, Items wartend
sind, Recent Failures vorhanden oder ein PANIC-Marker präsent ist
(Activity-Detection). Singleton-Lock via Python `fcntl.flock`. Siehe
[05 — Architektur](05-architecture.md#heartbeat-daemon-prs-70-71).

### Handle (Public-Profile)

Ein URL-fähiger Slug pro Workspace, über den unter `https://app/u/<handle>`
ein öffentliches Profil ohne Login angezeigt wird. Tabelle `public_profile`.
Siehe [02 — Konzepte](02-concepts.md#public-profile).

### Headless-Runner

macOS-LaunchAgent, der periodisch
[`.claude/scripts/headless-runner.sh`](../../.claude/scripts/headless-runner.sh)
ruft und ein [Backlog-Item](#backlog-headless-loop) abarbeitet. Siehe
[CLAUDE.md](../../CLAUDE.md).

## I

### IMAP

Mail-Protokoll, über das die App Postfächer abfragt. Implementiert via
`ImapFlow` in
[`inbox-poll/index.ts`](../../supabase/functions/inbox-poll/index.ts).
Passwörter liegen verschlüsselt in `mailbox_credentials`.

### Inbox

Tab in der App, der geparste Mails der angebundenen [IMAP](#imap)-Konten
zeigt. Drei Sub-Tabs: Eingang, Vorschläge, Postfächer. Siehe
[03 — Screens](03-screens-walkthrough.md#inbox).

### Inventory

Lagerbestand. Tabelle `inventory_items` + `inventory_movements` +
`inventory_batches`. Siehe [02 — Konzepte](02-concepts.md#inventory).

## L

### Live-Status (Deal)

Drei Spalten auf `deals` (`live_status`, `live_status_last_event`,
`live_status_updated_at`, Migration `20260515000000_deals_live_status.sql`).
Speichern den jüngsten Carrier-API-Status pro Deal. Der
`live_status_updated_at`-Timestamp dient zusätzlich als implizites
30s-Cooldown-Feld für den Single-Deal-Re-Track-Pfad. Siehe
[07 — Edge Functions](07-edge-functions.md#tracking-poll) und
[06 — Datenbank](06-database.md#deals).

### Lokalisierung (l10n)

Übersetzungen via `flutter_localizations` + ARB-Files in
[`lib/l10n/`](../../lib/l10n/). Aktuell `de` + `en`. Generiert per
`flutter gen-l10n`. Siehe [05 — Architektur](05-architecture.md#localization).

## M

### Mailbox-Account

Ein angebundenes IMAP-Konto, Tabelle `mailbox_accounts`. Pro Konto wird
das Passwort separat in `mailbox_credentials` verschlüsselt abgelegt.
Siehe [06 — Datenbank](06-database.md#mailbox_accounts--mailbox_credentials).

### Migration

SQL-File in
[`supabase/migrations/`](../../supabase/migrations/) mit dem Schema
`YYYYMMDDHHMMSS_<slug>.sql`. Wird per `supabase db push` deployed. Siehe
[06 — Datenbank](06-database.md#migrations-konventionen).

### MultiProvider

Top-Level-Widget aus dem `provider`-Paket, das alle Provider/Services in
einem Tree bereitstellt. Konfiguriert in
[`main.dart`](../../lib/main.dart). Siehe
[05 — Architektur](05-architecture.md#provider-di-tree).

## O

### Onboarding

Erstmaliger Stepper nach Sign-Up. Stellt sicher, dass `workspaces.onboarded_at`
gesetzt wird. Siehe [02 — Konzepte](02-concepts.md#onboarding) bzw.
[03 — Screens](03-screens-walkthrough.md#onboarding).

## P

### parsed_messages

Tabelle, in die [inbox-poll](#inbox-poll) eine Mail nach erfolgreichem
Adapter-Match speichert. Status-Lifecycle:
`pending → matched/suggested/unclassified/failed/dismissed`. Siehe
[06 — Datenbank](06-database.md#parsed_messages).

### pg_cron

Postgres-Erweiterung für zeitgesteuerte SQL-Jobs. In dieser App genutzt
für `inbox-poll`, `tracking-poll`, `cleanup_inbox_history` und
`send-notifications`. Aktiviert via
[`20260503001100_enable_cron.sql`](../../supabase/migrations/20260503001100_enable_cron.sql).

### Plan

Subscription-Level (`Free`, `Starter`, `Pro`, `Ultimate`). In
[`pricing_plan.dart`](../../lib/models/pricing_plan.dart) modelliert. Steuert
`mailboxLimit`, `inboxVisibilityDays`, `hasInbox`. Siehe
[02 — Konzepte](02-concepts.md#plan--billing).

### Provider

Zwei Bedeutungen — bitte trennen:

1. **`provider`-Paket**: Flutter-State-Management-Library. Quelle der
   Wahrheit für allen App-Zustand.
2. **`Provider<T>`-Widget** aus dem Paket: stellt einen Service unter
   einem Type bereit (`ctx.read<T>()`).

In dieser App lebt jede stateful Provider-Klasse in
[`lib/providers/`](../../lib/providers/), jeder Service in
[`lib/services/`](../../lib/services/).

## R

### REJECT_PATTERNS

Negativ-Liste in
[`inbox_adapters.ts`](../../supabase/functions/_shared/inbox_adapters.ts),
die explizit bekannte Falsch-Positive (Amazon-Order-IDs wie
`123-1234567-1234567`, IBAN-Prefixe, Telefonnummern, PLZ) aus
Tracking-Candidates aussortiert. Läuft NUR gegen den bereits-
gematchten 3–30-Zeichen-Token (ReDoS-Mitigation). Reject-Hits werden
in `parsed_payload.tracking_candidates[].validation.rejectedBy`
geloggt, nicht silent verworfen. Siehe
[04 — Inbox-Pipeline](04-inbox-mail-pipeline.md#strict-tracking-extraction-confidence-modell).

### Reship

Versandart eines Deals: Ware kommt erst zum Reseller, der sie dann an den
Buyer weiterversendet. Gegenstück: [Dropship](#dropship).

### RLS (Row Level Security)

Postgres-Feature, das pro Row über `auth.uid()` und Policies entscheidet,
ob ein User lesen/schreiben darf. Diese App nutzt RLS überall — siehe
[06 — Datenbank](06-database.md#workspace-modell--rls-helper).

### Runner (Headless)

Synonym für [Headless-Runner](#headless-runner).

## S

### Service

Stateless-Klasse in [`lib/services/`](../../lib/services/), die mit
Supabase oder Edge-Functions spricht. Beispiel: `SupabaseRepository`. Pro
Domain genau eine Service-Klasse. Siehe
[05 — Architektur](05-architecture.md#service-schicht).

### Service-Role

Supabase-Role mit voller Schreibrechten, ignoriert RLS. Wird **nur** in
Edge-Functions benutzt; nie in der Flutter-App. Schlüssel:
`SUPABASE_SERVICE_ROLE_KEY` (Secret).

### Soft-Delete

Pattern: `deleted_at`-Spalte statt `DELETE`. App-Default-Filter nimmt nur
Rows mit `deleted_at IS NULL`. Erlaubt Wiederherstellen. Siehe
[06 — Datenbank](06-database.md#soft-delete).

### Strict-Tracking

Pipeline-Modus seit Plan
[`2026-05-13_strict_tracking_extraction.md`](../../plans/2026-05-13_strict_tracking_extraction.md):
eine Tracking-Nummer landet in den Persistenz-Feldern nur, wenn sie aus
einer Carrier-URL **oder** einem Anchor-gebundenen Strong-Pattern
stammt, die strukturelle Validierung (Länge + Charset + Checksum, soweit
möglich) besteht und Confidence `strong` erreicht. Sonst: `tracking =
NULL`, `tracking_confidence = 'none'`, `tracking_needs_review = TRUE`.
Siehe [04 — Inbox-Pipeline](04-inbox-mail-pipeline.md#strict-tracking-extraction-confidence-modell).

### Supplier

Großhändler / Lieferant. Tabelle `suppliers`. Siehe
[02 — Konzepte](02-concepts.md#supplier).

## T

### Ticket

Verkaufs-Ticket auf einer externen Plattform (Discord-Channel, Forum-
Thread). Mehrere [Deals](#deal) können demselben Ticket zugeordnet sein.
Tabelle `tickets`. Siehe [02 — Konzepte](02-concepts.md#ticket).

### tracking_confidence

Spalte auf `deals`, `pending_deal_suggestions` und `parsed_messages`
(via JSONB-Spiegel). Wertebereich: `'strong' | 'manual' | 'none'` auf
`deals`, `'strong' | 'none'` auf `pending_deal_suggestions`,
`'strong' | 'medium' | 'weak' | 'none'` auf `parsed_messages`
(Forensik). `CHECK`-Constraints enforce die Wertebereiche pro
Tabelle. Dart-Enum-Pendant in
[`lib/models/tracking_confidence.dart`](../../lib/models/tracking_confidence.dart).
Siehe [04 — Inbox-Pipeline](04-inbox-mail-pipeline.md#strict-tracking-extraction-confidence-modell)
und [06 — Datenbank](06-database.md#deals).

### tracking_needs_review

Boolean auf `deals` und `parsed_messages`. `TRUE` markiert Rows, deren
Tracking aus einer älteren (schwächeren) Detection stammt und vom User
geprüft werden sollte. Partial-Index `deals_needs_tracking_review_idx`
trägt den Deals-Filter „Prüfen ({count})". Wird vom Re-Parse-Mode
`reparse_low_confidence` und vom `tracking-poll`-Skip ausgewertet.
Siehe [04 — Inbox-Pipeline](04-inbox-mail-pipeline.md#strict-tracking-extraction-confidence-modell).

### TrackingCandidate

TypeScript-Interface in
[`inbox_adapters.ts`](../../supabase/functions/_shared/inbox_adapters.ts):
ein einzelner Tracking-Kandidat mit `value`, `carrier`,
`confidence` (`strong | medium | weak`), `source` (z. B.
`strong-pattern`, `html-carrier-url`, `amazon-shipment-id`),
optionalem `anchorMatched` und einer `validation`-Substruktur
(`lengthOk`, `checksumOk?`, `rejectedBy?`). `findAllTrackings()` gibt
ein sortiertes Array; nur der erste `strong`-Eintrag landet in den
Persistenz-Feldern, der Rest bleibt in
`parsed_payload.tracking_candidates[]` (max 10 Einträge) als Forensik.

### Tracking-Poll

Edge-Function `tracking-poll`, die alle 4h offene Deals beim
[Carrier](#carrier) abfragt und bei `delivered` den Deal auf
"Angekommen" setzt. Zusätzlich Single-Deal-Mode via `body.deal_id` +
User-JWT für den Refresh-Button im UI (30s-Cooldown via
[Live-Status](#live-status-deal)). Siehe
[07 — Edge Functions](07-edge-functions.md#tracking-poll).

## V

### Vault (Supabase Vault)

Verschlüsseltes Secret-Storage in Postgres, abrufbar als
`vault.decrypted_secrets`. Master-Keys (z.B. `mailbox_master_key`) liegen
hier. Pre-Launch-Setup: Secret im Studio anlegen.

## W

### Web-Renderer

Build-Variante für Flutter-Web (`canvaskit` oder `html`). Default
`canvaskit`. Wenn die App auf alten Browsern läuft, evtl. `--web-renderer
html` testen.

### Workspace

Mandanten-Klammer um alle Daten. Pro User mind. ein Personal-Workspace
(Auto-Trigger). Mehrbenutzer-fähig mit Rollen owner/admin/member/viewer.
Siehe [02 — Konzepte](02-concepts.md#workspace).

### Workspace-ID

UUID, die als Foreign-Key auf `workspaces.id` zeigt. Pflichtspalte in
allen Workspace-gescoped Tabellen. RLS prüft mit
`is_workspace_member(workspace_id, auth.uid())`.

## Z

### Ziel-Bestände (Min-Stock)

`inventory_items.min_stock`-Wert, ab dem das Dashboard eine
Mengen-Warnung wirft. Siehe [03 — Screens](03-screens-walkthrough.md#dashboard).

## Mehr Lektüre

- [README](README.md) — Inhaltsverzeichnis des Handbuchs.
- [STRATEGY.md](../STRATEGY.md) — Roadmap & Geschäftsmodell.
- [SUPABASE_SETUP.md](../../SUPABASE_SETUP.md) — Cloud-Erstkonfiguration.
- [CLAUDE.md](../../CLAUDE.md) — Verbindliche Regeln für Subagenten.

## Quelle im Code

- [`lib/`](../../lib/) — Flutter-App
- [`supabase/`](../../supabase/) — Migrations & Edge Functions
- [Handbuch-Index](README.md) — alle Kapitel
- [01 — Getting Started](01-getting-started.md), [02 — Konzepte](02-concepts.md), [03 — Screens](03-screens-walkthrough.md), [04 — Inbox-Pipeline](04-inbox-mail-pipeline.md), [05 — Architektur](05-architecture.md), [06 — Datenbank](06-database.md), [07 — Edge Functions](07-edge-functions.md), [08 — Deployment](08-deployment.md), [09 — Troubleshooting](09-troubleshooting.md)
