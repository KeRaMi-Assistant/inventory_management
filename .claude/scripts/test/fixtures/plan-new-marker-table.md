# Test Plan: new table with [NEW] marker

Neue Tabelle `tracking_unicorn [NEW]`:

```sql
CREATE TABLE public.tracking_unicorn [NEW] (
  id UUID PRIMARY KEY
);
INSERT INTO tracking_unicorn [NEW] (id) VALUES (gen_random_uuid());
```
