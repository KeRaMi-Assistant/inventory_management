---
slug: seed-demo-workspace
priority: 4
plan: true
---

## Ziel
**Demo-fähigen Test-Workspace bauen.** Aktuell hat `test@test.com`:
1 Käufer (BountyTest), 9 Deals, 2 Lager-Artikel, 42 Vorschläge,
53 Unklassifizierte. Das ist nicht präsentations-würdig.

Wir wollen: **realistische Demo-Daten abgeleitet aus den echten
parsed_messages der letzten 90 Tage** — pseudo-anonymisiert.

## User hat dir Permission gegeben

Du darfst nach lokalem Test die Edge Function gegen die Cloud-Dev-DB
ausführen, um den Test-Workspace zurückzusetzen. **NUR test@test.com**,
keine anderen Workspaces. Hard-Block: nur wenn `auth.user.email =
'test@test.com'` lädt die Function — sonst RAISE EXCEPTION.

## Was zu tun ist

### 1. Edge Function `seed-demo-workspace`

`supabase/functions/seed-demo-workspace/index.ts`:

**Phase 1 — Cleanup:**
- Hole `workspace_id` von test@test.com (über Supabase Auth + workspace_members)
- DELETE FROM `deals`, `inventory_items`, `tickets`, `pending_deal_suggestions`,
  `parsed_messages` (außer letzte 90 Tage, die brauchen wir als Quelle),
  `activity_log`, `buyers`, `shops`, `suppliers` WHERE workspace_id = $1
- ON CASCADE räumt Sub-Tabellen mit weg

**Phase 2 — Seed:**
- Hole `parsed_messages` der letzten 90 Tage des Workspaces
- Für jede Bestätigungs-Mail (status='suggested'):
  - Erstelle einen `deal` mit:
    - `product_name` aus parsed payload
    - `shop_id` (lege Shop an falls nicht existiert)
    - `quantity` aus payload
    - `ek_brutto` aus payload total
    - `vk_brutto` = ek + 18% (realistischer Profit)
    - `status` random aus realistischem Mix:
      30% Bestellt, 25% Unterwegs, 15% Angekommen,
      10% Rechnung gestellt, 20% Done
    - `ticket_number` gruppiert (5-10 Tickets total mit jeweils 3-7 Deals)
    - `buyer_id` aus Pool von 5 pseudo-anonymen Käufern:
      Reseller_DE_01, Reseller_DE_02, ResellerKollege_München,
      Discord_BountyClient, Direkt_Sneaker_Reseller
- 8-12 `inventory_items` aus den meist-gekauften Produkten der Mails
- 5-8 `suppliers` aus den Top-Shops der Mails
- 3-5 `activity_log` Einträge der letzten 7 Tage

### 2. Hard-Constraints

```typescript
// am Anfang der Function:
const { data: { user } } = await supabase.auth.getUser(jwt);
if (!user || user.email !== 'test@test.com') {
  return new Response('Forbidden — only test@test.com', { status: 403 });
}
```

### 3. Lokal testen

1. `supabase functions serve seed-demo-workspace`
2. Mit Test-JWT von `test@test.com` invoken:
   ```bash
   curl -X POST http://localhost:54321/functions/v1/seed-demo-workspace \
     -H "Authorization: Bearer $TEST_JWT" -H "Content-Type: application/json"
   ```
3. Prüfe lokal in Supabase-Studio: workspace ist resettet + neu gefüllt.

### 4. Cloud-Dev ausführen

User hat dir explizit erlaubt. Schritte:
1. `supabase functions deploy seed-demo-workspace --project-ref <dev>`
2. Aus der App heraus loggen via test@test.com
3. JWT extrahieren (im Browser-localStorage `sb-...-auth-token`)
4. `curl` gegen Cloud-Dev-Endpoint (gleiche URL-Form, aber mit Cloud-Domain)
5. Verifizieren in Supabase-Studio Cloud-Dev: Test-Workspace befüllt
6. **Stop falls irgendwo `email !== 'test@test.com'` oder andere Workspace-IDs auftauchen**

## Akzeptanz

- Edge Fn ist lokal getestet + Cloud-Dev erfolgreich ausgeführt
- App-Login mit test@test.com zeigt:
  - 30-50 Deals in versch. Status
  - 5-8 Tickets (4-5 aktiv, 2-3 archiviert)
  - 8-12 Lager-Artikel
  - 5-8 Lieferanten
  - 5 Käufer mit pseudo-anonymen Namen
- Statistiken-Screen zeigt nicht-leere Charts (90-Tage-Trend)

## Hinweis

Du arbeitest auf opus, kein Budget-Cap. Dies ist eine **destruktive
Operation auf einer geteilten DB** — auch wenn nur Test-Account, sei
sehr vorsichtig. Bei JEDER Unsicherheit: STOP, dokumentiere, lass
User entscheiden.
