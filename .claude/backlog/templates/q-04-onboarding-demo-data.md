---
slug: onboarding-demo-data
priority: 6
plan: true
budget_usd: 6
---

First-Time-User-Flow + Demo-Daten-Loader.

1. **Onboarding-Screen** `lib/screens/onboarding_screen.dart` mit 6
   Steps (PageView):
   1. "Willkommen" + Logo-Animation
   2. Workspace anlegen / beitreten
   3. "Welche Shops nutzt du?" — Multi-Select aus Liste
   4. "Wer sind deine Lieferanten?" — Optional, Skip-Button
   5. "Erstes Ticket anlegen" — Mini-Form (kann skippen)
   6. "Discord + Postfach" — Hinweis dass das in Settings ist

2. **Routing-Logik** in `app.dart`:
   - Wenn `auth.user.firstSignIn AND no workspace` → Onboarding
   - Sonst → Dashboard

3. **Demo-Daten-Button** im Empty-State des Dashboards:
   - "Beispiel-Daten laden"
   - Lädt 5 Test-Tickets, 20 Inventory-Items, 3 Käufer aus einer
     fixen JSON-Liste in `assets/demo_data.json`
   - Markiert Items mit `is_demo = true` (neue Spalte)
   - Settings-Tab "Daten" bekommt einen "Demo-Daten löschen"-Button

Mobile-First (PFLICHT):
- Onboarding ist Phone-First-Carousel (PageView mit Indicator-Dots).
- Auf Tablet/Desktop: Centered max-width 480px.
- Skip-Button immer sichtbar.

l10n: `onboarding_*` (~20 Keys), DE + EN.

`flutter analyze` + `flutter test` müssen grün sein. `supabase db reset`
nach Migration grün.
