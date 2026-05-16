---
slug: selectable-color-palettes
source: tier-3-intake
priority: 1
budget_usd: 8.00
model: sonnet
touches: [lib/app_theme.dart, lib/providers/app_preferences_provider.dart, lib/screens/settings_screen.dart, lib/l10n/app_de.arb, lib/l10n/app_en.arb, lib/screens/, lib/widgets/, lib/main.dart]
needs_gh: false
needs_dispute: false
requires_human_dispute: false
estimated_minutes: 120
created_from: intake-council
trust_tier: 2
verdict: propose
retry_count: 2
retry_reason: previous-attempt-left-17-const-errors-in-callers
---

<!-- re-queued: 2026-05-13 mit explizitem Acceptance + höherem Budget -->

## Aufgabe

**5 wählbare Farbpaletten** für die App (Accent-Color-Variants) — analog zum existierenden Theme-Mode-Toggle (Light/Dark/System).

Konkret:
- Neuer Enum `AppColorPalette` in `lib/app_theme.dart` mit z.B. `{ blue, indigo, violet, teal, rose }` (Default: `blue` = aktueller Stand).
- Pro Palette: `accent`-Farbe + Light/Dark-Tonen + Border-Farben + selected-state-Farben (8 Tokens pro Palette wie heute schon strukturiert in `app_theme.dart`).
- Persistenz: `app_preferences_provider.dart` bekommt `colorPalette` (analog `themeMode`), SharedPreferences-Pattern.
- UI: Settings-Screen bekommt unter dem Theme-Toggle einen Palette-Picker (5 Farb-Kreise, Tap = wählen). Mobile-First: Touch-Target ≥ 48dp.
- l10n: 6-8 neue ARB-Keys in `app_de.arb` + `app_en.arb` (Palette-Namen + "Farbschema:"-Label).
- `main.dart` nutzt die ausgewählte Palette als `ColorScheme.primary` für `theme`/`darkTheme`.

## 🚨 KRITISCH — Const-Callers-Fix (Pflicht!)

Vorheriger Worker-Versuch hat `static const Color AppTheme.accent` zu Runtime-Getter umgebaut → 17 `const`-Kontexte in `lib/screens/*` + `lib/widgets/*` brachen.

**Acceptance:** `flutter analyze --no-pub` muss EXIT 0 zurückgeben. Wenn du `static const` → Getter änderst, MUSST du parallel alle Aufrufer fixen:

- `grep -rn "const.*AppTheme\." lib/` zeigt alle const-Aufrufer.
- Für jeden Treffer in `const`-Kontext (z.B. `const TextStyle(color: AppTheme.accent)` oder `const Icon(..., color: AppTheme.accent)`) entweder:
  - (a) `const` entfernen (`TextStyle(color: AppTheme.accent)`)
  - (b) Die Farbe in eine non-const-Variable extrahieren
  - (c) Den Bezug auf das Token via `Theme.of(context).colorScheme.primary` umstellen (sauberste Lösung für Accent)
- Geh systematisch durch — `lib/screens/activity_screen.dart`, `dashboard_screen.dart`, `help_screen.dart`, `main_screen.dart`, `onboarding_screen.dart`, `widgets/attachment_gallery.dart`, `invites_bell.dart`, `tracking_chip.dart` waren laut letzter Analyse betroffen.

## ✅ Acceptance-Criteria (Self-Verify vor /ship — PFLICHT)

1. `flutter analyze --no-pub` → **0 issues** (alle 17+ const-errors behoben).
2. `flutter test` → grün (keine neuen Test-Failures).
3. ARB-Symmetrie: `python3 .claude/scripts/check-l10n.py` exit 0 (DE+EN gleiche Keys, gleiche Platzhalter).
4. Smoke: `bash .claude/scripts/dev-web.sh` startet, App rendert, Palette-Picker im Settings-Screen funktioniert (kann nicht headless getestet werden — du verifizierst nur dass Build clean ist und Settings-Screen-Code valid).
5. Mobile-First: SettingsScreen-Palette-Picker NICHT auf Hover-only, Touch-Target ≥ 48dp pro Kreis.
6. KEIN hardcoded String — alle UI-sichtbaren Texte über ARB-Keys.
7. KEIN Riverpod/Bloc-Import — nur `provider`-Pattern (existing).
8. `lib/config/supabase_config.dart` NICHT anfassen.

## ⚠️ Anti-Patterns (Verboten)

- ❌ `AppTheme.accent` als `const` lassen wenn es dynamisch wird — entweder ganz `const` weg in callers ODER Token bleibt `static const` und du baust eine zusätzliche `static Color get currentAccent` ohne const-Aufrufer zu brechen.
- ❌ Custom Color-Picker mit ColorWheel — Scope ist 5 vorgegebene Paletten, fertig.
- ❌ Globale Singleton-State — nutze existierenden `app_preferences_provider`.
- ❌ Eigene SharedPreferences-Logik — re-use das was schon da ist.

## Verify

`smoke-help` (Settings-Screen ist auf der Help-Seite verlinkt — wenn die rendert ist Palette-Picker erreichbar).

## Stakeholder-Original

<<<UNTRUSTED_STAKEHOLDER_INPUT tier=2>>>
Make different App Themes, all Fonts and colors are in some central place so Theme switches are easy
<<<END_UNTRUSTED_STAKEHOLDER_INPUT>>>

## Hinweis für Worker

Das ist Re-Try Nr. 2 desselben Items. Vorheriger Worker (claude --print) hat zwar 228 Zeilen Code geschrieben, aber:
- `static const Color accent` → Getter ohne const-callers-Fix → 17 `flutter analyze`-Errors → kein `/ship`.
- Du kannst die Vorarbeit im Worktree `../inventory_management_worker_selectable-color-palettes` als Inspiration nutzen ODER von vorne anfangen.
- Falls du den Worktree nutzt: prüfe ob er nicht stale ist (`git log` zeigt c2e9ec2, main ist jetzt 8c7296b — rebase nötig).
- Empfehlung: **`Theme.of(context).colorScheme.primary` statt `AppTheme.accent`** im UI — das ist der idiomatische Flutter-Weg und vermeidet const-Probleme komplett.
