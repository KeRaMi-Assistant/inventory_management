# 00 — Capability-Overview

> Flach, scannbar, evidence-based. Antwort auf "Was kann diese App?".
> Jede Zeile referenziert einen Code-Anker, der wirklich in der Codebase
> existiert. Für tiefe Details: jeweilige Detail-Kapitel
> (siehe [README](README.md)).

## Inhalt

- [Screens (User-sichtbar)](#screens-user-sichtbar)
- [Pipelines](#pipelines)
- [Edge-Functions](#edge-functions)
- [Daten-Modell (Top-Level)](#daten-modell-top-level)
- [Auth / Workspace](#auth--workspace)
- [Billing / Pricing](#billing--pricing)
- [Notifications](#notifications)
- [Subagents (Tooling)](#subagents-tooling)
- [Stakeholder-Trigger (Power-User)](#stakeholder-trigger-power-user)

## Screens (User-sichtbar)

Canonical-Source: [`_page-registry.md`](../../.claude/agents/_page-registry.md).
Hier nur die Quintessenz pro Top-Level-Route — Sub-Routes/Dialogs nur,
wenn user-significant.

### Eingeloggter Bereich

| Route | Was es kann | Code-Anker |
|---|---|---|
| `/main` | App-Shell mit Bottom-Nav (Phone) bzw. NavigationRail (Desktop, `≥ 800px`), AppBar, Global-Search-Hotkey | [`lib/screens/main_screen.dart`](../../lib/screens/main_screen.dart) |
| `/dashboard` | KPI-Cards (Revenue, Profit, ROI), Recent-Deals, Skeleton-Loader | [`lib/screens/dashboard_screen.dart`](../../lib/screens/dashboard_screen.dart) |
| `/deals` | Deals-Tabelle + Detail-Sidebar (Desktop) / Stack (Phone), Filter, Tracking-Review-Chip | [`lib/screens/deals_screen.dart`](../../lib/screens/deals_screen.dart) |
| `/tickets` | Tickets mit Aktiv-/Archiv-Tabs | [`lib/screens/tickets_screen.dart`](../../lib/screens/tickets_screen.dart) |
| `/inbox` | 3 Tabs (Trackings, Bestellungen, Sonstiges), Suggestion-Accept-Flow, Mail-Details | [`lib/screens/inbox_screen.dart`](../../lib/screens/inbox_screen.dart) |
| `/inventory` | KPI-Header + Item-Tabelle + Barcode-Scan; Desktop-Master-Detail mit eingebettetem `ProductDetailScreen` | [`lib/screens/inventory_screen.dart`](../../lib/screens/inventory_screen.dart) |
| `/suppliers` | Lieferanten-CRUD | [`lib/screens/suppliers_screen.dart`](../../lib/screens/suppliers_screen.dart) |
| `/statistics` | KPI + Charts + Product-Drilldown, Excel-Export | [`lib/screens/statistics_screen.dart`](../../lib/screens/statistics_screen.dart) |
| `/activity` | Workspace-weiter Activity-Log | [`lib/screens/activity_screen.dart`](../../lib/screens/activity_screen.dart) |
| `/help` | FAQ + Search + Quick-Start | [`lib/screens/help_screen.dart`](../../lib/screens/help_screen.dart) |
| `/settings` | 8 Tabs: Buyers, Shops, Team, Push, Postfach, Shipping, Public profile, General | [`lib/screens/settings_screen.dart`](../../lib/screens/settings_screen.dart) |
| `/pricing` | Plan-Übersicht + Checkout-Trigger | [`lib/screens/pricing_screen.dart`](../../lib/screens/pricing_screen.dart) |
| `/billing-profile` | Rechnungs-Adresse, USt-ID, Push aus Pricing | [`lib/screens/billing_profile_screen.dart`](../../lib/screens/billing_profile_screen.dart) |
| `/warehouse` | Hub für Artikelstamm, Bestellungen, Lager, Kategorien, Inventur, Reporting; Desktop-Master-Detail | [`lib/screens/warehouse_hub_screen.dart`](../../lib/screens/warehouse_hub_screen.dart) |

### Warenwirtschaft-Sub-Routen

| Route | Was es kann | Code-Anker |
|---|---|---|
| `/warehouse` → Artikelstamm | Produktkatalog (CRUD via `AddEditProductDialog`) | [`lib/screens/product_catalog_screen.dart`](../../lib/screens/product_catalog_screen.dart) |
| `/warehouse` → Warengruppen | Kategorien-CRUD | [`lib/screens/categories_screen.dart`](../../lib/screens/categories_screen.dart) |
| `/warehouse` → Bestellungen | Liste mit Status-Badges, FAB für neue PO | [`lib/screens/purchase_orders_screen.dart`](../../lib/screens/purchase_orders_screen.dart) |
| `/warehouse` → Bestellungs-Detail | Positionen, Wareneingang buchen, PDF-Export | [`lib/screens/purchase_order_detail_screen.dart`](../../lib/screens/purchase_order_detail_screen.dart) |
| `/warehouse` → Lager | Lager-CRUD | [`lib/screens/warehouses_screen.dart`](../../lib/screens/warehouses_screen.dart) |
| `/warehouse` → Inventur | Inventur-Sessionen auflisten | [`lib/screens/stocktake_screen.dart`](../../lib/screens/stocktake_screen.dart) |
| `/warehouse` → Inventur-Detail | Zählung mit Filter, Differenz-Report, Abschluss | [`lib/screens/stocktake_detail_screen.dart`](../../lib/screens/stocktake_detail_screen.dart) |
| Inventory → Item-Tap | Artikel-Detail mit Stammdaten, Bewegungshistorie, Chargen | [`lib/screens/product_detail_screen.dart`](../../lib/screens/product_detail_screen.dart) |

### Auth & Onboarding

| Route | Was es kann | Code-Anker |
|---|---|---|
| `/splash` | Boot-Transient mit Logo + Spinner | [`lib/screens/auth/splash_screen.dart`](../../lib/screens/auth/splash_screen.dart) |
| `/login` | Email + Google + Apple, Personal-/Team-Modus | [`lib/screens/auth/login_screen.dart`](../../lib/screens/auth/login_screen.dart) |
| `/register` | Konto erstellen, Push aus Login | [`lib/screens/auth/register_screen.dart`](../../lib/screens/auth/register_screen.dart) |
| `/forgot-password` | Reset-Mail anfordern | [`lib/screens/auth/forgot_password_screen.dart`](../../lib/screens/auth/forgot_password_screen.dart) |
| `/reset-password` | Neues Passwort setzen via Recovery-Link | [`lib/screens/auth/reset_password_screen.dart`](../../lib/screens/auth/reset_password_screen.dart) |
| `/verify-email` | E-Mail-Verifikation nach Register | [`lib/screens/auth/verify_email_screen.dart`](../../lib/screens/auth/verify_email_screen.dart) |
| `/onboarding` | 6-Step-PageView für neue Workspace-Owner | [`lib/screens/onboarding_screen.dart`](../../lib/screens/onboarding_screen.dart) |
| `/u/<handle>` | Public-Profile, Web-only, ohne Login | [`lib/screens/public_profile_screen.dart`](../../lib/screens/public_profile_screen.dart) |

## Pipelines

| Pipeline | Was sie tut | Trigger | Code-Anker |
|---|---|---|---|
| Inbox-Poll (IMAP) | IMAP-Mails holen, normalisieren, speichern | Cron auf Edge-Function | [`supabase/functions/inbox-poll/index.ts`](../../supabase/functions/inbox-poll/index.ts) |
| Inbox-Parse | Mails → Tracking-Detection + Klassifizierung → Suggestions | Edge-Function nach Poll oder Re-Parse | [`supabase/functions/inbox-parse/index.ts`](../../supabase/functions/inbox-parse/index.ts) + [`supabase/functions/_shared/inbox_adapters.ts`](../../supabase/functions/_shared/inbox_adapters.ts) |
| Tracking-Poll | Carrier-APIs pollen → `deals.live_status` schreiben | Cron (pg_cron + pg_net) | [`supabase/functions/tracking-poll/index.ts`](../../supabase/functions/tracking-poll/index.ts) |
| Inbox-Match (Suggestion-Linking) | Pending-Suggestions an existierende Deals/Items zuordnen | Client-Side beim Accept | [`lib/services/inbox_match_service.dart`](../../lib/services/inbox_match_service.dart) |
| Send-Notifications | Push-Notifications (FCM) für Status-Changes + Inbox-Matches | Cron | [`supabase/functions/send-notifications/index.ts`](../../supabase/functions/send-notifications/index.ts) |
| Statistics-Berechnung | KPI- + Chart-Daten aggregieren | Client-Side beim Screen-Open | [`lib/services/statistics_service.dart`](../../lib/services/statistics_service.dart) |

## Edge-Functions

| Function | Trigger | Public API? | Was sie tut |
|---|---|---|---|
| `inbox-poll` | Cron | nein (service-role) | Pollt IMAP-Postfächer pro Workspace, speichert Raw-Mails | [`supabase/functions/inbox-poll/index.ts`](../../supabase/functions/inbox-poll/index.ts) |
| `inbox-parse` | Cron / Re-Parse-Trigger | nein | Tracking-Detection + Klassifizierung über `inbox_adapters.ts` | [`supabase/functions/inbox-parse/index.ts`](../../supabase/functions/inbox-parse/index.ts) |
| `tracking-poll` | Cron + Single-Deal-Force | nein | Carrier-APIs (DHL, Hermes, …) → `deals.live_status` | [`supabase/functions/tracking-poll/index.ts`](../../supabase/functions/tracking-poll/index.ts) |
| `send-notifications` | Cron | nein | FCM-Push für Status-Changes, Inbox-Matches, Low-Stock | [`supabase/functions/send-notifications/index.ts`](../../supabase/functions/send-notifications/index.ts) |
| `delete-account` | User-initiiert (Client-Call) | ja (anon, auth-gated) | Vollständiges Account-Löschen samt Daten | [`supabase/functions/delete-account/index.ts`](../../supabase/functions/delete-account/index.ts) |
| `seed-demo-workspace` | User-initiiert beim Onboarding | ja (anon, auth-gated) | Demo-Daten in den aktiven Workspace seeden | [`supabase/functions/seed-demo-workspace/index.ts`](../../supabase/functions/seed-demo-workspace/index.ts) |

## Daten-Modell (Top-Level)

Nur die wichtigsten Tabellen — Spalten-Details und RLS-Policies stehen in
[`06-database.md`](06-database.md). Alle Tabellen außer
`tracking_validation_cache` und `mailbox_credentials` sind
workspace-scoped via `workspace_id`-Spalte + RLS.

| Tabelle | Was sie hält | Workspace-Scoped | Migration |
|---|---|---|---|
| `workspaces` | Workspace-Stammsatz + Plan + Owner | n/a | [`20260504000200_workspaces.sql`](../../supabase/migrations/20260504000200_workspaces.sql) |
| `workspace_members` | Membership + Rolle (Owner/Admin/Editor/Viewer) | ja | [`20260504000200_workspaces.sql`](../../supabase/migrations/20260504000200_workspaces.sql) |
| `workspace_invites` | Offene Invite-Tokens | ja | [`20260504000200_workspaces.sql`](../../supabase/migrations/20260504000200_workspaces.sql) |
| `deals` | Deal-Stammsatz + Tracking + `live_status` | ja | [`20260430000000_initial_schema.sql`](../../supabase/migrations/20260430000000_initial_schema.sql) + [`20260515000000_deals_live_status.sql`](../../supabase/migrations/20260515000000_deals_live_status.sql) |
| `deal_comments` | Kommentare an Deals | ja | [`20260504000100_deal_comments.sql`](../../supabase/migrations/20260504000100_deal_comments.sql) |
| `tickets` | Support-/Reklamations-Tickets | ja | [`20260509000000_tickets_table.sql`](../../supabase/migrations/20260509000000_tickets_table.sql) |
| `buyers` | Käufer-Stammdaten | ja | [`20260430000000_initial_schema.sql`](../../supabase/migrations/20260430000000_initial_schema.sql) |
| `shops` | Verkaufsplattformen | ja | [`20260430000000_initial_schema.sql`](../../supabase/migrations/20260430000000_initial_schema.sql) |
| `suppliers` | Lieferanten-Stammdaten | ja | [`20260503000600_suppliers.sql`](../../supabase/migrations/20260503000600_suppliers.sql) |
| `products` | Produktkatalog (Stammartikel) | ja | [`20260522000609_products_catalog.sql`](../../supabase/migrations/20260522000609_products_catalog.sql) |
| `product_categories` | Warengruppen | ja | [`20260521222920_categories_supplier_extension.sql`](../../supabase/migrations/20260521222920_categories_supplier_extension.sql) |
| `product_suppliers` | Produkt↔Lieferant + Bestell-Konditionen | ja | [`20260522001308_product_stock_and_suppliers.sql`](../../supabase/migrations/20260522001308_product_stock_and_suppliers.sql) |
| `inventory_items` | Inventory-Items (verkaufsfähige Einheiten) | ja | [`20260430000000_initial_schema.sql`](../../supabase/migrations/20260430000000_initial_schema.sql) |
| `inventory_movements` | Bewegungs-Historie (getypt: purchase/sale/stocktake/…) | ja | [`20260430000000_initial_schema.sql`](../../supabase/migrations/20260430000000_initial_schema.sql) + [`20260521214855_movement_type_typed.sql`](../../supabase/migrations/20260521214855_movement_type_typed.sql) |
| `inventory_batches` | Chargen / Batch-Tracking | ja | [`20260503000700_batches.sql`](../../supabase/migrations/20260503000700_batches.sql) |
| `warehouses` | Lager-Stammsatz | ja | [`20260522015018_warehouses.sql`](../../supabase/migrations/20260522015018_warehouses.sql) |
| `purchase_orders` | Bestellungen (Header) | ja | [`20260522010918_purchase_orders.sql`](../../supabase/migrations/20260522010918_purchase_orders.sql) |
| `purchase_order_items` | Positionen pro Bestellung | ja | [`20260522010918_purchase_orders.sql`](../../supabase/migrations/20260522010918_purchase_orders.sql) |
| `stocktakes` | Inventur-Sessions | ja | [`20260522021641_stocktakes.sql`](../../supabase/migrations/20260522021641_stocktakes.sql) |
| `stocktake_items` | Zählwerte pro Inventur-Position | ja | [`20260522021641_stocktakes.sql`](../../supabase/migrations/20260522021641_stocktakes.sql) |
| `mailbox_accounts` | IMAP-Konten pro Workspace | ja | [`20260507000000_inbox.sql`](../../supabase/migrations/20260507000000_inbox.sql) |
| `mailbox_credentials` | IMAP-Passwörter (encrypted, service-role only) | indirekt | [`20260507000000_inbox.sql`](../../supabase/migrations/20260507000000_inbox.sql) |
| `parsed_messages` | Geparste Mails (Inbox-Items) | ja | [`20260507000000_inbox.sql`](../../supabase/migrations/20260507000000_inbox.sql) |
| `pending_deal_suggestions` | Vorgeschlagene Deals aus Mails | ja | [`20260507000000_inbox.sql`](../../supabase/migrations/20260507000000_inbox.sql) |
| `inbox_dismissals` | Verworfene Suggestions pro User | ja | [`20260507800000_inbox_dismissals.sql`](../../supabase/migrations/20260507800000_inbox_dismissals.sql) |
| `inbox_reads` | Read-Marker pro Mail/User | ja | [`20260507900000_inbox_reads.sql`](../../supabase/migrations/20260507900000_inbox_reads.sql) |
| `workspace_carrier_credentials` | Carrier-API-Keys pro Workspace | ja | [`20260508000000_workspace_carrier_credentials.sql`](../../supabase/migrations/20260508000000_workspace_carrier_credentials.sql) |
| `tracking_validation_cache` | Carrier-API-Antwort-Cache | nein (global) | [`20260517000000_tracking_validation_cache.sql`](../../supabase/migrations/20260517000000_tracking_validation_cache.sql) |
| `billing_profiles` | Rechnungs-Adresse + USt-ID | ja | [`20260504001000_billing_profiles.sql`](../../supabase/migrations/20260504001000_billing_profiles.sql) |
| `fcm_tokens` | FCM-Device-Tokens pro User | ja | [`20260503001000_push_notifications.sql`](../../supabase/migrations/20260503001000_push_notifications.sql) |
| `notification_preferences` | Per-User-Notify-Toggles | ja | [`20260503001000_push_notifications.sql`](../../supabase/migrations/20260503001000_push_notifications.sql) |
| `notifications_sent` | Notification-Outbox / Dedup | ja | [`20260503001000_push_notifications.sql`](../../supabase/migrations/20260503001000_push_notifications.sql) |
| `audit_log` | Audit-Trail (Workspace-Aktionen) | ja | [`20260504000200_workspaces.sql`](../../supabase/migrations/20260504000200_workspaces.sql) |
| `activity_log` | User-sichtbarer Activity-Feed | ja | [`20260430000000_initial_schema.sql`](../../supabase/migrations/20260430000000_initial_schema.sql) |
| `app_settings` | Per-User-Settings (Theme, Locale) | n/a | [`20260430000000_initial_schema.sql`](../../supabase/migrations/20260430000000_initial_schema.sql) |
| `attachments` | Datei-Anhänge an Deals/Mails | ja | [`20260503000900_attachments.sql`](../../supabase/migrations/20260503000900_attachments.sql) |

## Auth / Workspace

| Capability | Wie | Code-Anker |
|---|---|---|
| Email-Password-Login | Supabase Auth | [`lib/screens/auth/login_screen.dart`](../../lib/screens/auth/login_screen.dart) + [`lib/providers/auth_provider.dart`](../../lib/providers/auth_provider.dart) |
| Google Sign-In | OAuth via Supabase + `google_sign_in` | [`lib/providers/auth_provider.dart`](../../lib/providers/auth_provider.dart) |
| Apple Sign-In | OAuth via Supabase + `sign_in_with_apple` | [`lib/providers/auth_provider.dart`](../../lib/providers/auth_provider.dart) |
| Passwort-Reset (Mail) | Recovery-Flow via Supabase | [`lib/screens/auth/forgot_password_screen.dart`](../../lib/screens/auth/forgot_password_screen.dart) + [`lib/screens/auth/reset_password_screen.dart`](../../lib/screens/auth/reset_password_screen.dart) |
| Email-Verifikation | Bestätigungs-Mail nach Register | [`lib/screens/auth/verify_email_screen.dart`](../../lib/screens/auth/verify_email_screen.dart) |
| Multi-User-Workspace | RLS-basiert + Membership-Tabelle | [`lib/providers/active_workspace_provider.dart`](../../lib/providers/active_workspace_provider.dart) + [`lib/services/workspace_service.dart`](../../lib/services/workspace_service.dart) |
| Workspace-Wechsel | Live-Switcher mit Hydrator-Preset | [`lib/widgets/workspace_switcher.dart`](../../lib/widgets/workspace_switcher.dart) |
| Workspace-Invites | Token-basierte Einladungen (Editor/Viewer/Admin) | [`lib/widgets/invite_member_dialog.dart`](../../lib/widgets/invite_member_dialog.dart) + [`lib/providers/invites_provider.dart`](../../lib/providers/invites_provider.dart) |
| Session-Lifecycle | Idle-Timeout + Auto-Refresh + Ablauf-Warnung | [`lib/services/session_manager.dart`](../../lib/services/session_manager.dart) |
| Account-Löschen (DSGVO) | Edge-Function `delete-account` | [`supabase/functions/delete-account/index.ts`](../../supabase/functions/delete-account/index.ts) |
| Onboarding (6-Step) | Pflicht für neue Workspace-Owner | [`lib/screens/onboarding_screen.dart`](../../lib/screens/onboarding_screen.dart) + [`lib/providers/onboarding_provider.dart`](../../lib/providers/onboarding_provider.dart) |

## Billing / Pricing

| Capability | Wie | Code-Anker |
|---|---|---|
| Pricing-Tiers | Plan-Modell Free / Pro / Team etc. | [`lib/models/pricing_plan.dart`](../../lib/models/pricing_plan.dart) + [`lib/screens/pricing_screen.dart`](../../lib/screens/pricing_screen.dart) |
| Plan-Realignment-Migration | Aktuelles Plan-Schema | [`supabase/migrations/20260520000000_billing_plan_realign.sql`](../../supabase/migrations/20260520000000_billing_plan_realign.sql) |
| Billing-Profile | Rechnungs-Adresse + USt-ID | [`lib/providers/billing_provider.dart`](../../lib/providers/billing_provider.dart) + [`lib/services/billing_service.dart`](../../lib/services/billing_service.dart) |
| Feature-Gating | Tab-/Aktion-Sichtbarkeit per Plan | [`lib/providers/billing_provider.dart`](../../lib/providers/billing_provider.dart) (`hasInbox`, etc.) |
| Limit-Reached-Upsell | Modal-Dialog → Pricing-Push | [`lib/widgets/limit_reached_dialog.dart`](../../lib/widgets/limit_reached_dialog.dart) |

> Stripe-Integration ist noch nicht aktiviert (Pre-Launch). Pricing-Screen
> existiert als UI-Skelett, Checkout-Trigger ist Stub.

## Notifications

| Capability | Trigger | Channel | Code-Anker |
|---|---|---|---|
| Push (FCM) | Status-Changes, Inbox-Matches, Low-Stock | Mobile + Web | [`lib/services/push_service.dart`](../../lib/services/push_service.dart) + [`supabase/functions/send-notifications/index.ts`](../../supabase/functions/send-notifications/index.ts) |
| Notification-Preferences | Per-User-Toggles (Push-Kategorien) | App-intern | [`lib/services/push_service.dart`](../../lib/services/push_service.dart) (`NotificationPreferencesService`) |
| Low-Stock-Push | Bestand unterschreitet Min-Schwelle | Push | [`supabase/migrations/20260522015347_low_stock_notification_kind.sql`](../../supabase/migrations/20260522015347_low_stock_notification_kind.sql) |
| In-App-SnackBar | Aktionsbestätigungen, Fehler, Undo | App-intern | [`lib/widgets/app_feedback.dart`](../../lib/widgets/app_feedback.dart) |
| Invites-Bell | Workspace-Invites im AppBar | App-intern | [`lib/widgets/invites_bell.dart`](../../lib/widgets/invites_bell.dart) |
| Telegram-Bot (Dev-Only) | Stakeholder-Trigger, Yota-Snapshot | Phone | [`.claude/scripts/telegram-bot.py`](../../.claude/scripts/telegram-bot.py) |
| ntfy-Push (Dev-Only) | Heartbeat, Yota-Watch | Phone | [`.claude/scripts/notify.sh`](../../.claude/scripts/notify.sh) + [`.claude/scripts/heartbeat.sh`](../../.claude/scripts/heartbeat.sh) |

## Subagents (Tooling)

Dev-Workflow-Tools für Claude Code Sessions. Voller Modell-Routing-Plan
in [CLAUDE.md](../../CLAUDE.md).

| Trigger | Was es macht | Code-Anker |
|---|---|---|
| `/yota` | Status-Snapshot des Swarms (3-7 Zeilen) | [`.claude/agents/yota.md`](../../.claude/agents/yota.md) + [`.claude/scripts/yota-snapshot.sh`](../../.claude/scripts/yota-snapshot.sh) |
| `/btw <text>` | Stakeholder-Item ins Triage-Inbox | [`.claude/scripts/btw.sh`](../../.claude/scripts/btw.sh) + [`.claude/agents/stakeholder-triage.md`](../../.claude/agents/stakeholder-triage.md) |
| `/queue <text>` | Backlog-Item direkt anlegen | [`.claude/commands/queue.md`](../../.claude/commands/queue.md) |
| `/plan <feature>` | Plan-Erstellung (Architekt-Modus) | [`.claude/commands/plan.md`](../../.claude/commands/plan.md) + [`.claude/agents/planner.md`](../../.claude/agents/planner.md) |
| `/council <plan>` | 5-Reviewer-Council über einen Plan | [`.claude/commands/council.md`](../../.claude/commands/council.md) |
| `/ship` | Commit + Push + PR + Auto-Merge | [`.claude/commands/ship.md`](../../.claude/commands/ship.md) |
| `/test-ui <szenario>` | Browser-Smoke-Test via Playwright-MCP | [`.claude/commands/test-ui.md`](../../.claude/commands/test-ui.md) + [`.claude/agents/browser-tester.md`](../../.claude/agents/browser-tester.md) |
| `/check-l10n` | ARB-Symmetrie + Hardcoded-Strings prüfen | [`.claude/commands/check-l10n.md`](../../.claude/commands/check-l10n.md) + [`.claude/scripts/check-l10n.py`](../../.claude/scripts/check-l10n.py) |
| `/update-docs` | Handbuch + Page-Registry inkrementell pflegen | [`.claude/commands/update-docs.md`](../../.claude/commands/update-docs.md) + [`.claude/agents/doc-updater.md`](../../.claude/agents/doc-updater.md) |
| `/update-help` | Hilfeseite + ARB-Keys inkrementell pflegen | [`.claude/commands/update-help.md`](../../.claude/commands/update-help.md) + [`.claude/agents/help-curator.md`](../../.claude/agents/help-curator.md) |
| `/yota propose <idee>` | Intake-Council (3 Agents) vor Backlog-Aufnahme | [`.claude/scripts/yota-propose.sh`](../../.claude/scripts/yota-propose.sh) + [`.claude/scripts/intake-council.sh`](../../.claude/scripts/intake-council.sh) |

## Stakeholder-Trigger (Power-User)

Manuelle Hebel, die normalerweise vom Cron-Polling-Loop ausgelöst werden,
aber im UI verfügbar sind.

| Trigger | Wo | Was passiert | Code-Anker |
|---|---|---|---|
| Re-Parse aller Inbox-Mails | Settings → "Sendungsnummern neu prüfen" | Setzt Re-Parse-Marker, `inbox-parse` läuft über bestehende Bodies | [`lib/providers/inbox_provider.dart`](../../lib/providers/inbox_provider.dart) (`reparseTracking`) + [`.claude/scripts/trigger-reparse.sh`](../../.claude/scripts/trigger-reparse.sh) |
| Retrack Single Deal | Deal-Detail → Refresh-Icon | Sofort-`tracking-poll`-Call, 30s-Cooldown pro Deal | [`lib/services/supabase_repository.dart`](../../lib/services/supabase_repository.dart) (`retrackDeal`) + [`lib/providers/deals_provider.dart`](../../lib/providers/deals_provider.dart) |
| Barcode-Scan | Inventory / Stocktake / PO-Detail → Scan-Icon | Öffnet `BarcodeScannerSheet` (Kamera) | [`lib/widgets/barcode_scanner_sheet.dart`](../../lib/widgets/barcode_scanner_sheet.dart) |
| Wareneingang buchen | PO-Detail → "Wareneingang buchen" | Bestand wird inkrementiert, PO-Status aktualisiert | [`lib/screens/purchase_order_detail_screen.dart`](../../lib/screens/purchase_order_detail_screen.dart) + [`supabase/migrations/20260522032123_po_receive_increment.sql`](../../supabase/migrations/20260522032123_po_receive_increment.sql) |
| Inventur abschließen | Stocktake-Detail → "Abschließen" | Differenz-Report + Bestandsanpassung als `inventory_movements` | [`lib/screens/stocktake_detail_screen.dart`](../../lib/screens/stocktake_detail_screen.dart) |
| Demo-Daten seeden | Onboarding | Edge-Function-Call mit Demo-Workspace-Daten | [`lib/services/demo_data_service.dart`](../../lib/services/demo_data_service.dart) + [`supabase/functions/seed-demo-workspace/index.ts`](../../supabase/functions/seed-demo-workspace/index.ts) |
| Statistics-Export (Excel) | Statistics → Export-Button | KPI + Charts als `.xlsx` | [`lib/services/statistics_export_service.dart`](../../lib/services/statistics_export_service.dart) |
| CSV-Import / -Export | Inventory + Suppliers | CSV-Roundtrip für Stammdaten | [`lib/services/csv_service.dart`](../../lib/services/csv_service.dart) |
| PO-PDF-Export | PO-Detail | Bestellung als PDF generieren | [`lib/services/purchase_order_pdf_service.dart`](../../lib/services/purchase_order_pdf_service.dart) |
| Global-Search (Cmd+K) | App-Shell (Hotkey) | Cross-Domain-Suche mit Recent-Searches | [`lib/widgets/global_search_dialog.dart`](../../lib/widgets/global_search_dialog.dart) |
| Account-Löschen | Settings → General → "Konto löschen" | Edge-Function `delete-account` | [`supabase/functions/delete-account/index.ts`](../../supabase/functions/delete-account/index.ts) |

---

**Pflege:** Diese Datei ist der **flache Einstieg**. Wenn ein neues
Feature hinzukommt:

1. Code-Anker hier ergänzen (eine Zeile).
2. Detail in das passende Detail-Kapitel ([`03`](03-screens-walkthrough.md),
   [`05`](05-architecture.md), [`06`](06-database.md), [`07`](07-edge-functions.md)).
3. `_page-registry.md` ggf. updaten (Pflicht-Tests, Notizen).

Drift zwischen Code und Doku wird vom `doc-updater`-Agent (`/update-docs`)
inkrementell aufgefangen.
