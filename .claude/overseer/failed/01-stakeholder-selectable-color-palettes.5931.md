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
retry_count: 3
retry_reason: previous-attempts-blocked-on-const-callers-and-pre-ship-smoke-audit
---

<!-- re-queued: 2026-05-13 — Versuch 3 mit verschärften Acceptance + pre-ship smoke -->

## Aufgabe

**5 wählbare Farbpaletten** für die App (Accent-Color-Variants) — analog zum existierenden Theme-Mode-Toggle (Light/Dark/System).

Konkret:
- Neuer Enum `AppColorPalette` in `lib/app_theme.dart` mit `{ blue, indigo, violet, teal, rose }` (Default: `blue` = aktueller Stand).
- Pro Palette: `accent`-Farbe + Light/Dark-Töne + Border + selected-state (alle Tokens die heute in `app_theme.dart` existieren).
- Persistenz: `app_preferences_provider.dart` bekommt `colorPalette` (analog `themeMode`), via SharedPreferences.
- UI: Settings-Screen bekommt unter Theme-Toggle einen Palette-Picker mit 5 Farb-Kreisen. **Touch-Target ≥ 48dp** (z.B. SizedBox(48,48) um den 36dp-Kreis-Visual).
- l10n: 6-8 neue ARB-Keys in `app_de.arb` + `app_en.arb` (Palette-Namen + "Farbschema:"-Label).
- `main.dart` nutzt die ausgewählte Palette als `ColorScheme.primary` für `theme`/`darkTheme`.

## 🚨 KRITISCHE Acceptance (alle Pflicht vor /ship)

**1. Const-Callers-Fix (war Grund für Versuch 1+2 zu scheitern):**
- Wenn `AppTheme.accent` (oder andere Tokens) von `static const Color` zu Runtime-Getter wechseln: ALLE `const`-Aufrufer im Code anpassen.
- `grep -rn "const.*AppTheme\." lib/` zeigt alle Treffer.
- Lösung pro Treffer:
  - (a) `const` entfernen (`TextStyle(color: AppTheme.accent)` ohne `const`)
  - (b) **Empfohlen:** `Theme.of(context).colorScheme.primary` statt `AppTheme.accent` (idiomatischer Flutter-Weg)
- **`flutter analyze --no-pub` MUSS 0 Issues zeigen.** Wenn nicht — fix weiter, NICHT pushen.

**2. Pre-Ship Smoke-Audit (war Grund für Versuch 2 blocked-pre-ship):**
- Vor `/ship` MUSST du `bash .claude/scripts/dev-web.sh` starten + `mcp__playwright__browser_navigate` zum Settings-Screen + Screenshot + Palette wechseln + Bestätigen dass Farbe sich live ändert.
- Schreibe einen passed-Report nach `.claude/test-runs/<timestamp>/report.md` mit `Result: passed` (Format wie browser-tester es macht).
- Alternative: ruf direkt den `browser-tester`-Agent auf via `claude --print --agent browser-tester "smoke-help"` — der schreibt den Report selbst.

**3. ARB-Symmetrie:**
- `python3 .claude/scripts/check-l10n.py` exit 0 (DE+EN gleiche Keys + Platzhalter).

**4. flutter test:**
- Bestehende Tests bleiben grün.

## ✅ Self-Verify-Sequenz vor /ship (in dieser Reihenfolge)

```bash
cd $WORKTREE
flutter analyze --no-pub          # MUSS 0 issues
python3 ../inventory_management/.claude/scripts/check-l10n.py  # MUSS exit 0
flutter test                       # MUSS grün
# Pre-Ship-Smoke:
bash ../inventory_management/.claude/scripts/dev-web.sh
# → browser-tester aufrufen ODER manuell Palette-Picker testen + report.md schreiben
```

## ⚠️ Anti-Patterns (Verboten)

- ❌ Worker beendet sich mit "permission prompt needs approval" → das blockiert sofort. Du läufst mit `--permission-mode auto`, **nutze deine Tools direkt** statt um Permission zu betteln.
- ❌ `static const Color accent` → Getter ohne const-callers-Fix → 17 errors → blocked.
- ❌ Custom Color-Wheel/Picker — Scope ist 5 vorgegebene Paletten, fertig.
- ❌ `lib/config/supabase_config.dart` anfassen.
- ❌ Hardcoded Strings — alles über ARB-Keys.
- ❌ Riverpod/Bloc — nur `provider`.

## Hinweis: Vorarbeit verfügbar

Worktree `../inventory_management_worker_selectable-color-palettes` enthält 228 Zeilen Vorarbeit aus Versuch 2 (Enum + Provider + ARB-Keys + Settings-Picker fast fertig). Optional als Inspiration nutzen oder von vorne anfangen — entscheide selbst. Falls Worktree stale: `git fetch && git rebase origin/main`.

## Stakeholder-Original

<<<UNTRUSTED_STAKEHOLDER_INPUT tier=2>>>
Make different App Themes, all Fonts and colors are in some central place so Theme switches are easy
<<<END_UNTRUSTED_STAKEHOLDER_INPUT>>>
