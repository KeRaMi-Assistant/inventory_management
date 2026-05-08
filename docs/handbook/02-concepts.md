# 02 — Konzepte

Dieses Kapitel erklärt die zentralen Domänenbegriffe. Wer diese Konzepte
verinnerlicht hat, versteht den Rest der App fast ohne weitere Lektüre.

> Zur schnellen Nachschlage: Kompakte Definitionen findest du im
> [Glossar](10-glossary.md). Hier wird jeder Begriff im Kontext erklärt.

## Workspace

Ein **Workspace** ist die Mandanten-Klammer um alle Daten. Jede:r
eingeloggte User gehört zu mindestens einem Workspace; per Default wird beim
Sign-Up ein "Personal"-Workspace per DB-Trigger erzeugt. Für Teamarbeit
können weitere Workspaces angelegt und mit Mitgliedern bestückt werden.

- **Owner** — kann alles (inklusive Löschen + Mitglieder verwalten).
- **Admin** — Daten + Mitglieder verwalten, aber Workspace nicht löschen.
- **Member** — Daten lesen + schreiben, keine Mitglieder verwalten.
- **Viewer** — read-only, für Steuerberater oder externe Reviewer.

Alle Datentabellen (`deals`, `inventory_items`, `buyers`, `shops`,
`suppliers`, `tickets`, `parsed_messages`, …) tragen eine `workspace_id`-
Spalte. Die [RLS-Policies](10-glossary.md#rls) prüfen über die Helper
`is_workspace_member(workspace_id, auth.uid())` und
`has_workspace_role(...)` aus
[Migration `20260504000300_workspace_rls_fix.sql`](../../supabase/migrations/20260504000300_workspace_rls_fix.sql).

> Praktischer Effekt: Wenn du in der App in einen anderen Workspace
> wechselst, lädt der `InventoryProvider` alle Daten neu — siehe
> `lib/providers/active_workspace_provider.dart`.

**Wann ein Workspace?** Jeder, der eigene Daten verwaltet, hat einen.
Mehrere Workspaces sind die Ausnahme — z.B. wenn jemand neben dem
persönlichen Reseller-Geschäft auch ein Side-Shop-Team koordiniert.

## Deal

Ein **Deal** ist eine **Bestellung beim Shop, die du an einen Buyer
weiter-verkaufst** (oder die direkt an den Endkunden geht). Das ist das
Kern-Entity der App — alles dreht sich darum.

Ein Deal trägt mindestens:

| Feld | Bedeutung |
|---|---|
| `product` | freier Produktname (kein FK auf Inventory!) |
| `quantity` | Stückzahl |
| `shop` | Name des Quell-Shops (referenziert lose `shops.name`) |
| `shipping_type` | "Reship" (kommt zu mir, ich versende weiter) oder "Dropship" (geht direkt zum Buyer) |
| `order_date` | Bestelldatum |
| `ek_netto`/`ek_brutto`/`vk` | Einkaufs-/Verkaufspreis |
| `buyer` | freier Buyer-Name |
| `tracking` | Tracking-Nummer (oder mehrere kommagetrennt im UI) |
| `arrival_date` | Wann Sendung angekommen ist |
| `status` | `Bestellt` → `Unterwegs` → `Angekommen` → `Rechnung gestellt` → `Done` |
| `ticket_number` | Verbindung zum Discord-/Forum-Ticket des Käufers |
| `ticket_url` | externer Deep-Link |
| `beleg` | "Ja" / "Nein" — Buchhaltungs-Marker |

Statt `product`/`shop`/`buyer` als Foreign-Keys zu modellieren, sind das
**bewusst freie Strings**. Begründung: Reseller arbeiten mit unsauberen
Quellen (Mails, Discord-Dumps), und Stammdaten würden den Workflow ständig
blockieren. Stattdessen gibt es Stammdaten-Tabellen (`shops`, `buyers`,
`suppliers`) als **Hinweise** für Autocomplete und Statistik.

### Status-Lifecycle

```text
Bestellt ─► Unterwegs ─► Angekommen ─► Rechnung gestellt ─► Done
                                              │
                                              ▼
                                          (Archiv-Trigger)
```

Sobald `status = 'Done'` und `arrival_date` gesetzt sind, archiviert ein
DB-Trigger den Deal automatisch unter Tickets oder lässt ihn liegen, je
nach Konfiguration. Siehe
[Migration `20260509000300_archive_triggers.sql`](../../supabase/migrations/20260509000300_archive_triggers.sql).

## Inventory

Inventory ist der **physische Lagerbestand** im Reship-Modell: Was liegt
gerade hier, bevor es weitergeht? Es ist getrennt vom Deal, weil ein
Deal "nur" ein Auftrag ist — Inventory ist das *Stück Hardware*, das du in
der Hand hältst.

- **`inventory_items`** — Einzelartikel (Name, SKU, Menge, Lagerort,
  Kostenpreis, Status).
- **`inventory_movements`** — Buchungen, die einen Item-Stand ändern (rein,
  raus, gebucht-für-Deal). Append-only.
- **`inventory_batches`** — Charge eines Items (mit MHD, Lieferant,
  Eingangsdatum). Wird genutzt, wenn der Lieferant einen Posten in
  unterschiedlichen Lagen liefert.

Status-Werte für Items: `Im Lager`, `Reserviert`, `Versandt`, `Verkauft`.

`inventory_items.deal_id` referenziert optional einen Deal — z.B. wenn ein
Item exklusiv für einen bestimmten Auftrag liegt.

## Buyer

Ein **Buyer** ist ein **Käufer / Endkunde**. Im Resell-Workflow ist das oft
ein Discord-User oder Stammkunde. Der Buyer-Datensatz dient hauptsächlich:

- **Farbcodierung** in der Deal-Liste (`row_fill_color`,
  `buyer_cell_color`, `font_color`) — visuelle Unterscheidung im
  [Deal-Table](03-screens-walkthrough.md#deals).
- **Discord-Server-IDs** — JSON-Array, hilft beim Matchen über mehrere
  Communities.
- **`payment_status`** — "OK", "Mahnung", "Insolvent" o.ä.; UI badged das
  rot, wenn nicht "OK".

Buyer sind **bewusst kein Pflichtfeld** im Deal — manche Verkäufe gehen an
Walk-ins. Der freie Text-Buyer auf dem Deal kann mit oder ohne
`buyers`-Eintrag stehen.

## Shop

Ein **Shop** ist ein **Quell-Shop**, von dem eingekauft wird (Amazon,
MediaMarkt, PCComponentes etc.). Der Shop-Datensatz trägt:

- `name`, `region`, `channel` (z.B. "marketplace", "direkt").
- `url` — Direkter Link auf Login/Account-Seite.
- `active` — Inaktive Shops werden in Autocomplete unterdrückt.

Wichtig: `shop` im Deal ist **freier Text**, nicht FK auf `shops`.
Stammdaten-Eintrag = Hinweis für Autocomplete + Inbox-Mapping. Die
[Inbox-Adapter](04-inbox-mail-pipeline.md#shop-adapter) referenzieren Shops
über einen separaten `shop_key` (z.B. `amazon`, `mediamarkt`).

## Supplier

Ein **Supplier** ist ein **Großhändler**, von dem du Ware ohne Vermittlung
ziehst. Anders als ein Shop ist der Supplier oft mit Eingangs-Rechnungen,
Margen und Lieferzeiten verbunden.

- `name`, `contact_email`, `phone`, `notes`.
- `active`-Flag für ausgemusterte Quellen.

Suppliers tauchen in der [Inventory](#inventory)-Erfassung als
"Lieferant" auf. Im Deal-Kontext spielen sie keine direkte Rolle, weil ein
Deal mit Shop verknüpft ist (≠ Supplier-Bestellung).

## Ticket

Ein **Ticket** in der Domäne hier ist **kein Bug-Ticket** — es ist ein
**Verkaufs-Ticket** auf einer externen Plattform (Discord-Channel,
Forum-Thread). Mehrere Deals können demselben Ticket zugehören (Sammel-
Bestellung).

Felder:

| Feld | Bedeutung |
|---|---|
| `ticket_number` | externer Identifier (oft Discord-Thread-ID) |
| `archived_at` | gesetzt, wenn alle zugehörigen Deals "Done" sind |
| `archive_reason` | "manual" / "auto-archive" |

Der DB-Trigger
[`archive_triggers.sql`](../../supabase/migrations/20260509000300_archive_triggers.sql)
setzt automatisch `archived_at`, wenn alle verbundenen Deals fertig sind.
Reopen schreibt einen `null`-Wert zurück und lässt den Trigger wieder
greifen.

## Inbox / Postfach

Die **Inbox** ist die App-eigene Sicht auf eingehende Bestätigungs-Mails
aus den verknüpften IMAP-Postfächern. Eine Mail wird:

1. Vom Cron-Job **inbox-poll** über IMAP geholt.
2. Über die **Adapter-Registry** auf Shop-Match geprüft.
3. Bei erkanntem Shop → Felder extrahiert (`order_id`, `tracking`, `total`,
   …) und entweder als `pending_deal_suggestion` (neuer Deal-Vorschlag)
   oder direkt als `match_deal_id`-Zuweisung an einen bestehenden Deal
   verknüpft.
4. Im UI siehst du sie als **Inbox-Card** mit Badge `pending`,
   `suggested`, `matched` oder `unclassified`.

Mehr dazu in [04-inbox-mail-pipeline.md](04-inbox-mail-pipeline.md).

> **Sichtbarkeit (Plan-abhängig):** Der Inbox-Tab ist nur für Pläne mit
> `hasInbox = true` sichtbar. Free hat 0 Postfächer und 0 Sichtbarkeitstage.
> Der `BillingProvider` propagiert das nach `InboxProvider.applyPlanQuota`.

## Statistik

Die App rendert **Statistiken** auf Basis der Deal- und Inventory-Daten:

- **Umsatz pro Monat** (gefiltert nach Buyer/Shop/Status).
- **Marge** (`vk - ek_brutto`) pro Deal-Cluster.
- **Aktive Deals**, **offene Beträge**, **MHD-Warnungen** für Items.

`StatisticsService` und `StatisticsExportService` rechnen alles clientseitig
auf der schon geladenen Provider-Datenmenge — kein zusätzlicher Roundtrip.

## Activity-Log

Jede non-triviale Aktion (`createDeal`, `updateInventory`, `inviteUser`)
schreibt in `activity_log`. Anders als `audit_log` (workspace-scoped,
streng compliance-orientiert) ist `activity_log` ein **User-Heatmap-Stream**
für die UI. Der `ActivityScreen` rendert die letzten 50 Einträge.

Der Repository-Code limitiert die Tabelle auf 50 Einträge per
`trimActivityLog` — länger ist nicht nötig, weil das echte Audit über
`audit_log` läuft.

## Carrier-Credentials

Tracking-API-Keys (DHL, DPD, UPS) liegen in
`workspace_carrier_credentials`. Der Edge-Function-Cron `tracking-poll`
liest sie für offene Deals (`status='Unterwegs'`, `tracking IS NOT NULL`,
`arrival_date IS NULL`), ruft den Carrier ab und aktualisiert den Deal.

API-Keys werden in `pgp_sym_encrypt` mit einem Master-Key aus Supabase
Vault verschlüsselt — siehe
[Migration `20260508000000_workspace_carrier_credentials.sql`](../../supabase/migrations/20260508000000_workspace_carrier_credentials.sql).

## Plan / Billing

`PricingPlan` aus `lib/models/pricing_plan.dart` mappt das aktuelle
[Subscription-Level](10-glossary.md#plan) auf:

- `mailboxLimit` — wie viele IMAP-Konten der Workspace anhängen darf (Free=0).
- `inboxVisibilityDays` — wie weit zurück Mails sichtbar bleiben (Free=0).
- `hasInbox`, `hasTeam`, `hasInventory`, `hasStatistics`.

Der `BillingProvider` lädt das aktuelle Plan-Level via
`BillingService.load()` und propagiert es an die abhängigen Provider
(insb. `InboxProvider.applyPlanQuota`).

## Public Profile

Pro Workspace gibt es einen optionalen **öffentlichen Verkaufsprofil-Slug**
(`public_profile.handle`). Über `https://app/u/<handle>` rendert die App
ohne Login eine Read-only-Sicht — das wird in der Resell-Community gerne
als "öffentliche Visitenkarte" genutzt. Siehe
[Migration `20260510000000_public_profile.sql`](../../supabase/migrations/20260510000000_public_profile.sql)
und `lib/screens/public_profile_screen.dart`.

## Demo-Daten

`seed-demo-workspace` ist eine Edge Function, die für `test@test.com` den
eigenen Workspace zuerst leert und dann aus echten `parsed_messages` der
letzten 90 Tage hochwertige Demo-Datensätze erzeugt. Praktisch beim
Browser-Smoke-Test, sehr **kein Tool für Prod-Workspaces** (Hard-Constraint
im Function-Code: nur `test@test.com`).

## Zusammenspiel auf einen Blick

```text
auth.users  ──► workspaces  ─┬─► deals       ─► tickets
                             ├─► inventory_items ─► inventory_movements
                             │                  └─► inventory_batches
                             ├─► buyers, shops, suppliers
                             ├─► mailbox_accounts ─► parsed_messages
                             │                       └─► pending_deal_suggestions
                             ├─► workspace_carrier_credentials
                             ├─► billing_profiles, public_profile
                             └─► activity_log, audit_log
```

Workspace ist die Klammer, alles andere hängt darunter. Lies das einmal in
Ruhe, und der Rest des Codes erschließt sich von selbst.

## Quelle im Code

- [`lib/models/`](../../lib/models/) — Domain-Modelle (`deal.dart`, `buyer.dart`, `shop.dart`, `supplier.dart`, `ticket.dart`, `workspace.dart`, `inventory_item.dart`, `inventory_batch.dart`, `inbox_message.dart`, `pricing_plan.dart`)
- [`lib/providers/active_workspace_provider.dart`](../../lib/providers/active_workspace_provider.dart) — Workspace-State
- [`lib/providers/inventory_provider.dart`](../../lib/providers/inventory_provider.dart) — der größte Provider, hält Deals + Items
- [`lib/services/supabase_repository.dart`](../../lib/services/supabase_repository.dart) — typisierte CRUD-API
- [`supabase/migrations/20260430000000_initial_schema.sql`](../../supabase/migrations/20260430000000_initial_schema.sql) — Basis-Schema
- [`supabase/migrations/20260504000200_workspaces.sql`](../../supabase/migrations/20260504000200_workspaces.sql) — Workspace-Layer
- [`supabase/migrations/20260504000500_data_workspace_scope.sql`](../../supabase/migrations/20260504000500_data_workspace_scope.sql) — workspace-RLS
- [`supabase/migrations/20260507000000_inbox.sql`](../../supabase/migrations/20260507000000_inbox.sql) — Mailbox + parsed_messages
- [`supabase/migrations/20260509000000_tickets_table.sql`](../../supabase/migrations/20260509000000_tickets_table.sql) — Tickets
- [Glossar](10-glossary.md) — kurze Definitionen aller Begriffe
