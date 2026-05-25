# 03 — Screens-Walkthrough

Die App rendert eine handvoll Top-Level-Screens. Auf Phone
(`Breakpoints.navRail` = 900px Viewport-Schwelle, seit T1.3b) wird die
Bottom-Navigation angezeigt, auf Desktop eine Sidebar / `NavigationRail`.
Die Reihenfolge wird in
[`lib/screens/main_screen.dart`](../../lib/screens/main_screen.dart) als
Index-Liste definiert — siehe Konstanten `_navIcons`, `_navLabels`,
`_navVisibility`. Das Switch-Statement `_buildBody()` mappt den Index auf
den jeweiligen Screen.

| Index | Screen | Datei |
|---|---|---|
| 0 | [Dashboard](#dashboard) | `dashboard_screen.dart` |
| 1 | [Deals](#deals) | `deals_screen.dart` |
| 2 | [Tickets](#tickets) | `tickets_screen.dart` |
| 3 | [Inbox](#inbox) (plan-abhängig) | `inbox_screen.dart` |
| 4 | [Inventory](#inventory) | `inventory_screen.dart` |
| 5 | [Suppliers](#suppliers) | `suppliers_screen.dart` |
| 6 | [Statistics](#statistics) | `statistics_screen.dart` |
| 7 | [Activity](#activity) | `activity_screen.dart` |
| 8 | [Help](#help) | `help_screen.dart` |
| 9 | [Settings](#settings) | `settings_screen.dart` |
| 10 | [Warenwirtschaft-Hub](#warenwirtschaft-hub) | `warehouse_hub_screen.dart` |

Sub-Screens der Warenwirtschaft (kein eigener MainTab, per
`Navigator.push` auf Phone erreichbar — auf Desktop als eingebettete
Detail-Spalte im Hub-Master-Detail, siehe [Warenwirtschaft-Hub](#warenwirtschaft-hub)):

| Sub-Screen | Datei | Erreichbar via | Embedded-fähig (seit T3.x) |
|---|---|---|---|
| [Produktdetail](#produktdetail) | `product_detail_screen.dart` | Inventory → Item-Tap | Ja — `ProductDetailScreen(embedded: true)` (seit T3.3a) |
| [Warengruppen](#warengruppen) | `categories_screen.dart` | Warenwirtschaft-Hub | Ja — `CategoriesScreen(embedded: true)` (seit T3.4) |
| [Bestellungen](#bestellungen) | `purchase_orders_screen.dart` | Warenwirtschaft-Hub | Ja — `PurchaseOrdersScreen(embedded: true)` (seit T3.4) |
| [Bestellungs-Detail](#bestellungs-detail) | `purchase_order_detail_screen.dart` | Bestellungen → Tap | Nein |
| [Lager](#lager) | `warehouses_screen.dart` | Warenwirtschaft-Hub | Ja — `WarehousesScreen(embedded: true)` (seit T3.4) |
| [Inventur-Liste](#inventur-liste) | `stocktake_screen.dart` | Warenwirtschaft-Hub | Ja — `StocktakeScreen(embedded: true)` (seit T3.4) |
| [Inventur-Detail](#inventur-detail) | `stocktake_detail_screen.dart` | Inventur-Liste → Tap | Nein |

> **`embedded: bool`-Parameter-Pattern:** Screens mit `embedded: true`
> rendern ohne eigenes `Scaffold` und ohne `AppBar`. Sie werden als reine
> Content-Widgets in die Detail-Spalte des Hub-Master-Detail-Layouts
> eingebettet. Das Pattern folgt dem bestehenden `SettingsScreen(embedded: true)`
> (vgl. `help_screen.dart`). Wenn `embedded: false` (Default), verhält sich
> der Screen wie gehabt (eigener `Scaffold`, eigene `AppBar`, Push-Navigation).

Auth-/System-Screens (Login, Register, Forgot, Reset, Splash, Onboarding,
Pricing, BillingProfile, PublicProfile) werden separat über den
`AuthGate`-Mechanismus erreicht; sie sind weiter unten dokumentiert.

> Begriffe wie *Provider*, *Consumer*, *RLS* sind im
> [Glossar](10-glossary.md) definiert.

## Login

Datei: [`lib/screens/auth/login_screen.dart`](../../lib/screens/auth/login_screen.dart)

Zwei Modi:

- **Personal** — Email + Passwort. Ergebnis: User wird in seinen Personal-
  Workspace eingeloggt.
- **Team** — Zusätzlich ein Workspace-ID-Feld. Vor dem Auth-Call ruft die
  App `ActiveWorkspaceProvider.presetActiveId(...)` auf, damit der
  Hydrator nach erfolgreichem Login direkt im richtigen Workspace landet
  und nicht erst in den Personal-Workspace springt.

Zusatz-Buttons:

- **Google Sign-In** und **Apple Sign-In** (über die jeweiligen Pakete).
- **Passwort vergessen?** → `ForgotPasswordScreen`.
- **Account erstellen?** → `RegisterScreen`.

Form-Validierung läuft über
[`lib/utils/validators.dart`](../../lib/utils/validators.dart). Fehler aus
Supabase werden über
[`lib/utils/auth_error_l10n.dart`](../../lib/utils/auth_error_l10n.dart)
in lokalisierte Strings übersetzt.

## Register / Forgot / Reset / Verify

- `register_screen.dart` — Email + Passwort + Passwortbestätigung.
  `PasswordStrengthIndicator`-Widget zeigt live Stärke.
- `forgot_password_screen.dart` — Schickt einen Recovery-Magic-Link.
- `reset_password_screen.dart` — Wird vom `_RecoveryListener` in
  [`main.dart`](../../lib/main.dart) gepusht, sobald Supabase ein
  `passwordRecovery`-Event meldet (Magic-Link-Klick).
- `verify_email_screen.dart` — Hinweisseite, falls Email-Confirm noch
  ausstehend ist.

## Splash

Datei: [`lib/screens/auth/splash_screen.dart`](../../lib/screens/auth/splash_screen.dart)

Wird vom `_AuthGate` während des `_hydrate()`-Aufrufs angezeigt: Workspaces
laden, Inventory laden, Invites refreshen, Billing laden, Push registrieren.
Ohne Splash würde die UI mit halb-geladenen Daten flackern.

## Onboarding

Datei: [`lib/screens/onboarding_screen.dart`](../../lib/screens/onboarding_screen.dart)

Drei Schritte (siehe
[`OnboardingProvider`](../../lib/providers/onboarding_provider.dart)):

1. **Welcome** — Begrüßung, Workspace-Name bestätigen.
2. **Demo-Daten** — Optionaler Aufruf der Edge-Function
   `seed-demo-workspace`. Nur für `test@test.com`.
3. **Done** — Markiert `onboarded_at` und schaltet zum
   [`MainScreen`](#main).

> **Fortschrittsanzeige (PR #109):** Die Schritt-Navigation (früher
> eine Dot-Row) ist durch einen `_StepProgressBar` ersetzt:
> animierter `LinearProgressIndicator` (via `TweenAnimationBuilder`,
> smooth statt sprunghaft) + Step-Label-Text. Erste Anzeige:
> `1/N`, letzte: `N/N`. Verbessert die Wahrnehmung des Fortschritts
> auf Phone-Viewport erheblich.

> Auf Phone-Viewport sehr wichtig: Die Buttons sind 48dp hoch, das Layout
> nutzt `SafeArea` für Notch + Bottom-Indikator. Wenn das jemals bricht,
> ist der erste Eindruck der App kaputt.

## Main

Datei: [`lib/screens/main_screen.dart`](../../lib/screens/main_screen.dart)

Wrapper-Scaffold mit Sidebar (Desktop) oder Drawer (Phone). Sehr wichtig:

- `_navVisibility(billing)` blendet den Inbox-Tab aus, wenn der Plan kein
  Inbox-Feature hat.
- Wenn der User in den Inbox-Tab geht und dann auf einen Plan **ohne**
  Inbox downgradet, springt der Selected-Index automatisch zurück auf 0
  (Dashboard).
- `CallbackShortcuts` bindet `Cmd/Ctrl+K` an `_openSearch`, was
  [`GlobalSearchDialog`](../../lib/widgets/global_search_dialog.dart) öffnet.
- Floating-Action-Button "Neuer Deal" ist nur auf Index 1 (Deals) und 2
  (Tickets) sichtbar.

**Mehr-Sheet / MoreNavSheet (PR #109):**

Das Phone-Bottom-Sheet hinter dem „Mehr"-Slot (`Key('main-tab-more')`)
wurde erheblich überarbeitet:

- **Quick-Search-TextField** oben im Sheet filtert die angezeigten Tabs
  nach Bezeichnung (Substring, case-insensitive).
- **Section-Header** gruppieren die Tabs thematisch:
  - *Verwaltung* — Lieferanten, Postfach u.a.
  - *Tools* — Statistiken, Aktivitätseintrag.
  - *Account* — Einstellungen, Hilfe.
- Section-Header werden nur gerendert, wenn mindestens ein Tab der
  Gruppe den Suchfilter übersteht.
- **„Suchen"-Eintrag** am Kopf des Sheets — Tap schließt das Sheet und
  öffnet sofort den Global-Search-Dialog (Kontextwechsel ohne Workaround
  für Pop-Reihenfolge).

## Dashboard

Datei: [`lib/screens/dashboard_screen.dart`](../../lib/screens/dashboard_screen.dart)

Zentrale Übersicht. Rendert KPI-Cards
([`lib/widgets/kpi_card.dart`](../../lib/widgets/kpi_card.dart)):

- **Aktive Deals** (Status ≠ "Done")
- **Offener Umsatz** (Σ `vk` über aktive Deals)
- **Lager-Status** (Items im Lager / reserviert / versandt)
- **MHD-Warnungen** (Items mit MHD < N Tagen)

Darunter: Liste der zuletzt angelegten Deals + Summary-Panel
([`summary_panel.dart`](../../lib/widgets/summary_panel.dart)).

## Deals

Datei: [`lib/screens/deals_screen.dart`](../../lib/screens/deals_screen.dart)

Sehr dünn — die eigentliche Liste rendert
[`deal_table.dart`](../../lib/widgets/deal_table.dart) (Desktop) bzw.
[`deal_card.dart`](../../lib/widgets/deal_card.dart) (Phone). Filter laufen
über den
[`FilterProvider`](../../lib/providers/filter_provider.dart):

- Suche (freier Text)
- Status (`Bestellt`, `Unterwegs`, `Angekommen`, `Rechnung gestellt`, `Done`)
- Buyer (nur aktive)
- Shop (nur aktive)
- Datumsbereich
- "Beleg fehlt"-Toggle

Pro Deal mit Strong-Tracking zeigt
[`tracking_status_block.dart`](../../lib/widgets/tracking_status_block.dart)
einen **Re-Track-Button** (Refresh-Icon, 48dp Touch-Target). Tap →
`InventoryProvider.retrackDeal(dealId)` → Edge-Function
`tracking-poll` mit `body.deal_id`. 30s-Cooldown pro Deal (siehe
[07 — Edge Functions](07-edge-functions.md#tracking-poll)). SnackBars
für success / 429 / failed / offline. Cron-Polls (alle 4h) sind davon
unberührt.

Inline-Aktionen (Status ändern, Buyer ändern, Tracking eintragen) gehen
über [`InventoryProvider`](../../lib/providers/inventory_provider.dart) und
landen via
[`SupabaseRepository`](../../lib/services/supabase_repository.dart) im
Backend. Die Provider-Methoden sind **optimistic** — UI rendert sofort, und
ein Fehler vom Backend rollt zurück.

Bulk-Aktionen (mehrere Deals selektieren → Status, Buyer ändern, löschen)
gehen über `updateDealsStatus` / `updateDealsBuyer` / `deleteDeals`.

## Tickets

Datei: [`lib/screens/tickets_screen.dart`](../../lib/screens/tickets_screen.dart)

Gruppiert Deals nach `ticket_number`. Pro Ticket:

- Header mit Ticket-Nr + ggf. Discord-Deep-Link (URL aus Deal).
- Liste der Deals des Tickets, gemeinsam änderbar.
- "Archivieren"-Button (`archiveTicket`) → setzt `archived_at`.
- "Wieder öffnen" (`reopenTicket`) → setzt `archived_at = NULL`.

Die Tabelle rendert auf Phone als Card-Stapel — kein horizontales Scrollen.
Auf Desktop ist es eine kompakte Tabelle mit Inline-Edit.

## Inbox

Datei: [`lib/screens/inbox_screen.dart`](../../lib/screens/inbox_screen.dart)

Das mit Abstand komplexeste Screen (≈1700 LoC). Drei Tabs:

- **Eingang** — geparste Mails, sortiert nach `received_at`. Pro Mail eine
  Card mit Adapter-Badge (`amazon`, `mediamarkt`, `pccomponentes`, `xkom`,
  `saturn`, `unclassified`), Subject, From, extrahierte Felder
  (Order-ID, Tracking, Total).
- **Vorschläge** — `pending_deal_suggestions` mit Status `pending`. Pro
  Vorschlag: "Annehmen" (legt Deal an + verknüpft Mail), "Ablehnen"
  (setzt `resolved_action='rejected'`).
- **Postfächer** — Liste der `mailbox_accounts`, mit Add-/Edit-/Delete-
  Aktion (siehe
  [`add_edit_mailbox_dialog.dart`](../../lib/widgets/add_edit_mailbox_dialog.dart)).

Header-Aktionen:

- **Jetzt pollen** — Direkt-Aufruf der Edge-Function `inbox-poll` mit
  User-JWT. Beschränkt auf Workspaces des aufrufenden Users (siehe
  [04-inbox-mail-pipeline.md](04-inbox-mail-pipeline.md)).
- **Re-Parse** — Edge-Function `inbox-parse` mit
  `{reparse_unclassified: true}`-Body, damit alte unklassifizierte Mails
  gegen die neue Adapter-Registry laufen.
- **Alle als gelesen markieren** — `markAllInboxRead(workspaceId)`.

> Für die [Mail-Pipeline](04-inbox-mail-pipeline.md) ist dieses Kapitel nur
> die UI-Spitze. Die Logik liegt in den Edge-Functions und der
> Adapter-Registry.

## Inventory

Datei: [`lib/screens/inventory_screen.dart`](../../lib/screens/inventory_screen.dart)

Liste aller Items. Pro Card: Name, SKU, Menge, Lagerort, Status. Aktionen:

- **Add/Edit Item** — Form mit Barcode-Scanner-Button
  ([`barcode_scanner_sheet.dart`](../../lib/widgets/barcode_scanner_sheet.dart)).
- **Batches** — Sheet mit allen Chargen (MHD, Liefer-Datum, Lieferant). Siehe
  [`inventory_batches_sheet.dart`](../../lib/widgets/inventory_batches_sheet.dart).
- **Bewegung erfassen** — `+` / `-` schreibt einen `inventory_movement`-Eintrag
  mit typisierter `movement_type`-Spalte (seit Epic A-lite).
- **Artikel-Detail** — Tap auf Item-Card öffnet den
  [`ProductDetailScreen`](#produktdetail). Verhalten ist viewportabhängig
  (siehe Master-Detail-Note unten).

Filter: Status, Lagerort, MHD-Frist, Suchtext.

CSV-Export/Import passiert über
[`csv_service.dart`](../../lib/services/csv_service.dart) und ist im
[`MainScreen._import` / `_export`](#main) verkabelt.

> **Master-Detail-Split (seit T3.3b):** Ab Container-Breite ≥ 1200px
> (gemessen via `LayoutBuilder.constraints.maxWidth`, **nicht** via
> `MediaQuery`) zeigt der Screen ein zweigeteiltes Layout: Master-Liste
> links (380px, scrollbar), Detail-Spalte rechts (`Expanded`) mit
> eingebettetem `ProductDetailScreen(embedded: true)`. Ein Tap auf eine
> Item-Card setzt die Selektion — es wird kein `Navigator.push` ausgelöst.
> Phone-Verhalten (Vollbild-Push) bleibt unverändert. Der Selektions-State
> (`_selectedItemId`) lebt im Owner-Widget oberhalb des `LayoutBuilder`-
> Switches und überlebt einen Resize Phone↔Desktop. A11y-Keys für die
> Detail-Spalte: `Key('detailPane')` (wenn Item gewählt) und
> `Key('detailPaneEmpty')` (Placeholder, wenn kein Item gewählt).

> **Hero-Animation Phone-gated (PR #109):** Das Produkt-Bild/-Icon in der
> Item-Card ist mit einem `Hero`-Tag (`'product-hero-<id>'`) versehen.
> Die Animation greift ausschließlich auf Phone-Viewport (`isPhoneViewport(context) == true`)
> und wenn kein Master-Detail-Modus aktiv ist (`!isMasterDetail`). Auf
> Desktop / im Master-Detail-Layout wird kein Hero gerendert, um den
> Vollbild-Push-Übergang zu verhindern. Smoke-Test-Schlüssel:
> `smoke-hero-no-desktop-regression`.

> **Skeleton-Loader (PR #109):** Beim ersten Laden zeigt der Screen einen
> `ListSkeleton` (via `shouldShowSkeleton`-Helper aus
> [`lib/widgets/skeletons/list_skeleton.dart`](../../lib/widgets/skeletons/list_skeleton.dart)).
> Race-Condition-safe: Skeleton erscheint nur, wenn `initialLoadAttempted == false`
> (Cold-Start) oder `isLoading && !hasData`. Bei Refresh mit bereits
> vorhandenen Daten bleibt die Liste sichtbar — kein Layout-Jank.

## Warenwirtschaft-Hub

Datei:
[`lib/screens/warehouse_hub_screen.dart`](../../lib/screens/warehouse_hub_screen.dart)

Neuer Top-Level-Tab (MainTab-Index 10, Epic A-full AF11).
Kachel-Übersicht der Warenwirtschafts-Bereiche. Das Navigationsverhalten
ist viewportabhängig — siehe Master-Detail-Note unten.

| Kachel | Ziel-Screen | A11y-Key | Embeddable |
|---|---|---|---|
| Artikelstamm | [`ProductCatalogScreen`](#artikelstamm) | `Key('hubTileProductCatalog')` | Ja (seit T3.4) |
| Bestellungen | [`PurchaseOrdersScreen`](#bestellungen) | `Key('hubTilePurchaseOrders')` | Ja (seit T3.4) |
| Lager | [`WarehousesScreen`](#lager) | `Key('hubTileWarehouses')` | Ja (seit T3.4) |
| Warengruppen | [`CategoriesScreen`](#warengruppen) | `Key('hubTileCategories')` | Ja (seit T3.4) |
| Inventur | [`StocktakeScreen`](#inventur-liste) | `Key('hubTileStocktake')` | Ja (seit T3.4) |
| Reporting | bestehender `StatisticsScreen` | `Key('hubTileReporting')` | **Nein** — bleibt Vollbild-Push |

> **Master-Detail-Split auf Desktop (seit T3.4):** Ab Container-Breite
> ≥ 1200px (via `LayoutBuilder.constraints.maxWidth`) wird der Hub zum
> zweispaltigen Layout: Kachel-Übersicht links (Master), gewählter
> Sub-Bereich rechts als eingebetteter Screen (`embedded: true`). Die 5
> embeddable Sub-Screens (`product_catalog`, `purchase_orders`, `warehouses`,
> `categories`, `stocktake`) zeigen sich ohne eigenes `Scaffold`/`AppBar`
> in der Detail-Spalte. Kachel-Tap setzt die Selektion ohne
> `Navigator.push`. A11y-Keys: `Key('detailPane')` (Detail-Root wenn
> Sub-Bereich gewählt), `Key('detailPaneEmpty')` (Placeholder wenn kein
> Sub-Bereich aktiv).
>
> **Ausnahme Reporting-Tile:** Das Reporting-Tile pusht auch auf Desktop
> weiterhin als Vollbild-Screen (inline-`Scaffold` mit eigenem `AppBar` ist
> aktuell nicht embeddable — akzeptierter Trade-off, dokumentierte
> Inkonsistenz aus T3.4).
>
> **Phone-Verhalten unverändert:** Alle Kacheln öffnen per `Navigator.push`
> als Vollbild-Screen.

## Produktdetail

Datei:
[`lib/screens/product_detail_screen.dart`](../../lib/screens/product_detail_screen.dart)

360°-Sicht auf eine bestehende `inventory_items`-Row (Epic A-lite AL5).
Kein eigener Tab. Zeigt:

- Stammdaten (Name, SKU, EAN, Lagerort, Status, Mindestbestand).
- Aktueller Bestand + ggf. Produkt-Link auf den Stammkatalog.
- **Bewegungshistorie** mit Buchungsart-Badges (`movement_type`):
  `goods_in`, `goods_out`, `correction`, `stocktake`, `transfer`, `sale`.
- Chargen-Übersicht.
- Lieferanten-Info.

A11y-Keys: `Key('productDetailScrollView')`, `Key('movementHistoryList')`,
`Key('movementRow-<id>')`.

> **Embedded-Modus (seit T3.3a):** `ProductDetailScreen(embedded: true)`
> rendert ohne eigenes `Scaffold` und ohne `AppBar` — für die Nutzung als
> rechte Detail-Spalte im Inventory-Master-Detail-Layout. Im Default-Modus
> (`embedded: false`) wird der Screen wie bisher per `Navigator.push` als
> Vollbild-Screen geöffnet (Phone-Pfad unverändert).

## Warengruppen

Datei:
[`lib/screens/categories_screen.dart`](../../lib/screens/categories_screen.dart)

CRUD-Liste der Warengruppen (`product_categories`, Epic B / Task B4).
Sub-Route des Warenwirtschaft-Hubs. Unterkategorien werden eingerückt
unter ihrer Elternkategorie angezeigt (max. 2 Ebenen). Aktionen: Neu,
Umbenennen, Löschen (mit Confirm-Dialog). `Viewer`-Rolle sieht kein FAB.

A11y-Keys: `Key('categoryNewFab')`, `Key('categoryRow-<id>')`.

## Bestellungen

Datei:
[`lib/screens/purchase_orders_screen.dart`](../../lib/screens/purchase_orders_screen.dart)

Liste der Einkaufsbestellungen (Epic C / Task C5). Status-Badges
(`draft`, `ordered`, `partially_received`, `received`, `cancelled`).
FAB „Neue Bestellung" (`Key('poNewFab')`), nur wenn `canEdit`. Pro
Bestellung: Lieferant, Bestellnummer, Datum, Gesamt-Netto.

Tap auf eine Bestellung → [`PurchaseOrderDetailScreen`](#bestellungs-detail).

## Bestellungs-Detail

Datei:
[`lib/screens/purchase_order_detail_screen.dart`](../../lib/screens/purchase_order_detail_screen.dart)

Detail-View einer Bestellung (Epic C / Task C6). Zeigt alle Positionen
mit Soll-/Ist-Mengen. **Wareneingang buchen** via Soll/Ist-Stepper
(`Key('poItemReceivedStepper-<id>')`) und Button
`Key('goodsReceiptBookButton')`: ruft die SECURITY-DEFINER-RPC
`increment_po_item_received` auf → DB-Trigger aktualisiert den
PO-Status automatisch auf `partially_received` oder `received`.
PDF-Export via `PurchaseOrderPdfService`
(`Key('poPdfExportButton')`).

A11y-Keys: `Key('poCard-<id>')`, `Key('goodsReceiptBookButton')`,
`Key('poItemReceivedStepper-<id>')`, `Key('poPdfExportButton')`.

## Lager

Datei:
[`lib/screens/warehouses_screen.dart`](../../lib/screens/warehouses_screen.dart)

CRUD-Liste der Lagerorte (`warehouses`, Epic D / Task D3). FAB „Neues
Lager" (`Key('warehouseNewFab')`), nur wenn `canEdit`. Pro Lager:
Name, Adresse, Default-Flag, Status (aktiv/inaktiv). Nur ein Default-
Lager pro Workspace (DB-UNIQUE).

A11y-Keys: `Key('warehouseRow-<id>')`, `Key('warehouseDropdown')`.

## Inventur-Liste

Datei:
[`lib/screens/stocktake_screen.dart`](../../lib/screens/stocktake_screen.dart)

Liste der Inventur-Sessions (`stocktakes`, Epic E / Task E3). FAB
„Neue Inventur" (`Key('stocktakeNewFab')`), nur wenn `canEdit`. Status-
Anzeige pro Session: `open`, `counting`, `closed`, `cancelled`. Tap →
[`StocktakeDetailScreen`](#inventur-detail).

A11y-Keys: `Key('stocktakeRow-<id>')`.

## Inventur-Detail

Datei:
[`lib/screens/stocktake_detail_screen.dart`](../../lib/screens/stocktake_detail_screen.dart)

Vollständiger Inventur-Workflow (Epic E / Task E3):

1. Scrollbare 48dp-Zeilen-Liste der `stocktake_items` (Soll vs. Ist).
2. Filter „nur ungezählte" (`Key('stocktakeFilterUncounted')`).
3. Fortschritts-Header (`{counted}/{total} gezählt`).
4. Barcode-Einsprung für schnelle Mengen-Eingabe.
5. **Abschließen** (`Key('stocktakeCloseButton')`) → Differenz-Report als
   vertikale Cards (Mobile-safe, kein horizontaler Scroll) → Bestand
   wird angepasst → `inventory_movements` mit `movement_type='stocktake'`
   (append-only) werden geschrieben.

A11y-Keys: `Key('stocktakeCountField-<id>')`,
`Key('stocktakeFilterUncounted')`, `Key('stocktakeCloseButton')`.

## Suppliers

Datei: [`lib/screens/suppliers_screen.dart`](../../lib/screens/suppliers_screen.dart)

CRUD-Liste der Lieferanten. Add/Edit über
[`add_edit_supplier_dialog.dart`](../../lib/widgets/add_edit_supplier_dialog.dart).
Inaktive Suppliers werden ausgeblendet, lassen sich aber über einen Toggle
wieder einblenden.

## Statistics

Datei: [`lib/screens/statistics_screen.dart`](../../lib/screens/statistics_screen.dart)

Charts auf Basis von `fl_chart`. Filter über
[`StatisticsFilterProvider`](../../lib/providers/statistics_filter_provider.dart):

- Datumsbereich
- Buyer / Shop
- Gruppierung (Tag / Woche / Monat)

Charts:

- **Umsatz pro Periode** (Linien-Chart)
- **Top-Buyer** (Bar-Chart)
- **Status-Verteilung** (Pie-Chart)

Daten kommen von
[`statistics_service.dart`](../../lib/services/statistics_service.dart).
Export (CSV/PDF) via
[`statistics_export_service.dart`](../../lib/services/statistics_export_service.dart).

## Activity

Datei: [`lib/screens/activity_screen.dart`](../../lib/screens/activity_screen.dart)

Heatmap-artige Liste der letzten 50 Aktivitäten — gefiltert auf den
aktiven Workspace. Tabelle pro Eintrag: Zeitstempel, Typ-Icon, Nachricht.

## Help

Datei: [`lib/screens/help_screen.dart`](../../lib/screens/help_screen.dart)

FAQ + Glossar light + Links zu Support-Channeln. Embedded-Modus, wenn
innerhalb des MainScreen gerendert (sonst voll-Screen mit AppBar).

## Settings

Datei: [`lib/screens/settings_screen.dart`](../../lib/screens/settings_screen.dart)

Sehr großer Screen (≈3400 LoC) mit vielen Sektionen:

- **Profil** — Name, Email, Sprache, Theme.
- **Farbpalette** — User wählt zwischen fünf vorgefertigten Akzent-
  Paletten (`blue`, `indigo`, `violet`, `teal`, `rose`). Persistiert via
  `AppPreferencesProvider.setPalette(...)`. Die Tokens aus
  [`lib/app_theme.dart`](../../lib/app_theme.dart) (`AppTheme.accent`,
  `AppTheme.accentBg` etc.) sind seit PR #68 **runtime-getter**, keine
  `const Color` mehr — d.h. Konsumenten dürfen sie nicht in `const`-
  Kontexten verwenden. Siehe
  [05 — Architektur](05-architecture.md#theme).
- **Workspace** — Name ändern, Mitglieder verwalten, Einladungen senden,
  Workspace löschen (mit harter Bestätigung).
- **Subscription / Plan** — Aktueller Plan, Upgrade-Pfad, Link zum
  [`pricing_screen.dart`](../../lib/screens/pricing_screen.dart).
- **Postfächer** — Add/Edit/Delete für `mailbox_accounts`. Der gleiche
  Dialog wird auch im Inbox-Tab gezeigt.
- **Carrier** — DHL/DPD/UPS-API-Keys. Speichert via Edge-Function-Path,
  damit Klartext nie in der DB landet.
- **Notifications** — Per-User-Preferences (MHD, Delivery, Payment-overdue).
- **Public Profile** — Handle ändern, Sichtbarkeit umschalten.
- **Billing-Profile** — Stammdaten für Rechnungen → eigener Screen
  [`billing_profile_screen.dart`](../../lib/screens/billing_profile_screen.dart).
- **Account löschen** — Aufruf der Edge-Function `delete-account`.

## Pricing

Datei: [`lib/screens/pricing_screen.dart`](../../lib/screens/pricing_screen.dart)

Vergleichstabelle der Pläne. Wird über Settings oder bei Plan-Limit-Hit
geöffnet. CTA-Buttons sind aktuell stumm (Pre-Launch, kein Stripe).

## Billing-Profile

Datei: [`lib/screens/billing_profile_screen.dart`](../../lib/screens/billing_profile_screen.dart)

Form für Rechnungs-Stammdaten: Firma, Adresse, USt-ID, IBAN. Per
Workspace **ein** Billing-Profile (UNIQUE-Constraint auf `workspace_id`).
Wird beim PDF-Export von Statistik referenziert.

## Public Profile

Datei: [`lib/screens/public_profile_screen.dart`](../../lib/screens/public_profile_screen.dart)

Read-only-Sicht ohne Login. Wird via `/u/<handle>`-Route geöffnet. Rendert
Handle, Profil-Beschreibung und (optional) eine kuratierte Liste aktueller
Verkaufs-Highlights. Die Logik in `lib/main.dart#publicProfileHandleFromUri`
parst Hash- und Path-URL-Strategie.

## Mobile-First-Hinweise

Für **jede** UI-Änderung gilt (siehe [CLAUDE.md](../../CLAUDE.md)):

- 360×640 / 390×844 / 768×1024 / 1440×900 müssen funktionieren.
- Touch-Targets ≥ 48dp.
- Bottom-Drawer/Sidebar bei `width < 600`, sonst Sidebar.
- `SafeArea` um Content; `MediaQuery.viewInsetsOf` bei TextFields gegen
  Tastatur-Verdeckung.
- Listen auf Phone als vertikale Cards, nicht als horizontal scrollbare
  Tabellen.

Diese Regeln sind nicht verhandelbar — der Browser-Tester prüft Phone-
Viewport zuerst.

## Quelle im Code

- [`lib/screens/main_screen.dart`](../../lib/screens/main_screen.dart) — Routing zu allen Tabs
- [`lib/screens/dashboard_screen.dart`](../../lib/screens/dashboard_screen.dart) — Dashboard
- [`lib/screens/deals_screen.dart`](../../lib/screens/deals_screen.dart) — Deals + DealTable/DealCard
- [`lib/screens/tickets_screen.dart`](../../lib/screens/tickets_screen.dart) — Tickets
- [`lib/screens/inbox_screen.dart`](../../lib/screens/inbox_screen.dart) — Inbox-UI
- [`lib/screens/inventory_screen.dart`](../../lib/screens/inventory_screen.dart) — Inventory
- [`lib/screens/settings_screen.dart`](../../lib/screens/settings_screen.dart) — Settings (alles workspace- und user-bezogen)
- [`lib/screens/warehouse_hub_screen.dart`](../../lib/screens/warehouse_hub_screen.dart) — Warenwirtschaft-Hub
- [`lib/screens/product_detail_screen.dart`](../../lib/screens/product_detail_screen.dart) — Produkt-Detailansicht
- [`lib/screens/categories_screen.dart`](../../lib/screens/categories_screen.dart) — Warengruppen-Verwaltung
- [`lib/screens/purchase_orders_screen.dart`](../../lib/screens/purchase_orders_screen.dart) — Bestellungen-Liste
- [`lib/screens/purchase_order_detail_screen.dart`](../../lib/screens/purchase_order_detail_screen.dart) — Bestellungs-Detail + Wareneingang
- [`lib/screens/warehouses_screen.dart`](../../lib/screens/warehouses_screen.dart) — Lager-Verwaltung
- [`lib/screens/stocktake_screen.dart`](../../lib/screens/stocktake_screen.dart) — Inventur-Sessionen
- [`lib/screens/stocktake_detail_screen.dart`](../../lib/screens/stocktake_detail_screen.dart) — Inventur-Durchführung
- [`lib/widgets/`](../../lib/widgets/) — Wiederverwendete Form-Dialoge
- [Glossar](10-glossary.md) — Begriffsdefinitionen
