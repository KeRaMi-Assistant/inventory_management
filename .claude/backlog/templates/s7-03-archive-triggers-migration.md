---
slug: archive-triggers
priority: 7
plan: false
budget_usd: 3
---

**Voraussetzung:** `s7-01-tickets-table-migration` und `s7-02-deals-shipped-at`
müssen schon gelaufen sein. Falls nicht: brich ab und melde dem Caller.

Migration `supabase/migrations/<timestamp>_archive_triggers.sql`:

Trigger 1 — nach `UPDATE` auf `deals`:
```sql
create function public.tg_check_ticket_archive_from_deal() returns trigger as $$
begin
  -- wenn alle Deals des Tickets shipped_at IS NOT NULL OR status = 'Done':
  -- archive Ticket mit reason 'all_shipped' oder 'all_done'
  ...
end $$ language plpgsql security definer;
```

Trigger 2 — nach `UPDATE` auf `inventory_items`:
```sql
create function public.tg_check_ticket_archive_from_inventory() returns trigger as $$
begin
  -- wenn alle Inventory-Items des Tickets in Status ('Verkauft','Versandt'):
  -- archive Ticket mit reason 'inventory_sold'
  ...
end $$ language plpgsql security definer;
```

Idempotent: nicht erneut archivieren wenn `archived_at` schon gesetzt.

Test in Migration-File: 1× Insert-Trigger-Demo am Ende auskommentiert
zur Doku.

`supabase db reset` muss grün durchlaufen.
