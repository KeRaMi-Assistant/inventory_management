---
slug: dark-mode-toggle
priority: 8
plan: false
budget_usd: 3
---

Dark-Mode-Toggle in `lib/screens/settings_screen.dart`.

1. Audit: `grep -rE "Color\\(0xFF[A-Fa-f0-9]{6}\\)" lib/` — alle
   hardcoded Color-Literals durch `AppTheme.*`-Tokens ersetzen.
2. In `lib/app_theme.dart`: zwei `ColorScheme`-Sets (`lightScheme`,
   `darkScheme`) mit gleichen Token-Namen, plus `ThemeMode.system`-Default.
3. Neuer Provider `lib/providers/theme_provider.dart` mit:
   - `ThemeMode get mode`
   - `Future<void> setMode(ThemeMode mode)` (persistiert via
     SharedPreferences)
4. In `main.dart`: `MaterialApp.themeMode: themeProvider.mode`,
   `theme: AppTheme.light()`, `darkTheme: AppTheme.dark()`.
5. Settings-Screen: Toggle "Hell / Dunkel / System" als
   `SegmentedButton`.

l10n: `settings_theme_light`, `settings_theme_dark`,
`settings_theme_system`.

Mobile-First: SegmentedButton auf Phone vollbreite.

`flutter analyze` + `flutter test` müssen grün sein. Keine hardcoded
Farben mehr in `lib/`.
