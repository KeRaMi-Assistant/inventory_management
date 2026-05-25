# 10 — Glossar

Kompakte Definitionen aller Fachbegriffe, die im Rest des Handbuchs
verwendet werden. Jeder Eintrag verlinkt auf das Kapitel, in dem der
Begriff im Kontext erklärt ist.

> Die Einträge sind alphabetisch geordnet (deutsche Begriffe zuerst,
> englische in den Klammern). Bei Synonymen ist der Hauptbegriff fett, das
> Synonym kursiv.

## A

### AppElevation

Klasse in [`lib/app_theme.dart`](../../lib/app_theme.dart) mit `const`-Elevation-Konstanten:
`card = 1`, `dialog = 8`, `fab = 6`. Ergänzt `AppSpacing` und `AppRadius`
als semantische Alternative zu Magic-Number-Schatten. Neue Widgets sollen
diese Werte bevorzugen. Siehe
[05 — Architektur](05-architecture.md#visual-tokens-appspacing--appradius--appelevation-pr-109).

### AppFeedback

Abstrakter Helper (`abstract class AppFeedback`) in
[`lib/widgets/app_feedback.dart`](../../lib/widgets/app_feedback.dart)
für konsistente SnackBars (success / error / info) mit optionalem
Undo-Action-Slot. Kennt zwei Aufruf-Varianten: Context-Variante
(`AppFeedback.success(context, …)`) und ScaffoldMessengerState-Variante
(`AppFeedback.successOn(messenger, …, rootContext: context)`) für das
Dialog-Context-Pattern. Bottom-Margin auf Phone: über Bottom-Nav
(80 dp + SafeArea + 8 dp). Siehe
[05 — Architektur](05-architecture.md#appfeedback).

### AppNavRail

Widget in [`lib/widgets/app_nav_rail.dart`](../../lib/widgets/app_nav_rail.dart),
das die Desktop-Sidebar in `MainScreen` implementiert. Basiert auf
Flutter's `NavigationRail` (Material 3) mit Branding-Header, Plan-Gating
über `visibility`-Map und `MainTab`-basiertem Callback (kein int-Index).
Ersetzt das frühere Custom-`_Sidebar`-Widget (PR #109). A11y-Keys:
`Key('mainNavRail')`, `Key('navRailDestination-<tab.name>')`. Siehe
[05 — Architektur](05-architecture.md#appnavrail).

### AppRadius

Klasse in [`lib/app_theme.dart`](../../lib/app_theme.dart) mit `const`-Border-Radius-Konstanten:
`sm = 6` (Chips), `md = 8` (Cards), `lg = 12` (Dialoge/FAB), `xl = 16`,
`pill = 999` (Badges). Semantische Aliasnamen für `AppTheme.radius*`. Neue
Widgets sollen diese Werte bevorzugen statt Magic-Number-Werten. Verwandte
Tokens: [AppSpacing](#appspacing), [AppElevation](#appelevation). Siehe
[05 — Architektur](05-architecture.md#visual-tokens-appspacing--appradius--appelevation-pr-109).

### AppSpacing

Klasse in [`lib/app_theme.dart`](../../lib/app_theme.dart) mit `const`-Spacing-Konstanten
auf 4-px-Basis (Material-3-aligned): `xs=4`, `sm=8`, `md=12`, `lg=16`,
`xl=24`, `xxl=32`, `xxxl=48`. Semantische Aliasnamen für `AppTheme.space*`.
Neue Widgets sollen `AppSpacing.*` bevorzugen statt hardcodierten Abstands-
zahlen. Verwandte Tokens: [AppRadius](#appradius), [AppElevation](#appelevation).
Siehe [05 — Architektur](05-architecture.md#visual-tokens-appspacing--appradius--appelevation-pr-109).

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

### Artikelstamm (Produkt)

Wiederverwendbarer Stammsatz für ein Produkt — einmal angelegt, beliebig
oft als Bestand referenziert. Tabelle `products` (Epic A-full). Im
Gegensatz dazu ist `inventory_items` eine konkrete physische Bestandsrow,
die optional über `product_id` auf den Stammsatz verweist. Siehe
[06 — Datenbank](06-database.md#products) und
[02 — Konzepte](02-concepts.md).

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

### Bestandsbewertung

Monetäre Bewertung des Lagerbestands auf Basis von Einstandspreisen.
Grundlage: `inventory_movements.unit_cost` (nullable, seit Migration
`20260521214855`). Eine vollständige FIFO-/Gleitender-Durchschnitt-
Bewertung ist für P2 geplant. Siehe
[06 — Datenbank](06-database.md#inventory_movements-erweiterung).

### Buchungsart (movement_type)

Getypter Enum-Wert auf `inventory_movements.movement_type` (seit Epic
A-lite). Erlaubte Werte: `goods_in` (Wareneingang), `goods_out`
(Warenausgang), `correction` (Korrektur), `stocktake` (Inventur),
`transfer` (Umlagerung), `sale` (Verkauf). Ersetzt den auswertbaren
Freitext-`reason`. Dart-seitig: Feld `movementType` in `InventoryMovement`.
Siehe [06 — Datenbank](06-database.md#inventory_movements-erweiterung).

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

### Cold-Start-Skeleton-Race

Zustand, in dem ein Provider noch keinen einzigen `loadData()`/`refresh()`-
Aufruf abgeschlossen hat (`initialLoadAttempted == false`), die UI aber
bereits einen Build-Zyklus durchläuft. Ohne Gegenmaßnahme würde ein leeres
EmptyState-Widget gezeigt, obwohl die Daten noch unterwegs sind. Gelöst
durch den `shouldShowSkeleton`-Predicate in
[`lib/widgets/skeletons/list_skeleton.dart`](../../lib/widgets/skeletons/list_skeleton.dart):
Skeleton erscheint bei `!initialLoadAttempted && !hasData`. Betrifft
`InventoryProvider` und `InboxProvider` (PR #109). Verwandte Begriffe:
[ListSkeleton](#listskeleton), [shouldShowSkeleton-Predicate](#shouldshowskeleton-predicate).
Siehe [05 — Architektur](05-architecture.md#listSkeleton--shouldshowskeleton).

### ConfirmDialog

Responsive Bestätigungs-Dialog-Funktion `showConfirmDialog` in
[`lib/widgets/confirm_dialog.dart`](../../lib/widgets/confirm_dialog.dart).
Phone (Viewport < `Breakpoints.phone`): `showModalBottomSheet` (Keyboard-safe).
Desktop: `AlertDialog`. Unterstützt `isDestructive` (danger-Styling +
Haptics) und `requireTypeName` (Confirm gesperrt bis exakter String getippt;
Unicode-Bidi-Sanitize). Ablöst Inline-`AlertDialog`-Wildwuchs aus 28 Files.
Verwandte Begriffe: [UnsavedChangesGuard](#unsavedchangesguard),
[AppFeedback](#appfeedback). Siehe
[05 — Architektur](05-architecture.md#confirmdialog--showconfirmdialog).

### Cron-Secret

`CRON_SECRET`-Env-Variable, gemeinsamer Bearer-Token zwischen pg_cron und
den Edge-Functions. Wird mit `supabase secrets set` gesetzt.

## D

### Deal

Kern-Entity der App. Bestellung beim Shop, die an einen Buyer
weiterverkauft (oder direkt geliefert) wird. Tabelle `deals`. Siehe
[02 — Konzepte](02-concepts.md#deal).

### Delayed-Commit-Pattern

Optimistic-UX-Muster für destruktive Aktionen (Löschen, Verwerfen): Die
UI blendet das Element sofort aus (optimistisch), der tatsächliche DB-Call
wird erst nach einem Timer-Ablauf (Default 4 Sekunden) ausgeführt. Der User
kann innerhalb dieser Frist „Rückgängig" tippen — dann wird der Timer
gecancelt, kein DB-Call. Implementiert in `InventoryProvider.deleteDealWithUndo`
(`_pendingDeleteIds` + `_pendingDeleteTimers`) und
`InboxProvider.rejectSuggestionWithUndo` (`_pendingRejectIds` +
`_pendingRejectTimers`). `AppFeedback.success(context, msg, onUndo: …)`
liefert den SnackBar-Undo-Slot. Siehe
[05 — Architektur](05-architecture.md#delayed-commit-pattern--undo-delete-pr-109).

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

### Einkaufsbestellung (Purchase Order)

Bestellung bei einem Lieferanten. Tabelle `purchase_orders` (Epic C).
Status-Automat: `draft → ordered → partially_received → received →
cancelled`. Positionen in `purchase_order_items`; Wareneingang via
atomarer RPC `increment_po_item_received`. Siehe
[06 — Datenbank](06-database.md#purchase_orders) und
[03 — Screens](03-screens-walkthrough.md#bestellungen).

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

## G

### Gebinde-/Lagereinheit (Lagerumschlag)

Kennzahl: `Jahresverbrauch / Durchschnittsbestand`. Je höher, desto
kürzer liegt Ware im Lager. Relevant für ABC-Analyse und Reporting.
> TODO: Notiz ergänzen — Lagerumschlag-Reporting ist für P2 geplant
> (Plan-Lücke L12).

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

### Inventur (Stocktake)

Geführter Zähl-Workflow zum Abgleich von Soll- und Ist-Bestand.
Session-Kopf in `stocktakes` (Status: `open → counting → closed /
cancelled`), Positionen in `stocktake_items`. Beim Schließen erzeugt
die App pro Differenz eine `inventory_movements`-Row mit
`movement_type='stocktake'`. Siehe
[06 — Datenbank](06-database.md#stocktakes) und
[03 — Screens](03-screens-walkthrough.md#inventur-liste).

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

## K

### Kategorie (Warengruppe)

Hierarchische Klassifikation von Artikeln. Tabelle `product_categories`
mit self-referenzieller `parent_id` (max. 2 Ebenen). Jeder Artikel
(`products`) kann einer Kategorie zugeordnet sein. Verwaltung im
[`CategoriesScreen`](03-screens-walkthrough.md#warengruppen). Siehe
[06 — Datenbank](06-database.md#product_categories).

## L

### Lager (Warehouse)

Strukturierter Lagerort. Tabelle `warehouses` (Epic D). Ein Default-Lager
pro Workspace (Partial-UNIQUE). `inventory_items.warehouse_id` verknüpft
Items mit einem Lager. Der aggregierte Bestand pro Lager ist über die
`product_stock`-View (`qty_in_warehouse`) abrufbar. Verwaltung im
[`WarehousesScreen`](03-screens-walkthrough.md#lager). Siehe
[06 — Datenbank](06-database.md#warehouses).

### ListSkeleton

Widget in [`lib/widgets/skeletons/list_skeleton.dart`](../../lib/widgets/skeletons/list_skeleton.dart).
Zentrales Skeleton-Loading-Widget (basiert auf `skeletonizer`-Paket).
Rendert `itemCount` (Default 6, immer fest — nie aus echten Datenlängen
ableiten) Platzhalter-Cards in `Skeletonizer.zone`. A11y-Key:
`Key('skeletonLoader')`. Typisch kombiniert mit `AnimatedSwitcher` (200 ms)
und `shouldShowSkeleton`-Predicate. Verwandte Begriffe:
[Cold-Start-Skeleton-Race](#cold-start-skeleton-race),
[shouldShowSkeleton-Predicate](#shouldshowskeleton-predicate). Siehe
[05 — Architektur](05-architecture.md#listskeleton--shouldshowskeleton).

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

### product_stock (View)

Postgres-View, die den aggregierten Lagerbestand pro
`(workspace_id, product_id, warehouse_id)` aus `inventory_items`
berechnet. `security_invoker = true` → erbt RLS des aufrufenden Users.
Einzige offizielle Bestands-Wahrheit für Low-Stock-Alerts und
Produkt-Detail-Aggregation. Rows ohne `product_id` sind bewusst
ausgeschlossen. Siehe
[06 — Datenbank](06-database.md#product_stock-view).

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

### sanitizeError()

Hilfsfunktion in [`lib/utils/error_messages.dart`](../../lib/utils/error_messages.dart).
Wandelt rohe Exception-Objekte in User-freundliche, lokalisierte Strings um.
Prüft der Reihe nach: `PostgrestException` (nur `message`-Field, nie
Stack-Trace), `SocketException` (Offline), `TimeoutException`,
`AuthException` (Anmeldung abgelaufen), `FormatException`, Fallback.
Nimmt optionales `AppLocalizations? l10n` — ohne `l10n` greift ein
Deutsch-Fallback-String (für Provider-Layer ohne `BuildContext`). Verwendung:

```dart
} catch (e) {
  AppFeedback.error(context, sanitizeError(e, l10n: l10n));
}
```

Verhindert, dass Postgres-Stack-Traces oder interne Supabase-Codes an den
User durchdringen. Siehe
[05 — Architektur](05-architecture.md#modal-layer-widgets-pr-109).

### Service-Role

Supabase-Role mit voller Schreibrechten, ignoriert RLS. Wird **nur** in
Edge-Functions benutzt; nie in der Flutter-App. Schlüssel:
`SUPABASE_SERVICE_ROLE_KEY` (Secret).

### shouldShowSkeleton-Predicate

Pure Funktion in [`lib/widgets/skeletons/list_skeleton.dart`](../../lib/widgets/skeletons/list_skeleton.dart):
`shouldShowSkeleton({bool isLoading, bool hasData, bool initialLoadAttempted})`.
Gibt `true` zurück, wenn ein Skeleton-Loader angezeigt werden soll —
und zwar Race-Condition-safe: Bei `!initialLoadAttempted && !hasData`
(Cold-Start) sowie bei `isLoading && !hasData`. Bei Refresh mit
vorhandenen Daten (`hasData == true`) gibt die Funktion stets `false`
zurück (kein Layout-Jank beim Neu-Laden). Verwandte Begriffe:
[Cold-Start-Skeleton-Race](#cold-start-skeleton-race),
[ListSkeleton](#listskeleton). Siehe
[05 — Architektur](05-architecture.md#listskeleton--shouldshowskeleton).

### Soft-Delete

Pattern: `deleted_at`-Spalte statt `DELETE`. App-Default-Filter nimmt nur
Rows mit `deleted_at IS NULL`. Erlaubt Wiederherstellen. Siehe
[06 — Datenbank](06-database.md#soft-delete).

### Supplier (erweitert)

Seit Epic B hat `suppliers` 9 neue Kreditoren-Felder (Adresse, USt-IdNr,
Kundennummer, Zahlungsziel, Lieferzeit, Mindestbestellwert). Zuordnung zu
Produkten über `product_suppliers` (n:m). `is_preferred`-Flag markiert
den bevorzugten Lieferanten pro Artikel. Siehe
[06 — Datenbank](06-database.md#suppliers-erweiterung).

### Stammkatalog

Synonym für [Artikelstamm](#artikelstamm-produkt). Die Tabelle `products`
ist der Stammkatalog — alle physischen Bestands-Rows in `inventory_items`
können per `product_id` darauf verweisen.

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

### UnsavedChangesGuard

`PopScope`-Wrapper-Widget in
[`lib/widgets/unsaved_changes_guard.dart`](../../lib/widgets/unsaved_changes_guard.dart).
Bei `isDirty: true` wird Back-Button / `Navigator.pop` abgefangen und
ein Discard-Confirm (destruktiv, via `showConfirmDialog`) gezeigt. Muss
**innerhalb** des Dialog-Trees liegen (nicht um den `showDialog`-Call),
damit `PopScope` auf die Dialog-Route wirkt. Optionaler
`onDiscardConfirmed`-Callback für Form-State-Reset nach Discard. Verwandte
Begriffe: [ConfirmDialog](#confirmdialog). Siehe
[05 — Architektur](05-architecture.md#unsavedchangesguard).

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

### Wareneingang

Buchungsvorgang, bei dem Ware physisch im Lager eintrifft und als
`inventory_movements`-Row mit `movement_type='goods_in'` verbucht wird.
Bei PO-basiertem Wareneingang wird zusätzlich
`purchase_order_items.quantity_received` per RPC inkrementiert. Siehe
[06 — Datenbank](06-database.md#purchase_order_items) und
[03 — Screens](03-screens-walkthrough.md#bestellungs-detail).

### Warenwirtschaft-Hub

Neuer Top-Level-Tab (Index 10 in `MainScreen`, `MainTab.warehouse`).
Kachel-Übersicht, die alle Warenwirtschafts-Bereiche (Bestellungen, Lager,
Warengruppen, Inventur, Reporting) als Sub-Routen per `Navigator.push`
aufmacht. Datei:
[`lib/screens/warehouse_hub_screen.dart`](../../lib/screens/warehouse_hub_screen.dart).
Siehe [03 — Screens](03-screens-walkthrough.md#warenwirtschaft-hub).

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
