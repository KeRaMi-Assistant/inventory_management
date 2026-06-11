# 06 — Datenbank

Die App lebt auf **Supabase** (Postgres 15+ mit RLS). Dieses Kapitel
beschreibt das Schema, die [RLS-Strategie](10-glossary.md#rls), die
Migrationskonventionen und die wichtigsten Indexe.

> Begriffe wie *Workspace*, *Service-Role*, *Vault*, *pg_cron* sind im
> [Glossar](10-glossary.md) erklärt.

## Schema-Übersicht

Alle Tabellen liegen im `public`-Schema. Workspace-gescoped sind:

| Tabelle | Zweck | Migration |
|---|---|---|
| `workspaces` | Mandanten-Klammer | `20260504000200_workspaces.sql` |
| `workspace_members` | User ↔ Workspace + Rolle | `20260504000200_workspaces.sql` |
| `workspace_invites` | Einladungstokens | `20260504000200_workspaces.sql` |
| `audit_log` | Compliance-Spur | `20260504000200_workspaces.sql` |
| `deals` | Kern-Bestellungen | `20260430000000_initial_schema.sql` |
| `buyers` | Endkunden | `20260430000000_initial_schema.sql` |
| `shops` | Quell-Shops | `20260430000000_initial_schema.sql` |
| `suppliers` | Lieferanten | `20260503000600_suppliers.sql` |
| `inventory_items` | Lagerartikel | `20260430000000_initial_schema.sql` |
| `inventory_movements` | Item-Bewegungen | `20260430000000_initial_schema.sql` |
| `inventory_batches` | Chargen | `20260503000700_batches.sql` |
| `tickets` | Verkaufs-Tickets | `20260509000000_tickets_table.sql` |
| `deal_comments` | Kommentare am Deal | `20260504000100_deal_comments.sql` |
| `activity_log` | UI-Heatmap | `20260430000000_initial_schema.sql` |
| `mailbox_accounts` | IMAP-Konten | `20260507000000_inbox.sql` |
| `mailbox_credentials` | verschlüsselte Passwörter | `20260507000000_inbox.sql` |
| `parsed_messages` | geparste Mails | `20260507000000_inbox.sql` |
| `pending_deal_suggestions` | Adapter-Vorschläge | `20260507000000_inbox.sql` |
| `inbox_dismissals` | Dismiss-Flags | `20260507800000_inbox_dismissals.sql` |
| `inbox_reads` | Read-Marker | `20260507900000_inbox_reads.sql` |
| `workspace_carrier_credentials` | DHL/DPD/UPS-Keys | `20260508000000_workspace_carrier_credentials.sql` |
| `billing_profiles` | Rechnungs-Stammdaten | `20260504001000_billing_profiles.sql` |
| `public_profile` | öffentlicher Verkaufs-Slug | `20260510000000_public_profile.sql` |
| `product_categories` | Warengruppen (hierarchisch, max. 2 Ebenen) | `20260521222920_categories_supplier_extension.sql` |
| `products` | Artikel-Stammkatalog (1× pro SKU, n× Bestand) | `20260522000609_products_catalog.sql` |
| `product_suppliers` | Artikel↔Lieferant n:m mit Lieferant-SKU + -Preis | `20260522001308_product_stock_and_suppliers.sql` |
| `purchase_orders` | Bestell-Kopf (Einkaufsbestellungen) | `20260522010918_purchase_orders.sql` |
| `purchase_order_items` | Bestell-Positionen (Kind-Tabelle) | `20260522010918_purchase_orders.sql` |
| `warehouses` | Strukturierte Lagerorte | `20260522015018_warehouses.sql` |
| `stocktakes` | Inventur-Sessions (Kopf) | `20260522021641_stocktakes.sql` |
| `stocktake_items` | Inventur-Positionen (Zähl-Kind-Tabelle) | `20260522021641_stocktakes.sql` |
| `tracking_events` | Carrier-Event-Historie pro Deal (Klarna-Style-Timeline) | `20260610090000_tracking_events.sql` |

Views (kein eigener Tabellen-Eintrag in Supabase-Studio, aber abfragbar wie eine Tabelle):

| View | Zweck | Migration |
|---|---|---|
| `product_stock` | Bestand pro `(workspace_id, product_id, warehouse_id)` | `20260522001308_product_stock_and_suppliers.sql` |

User-gescoped (nicht Workspace):

| Tabelle | Zweck | Migration |
|---|---|---|
| `app_settings` | Per-User-Settings (Theme, Sprache) | `20260430000000_initial_schema.sql` |
| `fcm_tokens` | Geräte-Tokens für Push | `20260503001000_push_notifications.sql` |
| `notification_preferences` | Push-Präferenzen | `20260503001000_push_notifications.sql` |
| `notifications_sent` | Dedup für versendete Push | `20260503001000_push_notifications.sql` |

## Workspace-Modell — RLS-Helper

Datei:
[`supabase/migrations/20260504000300_workspace_rls_fix.sql`](../../supabase/migrations/20260504000300_workspace_rls_fix.sql)

Zwei zentrale `SECURITY DEFINER`-Funktionen, auf denen alle RLS-Policies
aufbauen:

```sql
public.is_workspace_member(_workspace_id UUID, _user_id UUID) RETURNS BOOLEAN
public.has_workspace_role(_workspace_id UUID, _user_id UUID, _roles TEXT[]) RETURNS BOOLEAN
```

Pattern für jede Datentabelle (vereinfacht):

```sql
CREATE POLICY tablename_ws_read ON public.tablename FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY tablename_ws_insert ON public.tablename FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY tablename_ws_update ON public.tablename FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));
CREATE POLICY tablename_ws_delete ON public.tablename FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));
```

Konvention: `viewer` darf lesen, schreibt aber nichts. `owner`, `admin`,
`member` dürfen schreiben.

## Auto-Provisioning des Personal-Workspaces

Trigger auf `auth.users`:

```sql
CREATE TRIGGER trg_provision_personal_workspace
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.provision_personal_workspace();
```

Die Function legt:

1. Einen Eintrag in `workspaces` (Name `'Personal'`, Owner = neuer User).
2. Einen Eintrag in `workspace_members` mit Rolle `owner`.

→ Damit hat **jeder neue User automatisch einen Workspace**, ohne dass die
App das vor dem ersten Login wissen muss.

## Schema im Detail

### `deals`

```sql
id              BIGSERIAL PRIMARY KEY,
workspace_id    UUID NOT NULL,
user_id         UUID NOT NULL,
product         TEXT NOT NULL,
quantity        INTEGER NOT NULL DEFAULT 1,
shipping_type   TEXT NOT NULL CHECK (... 'Reship', 'Dropship'),
shop            TEXT NOT NULL,
order_date      TIMESTAMPTZ NOT NULL,
ek_netto        NUMERIC(12,2),
ek_brutto       NUMERIC(12,2),
vk              NUMERIC(12,2),
buyer           TEXT,
ticket_number   TEXT,
ticket_url      TEXT,
tracking        TEXT,
arrival_date    TIMESTAMPTZ,
shipped_at      TIMESTAMPTZ,                    -- 20260509000200
status          TEXT NOT NULL DEFAULT 'Bestellt',
beleg           TEXT NOT NULL DEFAULT 'Nein',
lexware         TEXT,
note            TEXT,
ticket_id       INTEGER REFERENCES tickets(id), -- 20260509000100
tax_rate_pct    NUMERIC(5,2),                   -- 20260503000800
currency        TEXT DEFAULT 'EUR',             -- 20260503000800
internal_invoice_sent BOOLEAN DEFAULT FALSE,    -- 20260504000000
internal_invoice_paid BOOLEAN DEFAULT FALSE,    -- 20260504000000
tracking_confidence   TEXT CHECK (... 'strong','manual','none'),  -- 20260513183000
tracking_needs_review BOOLEAN NOT NULL DEFAULT FALSE,             -- 20260513183000
live_status           TEXT,                                       -- 20260515000000
live_status_last_event TEXT,                                      -- 20260515000000
live_status_updated_at TIMESTAMPTZ,                               -- 20260515000000
carrier               TEXT CHECK (carrier IS NULL OR carrier IN
                        ('dhl','amazon','dpd','gls','ups')),       -- 20260603074312 / 20260610150000
live_eta              TIMESTAMPTZ,                                 -- 20260610090000
last_polled_at        TIMESTAMPTZ,                                 -- 20260610090000
created_at, updated_at, deleted_at TIMESTAMPTZ
```

Die `carrier`-Spalte hält den lowercase-Carrier-Key. Migration
[`20260610150000_deals_carrier_gls.sql`](../../supabase/migrations/20260610150000_deals_carrier_gls.sql)
erweitert den CHECK auf `'gls'` + `'ups'` — damit ist er die **Obermenge**
aller Carrier in der kanonischen Registry
[`carriers.ts`](../../supabase/functions/_shared/carriers.ts) (Audit-Fix
„Carrier 3-fach inkonsistent"). `amazon` + `gls` sind dabei
[detection-only](10-glossary.md#detection-only-carrier) (kein Live-Poll).

`live_eta` (geschätztes Zustellfenster, Quelle Carrier-API oder Mail-ETA)
und `last_polled_at` (letzter **erfolgreicher** Poll, getrennt vom letzten
Status-Wechsel `live_status_updated_at`) kamen mit Migration
[`20260610090000_tracking_events.sql`](../../supabase/migrations/20260610090000_tracking_events.sql).
`last_polled_at` steuert die [adaptive Poll-Frequenz](07-edge-functions.md#tracking-poll)
und den 30s-Retrack-Cooldown.

Indexe auf `workspace_id`, `(workspace_id, order_date DESC)`, `ticket_id`,
`tracking`, Partial-Index `deals_needs_tracking_review_idx`
(`(workspace_id, tracking_needs_review) WHERE tracking_needs_review = TRUE`)
und `deals_live_status_idx` für den Live-Status-Filter (`live_status` IS NOT NULL).
`live_status_updated_at` dient zusätzlich als implizites Cooldown-Feld für
den Single-Deal-Re-Track-Pfad (siehe
[07 — Edge Functions](07-edge-functions.md#tracking-poll)).
Siehe [04 — Inbox-Pipeline](04-inbox-mail-pipeline.md#strict-tracking-extraction-confidence-modell)
für die Semantik der beiden neuen Spalten.

### `inventory_items`

```sql
id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
workspace_id  UUID NOT NULL,
user_id       UUID NOT NULL,
name          TEXT NOT NULL,
sku           TEXT,
quantity      INTEGER NOT NULL DEFAULT 0,
min_stock     INTEGER NOT NULL DEFAULT 0,
location      TEXT,
cost_price    NUMERIC(12,2),
arrival_date  TIMESTAMPTZ,
deal_id       BIGINT REFERENCES deals(id) ON DELETE SET NULL,
ticket_number TEXT,
ticket_url    TEXT,
note          TEXT,
status        TEXT NOT NULL DEFAULT 'Im Lager',
ean           TEXT,                  -- 20260503000500
product_id    UUID REFERENCES products(id) ON DELETE SET NULL,  -- 20260522000927 (nullable, dauerhaft)
warehouse_id  UUID REFERENCES warehouses(id) ON DELETE SET NULL, -- 20260522000927 + D1-FK
created_at, updated_at, deleted_at TIMESTAMPTZ
```

`product_id` ist **dauerhaft nullable** (Committee-Finding 2): bestehende
Items ohne Stammkatalog-Bezug funktionieren unverändert; nur neue
Wareneingänge/PO-Receipts verknüpfen auf ein `products`-Record. Der
FK-Cross-Workspace-Trigger `inventory_items_product_id_ws_check`
verhindert Cross-Workspace-Referenzen auch auf Service-Role-Ebene.

### `tickets`

Datei:
[`20260509000000_tickets_table.sql`](../../supabase/migrations/20260509000000_tickets_table.sql)

```sql
id             BIGSERIAL PRIMARY KEY,
workspace_id   UUID NOT NULL,
ticket_number  TEXT NOT NULL,
title          TEXT,
archived_at    TIMESTAMPTZ,
archive_reason TEXT,
created_at, updated_at TIMESTAMPTZ,
UNIQUE (workspace_id, ticket_number)
```

### `inventory_movements` (Erweiterung)

Migration
[`20260521214855_movement_type_typed.sql`](../../supabase/migrations/20260521214855_movement_type_typed.sql)
ergänzt zwei neue Spalten additiv (bestehende Rows bleiben unberührt,
kein Schema-Break):

```sql
movement_type TEXT NOT NULL DEFAULT 'correction'
  CHECK (movement_type IN
    ('goods_in','goods_out','correction','stocktake','transfer','sale')),
unit_cost     NUMERIC(12,2)   -- nullable, Einstandspreis der Buchung
```

`reason` bleibt als optionale Freitext-Notiz erhalten.
`product_id UUID REFERENCES products(id)` (nullable, Migration
[`20260522000927`](../../supabase/migrations/20260522000927_inventory_product_link.sql))
ermöglicht katalogweite Auswertungen in der Produkt-Detail-Ansicht.

`inventory_movements` ist **append-only** — keine UPDATE/DELETE-Policy,
keine `deleted_at`-Spalte. Korrekturbuchungen laufen über Gegenbuchungen
mit `movement_type='correction'`. Inventurausgleiche schreiben
`movement_type='stocktake'`.

### `suppliers` (Erweiterung)

Migration
[`20260521222920_categories_supplier_extension.sql`](../../supabase/migrations/20260521222920_categories_supplier_extension.sql)
ergänzt 9 nullable Kreditoren-Stammdaten-Spalten:

```sql
address_street     TEXT,
address_zip        TEXT,
address_city       TEXT,
address_country    TEXT DEFAULT 'DE',
vat_id             TEXT,           -- USt-IdNr
customer_number    TEXT,           -- Kundennummer beim Lieferanten
payment_terms_days INTEGER,        -- Zahlungsziel (Tage)
lead_time_days     INTEGER,        -- Lieferzeit (Tage)
min_order_value    NUMERIC(12,2)   -- Mindestbestellwert
```

Kein Backfill (Pre-Launch, keine echten Daten). Alle Felder sind nullable
und rückwärtskompatibel.

### `product_categories`

Datei:
[`supabase/migrations/20260521222920_categories_supplier_extension.sql`](../../supabase/migrations/20260521222920_categories_supplier_extension.sql)

```sql
id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
user_id      UUID NOT NULL REFERENCES auth.users(id),
name         TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
parent_id    UUID REFERENCES product_categories(id) ON DELETE SET NULL,
sort_order   INTEGER NOT NULL DEFAULT 0,
created_at, updated_at, updated_by, version TIMESTAMPTZ/INT,
deleted_at   TIMESTAMPTZ
```

Self-referenziell über `parent_id` — max. 2 Hierarchie-Ebenen
(App-seitig validiert). FK-Cross-Workspace-Trigger
`product_categories_parent_id_ws_check` verhindert Cross-Workspace-
Referenzen bei `parent_id`. Standard-4-Policy-RLS + `touch_row`-Trigger.

### `products`

Datei:
[`supabase/migrations/20260522000609_products_catalog.sql`](../../supabase/migrations/20260522000609_products_catalog.sql)

```sql
id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
workspace_id        UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
user_id             UUID NOT NULL REFERENCES auth.users(id),
name                TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 200),
sku                 TEXT,    -- Partial-UNIQUE auf lower(sku) pro Workspace (non-NULL)
ean                 TEXT,    -- CHECK: 8/12/13/14 Ziffern (nullable)
category_id         UUID REFERENCES product_categories(id) ON DELETE SET NULL,
default_supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL,
unit                TEXT NOT NULL DEFAULT 'Stk',
default_cost_price  NUMERIC(12,2),
default_sale_price  NUMERIC(12,2),
min_stock           INTEGER NOT NULL DEFAULT 0,
tax_rate            NUMERIC(5,2),
note                TEXT,
is_active           BOOLEAN NOT NULL DEFAULT TRUE,
is_demo             BOOLEAN NOT NULL DEFAULT FALSE,
created_at, updated_at, updated_by, version TIMESTAMPTZ/INT,
deleted_at          TIMESTAMPTZ
```

Standard-4-Policy-RLS + `touch_row`-Trigger. FK-Cross-Workspace-Trigger
`products_fks_ws_check` deckt `category_id` + `default_supplier_id` ab.
Partial-UNIQUE `products_workspace_sku_uidx` auf `lower(sku)` sichert
SKU-Eindeutigkeit pro Workspace (nur für gesetzte + nicht gelöschte SKUs).

### `product_suppliers`

Datei:
[`supabase/migrations/20260522001308_product_stock_and_suppliers.sql`](../../supabase/migrations/20260522001308_product_stock_and_suppliers.sql)

n:m-Verknüpfung zwischen `products` und `suppliers`:

```sql
id             UUID PRIMARY KEY,
workspace_id   UUID NOT NULL,
user_id        UUID NOT NULL,
product_id     UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
supplier_id    UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
supplier_sku   TEXT,
supplier_price NUMERIC(12,2),
is_preferred   BOOLEAN NOT NULL DEFAULT FALSE,
created_at, updated_at, updated_by, version TIMESTAMPTZ/INT,
deleted_at     TIMESTAMPTZ
```

Zwei Partial-UNIQUE-Indexe: eindeutige `(product_id, supplier_id)`-Kombi
und maximal ein `is_preferred`-Lieferant pro Produkt.

### `product_stock` (View)

Datei:
[`supabase/migrations/20260522001308_product_stock_and_suppliers.sql`](../../supabase/migrations/20260522001308_product_stock_and_suppliers.sql)

```sql
CREATE VIEW public.product_stock
WITH (security_invoker = true) AS
SELECT workspace_id, product_id, warehouse_id,
       SUM(quantity) AS qty_in_warehouse
FROM inventory_items
WHERE deleted_at IS NULL AND product_id IS NOT NULL
GROUP BY workspace_id, product_id, warehouse_id;
```

**Die einzige Bestands-Wahrheit** für Low-Stock-Alerts und
Produkt-Detail-Aggregation. `security_invoker = true` (PG 15+) sorgt
dafür, dass die `inventory_items_ws_read`-RLS des aufrufenden Users
greift — die View erbt die Workspace-Isolation implizit.
Rows ohne `product_id` fallen bewusst raus (kein Mindestbestand-Ziel).

### `purchase_orders`

Datei:
[`supabase/migrations/20260522010918_purchase_orders.sql`](../../supabase/migrations/20260522010918_purchase_orders.sql)

```sql
id            BIGSERIAL PRIMARY KEY,
workspace_id  UUID NOT NULL,
user_id       UUID NOT NULL,
supplier_id   UUID NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
order_number  TEXT NOT NULL,  -- Partial-UNIQUE pro Workspace (non-deleted)
status        TEXT NOT NULL DEFAULT 'draft'
  CHECK (status IN ('draft','ordered','partially_received','received','cancelled')),
order_date    TIMESTAMPTZ,
expected_date TIMESTAMPTZ,
note          TEXT,
total_net     NUMERIC(12,2),
created_at, updated_at, updated_by, version TIMESTAMPTZ/INT,
deleted_at    TIMESTAMPTZ
```

Status-Automat: `draft → ordered → partially_received / received →
cancelled`. Statuswechsel auf `partially_received`/`received` erfolgt
automatisch per DB-Trigger (`purchase_order_items_status_trg`), der
auf UPDATE von `purchase_order_items.quantity_received` feuert — die
App setzt den Status **nicht** manuell.

### `purchase_order_items`

Kind-Tabelle zu `purchase_orders` (gleiche Migration):

```sql
id                UUID PRIMARY KEY,
workspace_id      UUID NOT NULL,
purchase_order_id BIGINT NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
product_id        UUID REFERENCES products(id) ON DELETE RESTRICT,
description       TEXT NOT NULL,
quantity_ordered  INTEGER NOT NULL DEFAULT 1,
quantity_received INTEGER NOT NULL DEFAULT 0,
unit_price        NUMERIC(12,2),
created_at, updated_at, updated_by, version TIMESTAMPTZ/INT
```

`quantity_received` wird atomar via der SECURITY-DEFINER-RPC
`increment_po_item_received(p_item_id, p_qty)` inkrementiert — kein
Client-seitiges Read-modify-write. Über-Buchungs-Schranke im
RPC-Body: `quantity_received + p_qty ≤ quantity_ordered`.

### `warehouses`

Datei:
[`supabase/migrations/20260522015018_warehouses.sql`](../../supabase/migrations/20260522015018_warehouses.sql)

```sql
id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
user_id      UUID NOT NULL,
name         TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
address      TEXT,
is_default   BOOLEAN NOT NULL DEFAULT FALSE,
is_active    BOOLEAN NOT NULL DEFAULT TRUE,
created_at, updated_at, updated_by, version TIMESTAMPTZ/INT,
deleted_at   TIMESTAMPTZ
```

Partial-UNIQUE auf `(workspace_id) WHERE is_default`: maximal **ein**
Default-Lager pro Workspace. Das erste Lager wird App-seitig beim
ersten Workspace-Touch angelegt (kein DB-Trigger). Standard-4-Policy-RLS
+ `touch_row`-Trigger.

### `notifications_sent` (Erweiterung)

Migration
[`20260522015347_low_stock_notification_kind.sql`](../../supabase/migrations/20260522015347_low_stock_notification_kind.sql)
erweitert den `ref_kind`-CHECK-Constraint und ergänzt eine nullable
`workspace_id`-Spalte:

```sql
-- CHECK-Constraint (ALT):
ref_kind IN ('mhd','delivery','payment')
-- CHECK-Constraint (NEU):
ref_kind IN ('mhd','delivery','payment','low_stock')

-- Neue Spalte (additiv, nullable):
workspace_id UUID REFERENCES workspaces(id) ON DELETE CASCADE
```

`workspace_id` ermöglicht Workspace-gescoped Dedup des
`low_stock`-Alerts (max. ein Push pro Workspace + Kalender-Tag). Der
PK `(user_id, ref_kind, ref_id)` bleibt unverändert.

Migration
[`20260610090000_tracking_events.sql`](../../supabase/migrations/20260610090000_tracking_events.sql)
erweitert den CHECK ein weiteres Mal:

```sql
-- CHECK-Constraint (NEU):
ref_kind IN ('mhd','delivery','payment','low_stock','tracking_status')
```

`tracking_status` deckt die **Status-Wechsel-Pushes** ab, die
[`tracking-poll`](07-edge-functions.md#tracking-poll) bei einem
Live-Status-Wechsel sofort sendet (Claim-then-Send-Dedup pro
Deal + Status).

### `stocktakes`

Datei:
[`supabase/migrations/20260522021641_stocktakes.sql`](../../supabase/migrations/20260522021641_stocktakes.sql)

```sql
id           BIGSERIAL PRIMARY KEY,
workspace_id UUID NOT NULL,
user_id      UUID NOT NULL,
warehouse_id UUID REFERENCES warehouses(id) ON DELETE SET NULL,
status       TEXT NOT NULL DEFAULT 'open'
  CHECK (status IN ('open','counting','closed','cancelled')),
title        TEXT,
started_at   TIMESTAMPTZ,
closed_at    TIMESTAMPTZ,
created_at, updated_at, updated_by, version TIMESTAMPTZ/INT,
deleted_at   TIMESTAMPTZ
```

### `stocktake_items`

Kind-Tabelle zu `stocktakes` (gleiche Migration):

```sql
id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
workspace_id UUID NOT NULL,
stocktake_id BIGINT NOT NULL REFERENCES stocktakes(id) ON DELETE CASCADE,
product_id   UUID REFERENCES products(id) ON DELETE RESTRICT,
item_id      UUID REFERENCES inventory_items(id) ON DELETE SET NULL,
qty_expected INTEGER NOT NULL DEFAULT 0,  -- Soll-Bestand
qty_counted  INTEGER,                     -- Ist-Bestand (NULL = noch ungezählt)
note         TEXT,
created_at, updated_at, updated_by, version TIMESTAMPTZ/INT
```

Beim Schließen einer Inventur erzeugt die App pro Differenz
(`qty_counted ≠ qty_expected`) eine `inventory_movements`-Row mit
`movement_type='stocktake'` (append-only).

### `tracking_events`

Datei:
[`supabase/migrations/20260610090000_tracking_events.sql`](../../supabase/migrations/20260610090000_tracking_events.sql)

```sql
id           BIGSERIAL PRIMARY KEY,
deal_id      BIGINT NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
tracking     TEXT NOT NULL,           -- Teil des Dedup-Keys (Tracking-Wechsel = frische Timeline)
carrier      TEXT,
occurred_at  TIMESTAMPTZ NOT NULL,
status       TEXT CHECK (status IN
               ('pending','in_transit','out_for_delivery','delivered','exception')),
raw_code     TEXT,
description  TEXT NOT NULL DEFAULT '',  -- Writer kürzt auf 500 Zeichen VOR Upsert (Teil des Dedup-Keys)
location     TEXT,
source       TEXT NOT NULL DEFAULT 'poll' CHECK (source IN ('poll','mail','manual')),
created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
CONSTRAINT tracking_events_dedup UNIQUE (deal_id, tracking, occurred_at, description)
```

**Carrier-Event-Historie pro Deal** (Klarna-Style-Timeline). Bisher
persistierte nur `deals.live_status_last_event` den letzten Event-Text;
die Carrier-APIs liefern aber den kompletten Verlauf, der ab jetzt bei
jedem Poll idempotent upserted wird (`ON CONFLICT DO NOTHING` über den
Dedup-UNIQUE). Ohne den Dedup-Key würde die Tabelle pro Poll wachsen —
`description` ist `NOT NULL DEFAULT ''`, weil UNIQUE NULLs als distinct
behandelt (= Duplikate). Der **einzige Writer** ist die
[`tracking-poll`](07-edge-functions.md#tracking-poll)-Edge-Function
(Service-Role).

**RLS:** nur eine `tracking_events_ws_read`-SELECT-Policy für
Workspace-Mitglieder. **Keine** INSERT/UPDATE/DELETE-Policy → default-deny
für `authenticated`; Schreiben darf nur der Service-Role-Pfad (bypassed
RLS). Indexe: `(deal_id, occurred_at DESC)` für die Timeline-Query und
`(workspace_id)`. Siehe [Glossar](10-glossary.md#tracking_events) und die
UI-Anbindung in [03 — Screens](03-screens-walkthrough.md#deals).

### `mailbox_accounts` & `mailbox_credentials`

Zwei Tabellen, weil das Sicherheits-Modell streng ist:

- `mailbox_accounts` — sichtbar für Workspace-Mitglieder (read), schreibbar
  nur für Owner/Admin.
- `mailbox_credentials` — **keine** RLS-Policies. Nur die
  `SECURITY DEFINER`-RPCs `set_mailbox_password(uuid, text)` und
  `get_mailbox_password(uuid)` (nur `service_role`) kommen ran.

Verschlüsselung: `pgp_sym_encrypt(<password>, master_key)`. Master-Key
kommt aus `vault.decrypted_secrets` (`name='mailbox_master_key'`) oder
fallback auf `current_setting('app.mailbox_master_key', true)` für
Self-Hosted-Setups.

### `parsed_messages`

```sql
id              UUID PRIMARY KEY,
workspace_id    UUID NOT NULL,
account_id      UUID NOT NULL,
message_uid     BIGINT NOT NULL,
message_hash    TEXT NOT NULL,
from_address    TEXT,
subject         TEXT,
received_at     TIMESTAMPTZ NOT NULL,
shop_key        TEXT,
parsed_payload  JSONB,
status          TEXT NOT NULL DEFAULT 'pending',
match_deal_id   BIGINT REFERENCES deals(id),
error           TEXT,
tracking_confidence    TEXT CHECK (... 'strong','medium','weak','none'),  -- 20260513183500
tracking_needs_review  BOOLEAN NOT NULL DEFAULT FALSE,                    -- 20260513183500
created_at, processed_at TIMESTAMPTZ
```

UNIQUE-Indexe: `(account_id, message_uid)` und `(account_id, message_hash)`
— siehe Dedup-Logik in [04-inbox-mail-pipeline.md](04-inbox-mail-pipeline.md#dedup-logik).
Partial-Index `parsed_messages_needs_tracking_review_idx` auf
`(workspace_id, tracking_needs_review) WHERE tracking_needs_review = TRUE`
für den Re-Parse-Sweep (siehe [Strict-Tracking-Pipeline](04-inbox-mail-pipeline.md#strict-tracking-extraction-confidence-modell)).

Zusätzliche Strict-Tracking-Spalten:

- `pending_deal_suggestions.tracking_confidence TEXT CHECK (... 'strong','none')`
  (Migration `20260513183000_strict_tracking_schema.sql`).
- `mailbox_accounts.last_reparse_at TIMESTAMPTZ` — 5-Minuten-Cooldown
  für den Re-Parse-Trigger aus den Settings (siehe
  [07 — Edge Functions](07-edge-functions.md#inbox-parse)).

### `workspace_carrier_credentials`

Verschlüsselte Carrier-API-Keys (DHL, DPD, UPS) pro Workspace. Selbes
Vault-Pattern wie Mailbox.

Migration
[`20260610090000_tracking_events.sql`](../../supabase/migrations/20260610090000_tracking_events.sql)
ergänzt zwei Tages-Quota-Spalten:

```sql
daily_call_count INTEGER NOT NULL DEFAULT 0,
daily_call_date  DATE
```

Harter Guard gegen einen Quota-Riss beim
[adaptiven Polling](07-edge-functions.md#tracking-poll): DHL erlaubt
1.000 Queries/Tag, wir kappen bei **900** pro Workspace×Carrier. Der
Zähler wird ausschließlich über die SECURITY-DEFINER-RPC
`bump_carrier_daily_calls(_workspace_id, _carrier_id, _calls, _today,
_last_error)` inkrementiert — ein **atomares** UPDATE in einem Statement
(row-level lock), damit parallele Poll-Läufe (stündlicher Sweep +
Event-Trigger-Polls) sich die Zähler nicht via Lost-Update-Race
überschreiben. Datums-Rollover (anderes `daily_call_date`) startet den
Zähler neu. `GRANT EXECUTE` nur an `service_role` (REVOKE von
`anon`/`authenticated`).

### `audit_log` vs. `activity_log`

| Tabelle | Zweck | Bereich |
|---|---|---|
| `activity_log` | UI-Stream der letzten User-Aktionen | per Workspace, max 50 Einträge |
| `audit_log` | Compliance-Trail für Team-Mode | per Workspace, append-only, kein User-Insert (Trigger/Edge-Fn schreibt) |

`audit_log.action` ∈ `{create, update, delete, restore, invite, accept,
revoke, role_change}`. `diff` ist JSONB mit `before`/`after`.

## Migrations-Konventionen

- **Namensschema:** `YYYYMMDDHHMMSS_<slug>.sql`. Anlegen via:

  ```bash
  supabase migration new <slug>
  ```

- **RLS ist Pflicht.** Default-Deny, dann gezielt erlauben.
- **Lokal getestet** mit `supabase db reset`, bevor Push gegen Cloud.
- **Kein `supabase db push --include-all`**, sondern explizit. Wir wollen,
  dass der Reviewer sieht, was Stand ist.
- **Idempotent** wo sinnvoll (`IF NOT EXISTS`, `DROP POLICY IF EXISTS`).
- **`SECURITY DEFINER` vorsichtig.** Search-Path explizit setzen
  (`SET search_path = public, vault`), `REVOKE EXECUTE ... FROM PUBLIC`,
  dann gezielt `GRANT ... TO authenticated/service_role`.

## Indexierung

Faustregel: **Pro Workspace-Filter ein Index.** Beispiele:

- `deals_workspace_idx` auf `(workspace_id)`.
- `deals_user_order_date_idx` auf `(user_id, order_date DESC)`.
- `mailbox_accounts_poll_idx` auf `(last_polled_at NULLS FIRST) WHERE enabled = TRUE`.
- `parsed_messages_pending_idx` auf `(status) WHERE status = 'pending'`.

Partial-Indexe sind Standard, weil sie bei stark gefilterten Queries
(`enabled=true`, `status='pending'`) deutlich performanter sind.

## Soft-Delete

Datei:
[`20260503000100_soft_delete.sql`](../../supabase/migrations/20260503000100_soft_delete.sql)

`deleted_at`-Spalte auf `deals`, `inventory_items` u.a. — Default-Filter
in App prüft `deleted_at IS NULL`. So kann man "wiederherstellen"
ermöglichen, ohne FKs zu zerstören.

## Audit-Spalten

Datei:
[`20260503000000_audit_columns.sql`](../../supabase/migrations/20260503000000_audit_columns.sql)

`created_at`, `updated_at` (Trigger setzt `updated_at` auf NOW()),
optional `deleted_at`. Pattern für Trigger:

```sql
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := NOW(); RETURN NEW; END;
$$;
```

## Constraints & Checks

Datei:
[`20260503000200_check_constraints.sql`](../../supabase/migrations/20260503000200_check_constraints.sql)

Beispiele:

- `quantity > 0`
- `shipping_type IN ('Reship', 'Dropship')`
- `status IN ('Bestellt','Unterwegs','Angekommen','Rechnung gestellt','Done')`
- `length(name) BETWEEN 1 AND 80`

## Trigger-Übersicht

| Trigger | Effekt |
|---|---|
| `trg_provision_personal_workspace` | Neuer User → Personal-Workspace + Member |
| `mailbox_accounts_set_updated_at` | `updated_at` aktualisieren |
| `archive_triggers.sql` | Tickets autom. archivieren wenn alle Deals "Done" |
| `set_updated_at` (mehrfach) | Standard-Touch-Trigger |
| `trg_touch_product_categories` | `touch_row` auf `product_categories` |
| `trg_touch_products` | `touch_row` auf `products` |
| `trg_touch_product_suppliers` | `touch_row` auf `product_suppliers` |
| `trg_touch_purchase_orders` | `touch_row` auf `purchase_orders` |
| `trg_touch_purchase_order_items` | `touch_row` auf `purchase_order_items` |
| `purchase_order_items_status_trg` | Status `purchase_orders` bei Wareneingang automatisch setzen (`partially_received`/`received`) |
| `trg_touch_warehouses` | `touch_row` auf `warehouses` |
| `trg_touch_stocktakes` | `touch_row` auf `stocktakes` |
| `trg_touch_stocktake_items` | `touch_row` auf `stocktake_items` |
| `inventory_items_product_id_ws_check` | Cross-Workspace-Schutz für `inventory_items.product_id` |
| `inventory_movements_product_id_ws_check` | Cross-Workspace-Schutz für `inventory_movements.product_id` |
| `products_fks_ws_check` | Cross-Workspace-Schutz für `products.category_id` + `.default_supplier_id` |
| `product_suppliers_fks_ws_check` | Cross-Workspace-Schutz für `product_suppliers.product_id` + `.supplier_id` |

### RPC `increment_po_item_received`

Datei:
[`supabase/migrations/20260522032123_po_receive_increment.sql`](../../supabase/migrations/20260522032123_po_receive_increment.sql)

```sql
public.increment_po_item_received(p_item_id UUID, p_qty INTEGER)
RETURNS SETOF public.purchase_order_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
```

Atomar-Increment von `purchase_order_items.quantity_received` ohne
Client-seitiges Read-modify-write. Checks im Body:

1. Workspace-Rollen-Check: Caller muss `owner`/`admin`/`member` sein.
2. Über-Buchungs-Schranke: `quantity_received + p_qty ≤ quantity_ordered`.

Auf das UPDATE feuert `purchase_order_items_status_trg` → aktualisiert
`purchase_orders.status` automatisch. `GRANT EXECUTE` nur an
`authenticated` (nicht `anon`/`public`). Siehe
[07 — Edge Functions](07-edge-functions.md) für den UI-Aufrufpfad.

### RPC `bump_carrier_daily_calls`

Datei:
[`supabase/migrations/20260610090000_tracking_events.sql`](../../supabase/migrations/20260610090000_tracking_events.sql)

```sql
public.bump_carrier_daily_calls(
  _workspace_id UUID, _carrier_id TEXT, _calls INTEGER,
  _today DATE, _last_error TEXT DEFAULT NULL)
RETURNS void
LANGUAGE sql SECURITY DEFINER
SET search_path = public
```

Atomarer Tages-Quota-Bump auf `workspace_carrier_credentials` (siehe
[oben](#workspace_carrier_credentials)). Increment in **einem** Statement
(row-level lock durch `UPDATE`), damit parallele
[`tracking-poll`](07-edge-functions.md#tracking-poll)-Läufe sich die
Zähler nicht via Lost-Update-Race überschreiben. Datums-Rollover →
Zähler startet neu. `GRANT EXECUTE` nur an `service_role` (REVOKE von
`anon`/`authenticated`).

## Cron-Jobs (pg_cron)

Datei:
[`20260503001100_enable_cron.sql`](../../supabase/migrations/20260503001100_enable_cron.sql)

Aktivierte Jobs (siehe Migrations + Edge-Function-SETUPs):

| Jobname | Schedule | Effekt |
|---|---|---|
| `cleanup_inbox_history_daily` | `15 3 * * *` (täglich 03:15 UTC) | Mails > 30 Tage löschen |
| `inbox-poll` | `*/5 * * * *` | siehe [04-inbox-mail-pipeline.md](04-inbox-mail-pipeline.md) |
| `tracking-poll-adaptive` | `7 * * * *` (stündlich, Minute :07) | Carrier-API-Refresh, In-Function-Gating + Quiet-Hours + Quota-Guard |
| `send-notifications` | hängt von Setup ab | Push-Trigger |

> Der alte `tracking-poll-daily`-Job (`0 */4 * * *`, 1×/Tag) wurde von
> Migration
> [`20260610090100_tracking_poll_adaptive_cron.sql`](../../supabase/migrations/20260610090100_tracking_poll_adaptive_cron.sql)
> auf den stündlichen `tracking-poll-adaptive`-Sweep umgestellt
> (`mode='adaptive-sweep'`). Die Frequenz-Logik liegt **in** der Edge-Function
> (siehe [07 — Edge Functions](07-edge-functions.md#tracking-poll)).

> Cron-Setup ist in den Function-`SETUP.md`s dokumentiert (siehe z.B.
> [`tracking-poll/SETUP.md`](../../supabase/functions/tracking-poll/SETUP.md)).

## Backfill-Strategien

Bei Schema-Änderungen, die existierende Daten betreffen, wird der Backfill
in derselben Migration mitgeschrieben. Beispiel aus
[`20260504000500_data_workspace_scope.sql`](../../supabase/migrations/20260504000500_data_workspace_scope.sql):

1. `workspace_id`-Spalte nullable hinzufügen.
2. Backfill: Jede Row bekommt die ID des **ältesten** Workspaces des Owners.
3. `NOT NULL` setzen + Index.
4. Alte `user_id`-RLS-Policies droppen, neue Workspace-Policies anlegen.

## Reset & Reseed (lokal)

```bash
supabase db reset                     # alle Migrations frisch
psql "$LOCAL_DB_URL" -f seed.sql       # optional eigenes Seed
```

> Kein automatisches Seed-File im Repo — Demo-Daten kommen über die
> Edge-Function `seed-demo-workspace` und sind auf den Test-Account
> beschränkt.

## Quelle im Code

- [`supabase/migrations/`](../../supabase/migrations/) — alle Migrations chronologisch
- [`supabase/migrations/20260430000000_initial_schema.sql`](../../supabase/migrations/20260430000000_initial_schema.sql) — Basis-Tabellen
- [`supabase/migrations/20260504000200_workspaces.sql`](../../supabase/migrations/20260504000200_workspaces.sql) — Workspace-Modell
- [`supabase/migrations/20260504000300_workspace_rls_fix.sql`](../../supabase/migrations/20260504000300_workspace_rls_fix.sql) — RLS-Helper
- [`supabase/migrations/20260504000500_data_workspace_scope.sql`](../../supabase/migrations/20260504000500_data_workspace_scope.sql) — Daten auf Workspace umstellen
- [`supabase/migrations/20260507000000_inbox.sql`](../../supabase/migrations/20260507000000_inbox.sql) — Mailbox + Vault
- [`supabase/migrations/20260508000000_workspace_carrier_credentials.sql`](../../supabase/migrations/20260508000000_workspace_carrier_credentials.sql) — Carrier-Keys
- [`supabase/migrations/20260509000000_tickets_table.sql`](../../supabase/migrations/20260509000000_tickets_table.sql) — Tickets
- [`supabase/migrations/20260509000300_archive_triggers.sql`](../../supabase/migrations/20260509000300_archive_triggers.sql) — Archive-Trigger
- [Glossar](10-glossary.md) — Begriffsdefinitionen
