---
slug: tickets-table-migration
priority: 7
plan: false
budget_usd: 4
---

Erstelle eine Migration `supabase/migrations/<timestamp>_tickets_table.sql`,
die eine echte `tickets`-Tabelle anlegt + Backfill aus existierenden
`deals.ticket_number`-Werten macht.

Schema:
```sql
create table public.tickets (
  id bigint generated always as identity primary key,
  workspace_id uuid not null references workspaces(id) on delete cascade,
  ticket_number text not null,
  archived_at timestamptz,
  archived_reason text check (archived_reason in
    ('all_shipped','all_done','inventory_sold','manual')),
  archived_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique (workspace_id, ticket_number)
);
create index tickets_workspace_archived_idx
  on tickets(workspace_id, archived_at);
```

RLS-Policies (Workspace-Member-basiert, analog zu existierenden Policies
in `20260504000500_data_workspace_scope.sql`):
- SELECT: `is_workspace_member(workspace_id, auth.uid())`
- INSERT/UPDATE: `has_workspace_role(workspace_id, auth.uid(), ARRAY['owner','admin','member'])`

Backfill: für jedes distinct `(workspace_id, ticket_number)` aus `deals`
einen Row in `tickets` anlegen.

Anschließend Migration `<timestamp+1>_deals_ticket_id_fk.sql`:
- Spalte `deals.ticket_id bigint references tickets(id)` hinzufügen
- Backfill: `update deals set ticket_id = t.id from tickets t where ...`

`ticket_number` als generated-Column behalten für Backward-Compat.

Validierung: `supabase db reset` muss durchlaufen, danach:
```sql
select count(*) from tickets;
select count(*) from deals where ticket_id is not null;
```
beides > 0 (oder = 0 wenn Dev-DB leer ist — auch OK).
