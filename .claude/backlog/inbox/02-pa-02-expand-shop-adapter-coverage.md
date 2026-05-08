---
slug: expand-shop-adapter-coverage
priority: 2
plan: true
test_scenario: smoke-inbox
---

## Symptom
User-Inbox zeigt **53 Unklassifizierte** Mails — der Parser hat sie
nicht zuordnen können. Das ist ~⅓ aller Mails.

## Diagnose-Source — MCP-Supabase (PRIMÄR)

**Du HAST Cloud-Dev-DB-Zugriff** über den `mcp__supabase__*` MCP-Server
(read-only, project-scoped, vom User explizit erlaubt in
`.claude/settings.json`). NUTZE IHN.

Erste Aktion (PFLICHT):
```sql
SELECT
  COALESCE(payload->>'from_email', payload->>'from', 'unknown') AS from_email,
  payload->>'subject' AS sample_subject,
  COUNT(*) AS n
FROM parsed_messages
WHERE status = 'unclassified'
GROUP BY 1, 2
ORDER BY n DESC
LIMIT 25;
```

Daraus die Top-5 Domains ableiten. Für jede Top-Domain 2-3 weitere
Queries für `raw_subject` und `payload->>'body_excerpt'` (oder
äquivalent) — das sind deine Samples.

**FALLBACK (nur wenn MCP-Tool nicht verfügbar):**
`docs/unclassified_samples.md` lesen. Wenn auch das fehlt:
exit 1 mit Blocker-Report.

## Was zu tun ist (sobald Samples vorhanden)

1. Lese `docs/unclassified_samples.md`. Gruppiere nach From-Domain.
   Liste Top-5 Domains mit Mail-Anzahl.

2. Für die Top-5-Shops ohne Adapter neue Adapter bauen in
   `supabase/functions/_shared/inbox_adapters/<shop>.ts`. Wahrscheinliche
   Kandidaten (priorisiert nach Reseller-Domain-Wissen):
   - AliExpress (`mail.aliexpress.com`, `notify@aliexpress.com`)
   - BackMarket (`noreply@backmarket.com`)
   - Saturn / Mediamarkt (`info@saturn.de`, `info@mediamarkt.de`)
   - Notebooksbilliger (`info@notebooksbilliger.de`)
   - pccomponentes (`info@pccomponentes.com`)
   - Otto (`auftragsbestaetigung@otto.de`)
   - About You (`auto-mail@aboutyou.de`)
   - eBay (re-validate, evtl. neue Subject-Formate)

   Plus: Versanddienstleister-Direkt-Mails (DHL, Hermes, DPD) — keine
   Bestellungen, sondern Tracking-Updates. Wenn die als "Bestellungen"
   miss-klassifiziert werden, hier abfangen mit eigener Carrier-Adapter-
   Erkennung.

3. Pro Adapter (~50 Zeilen TS):
   - `match(rawMail) → boolean` (From-Domain + Subject-Pattern)
   - `extract(rawMail) → ParsedOrder` mit
     `{ orderId, items: [{name, qty, price}], total, currency, eta?, tracking? }`
   - Test mit 1-2 echten Mail-Snippets aus `docs/unclassified_samples.md`

4. Fallback-Parser für Long-Tail (verbleibende < 3 Mails pro Shop):
   - In `_shared/inbox_adapters/_fallback.ts`:
     - Order-ID via Subject-Regex (`\d{3}-\d{7}-\d{7}`, `#\d{6,}`,
       `Bestellung \d+`)
     - Total-Price (regex: `\d+,\d{2}\s*€`)
     - Tracking-Nummer (Carrier-spezifische Patterns)
   - Wenn alle drei extrahierbar: classify als `'fallback'`,
     erzeuge Vorschlags-Deal mit `confidence: low`
   - Sonst: bleibt `unclassified`

## Tests + Akzeptanz

- 5+ neue Adapter-Tests in `test/services/inbox_adapters_test.dart`
  (jeder Adapter mind. 1 Happy-Path + 1 Edge-Case)
- `flutter test` 70+ grün
- `smoke-inbox` Visual-Test passed
- PR-Body: "User-Action nach Merge — neue Mails einsammeln + bisherige
  53 Unclassified erneut durch Parser laufen lassen via
  `supabase functions invoke inbox-parse --body '{"reparse_unclassified": true}'`"
  (Edge Function muss Re-Parse-Mode unterstützen).

## Hinweis

Du arbeitest auf opus, kein Budget-Cap. MCP-Supabase ist primär (User
hat explizit `mcp__supabase__execute_sql` und `list_tables` in
permissions.allow gewhitelistet). NUR wenn MCP nicht verfügbar →
Fallback auf samples.md.
