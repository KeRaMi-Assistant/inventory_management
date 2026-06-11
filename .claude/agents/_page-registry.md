# Page Registry — User-sichtbare Routen

Kanonische Liste aller Top-Level-Routes, Auth-Screens und User-sichtbaren
Sub-Routes / Modal-Dialogs / Bottom-Sheets der Flutter-App. Wird vom
[browser-tester](browser-tester.md) als Checkliste genutzt + vom
[doc-updater](doc-updater.md) automatisch gepflegt (siehe Sektion
"Page-Registry-Pflege").

> **Single-Source-of-Truth.** Wenn ein neuer Screen oder Sub-Route
> dazukommt, muss er hier auftauchen — sonst sieht der Browser-Tester
> ihn nicht und Audit-Lücken bleiben unsichtbar.

## Routing-Modell (Kontext)

Die App nutzt **kein** klassisches Named-Routing. Stattdessen:

- `lib/main.dart` mountet `MainScreen` (für eingeloggte User) bzw.
  `LoginScreen` (für ausgeloggte) bzw. `OnboardingScreen` (für noch
  nicht onboardete Workspace-Owner).
- `MainScreen` hält einen `_selectedIndex` mit den 10 Top-Level-
  Bereichen — diese sind weiter unten als Routes `/dashboard`, `/deals`
  usw. modelliert (synthetische URL-Bezeichner für Tester-Zwecke; in
  der App existieren sie nicht als URLs).
- Auth-Screens, `BillingProfileScreen` und `OnboardingScreen` werden
  als Push-Routen über den Root-Navigator angezeigt.
- `PublicProfileScreen` ist die einzige echte URL-Route: Web-only,
  `/u/<handle>`, ohne Login erreichbar.

Pflicht-Tests (Spalte "Pflicht-Tests") sind die Mindest-Smoke-Szenarien,
die der Browser-Tester pro Eintrag durchspielt — Definitionen unten.

## Top-Level-Routes (eingeloggter Bereich)

