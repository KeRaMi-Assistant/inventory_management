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
| `/main` (Shell) | [`lib/screens/main_screen.dart`](../../lib/screens/main_screen.dart) | smoke-theme, mobile-overflow | Side-Nav + AppBar, hält Tab-Index. **Bottom-Nav auf Phone (`< 800px`):** `Key('mainBottomNav')` mit 5 festen Slots (Dashboard, Deals, Tickets, Inbox[conditional], Inventory) + „Mehr"-Slot (`Key('main-tab-more')`). Inbox-Slot entfällt wenn `!billing.hasInbox` (4 Slots + Mehr). Help-Icon AppBar (Phone): `Key('appBar-help-action')` — navigiert direkt zu `/help`. Reihenfolge Slots: `Key('main-tab-dashboard')`, `main-tab-deals`, `main-tab-tickets`, `main-tab-inbox`, `main-tab-inventory`, `main-tab-more`. |
| `/dashboard` | [`lib/screens/dashboard_screen.dart`](../../lib/screens/dashboard_screen.dart) | smoke-theme, mobile-overflow | KPI-Cards + Recent-Deals. Skeleton-Loader via `skeletonizer` beim Initial-Load (`Key('skeletonLoader')`); aktiv nur wenn `isLoading=true && data leer` (Race-Condition-safe). |
| `/deals` | [`lib/screens/deals_screen.dart`](../../lib/screens/deals_screen.dart) | smoke-theme, mobile-overflow, deal-flow | Tabelle + Detail-Sidebar (Desktop) bzw. Stack (Phone). |
| `/tickets` | [`lib/screens/tickets_screen.dart`](../../lib/screens/tickets_screen.dart) | smoke-theme, archive-tab | Aktiv-/Archiv-Tabs. |
| `/inbox` | [`lib/screens/inbox_screen.dart`](../../lib/screens/inbox_screen.dart) | smoke-inbox, smoke-theme | 3 Tabs (Trackings, Bestellungen, Sonstiges). |
| `/inventory` | [`lib/screens/inventory_screen.dart`](../../lib/screens/inventory_screen.dart) | smoke-theme, mobile-overflow | KPI-Header + Item-Tabelle. |
| `/suppliers` | [`lib/screens/suppliers_screen.dart`](../../lib/screens/suppliers_screen.dart) | smoke-theme | Lieferanten-CRUD. |
| `/statistics` | [`lib/screens/statistics_screen.dart`](../../lib/screens/statistics_screen.dart) | smoke-theme, charts-render | KPI + Charts + Drilldown. |
| `/activity` | [`lib/screens/activity_screen.dart`](../../lib/screens/activity_screen.dart) | smoke-theme | Workspace-Activity-Log. |
| `/help` | [`lib/screens/help_screen.dart`](../../lib/screens/help_screen.dart) | smoke-help, smoke-theme | FAQ + Search + Quick-Start. |
| `/settings` | [`lib/screens/settings_screen.dart`](../../lib/screens/settings_screen.dart) | smoke-theme, all-settings-tabs | 8 Tabs: Buyers, Shops, Team, Push, Postfach, Shipping, Public profile, General. |
| `/pricing` | [`lib/screens/pricing_screen.dart`](../../lib/screens/pricing_screen.dart) | smoke-theme | Plan-Auswahl + Checkout-Trigger. |
| `/billing-profile` | [`lib/screens/billing_profile_screen.dart`](../../lib/screens/billing_profile_screen.dart) | smoke-theme | Rechnungs-Adresse, push aus Pricing. |
| `/public-profile/<slug>` | [`lib/screens/public_profile_screen.dart`](../../lib/screens/public_profile_screen.dart) | public-render | **Web-only**, ohne Login. URL `/u/<handle>`. |
| `/warehouse` | [`lib/screens/warehouse_hub_screen.dart`](../../lib/screens/warehouse_hub_screen.dart) | smoke-theme, mobile-overflow | Neuer `MainTab.warehouse` (Epic A-full, AF11). Hub mit Kacheln zu Sub-Routen: Bestellungen, Lager, Kategorien, Inventur, Reporting. A11y-Keys: `Key('hubTilePurchaseOrders')`, `Key('hubTileWarehouses')`, `Key('hubTileCategories')`, `Key('hubTileStocktake')`, `Key('hubTileReporting')`. |

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
| `/deals` → New-/Edit-Deal | [`lib/widgets/add_edit_deal_dialog.dart`](../../lib/widgets/add_edit_deal_dialog.dart) | smoke-theme, mobile-overflow |
| `/inventory` → Edit-Item | [`lib/screens/inventory_screen.dart`](../../lib/screens/inventory_screen.dart) (`_AddEditItemDialog`) | smoke-theme, mobile-overflow |
| `/inventory` → Batch-Sheet | [`lib/widgets/inventory_batches_sheet.dart`](../../lib/widgets/inventory_batches_sheet.dart) | smoke-theme, mobile-overflow |
| `/inventory` → Barcode-Scan | [`lib/widgets/barcode_scanner_sheet.dart`](../../lib/widgets/barcode_scanner_sheet.dart) | smoke-theme |
| `/inventory` → Artikel-Detail (Tap auf Item-Card) | [`lib/screens/product_detail_screen.dart`](../../lib/screens/product_detail_screen.dart) | smoke-theme, mobile-overflow | Gepushter Screen (kein eigener MainTab). 360°-Sicht auf bestehender `inventory_items`-Row: Stammdaten, Bestand, getypte Bewegungshistorie (Buchungsart-Badges), Chargen, Lieferant. A11y-Keys: `Key('productDetailScrollView')`, `Key('movementHistoryList')`, `Key('movementRow-<id>')`. Epic A-lite (AL5). |
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
| `/main` → More-Nav Sheet (Phone) | [`lib/screens/main_screen.dart`](../../lib/screens/main_screen.dart) (`_MoreNavSheet`) | smoke-theme, mobile-overflow | Geöffnet via „Mehr"-Slot (`Key('main-tab-more')`) in der Bottom-Nav. Sheet-Key: `Key('moreNavSheet')`. Items: `Key('moreNavSheet-suppliers')`, `moreNavSheet-stats`, `moreNavSheet-activity`, `moreNavSheet-settings`, `moreNavSheet-help`. |
| `/main` → Global-Search (Cmd+K) | [`lib/widgets/global_search_dialog.dart`](../../lib/widgets/global_search_dialog.dart) | smoke-theme, mobile-overflow | Recent-Searches-Section mit PII-Filter (`Key('recentSearchesSection')`). Items: `Key('recentSearchItem-$index')`. Clear-Button: `Key('recentSearchesClear')`. Zeigt max. 5 Einträge (FIFO). |
| `/main` → Invites-Bell | [`lib/widgets/invites_bell.dart`](../../lib/widgets/invites_bell.dart) | smoke-theme |
| `/inbox` → Message-Details | [`lib/widgets/inbox_message_details.dart`](../../lib/widgets/inbox_message_details.dart) | smoke-theme, mobile-overflow |
| `/inbox` → Suggestion-Accept-Snackbar | [`lib/screens/inbox_screen.dart`](../../lib/screens/inbox_screen.dart) (`_SuggestionCard._accept`) | smoke-theme | Accept-Snackbar mit `Key('inboxAcceptedSnack')` + Action-Button `Key('inboxAcceptedShowDealAction')` → wechselt in Deals-Tab. |
| `/inbox` → Suggestion Sheet (Long-Press) | [`lib/screens/inbox_screen.dart`](../../lib/screens/inbox_screen.dart) (`_SuggestionCard._showSuggestionSheet`) | smoke-theme, mobile-overflow | Long-Press auf Suggestion-Card öffnet Bottom-Sheet mit 3 Aktionen: Verwerfen (`Key('inboxSuggestion-dismiss-{id}')`), Bearbeiten (`Key('inboxSuggestion-edit-{id}')`), Annehmen (`Key('inboxSuggestion-accept-{id}')`). Sheet-Root: `Key('inboxSuggestionSheet')`. |
| `/deals` → Comments-Section | [`lib/widgets/deal_comments_section.dart`](../../lib/widgets/deal_comments_section.dart) | smoke-theme |
| `/deals` → Attachment-Gallery | [`lib/widgets/attachment_gallery.dart`](../../lib/widgets/attachment_gallery.dart) | smoke-theme |
| `/deals` → Tracking-Review-Filter | [`lib/widgets/deal_table.dart`](../../lib/widgets/deal_table.dart) (`_FilterBar`) | smoke-tracking-review-chip | Filter-Chip „Prüfen ({count})" filtert auf `tracking_needs_review=true`. Sichtbar nur wenn Count > 0. Kein eigener Top-Level-Screen (Council-Finding #10). Banner in Inbox + Deals via `lib/widgets/tracking_banner_improved_detection.dart`. Badge auf Inbox-Nav-Tab (Index 3). |
| `/statistics` → Product-Drilldown | [`lib/widgets/statistics/product_drilldown_sheet.dart`](../../lib/widgets/statistics/product_drilldown_sheet.dart) | smoke-theme, mobile-overflow |
| `/warehouse` → Warengruppen (Sub-Route) | [`lib/screens/categories_screen.dart`](../../lib/screens/categories_screen.dart) | smoke-theme, mobile-overflow |
| `/warehouse` → Bestellungen (Sub-Route) | [`lib/screens/purchase_orders_screen.dart`](../../lib/screens/purchase_orders_screen.dart) | smoke-theme, mobile-overflow | Liste der Bestellungen mit Status-Badges; FAB „Neue Bestellung" (`Key('poNewFab')`). Sub-Route des Warenwirtschaft-Hubs, kein eigener MainTab. Viewer → FAB ausgeblendet. Epic C (C5). |
| `/warehouse` → Bestellungs-Detail (Sub-Route) | [`lib/screens/purchase_order_detail_screen.dart`](../../lib/screens/purchase_order_detail_screen.dart) | smoke-theme, mobile-overflow, goods-receipt-flow | Positionen, Wareneingang buchen (Soll/Ist-Stepper), Status, PDF-Export. A11y-Keys: `Key('poCard-<id>')`, `Key('goodsReceiptBookButton')`, `Key('poItemReceivedStepper-<id>')`, `Key('poPdfExportButton')`. Epic C (C6). |
| `/warehouse` → Lager (Sub-Route) | [`lib/screens/warehouses_screen.dart`](../../lib/screens/warehouses_screen.dart) | smoke-theme, mobile-overflow | Lager verwalten (CRUD). FAB „Neues Lager" (`Key('warehouseNewFab')`). Sub-Route des Warenwirtschaft-Hubs, kein eigener MainTab. Viewer → kein FAB. A11y-Keys: `Key('warehouseRow-<id>')`, `Key('warehouseDropdown')`. Epic D (D3). |
| `/warehouse` → Inventur (Sub-Route) | [`lib/screens/stocktake_screen.dart`](../../lib/screens/stocktake_screen.dart) | smoke-theme, mobile-overflow | Inventur-Sessionen auflisten; FAB „Neue Inventur" (`Key('stocktakeNewFab')`). Sub-Route des Warenwirtschaft-Hubs, kein eigener MainTab. Viewer → kein FAB. A11y-Keys: `Key('stocktakeRow-<id>')`. Epic E (E3). |
| `/warehouse` → Inventur-Detail (Sub-Route) | [`lib/screens/stocktake_detail_screen.dart`](../../lib/screens/stocktake_detail_screen.dart) | smoke-theme, mobile-overflow, stocktake-count-flow | Inventur durchführen: durchscrollbare 48dp-Liste, Filter „nur ungezählte" (`Key('stocktakeFilterUncounted')`), Fortschritts-Header, Barcode-Einsprung, Differenz-Report als vertikale Cards, Abschließen-Button (`Key('stocktakeCloseButton')`). A11y-Keys: `Key('stocktakeCountField-<id>')`. Epic E (E3). |

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
