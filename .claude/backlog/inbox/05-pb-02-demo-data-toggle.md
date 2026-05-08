---
slug: demo-data-toggle
priority: 5
plan: false
test_scenario: smoke-login
---

## Ziel
Settings-Tab "Allgemein" um Demo-Reset-Button erweitern, damit der
User den Demo-Workspace ohne Code-Edit zurücksetzen kann.

## Was zu tun ist

In `lib/screens/settings_screen.dart` am Ende des "Allgemein"-Tabs:

```
Section "Demo / Daten"
  - Card: "Demo-Daten neu laden"
    Beschreibung: "Setzt diesen Workspace zurück und füllt ihn mit
                   30-50 realistischen Beispiel-Deals aus deinen Mails
                   der letzten 90 Tage. Alle aktuellen Daten gehen
                   verloren."
    Button: "Demo neu laden" → Confirmation-Dialog → ruft Edge Function
            seed-demo-workspace auf
```

Nur sichtbar wenn `auth.user.email == 'test@test.com'`. Sonst Card
ausgeblendet.

l10n-Keys: `settings_demo_section`, `settings_demo_reload`,
`settings_demo_reload_confirm`, `settings_demo_reload_success`,
`settings_demo_reload_error` — DE + EN.

## Akzeptanz

- Settings → Allgemein zeigt für test@test.com Card
- Click → Confirm → Loading-Indicator → Erfolg-SnackBar
- Anschließend Reload des Inventory-Providers, App zeigt frische Daten
- Für andere User-Accounts: Card unsichtbar

## Hinweis

Ruft die in pb-01 gebaute Edge Function. Wenn pb-01 noch nicht gemerged
ist: brich ab.