| Route | File | Pflicht-Tests | Notizen |
|---|---|---|---|
| `/main` (Shell) | [`lib/screens/main_screen.dart`](../../lib/screens/main_screen.dart) | smoke-theme, mobile-overflow, smoke-keyboard-nav, smoke-nav-feature-gating | Side-Nav + AppBar, hält `_selectedIndex` (`MainTab`-Enum, 11 Werte, stabil). **Tier-2b — Sektions-Ebene über dem Enum** ([`lib/screens/main_section.dart`](../../lib/screens/main_section.dart), `MainSection`: dashboard/verkauf/lager/auswertung/konto). `sectionOf(MainTab)`/`defaultTabOf(MainSection)` mappen zwischen den Ebenen. **Desktop-Rail (≥ 900px):** [`lib/widgets/app_nav_rail.dart`](../../lib/widgets/app_nav_rail.dart) (`AppNavRail`) jetzt **sektions-basiert** — genau **5** Destinations (kein `scrollable` mehr, kein `visibility`-Gating der Rail; Inbox-Gating lebt im Verkauf-Segment). `extended: true` bei Viewport-Breite ≥ 1200px, `extended: false` bei 900–1199px. A11y-Keys: `Key('mainNavRail')` auf Rail-Root, `Key('navRailDestination-<section.name>')` pro Destination: `navRailDestination-dashboard`, `navRailDestination-verkauf`, `navRailDestination-lager`, `navRailDestination-auswertung`, `navRailDestination-konto`. Verkauf-Destination trägt aggregierten Tracking-Badge (`mobile-nav-verkauf-badge`). **Bottom-Nav auf Phone (`< 900px`):** `Key('mainBottomNav')` mit **5 festen Sektions-Slots** (KEIN „Mehr"-Slot mehr): `Key('main-tab-dashboard')`, `main-tab-verkauf`, `main-tab-lager`, `main-tab-auswertung`, `main-tab-konto`. Verkauf-Slot trägt den aggregierten Tracking-Badge. Help-Icon AppBar (Phone): `Key('appBar-help-action')` — setzt `MainTab.help` (Konto-Deep-Link). CSV-Import/Export via AppBar-Overflow (`Key('appBar-overflow-menu')`). AppBar-Titel = Sektions-Label; Desktop-Breadcrumb zeigt `App › Sektion [› Sub-Tab]`. Deep-Link-Ziele inventory/suppliers/help (aus global_search / dashboard) bleiben über `_buildBody` erreichbar, ohne eigenen Slot. Tastatur-Shortcuts `Cmd/Ctrl+1..5` → Sektionen. |
| `/dashboard` | [`lib/screens/dashboard_screen.dart`](../../lib/screens/dashboard_screen.dart) | smoke-theme, mobile-overflow | KPI-Cards + Recent-Deals. Skeleton-Loader via `skeletonizer` beim Initial-Load (`Key('skeletonLoader')`); aktiv nur wenn `isLoading=true && data leer` (Race-Condition-safe). |
| `/deals` | [`lib/screens/deals_screen.dart`](../../lib/screens/deals_screen.dart) | smoke-theme, mobile-overflow, deal-flow | Tabelle + Detail-Sidebar (Desktop) bzw. Stack (Phone). |
| `/tickets` | [`lib/screens/tickets_screen.dart`](../../lib/screens/tickets_screen.dart) | smoke-theme, archive-tab | Aktiv-/Archiv-Tabs. |
| `/inbox` | [`lib/screens/inbox_screen.dart`](../../lib/screens/inbox_screen.dart) | smoke-inbox, smoke-theme | 3 Tabs (Trackings, Bestellungen, Sonstiges). |
| `/inventory` | [`lib/screens/inventory_screen.dart`](../../lib/screens/inventory_screen.dart) | smoke-theme, mobile-overflow, master-detail-flow | KPI-Header + Item-Tabelle. **Master-Detail-Split-Layout auf Desktop (Container-Breite ≥ 1200px, via `LayoutBuilder`):** Master-Liste links (380px), Detail-Spalte rechts mit eingebettetem `ProductDetailScreen(embedded: true)`. Phone-Verhalten unverändert (Vollbild-Push). A11y-Keys für Detail-Pane: `Key('detailPane')` (Detail-Root wenn Item gewählt), `Key('detailPaneEmpty')` (Placeholder wenn kein Item gewählt). Selektions-State (`_selectedItemId`) lebt im Owner-Widget oberhalb des `LayoutBuilder`-Switches, überlebt Resize Phone↔Desktop. |
| `/suppliers` | [`lib/screens/suppliers_screen.dart`](../../lib/screens/suppliers_screen.dart) | smoke-theme | Lieferanten-CRUD. |
| `/statistics` | [`lib/screens/statistics_screen.dart`](../../lib/screens/statistics_screen.dart) | smoke-theme, charts-render | KPI + Charts + Drilldown. |
| `/activity` | [`lib/screens/activity_screen.dart`](../../lib/screens/activity_screen.dart) | smoke-theme | Workspace-Activity-Log. |
| `/help` | [`lib/screens/help_screen.dart`](../../lib/screens/help_screen.dart) | smoke-help, smoke-theme | FAQ + Search + Quick-Start. |
| `/settings` | [`lib/screens/settings_screen.dart`](../../lib/screens/settings_screen.dart) | smoke-theme, all-settings-tabs | 8 Tabs: Buyers, Shops, Team, Push, Postfach, Shipping, Public profile, General. |
| `/pricing` | [`lib/screens/pricing_screen.dart`](../../lib/screens/pricing_screen.dart) | smoke-theme | Plan-Auswahl + Checkout-Trigger. |
| `/billing-profile` | [`lib/screens/billing_profile_screen.dart`](../../lib/screens/billing_profile_screen.dart) | smoke-theme | Rechnungs-Adresse, push aus Pricing. |
| `/public-profile/<slug>` | [`lib/screens/public_profile_screen.dart`](../../lib/screens/public_profile_screen.dart) | public-render | **Web-only**, ohne Login. URL `/u/<handle>`. |
| `/warehouse` | [`lib/screens/warehouse_hub_screen.dart`](../../lib/screens/warehouse_hub_screen.dart) | smoke-theme, mobile-overflow, master-detail-flow | Neuer `MainTab.warehouse` (Epic A-full, AF11). Hub mit Kacheln zu Sub-Routen: Artikelstamm, Bestellungen, Lager, Kategorien, Inventur, Reporting. A11y-Keys: `Key('hubTileProductCatalog')`, `Key('hubTilePurchaseOrders')`, `Key('hubTileWarehouses')`, `Key('hubTileCategories')`, `Key('hubTileStocktake')`, `Key('hubTileReporting')`. **Master-Detail-Split-Layout auf Desktop (Container-Breite ≥ 1200px, via `LayoutBuilder`):** Hub-Kacheln als Master-Spalte links; gewählter Sub-Bereich (1 von 5 embeddable: `purchase_orders`, `warehouses`, `categories`, `stocktake`, `product_catalog`) als Detail-Spalte rechts. **Ausnahme Reporting-Tile:** bleibt Vollbild-Push (inline-`Scaffold` mit eigenem `AppBar`, akzeptierter Trade-off aus T3.4). Phone-Verhalten unverändert (Vollbild-Push für alle Kacheln). A11y-Keys für Detail-Pane: `Key('detailPane')` (Detail-Root wenn Sub-Bereich gewählt), `Key('detailPaneEmpty')` (Placeholder wenn kein Sub-Bereich aktiv). |

## Auth- & First-Run-Routes (ausgeloggter / Onboarding-Bereich)

| Route | File | Pflicht-Tests | Notizen |
|---|---|---|---|
| `/splash` | [`lib/screens/auth/splash_screen.dart`](../../lib/screens/auth/splash_screen.dart) | smoke-splash | Boot-Transient. |
| `/login` | [`lib/screens/auth/login_screen.dart`](../../lib/screens/auth/login_screen.dart) | smoke-login, smoke-theme | E-Mail + Google + Apple. |
| `/register` | [`lib/screens/auth/register_screen.dart`](../../lib/screens/auth/register_screen.dart) | smoke-register, smoke-theme | Push aus Login. |
| `/forgot-password` | [`lib/screens/auth/forgot_password_screen.dart`](../../lib/screens/auth/forgot_password_screen.dart) | smoke-forgot, smoke-theme | Reset-Mail anfordern. |
| `/reset-password` | [`lib/screens/auth/reset_password_screen.dart`](../../lib/screens/auth/reset_password_screen.dart) | smoke-reset, smoke-theme | Push via Recovery-Link. |
| `/verify-email` | [`lib/screens/auth/verify_email_screen.dart`](../../lib/screens/auth/verify_email_screen.dart) | smoke-verify, smoke-theme | Push aus Register. |
| `/onboarding` | [`lib/screens/onboarding_screen.dart`](../../lib/screens/onboarding_screen.dart) | smoke-onboarding, smoke-theme | 6-Step-PageView, nur Workspace-Owner ohne `onboarded_at`. |

## Sub-Routes / Modal-Dialogs / Bottom-Sheets

User-sichtbare Modal-Layer, die der Tester bei Bedarf öffnet (Trigger-Spalte
beschreibt wie). Pflicht-Tests sind Mindest-Mobile-Audits — viele dieser
Dialogs müssen auf 390×844 ohne horizontalen Scroll funktionieren.

| Trigger | File | Pflicht-Tests |
|---|---|---|
| `/deals` → New-/Edit-Deal | [`lib/widgets/add_edit_deal_dialog.dart`](../../lib/widgets/add_edit_deal_dialog.dart) | smoke-theme, mobile-overflow | Deal-Detail-Dialog enthält seit Paket 1 den **Sendungsverlauf** (`TrackingTimelineSection` aus [`lib/widgets/tracking_timeline.dart`](../../lib/widgets/tracking_timeline.dart), `tracking_events`-Timeline, kollabiert auf 4 Einträge), die **ETA-Zeile** (`Key('tracking-eta-row')`), Copy-CTA + „Sendung verfolgen"-Deep-Link. Mobile-Audit muss diese Block-Erweiterungen auf 390×844 ohne Overflow prüfen. `tracking-timeline`-Spezialtest noch nicht im Tester-Prompt definiert (siehe TODO). |
| `/inventory` → Edit-Item | [`lib/screens/inventory_screen.dart`](../../lib/screens/inventory_screen.dart) (`_AddEditItemDialog`) | smoke-theme, mobile-overflow |
| `/inventory` → Batch-Sheet | [`lib/widgets/inventory_batches_sheet.dart`](../../lib/widgets/inventory_batches_sheet.dart) | smoke-theme, mobile-overflow |
| `/inventory` → Barcode-Scan | [`lib/widgets/barcode_scanner_sheet.dart`](../../lib/widgets/barcode_scanner_sheet.dart) | smoke-theme |
| `/inventory` → Artikel-Detail (Tap auf Item-Card) | [`lib/screens/product_detail_screen.dart`](../../lib/screens/product_detail_screen.dart) | smoke-theme, mobile-overflow | Gepushter Screen auf Phone (kein eigener MainTab). 360°-Sicht auf bestehender `inventory_items`-Row: Stammdaten, Bestand, getypte Bewegungshistorie (Buchungsart-Badges), Chargen, Lieferant. A11y-Keys: `Key('productDetailScrollView')`, `Key('movementHistoryList')`, `Key('movementRow-<id>')`. Epic A-lite (AL5). **Seit T3.3a embeddable (`embedded: bool`-Parameter)** — auf Desktop im Inventory-Hub-Master-Detail als `ProductDetailScreen(embedded: true)` genutzt (kein eigenes `Scaffold`/`AppBar` wenn `embedded: true`). |
| `/warehouse` → Neuer/Bearbeitungs-Artikel (Stammkatalog) | [`lib/widgets/add_edit_product_dialog.dart`](../../lib/widgets/add_edit_product_dialog.dart) | smoke-theme, mobile-overflow | `AddEditProductDialog` — Modal-Dialog für Produkt-Stammsatz (NEU, Epic A-full AF9). `SingleChildScrollView` + `SafeArea` + `MediaQuery.viewInsetsOf`. A11y-Keys: `Key('productSaveButton')`, `Key('productCategoryDropdown')`. Viewer ohne Speichern-Button. |
| `/suppliers` → Add-/Edit-Supplier | [`lib/widgets/add_edit_supplier_dialog.dart`](../../lib/widgets/add_edit_supplier_dialog.dart) | smoke-theme, mobile-overflow |
| `/settings` → Add-/Edit-Shop | [`lib/widgets/add_edit_shop_dialog.dart`](../../lib/widgets/add_edit_shop_dialog.dart) | smoke-theme, mobile-overflow |
| `/settings` → Add-/Edit-Buyer | [`lib/widgets/add_edit_buyer_dialog.dart`](../../lib/widgets/add_edit_buyer_dialog.dart) | smoke-theme, mobile-overflow |
| `/settings` → Add-/Edit-Mailbox | [`lib/widgets/add_edit_mailbox_dialog.dart`](../../lib/widgets/add_edit_mailbox_dialog.dart) | smoke-theme, mobile-overflow |
| `/settings` → Team-Tab Workspace-Switcher | [`lib/widgets/workspace_switcher.dart`](../../lib/widgets/workspace_switcher.dart) | smoke-theme, mobile-overflow | Vertikale Card-Liste der Workspaces des Users + „Neuer Workspace"-Card mit Usage-Pill. Tap auf Card → setActive; Tap auf „Neuer Workspace" → CreateWorkspaceDialog (oder LimitReachedDialog wenn Plan-Limit erreicht). |
| `/settings` → Create-Workspace | [`lib/widgets/create_workspace_dialog.dart`](../../lib/widgets/create_workspace_dialog.dart) | smoke-theme, mobile-overflow | Bottom-Sheet mit Name-TextField + Plan-Usage-Info. Submit ruft `ActiveWorkspaceProvider.createAndSwitchTo`; bei `WorkspaceLimitException` fängt der Dialog ab und öffnet `LimitReachedDialog`. |
| `/settings` → Invite-Member | [`lib/widgets/invite_member_dialog.dart`](../../lib/widgets/invite_member_dialog.dart) | smoke-theme, mobile-overflow | Bottom-Sheet mit Email-Input + RadioGroup für Editor/Beobachter/Admin (Admin gated auf Plan Team+). Erfolg → `InviteSuccessSheet` mit Token + Clipboard-Copy. |
| `/settings` → Limit-Reached | [`lib/widgets/limit_reached_dialog.dart`](../../lib/widgets/limit_reached_dialog.dart) | smoke-theme | AlertDialog mit Upsell-CTA → navigiert zum Pricing-Screen. |
| `/settings` → Member-Remove-Confirm | [`lib/widgets/member_remove_confirm_dialog.dart`](../../lib/widgets/member_remove_confirm_dialog.dart) | smoke-theme | Destruktiver Confirm-Dialog vor `WorkspaceService.removeMember`. |
| `/deals` → Deal-Picker (Comments) | [`lib/widgets/deal_picker_dialog.dart`](../../lib/widgets/deal_picker_dialog.dart) | smoke-theme |
| `/main` → Verkauf-Sektion (Sub-Tabs) | [`lib/screens/sales_section_screen.dart`](../../lib/screens/sales_section_screen.dart) (`SalesSectionScreen`) | smoke-theme, mobile-overflow | Tier-2b. `SegmentedButton<MainTab>` über Deals/Tickets/Inbox. Root-Key: `Key('salesSection')`. Segment-Keys (am Icon-Subtree): `Key('salesSeg-deals')`, `salesSeg-tickets`, `salesSeg-inbox`. Inbox-Segment nur wenn `inboxEnabled` (Plan ≥ Starter) — bei Free verschwindet nur das Segment, die Sektion bleibt. Inbox-Segment trägt Tracking-Badge. Mobile (Container < 430px): Icon-only-Segmente mit Tooltip = Label (kein Überlauf auf 360px). |
| `/main` → Auswertung-Sektion (Sub-Tabs) | [`lib/screens/analytics_section_screen.dart`](../../lib/screens/analytics_section_screen.dart) (`AnalyticsSectionScreen`) | smoke-theme, mobile-overflow | Tier-2b. `SegmentedButton<MainTab>` über Statistik (Default) / Aktivität. Root-Key: `Key('analyticsSection')`. Segment-Keys (am Icon-Subtree): `Key('analyticsSeg-stats')`, `analyticsSeg-activity`. `StatisticsScreen` bleibt Vollbild (nicht embeddable, Tier-3-Scope). |
| `/main` → Global-Search (Cmd+K) | [`lib/widgets/global_search_dialog.dart`](../../lib/widgets/global_search_dialog.dart) | smoke-theme, mobile-overflow | Recent-Searches-Section mit PII-Filter (`Key('recentSearchesSection')`). Items: `Key('recentSearchItem-$index')`. Clear-Button: `Key('recentSearchesClear')`. Zeigt max. 5 Einträge (FIFO). |
| `/main` → Invites-Bell | [`lib/widgets/invites_bell.dart`](../../lib/widgets/invites_bell.dart) | smoke-theme |
| `/inbox` → Message-Details | [`lib/widgets/inbox_message_details.dart`](../../lib/widgets/inbox_message_details.dart) | smoke-theme, mobile-overflow |
| `/inbox` → Suggestion-Accept-Snackbar | [`lib/screens/inbox_screen.dart`](../../lib/screens/inbox_screen.dart) (`_SuggestionCard._accept`) | smoke-theme | Accept-Snackbar mit `Key('inboxAcceptedSnack')` + Action-Button `Key('inboxAcceptedShowDealAction')` → wechselt in Deals-Tab. |
| `/inbox` → Suggestion Sheet (Long-Press) | [`lib/screens/inbox_screen.dart`](../../lib/screens/inbox_screen.dart) (`_SuggestionCard._showSuggestionSheet`) | smoke-theme, mobile-overflow | Long-Press auf Suggestion-Card öffnet Bottom-Sheet mit 3 Aktionen: Verwerfen (`Key('inboxSuggestion-dismiss-{id}')`), Bearbeiten (`Key('inboxSuggestion-edit-{id}')`), Annehmen (`Key('inboxSuggestion-accept-{id}')`). Sheet-Root: `Key('inboxSuggestionSheet')`. |
| `/deals` → Comments-Section | [`lib/widgets/deal_comments_section.dart`](../../lib/widgets/deal_comments_section.dart) | smoke-theme |
| `/deals` → Attachment-Gallery | [`lib/widgets/attachment_gallery.dart`](../../lib/widgets/attachment_gallery.dart) | smoke-theme |
| `/deals` → Tracking-Review-Filter | [`lib/widgets/deal_table.dart`](../../lib/widgets/deal_table.dart) (`_FilterBar`) | smoke-tracking-review-chip | Filter-Chip „Prüfen ({count})" filtert auf `tracking_needs_review=true`. Sichtbar nur wenn Count > 0. Kein eigener Top-Level-Screen (Council-Finding #10). Banner in Inbox + Deals via `lib/widgets/tracking_banner_improved_detection.dart`. Badge auf Inbox-Nav-Tab (Index 3). |
| `/statistics` → Product-Drilldown | [`lib/widgets/statistics/product_drilldown_sheet.dart`](../../lib/widgets/statistics/product_drilldown_sheet.dart) | smoke-theme, mobile-overflow |
| `/warehouse` → Artikelstamm (Sub-Route) | [`lib/screens/product_catalog_screen.dart`](../../lib/screens/product_catalog_screen.dart) | smoke-theme, mobile-overflow | Produktkatalog-Übersicht: vertikale Cards mit Name, SKU, Kategorie, Standard-EK/-VK, Aktiv-Status. FAB „Neuer Artikel" (`Key('productNewFab')`) — nur für Editor+. Tap auf Card → `AddEditProductDialog` im Edit-Modus. Viewer → kein FAB, kein Edit-Tap. A11y-Keys: `Key('productNewFab')`, `Key('productCatalogCard-<id>')`. Epic A-full. **Seit T3.4 embeddable (`embedded: bool`-Parameter)** — im Warehouse-Hub-Master-Detail als Detail-Spalte nutzbar. |
| `/warehouse` → Warengruppen (Sub-Route) | [`lib/screens/categories_screen.dart`](../../lib/screens/categories_screen.dart) | smoke-theme, mobile-overflow | **Seit T3.4 embeddable (`embedded: bool`-Parameter)** — im Warehouse-Hub-Master-Detail als Detail-Spalte nutzbar. |
| `/warehouse` → Bestellungen (Sub-Route) | [`lib/screens/purchase_orders_screen.dart`](../../lib/screens/purchase_orders_screen.dart) | smoke-theme, mobile-overflow | Liste der Bestellungen mit Status-Badges; FAB „Neue Bestellung" (`Key('poNewFab')`). Sub-Route des Warenwirtschaft-Hubs, kein eigener MainTab. Viewer → FAB ausgeblendet. Epic C (C5). **Seit T3.4 embeddable (`embedded: bool`-Parameter)** — im Warehouse-Hub-Master-Detail als Detail-Spalte nutzbar. |
| `/warehouse` → Bestellungs-Detail (Sub-Route) | [`lib/screens/purchase_order_detail_screen.dart`](../../lib/screens/purchase_order_detail_screen.dart) | smoke-theme, mobile-overflow, goods-receipt-flow | Positionen, Wareneingang buchen (Soll/Ist-Stepper), Status, PDF-Export. A11y-Keys: `Key('poCard-<id>')`, `Key('goodsReceiptBookButton')`, `Key('poItemReceivedStepper-<id>')`, `Key('poPdfExportButton')`. Epic C (C6). |
| `/warehouse` → Lager (Sub-Route) | [`lib/screens/warehouses_screen.dart`](../../lib/screens/warehouses_screen.dart) | smoke-theme, mobile-overflow | Lager verwalten (CRUD). FAB „Neues Lager" (`Key('warehouseNewFab')`). Sub-Route des Warenwirtschaft-Hubs, kein eigener MainTab. Viewer → kein FAB. A11y-Keys: `Key('warehouseRow-<id>')`, `Key('warehouseDropdown')`. Epic D (D3). **Seit T3.4 embeddable (`embedded: bool`-Parameter)** — im Warehouse-Hub-Master-Detail als Detail-Spalte nutzbar. |
| `/warehouse` → Inventur (Sub-Route) | [`lib/screens/stocktake_screen.dart`](../../lib/screens/stocktake_screen.dart) | smoke-theme, mobile-overflow | Inventur-Sessionen auflisten; FAB „Neue Inventur" (`Key('stocktakeNewFab')`). Sub-Route des Warenwirtschaft-Hubs, kein eigener MainTab. Viewer → kein FAB. A11y-Keys: `Key('stocktakeRow-<id>')`. Epic E (E3). **Seit T3.4 embeddable (`embedded: bool`-Parameter)** — im Warehouse-Hub-Master-Detail als Detail-Spalte nutzbar. |
| `/warehouse` → Inventur-Detail (Sub-Route) | [`lib/screens/stocktake_detail_screen.dart`](../../lib/screens/stocktake_detail_screen.dart) | smoke-theme, mobile-overflow, stocktake-count-flow | Inventur durchführen: durchscrollbare 48dp-Liste, Filter „nur ungezählte" (`Key('stocktakeFilterUncounted')`), Fortschritts-Header, Barcode-Einsprung, Differenz-Report als vertikale Cards, Abschließen-Button (`Key('stocktakeCloseButton')`). A11y-Keys: `Key('stocktakeCountField-<id>')`. Epic E (E3). |
| (global) → Destruktiver Confirm | [`lib/widgets/confirm_dialog.dart`](../../lib/widgets/confirm_dialog.dart) | smoke-confirm-dialog, smoke-form-keyboard-phone | Allgemeiner Confirm-Dialog-Helper (`showConfirmDialog`), generalisiert aus `MemberRemoveConfirmDialog`. Ablöst inline-`AlertDialog`-Wildwuchs aus 28 Files inkrementell. **Phone** (Container-Breite < `Breakpoints.phone`): `showModalBottomSheet(isScrollControlled: true)` mit `Padding(MediaQuery.viewInsetsOf(context))` — Keyboard-safe. **Desktop:** zentrierter `AlertDialog`. `requireTypeName`-Modus: Confirm-Button bleibt disabled bis der User `confirmTypeNameValue` exakt eingetippt hat; Unicode-Bidi-Sanitize (RTL-Override-Chars gefiltert via `_sanitizeBidi`). `HapticFeedback.lightImpact()` bei destruktivem Confirm. A11y-Keys: `Key('confirmDialog')`, `Key('confirmDialog-confirm')`, `Key('confirmDialog-cancel')`, `Key('confirmDialog-typeName-field')` (nur bei `requireTypeName`). Epic A (A2). |
| (global) → App-Feedback / SnackBar | [`lib/widgets/app_feedback.dart`](../../lib/widgets/app_feedback.dart) | smoke-feedback-undo | Zentraler SnackBar-Helper `AppFeedback` mit Varianten `success`, `error`, `info`, `loading`. Undo-Action-Slot über `undo`-Parameter. Farbkodierung über `AppTheme`-Tokens (`successBgOf`, `dangerBgOf`, `infoBgOf`). **Phone-Bottom-Margin:** SnackBar liegt über Bottom-Nav (`kBottomNavHeight = 80dp` + SafeArea-Bottom + 8dp), Desktop 16dp; `SnackBarBehavior.floating` zwingend. **Dialog-Context-Pattern:** Root-`ScaffoldMessengerState` vor `showDialog` capturen (`AppFeedback.successOn(messenger, …)`). A11y-Keys: `Key('appFeedbackSuccess')`, `Key('appFeedbackError')`, `Key('appFeedbackInfo')`, `Key('appFeedbackUndoAction')`. Epic A (A1). |
| (global) → Unsaved-Changes-Guard | [`lib/widgets/unsaved_changes_guard.dart`](../../lib/widgets/unsaved_changes_guard.dart) | smoke-form-unsaved | `PopScope`-Wrapper (`UnsavedChangesGuard`) für Dialog-/Form-Trees. Bei `isDirty: true` wird Back/Pop abgefangen und Discard-Confirm via `showConfirmDialog` gezeigt. **Muss INNERHALB des Dialog-Trees** liegen (nicht um `showDialog`-Call), damit `PopScope` greift. Dirty-Detection prüft `originalValue != currentValue` (kein False-Positive durch Feld-Fokus). Epic D (Form-UX). |
| (global) → Listen-Skeleton-Loader | [`lib/widgets/skeletons/list_skeleton.dart`](../../lib/widgets/skeletons/list_skeleton.dart) | smoke-skeleton | `ListSkeleton({itemCount, itemHeight})` — Loading-State-Companion für alle Listen-Screens. `Key('skeletonLoader')`-Konvention (übernommen aus `dashboard_screen.dart`). `shouldShowSkeleton(isLoading, hasData, initialLoadAttempted)` Helper steuert Race-Condition-safe Anzeige: Skeleton nur bei `!initialLoadAttempted && !hasData` ODER `isLoading && !hasData` — nie während Refresh mit vorhandenen Daten. Built-in `AnimatedSwitcher` (200ms) für Loading→Content-Crossfade. Powered by `skeletonizer`-Package (bereits in `pubspec.yaml`). Epic B (B1). |

## Pflicht-Tests-Definitionen

Die folgenden Test-Schlüssel sind die kanonische Schreibweise. Browser-
Tester nutzt sie als Sprungmarken in seinem System-Prompt.

- `smoke-theme` — Light **und** Dark-Mode pro Region kein Stilbruch
  (Kontrast, fehlende Hintergründe, hardcoded Colors). Screenshot pro
  Mode in den Run-Report.
- `mobile-overflow` — Phone-Viewport 390×844, kein horizontaler Scroll,
  kein abgeschnittener Text, Touch-Targets ≥ 48 dp.
- `smoke-inbox` — Inbox laden, Tab-Switch (Trackings / Bestellungen /
  Sonstiges), "Alle als gelesen markieren" sichtbar/aktiv. Siehe
  `.claude/agents/browser-tester.md` Szenario `smoke-inbox`.
- `smoke-login` — E-Mail-Login mit Test-Account aus `.env.test`,
  erwartet Redirect → `/main`.
- `smoke-register` — Register-Form öffnet, Validation-Hinweise sichtbar
  (kein echter Account-Create im Test).
- `smoke-forgot` — Forgot-Password-Form öffnet, Submit triggert
  Bestätigungs-Snack.
- `smoke-reset` — Reset-Password-Form rendert (Flow startet via
  Recovery-Mail-Link, im Test nur Render-Check).
- `smoke-verify` — Verify-Email-Screen rendert mit gemockter
  E-Mail-Adresse (kein echter Mail-Versand).
- `smoke-splash` — Splash zeigt Logo + Spinner ≤ 2 s, dann Redirect.
- `smoke-help` — Help-Screen öffnet, FAQ-Search filtert, mind. eine
  Sektion expandiert sauber.
- `smoke-onboarding` — 6 Steps durchklickbar, Skip-Button sichtbar.
- `archive-tab` — Tickets-Archiv-Tab lädt ohne Loading-Loop.
- `charts-render` — Statistics-Charts zeichnen ohne `RenderFlex`-Errors.
- `all-settings-tabs` — Settings: jeden Tab anklicken (aktuell 8:
  Buyers, Shops, Team, Push, Postfach, Shipping, Public profile,
  General), kein leeres Panel, kein Crash.
- `deal-flow` — Deal-CRUD: Add-Dialog öffnen → Pflichtfelder füllen →
  speichern → Eintrag erscheint in Tabelle → Edit → Delete.
- `public-render` — Public-Profile-URL `/u/test-handle` rendert ohne
  Login-Redirect.
- `goods-receipt-flow` — Wareneingang gegen eine Bestellung buchen:
  Bestellungs-Detail öffnen → Position via `Key('poItemReceivedStepper-<id>')`
  auswählen → Menge per Stepper erhöhen → „Wareneingang buchen"
  (`Key('goodsReceiptBookButton')`) tippen → `quantity_received` der
  Position steigt, PO-Status wechselt auf `partially_received` oder
  `received` je nach verbleibender offener Menge. Kein Overflow,
  kein Crash auf Phone-Viewport.
- `master-detail-flow` — Master-Detail-Split auf Desktop prüfen: Screen
  auf Desktop-Viewport (≥ 1200px Container-Breite) öffnen → kein Vollbild-Push
  bei Item-Tap, stattdessen Detail-Spalte (`Key('detailPane')`) erscheint
  rechts. `Key('detailPaneEmpty')` sichtbar wenn kein Item gewählt. Phone-
  Pfad (Vollbild-Push) auf 390×844 unverändert.
- `stocktake-count-flow` — Inventur vollständig durchführen: Inventur-
  Übersicht öffnen → „Neue Inventur" (`Key('stocktakeNewFab')`) tippen →
  Inventur-Detail öffnet → Positionen via `Key('stocktakeCountField-<id>')`
  zählen (Stepper) → Filter „nur ungezählte" (`Key('stocktakeFilterUncounted')`)
  aktivieren und verifizieren, dass gezählte Positionen ausgeblendet werden →
  Fortschritts-Header zeigt `{counted}/{total} gezählt` korrekt → Inventur
  abschließen (`Key('stocktakeCloseButton')`) → Differenz-Report erscheint als
  vertikale Cards (kein horizontaler Scroll auf Phone-Viewport) → Bestand der
  abweichenden Artikel wird angepasst → `inventory_movements` mit
  `movement_type='stocktake'` werden geschrieben (append-only). Kein Overflow,
  kein Crash auf 390×844.
- `smoke-feedback-undo` — Destruktive Aktion ausführen (z. B. Inbox-Mail
  verwerfen) → `AppFeedback`-SnackBar erscheint mit Undo-Button
  (`Key('appFeedbackUndoAction')`) → Undo tippen → Element kommt zurück.
  Prüft auch: SnackBar liegt ÜBER Bottom-Nav (kein Overlap) auf Phone-Viewport.
- `smoke-confirm-dialog` — Destruktive Aktion triggern (z. B. Mailbox
  löschen) → `showConfirmDialog` erscheint → Cancel-Button
  (`Key('confirmDialog-cancel')`) schließt ohne Aktion; erneut öffnen →
  Confirm-Button (`Key('confirmDialog-confirm')`) führt die Aktion aus.
  Phone-Viewport: Dialog erscheint als Bottom-Sheet (nicht als AlertDialog).
- `smoke-skeleton` — Listen-Screen (Dashboard, Inventory, Inbox) im ersten
  Load: Skeleton-Loader (`Key('skeletonLoader')`) sichtbar statt
  `CircularProgressIndicator`. Nach Daten-Eingang: AnimatedSwitcher-
  Crossfade → Content sichtbar. Refresh (Daten vorhanden) darf KEINEN
  Skeleton zeigen (Race-Condition-Test).
- `smoke-form-unsaved` — Add/Edit-Dialog öffnen → Textfeld ändern →
  Schließen-X oder Back-Button drücken → `UnsavedChangesGuard` zeigt
  Discard-Confirm (`Key('unsavedChangesGuard-dialog')`). Discard-Button
  (`Key('unsavedChangesGuard-discard')`) schließt Dialog. Bei unveränderten
  Feldern: Dialog schließt direkt ohne Confirm-Prompt.
- `smoke-form-keyboard-phone` — Add/Edit-Dialog auf Phone-Viewport (390×844)
  öffnen → Textfeld tippen → Tastatur öffnet sich → aktives TextField bleibt
  sichtbar (kein Verdecken durch Tastatur, `MediaQuery.viewInsetsOf` greift).
  Gilt auch für `showConfirmDialog` mit `requireTypeName` in der
  BottomSheet-Variante.
- `smoke-keyboard-nav` — Desktop-Viewport: Tab-Taste durch alle
  `AppNavRail`-Destinations (`Key('navRailDestination-<tab>')`) → Focus-Ring
  sichtbar auf jeder Destination → Enter aktiviert den Tab (Screen wechselt).
  Prüft M3-State-Layer und Keyboard-Focus-Handling.
- `smoke-nav-feature-gating` — Free-User-Login: alle 5 Sektions-Slots
  (Bottom-Nav + Rail) sind immer sichtbar. Das Postfach-Gating wirkt jetzt
  **innerhalb** der Verkauf-Sektion: bei `!billing.hasInbox` fehlt das
  `salesSeg-inbox`-Segment (4-bzw-2-Segment-SegmentedButton), die
  Sektions-Slots bleiben stabil (kein Index-Shift). Switch auf Premium →
  Inbox-Segment erscheint. Downgrade während Inbox offen → Redirect auf
  Dashboard.
- `smoke-hero-no-desktop-regression` — Desktop-Viewport (≥ 1200px):
  Inventory-Item-Tap öffnet Detail in Master-Detail-Pane OHNE Hero-Animation
  (kein Vollbild-Push). Phone-Viewport: Hero-Animation triggert korrekt
  beim Vollbild-Push auf `ProductDetailScreen`. Kein `RenderFlex`-Overflow
  auf beiden Viewports.

## Pflege-Hinweise

- **Reihenfolge der Top-Level-Tabelle** spiegelt die Bottom-Nav /
  Side-Nav (`MainScreen`-Tab-Index 0 … 9). Beim Anhängen neuer
  Screens bitte am Ende der Sektion einsortieren — der Auto-Updater
  hält das ein.
- **Synthetische Routes** (`/dashboard`, `/deals`, …) sind reine
  Tester-Bezeichner. In der App gibt es kein `Navigator.pushNamed`
  mit diesen Pfaden — sie referenzieren den Tab-Index in `MainScreen`.
- **Sub-Routes ohne eigene Datei** (z. B. inline-Dialoge in Screens
  wie `_AddEditItemDialog` in `inventory_screen.dart`) zeigen die
  Datei des umgebenden Screens, nicht eine eigene Widget-Datei.
- **Default Pflicht-Tests** für neue Screens: `smoke-theme,
  mobile-overflow`. Tester-spezifische Szenarien (Charts, 6-Tabs etc.)
  ergänzt der Maintainer manuell, der `doc-updater` setzt nur das
  Default-Set ein.
