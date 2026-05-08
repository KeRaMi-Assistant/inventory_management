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
created_at, updated_at, deleted_at TIMESTAMPTZ
```

Indexe auf `workspace_id`, `(workspace_id, order_date DESC)`, `ticket_id`,
`tracking`.

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
created_at, updated_at, deleted_at TIMESTAMPTZ
```

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
created_at, processed_at TIMESTAMPTZ
```

UNIQUE-Indexe: `(account_id, message_uid)` und `(account_id, message_hash)`
— siehe Dedup-Logik in [04-inbox-mail-pipeline.md](04-inbox-mail-pipeline.md#dedup-logik).

### `workspace_carrier_credentials`

Verschlüsselte Carrier-API-Keys (DHL, DPD, UPS) pro Workspace. Selbes
Vault-Pattern wie Mailbox.

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

## Cron-Jobs (pg_cron)

Datei:
[`20260503001100_enable_cron.sql`](../../supabase/migrations/20260503001100_enable_cron.sql)

Aktivierte Jobs (siehe Migrations + Edge-Function-SETUPs):

| Jobname | Schedule | Effekt |
|---|---|---|
| `cleanup_inbox_history_daily` | `15 3 * * *` (täglich 03:15 UTC) | Mails > 30 Tage löschen |
| `inbox-poll` | `*/5 * * * *` | siehe [04-inbox-mail-pipeline.md](04-inbox-mail-pipeline.md) |
| `tracking-poll` | `0 */4 * * *` | Carrier-API-Refresh |
| `send-notifications` | hängt von Setup ab | Push-Trigger |

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
