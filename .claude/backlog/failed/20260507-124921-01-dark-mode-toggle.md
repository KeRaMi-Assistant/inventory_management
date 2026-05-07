---
slug: dark-mode-toggle
priority: 8
plan: true
budget_usd: 12
test_scenario: smoke-theme-toggle
---

Dark-Mode-Toggle in `lib/screens/settings_screen.dart`.

**WICHTIG — Architektur-Pflicht:** Dark-Mode funktioniert NICHT, wenn die
Widgets weiterhin direkt aus statischen `AppTheme.bgApp`-Konstanten lesen.
Du MUSST diese auf `Theme.of(context)`-Lookups umstellen — sonst hast du
einen schwarzen Scaffold mit Light-Mode-Cards/Texten ("vercrackte UI").

## Schritte

### 1. Audit (PFLICHT, vollständig — keine Abkürzung)

```bash
grep -rE "AppTheme\\.(bgApp|bgSurface|bgSubtle|border|borderStrong|textPrimary|textSecondary|textMuted|textDisabled)" lib/ --include='*.dart' -l
```

→ erwartet ~10+ Files mit ~130+ Vorkommen. **Alle** müssen umgestellt werden.

### 2. AppTheme um context-aware Helper erweitern

In `lib/app_theme.dart`: pro Token eine context-aware Methode hinzufügen.
Pattern:

```dart
static Color bgAppOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? bgAppDark : bgApp;

static Color textPrimaryOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? textPrimaryDark : textPrimary;

// … alle 9 Tokens (bgApp, bgSurface, bgSubtle, border, borderStrong,
//   textPrimary, textSecondary, textMuted, textDisabled)
```

ALTERNATIV: nutze Material-3 `colorScheme.surface` / `colorScheme.onSurface` etc.
direkt in den Widgets. Das ist idiomatischer aber bedeutet Token-Mapping.

### 3. Widgets umstellen

Für jede gefundene Stelle aus dem Audit:
- `AppTheme.bgApp` → `AppTheme.bgAppOf(context)`
- `AppTheme.textPrimary` → `AppTheme.textPrimaryOf(context)`
- usw.

### 4. Dark-ColorSchemes in app_theme.dart

`light` und `dark` ThemeData-Getter mit korrekten ColorSchemes
(brightness, surface, onSurface, primary, …).

### 5. Theme-Provider + main.dart

- `lib/providers/theme_provider.dart`: `ThemeMode mode`,
  `setMode()` persistiert via SharedPreferences.
- `MaterialApp.themeMode: themeProvider.mode`,
  `theme: AppTheme.light`, `darkTheme: AppTheme.dark`.

### 6. Settings-Screen: Toggle

`SegmentedButton<ThemeMode>` auf Phone vollbreite (LayoutBuilder).
l10n: `settingsThemeLight`, `settingsThemeDark`, `settingsThemeSystem`.

## Akzeptanzkriterien

- `grep -rE "AppTheme\\.(bgApp|bgSurface|...)" lib/ --include='*.dart'` zeigt
  **0 Vorkommen ohne `Of(context)`-Suffix** in `lib/screens/` und `lib/widgets/`.
- `flutter analyze` clean.
- `flutter test` 41/41 grün.
- **Browser-Test `smoke-theme-toggle` `Result: passed`** — der visuelle
  Audit muss bestätigen dass nach Toggle auf Dunkel mind. 70% der
  Surfaces dunkel sind. Ohne diesen grünen Test KEIN /ship.

Mobile-First: SegmentedButton auf Phone vollbreite.
