---
slug: i18n-en-inventory-screen
priority: 9
plan: false
budget_usd: 4
---

`lib/screens/inventory_screen.dart` und alle direkt referenzierten Widgets:

Wie `s9-02-i18n-en-tickets-screen` — alle hardcoded Strings durch ARB-Keys
ersetzen, in beiden `app_de.arb` + `app_en.arb`.

Key-Naming: `inventory_<funktion>_<form>`.

Selbstcheck:
```bash
grep -nE "Text\\(['\"][A-Za-zäöüÄÖÜß]" lib/screens/inventory_screen.dart
```
→ leer.

`flutter analyze` + `flutter test` müssen grün sein.
