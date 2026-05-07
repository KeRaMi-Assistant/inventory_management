---
slug: deals-shipped-at
priority: 7
plan: false
budget_usd: 2
---

Migration `supabase/migrations/<timestamp>_deals_shipped_at.sql`:
- Spalte `deals.shipped_at timestamptz` hinzufügen (NULL = noch nicht
  versendet)
- Index `deals_shipped_at_idx on deals(workspace_id, shipped_at)`
- Backfill: für `deals` mit `status = 'Done'` und `arrival_date IS NOT NULL`
  setze `shipped_at = arrival_date - interval '2 days'` (best-effort
  Annahme, dokumentieren im Migration-Comment)

Modell-Update in `lib/models/`: füge `shippedAt: DateTime?` zum `Deal`
Modell hinzu (toJson, toSupabaseInsert, fromSupabase erweitern).

`supabase db reset` muss grün durchlaufen. `flutter analyze` clean.
