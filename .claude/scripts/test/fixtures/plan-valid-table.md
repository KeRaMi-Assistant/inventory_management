# Test Plan: valid table

Wir lesen aus `public.deals`:

```sql
SELECT * FROM deals WHERE workspace_id = $1;
```
