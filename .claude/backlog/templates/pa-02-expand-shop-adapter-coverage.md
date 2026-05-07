---
slug: expand-shop-adapter-coverage
priority: 2
plan: true
test_scenario: smoke-inbox
---

## Symptom
User-Inbox zeigt **53 Unklassifizierte** Mails — der Parser hat sie
nicht zuordnen können. Das ist ~⅓ aller Mails.

## Diagnose-Source

User stellt manuell eine Sample-Liste bereit unter
`docs/unclassified_samples.md` (or er liefert sie im Run-Log nach).
**Falls die Datei fehlt**, brich ab und sag dem User klar:

> "Mir fehlt eine Sample-Liste der unklassifizierten Mails.
> Bitte stell sie unter `docs/unclassified_samples.md` mit folgendem
> Format bereit: pro Mail eine Section mit Subject + From-Domain +
> Body-Snippet (PII-redacted). Mind. 10 Beispiele."

Du darfst NICHT direkt gegen Cloud-DB pollen.

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

Du arbeitest auf opus, kein Budget-Cap. **Kein direkter Cloud-DB-Zugriff**
ohne explizite Permission. Wenn `docs/unclassified_samples.md` fehlt:
abbrechen, User informieren — kein Blind-Bauen.
