# Headless-Loop — Phase 3 + 4 der Automatisierung

> Status: In Arbeit
> Datum: 2026-05-07
> Branch: `feature/headless-loop`

## Ziel

Der Laptop kann unbeaufsichtigt laufen und Claude arbeitet eingestellte
Backlog-Items selbständig ab: codet → analyzed → testet → committet →
pusht → öffnet PR → Auto-Merge bei grüner CI. Du sitzt nicht davor.

## Architektur

```
~/Library/LaunchAgents/com.kerami.inventory.headless.plist
   ↓ alle 30 Min
.claude/scripts/headless-runner.sh
   ├─ checkt .claude/backlog/inbox/*.md (sortiert nach Filename)
   ├─ wenn leer → exit 0 (keine Token-Verbrennung)
   ├─ wenn Lock-File da → exit 0 (vorheriger Run noch aktiv)
   ├─ pickt erstes File, schreibt Lock
   ├─ ruft `claude --print --permission-mode auto --max-budget-usd 5
   │      --model sonnet -p "<inhalt>"` im Repo
   ├─ verschiebt File → done/<timestamp>-<slug>.md
   ├─ macht Notification (macOS native + optional ntfy.sh push)
   └─ entfernt Lock
```

## Komponenten

| Datei | Zweck |
|---|---|
| `.claude/backlog/inbox/.gitkeep` | TODO-Backlog (Files = einzelne Tasks) |
| `.claude/backlog/done/.gitkeep` | Archiv erfolgreicher Runs |
| `.claude/backlog/failed/.gitkeep` | Fehlgeschlagene Runs zum Debuggen |
| `.claude/backlog/README.md` | Format-Doku für Backlog-Items |
| `.claude/scripts/headless-runner.sh` | Der Loop selbst |
| `.claude/scripts/notify.sh` | Notification-Helper (macOS + optional ntfy) |
| `.claude/scripts/install-headless.sh` | Installiert LaunchAgent |
| `.claude/scripts/uninstall-headless.sh` | Stoppt + entfernt LaunchAgent |
| `.claude/scripts/setup-branch-protection.sh` | Setzt main-branch-protection via gh API |
| `.claude/launchagent.plist.template` | Template für plist (paths werden beim install ersetzt) |
| `.claude/commands/queue.md` | Slash-Command `/queue <feature>` |
| `.claude/commands/auto-run.md` | Slash-Command `/auto-run` (manueller Trigger) |
| `.claude/commands/ship.md` (Update) | Auto-Merge mit `gh pr merge --auto --squash` |
| `CLAUDE.md` (Update) | Sektion „Headless-Loop" |

## Backlog-Item-Format

`.claude/backlog/inbox/<NN>-<slug>.md`:

```markdown
---
slug: add-dark-mode-toggle
priority: 2
plan: false   # true = Plan zuerst, dann Implementation; false = direkter Hit
---

Füge in `lib/screens/settings_screen.dart` einen Toggle hinzu, der
`AppTheme.themeMode` zwischen system/light/dark schaltet. Persistiere
über SharedPreferences. l10n-Keys ergänzen.
```

Sortierung nach Filename → `01-...md` läuft vor `02-...md`. Im Slash-
Command `/queue` kriegst du eine automatische Nummer.

## Sicherheitsmechanismen

1. **Lock-File** `.claude/backlog/.lock` — verhindert parallel laufende
   Runner. Wird bei SIGTERM/Exit gecleant.
2. **Budget-Cap** `--max-budget-usd 5` pro Run.
3. **Permission-Mode** `auto` — Auto-Mode (wie aktuell aktiv), erlaubt
   Tool-Use ohne Prompt, blockt aber destruktive Aktionen.
4. **Hooks** (`guard-bash.sh`) bleiben aktiv — blockt `git push -f main`,
   `supabase db push` etc.
5. **Branch-Whitelist:** Headless darf nur in `feature/*`-Branches
   committen, nie auf `main`. Im Runner geprüft.
6. **Network-Boundaries:** Edge-Function-Deploys, App-Store-Builds,
   Supabase-Push bleiben in der bisherigen Verbotsliste.

## Auto-Merge

Phase-3-Setup, einmalig:

1. `gh api -X PUT repos/:owner/:repo/branches/main/protection` mit
   required-checks (`flutter-ci`, `claude-review`) und allow-auto-merge.
2. `/ship` Slash-Command erweitert um `gh pr merge --auto --squash --delete-branch`.

## Notifications

- **Always-on:** macOS-Notification via `osascript -e 'display
  notification "..." with title "Claude" sound name "Glass"'`
- **Optional via ntfy.sh** (kostenlos, kein Account):
  ```
  export NTFY_TOPIC=mein-claude-topic-xyz
  curl -d "..." ntfy.sh/$NTFY_TOPIC
  ```
  Topic in lokaler `.env.headless` (gitignored).

## Risiken

1. **Endlos-Loop bei Test-Failures.** Mitigation: Tester-Subagent hat
   bereits `max 5 iterations`. Plus Budget-Cap.
2. **Permission-Prompt blockiert Headless-Run.** Mitigation:
   `--permission-mode auto` + getestete Hooks.
3. **Auto-Merge merged kaputten Code.** Mitigation: Required-Checks
   (CI grün) + Claude-Review-Action muss ohne `severity:high` enden.
4. **LaunchAgent läuft während User aktiv VS Code nutzt.**
   Mitigation: Lock-File + Filesystem-Locks. Branch-Konflikte sind
   theoretisch möglich, praktisch unwahrscheinlich da Headless nur in
   Feature-Branches arbeitet.
5. **Token-Burnout bei Backlog-Spam.** Budget-Cap pro Run + Backlog-
   Items werden manuell oder via /queue erstellt.
6. **Notifications stören nachts.** macOS-Focus-Mode regelt das, kein
   technischer Workaround nötig.
7. **Backlog-Items sind Plain-Text.** Wenn jemand reinschreibt
   "lösche alle Workspaces" — wird ausgeführt. Mitigation:
   Backlog ist gitignored / lokal, Trust-Boundary = User selbst.

## Tasks

- [x] T1 — Backlog-Verzeichnisstruktur + README
- [x] T2 — `headless-runner.sh` (Lock, Pick, Run, Verschieben, Notify)
- [x] T3 — `notify.sh` (macOS native + optional ntfy)
- [x] T4 — `launchagent.plist.template` + install/uninstall-Scripts
- [x] T5 — Slash-Commands `/queue`, `/auto-run`
- [x] T6 — `/ship` um Auto-Merge erweitern
- [x] T7 — `setup-branch-protection.sh` (manuell aufrufbar)
- [x] T8 — CLAUDE.md um Headless-Sektion + .env.headless.example
- [x] T9 — Trockentest: leere Inbox → "inbox empty" + exit 0;
       alle Scripts `bash -n` syntax-clean; notify.sh dispatched.
- [ ] T10 — Commit + Push + PR
