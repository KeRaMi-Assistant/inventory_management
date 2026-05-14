# Test Plan: bad table

Wir lesen aus `public.tracking_unicorn`:

```sql
SELECT * FROM tracking_unicorn WHERE workspace_id = $1;
```
