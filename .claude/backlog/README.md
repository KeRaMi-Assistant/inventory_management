# Backlog für Headless-Runs

Der `headless-runner.sh` arbeitet diese Items abends/nachts ab, ohne dass
du am Laptop sitzt.

## Verzeichnisse

- **`inbox/`** — TODO-Liste. Ein File pro Task.
- **`done/`** — erledigte Items, mit Timestamp prefixed beim Verschieben.
- **`failed/`** — fehlgeschlagene Items (mit `.error`-File daneben).
- **`runs/`** — Logs aller `claude --print`-Runs.

## File-Format

```markdown
---
slug: short-kebab-case-name
priority: 2          # 1 = höchste, läuft zuerst (per filename-prefix)
plan: false          # true = erst /plan, dann implementieren
budget_usd: 5        # optional, Default 5
---

Klare Anweisung an Claude. Was soll gebaut werden? Welche Files sind
betroffen? Welche Tests sollen am Ende grün sein?

Beispiel:
"Füge in `lib/screens/settings_screen.dart` einen Toggle für Dark-Mode hinzu.
Persistiere via SharedPreferences. l10n-Keys ergänzen.
Test: `flutter test test/settings_test.dart` muss grün sein."
```

## Filename-Konvention

`<priority>-<slug>.md`, z.B. `01-dark-mode-toggle.md`. Der Runner sortiert
alphabetisch, also `01-...` läuft vor `02-...`.

## Triggers

- **Manuell:** `/queue <text>` (legt Item interaktiv an), `/auto-run` (startet einen Run sofort)
- **Automatisch:** macOS LaunchAgent, alle 30 Min (siehe `.claude/scripts/install-headless.sh`)
