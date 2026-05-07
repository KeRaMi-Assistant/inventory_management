---
slug: i18n-en-tickets-screen
priority: 9
plan: false
budget_usd: 4
---

`lib/screens/tickets_screen.dart` und alle direkt referenzierten Widgets:

1. Suche alle hardcoded Strings (Pattern `Text(['"][A-Za-zäöüÄÖÜß]`,
   `label: ['"]...`, `hintText: ['"]...`).
2. Pro String: neuer Key in `lib/l10n/app_de.arb` + `app_en.arb`.
   Key-Naming: `tickets_<funktion>_<form>` (z.B.
   `tickets_filter_open`, `tickets_card_status_done`).
3. Ersetze hardcoded String mit `AppLocalizations.of(context)!.<key>`.
4. `flutter gen-l10n` läuft automatisch via Hook.

Selbstcheck am Ende:
```bash
grep -nE "Text\\(['\"][A-Za-zäöüÄÖÜß]" lib/screens/tickets_screen.dart
```
→ leer.

`flutter analyze` + `flutter test` müssen grün sein.
