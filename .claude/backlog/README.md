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
priority: 2                        # 1 = höchste, läuft zuerst
plan: false                        # true = erst /plan, dann implementieren
budget_usd: 5                      # optional, Default 5
test_scenario: smoke-theme-toggle  # optional — Browser-Test der vor /ship
                                   # laufen MUSS. Bei UI-Tasks immer setzen.
---

Klare Anweisung an Claude. Was soll gebaut werden? Welche Files sind
betroffen? Welche Tests sollen am Ende grün sein?
```

**`test_scenario`-Hinweis:** Wenn gesetzt, ruft der headless-runner nach
Implementation den `browser-tester`-Subagenten mit diesem Szenario auf.
Bei `Result: failed` wird /ship NICHT ausgeführt — Item landet in `failed/`.
Standard-Szenarien siehe `.claude/agents/browser-tester.md` (z.B.
`smoke-login`, `smoke-inbox`, `smoke-theme-toggle`).

## Filename-Konvention

`<priority>-<slug>.md`, z.B. `01-dark-mode-toggle.md`. Der Runner sortiert
alphabetisch, also `01-...` läuft vor `02-...`.

## Triggers

- **Manuell:** `/queue <text>` (legt Item interaktiv an), `/auto-run` (startet einen Run sofort)
- **Automatisch:** macOS LaunchAgent, alle 30 Min (siehe `.claude/scripts/install-headless.sh`)
