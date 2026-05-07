# Browser-Testing-Setup für Claude

> Status: In Arbeit
> Datum: 2026-05-07
> Branch: `feature/browser-testing`

## Ziel

Claude soll Flutter-Web in Chrome starten, einloggen (Test-Accounts) und
selbständig durch die App klicken können — für UI-Smoke-Tests nach
Feature-Implementierungen, Regressionsprüfungen und manuell ausgelöste
End-to-End-Walkthroughs.

## Ansatz

**Playwright MCP** als Browser-Treiber. Microsoft-MCP-Server, akzentu-
ierungsbaum-basiert (kein brittle CSS), unterstützt Klick/Fill/
Screenshot/Console-Capture. Headed-Mode für sichtbares Klickern, headless
für CI.

Ein neuer Subagent `browser-tester` (Sonnet) ruft den MCP, hat fest
definierte Test-Account-Credentials zugriff via `.env.test`, und gibt am
Ende einen JSON-Report (passed/failed Steps + Screenshots).

## Komponenten

| Datei | Zweck |
|---|---|
| `.mcp.json` (✅ existiert) | Playwright MCP project-scoped registriert |
| `.claude/agents/browser-tester.md` | Subagent-Definition |
| `.claude/scripts/dev-web.sh` | Startet Flutter-Web auf festem Port (8123) im Hintergrund |
| `.claude/scripts/stop-web.sh` | Stoppt den Dev-Server sauber |
| `.claude/commands/test-ui.md` | Slash-Command `/test-ui <scenario>` |
| `.env.test.example` | Template für lokale Test-Credentials (Real-File ist ignored) |
| `CLAUDE.md` (Update) | Browser-Testing-Sektion mit Workflow |

## Test-Scenarios (initial)

1. **smoke-login**: Auf `/`, Login mit `test@test.com`, prüfe dass Dashboard
   lädt (Element mit `key('dashboard-root')` o.ä. sichtbar).
2. **smoke-inbox**: Login → Inbox-Tab → "Alle als gelesen markieren"
   klicken → Confirm → SnackBar erscheint → unread-Counter ist 0.

Mehr Scenarios kommen je nach Feature dazu, wenn es eingeführt wird.

## Workflow

```
/test-ui <scenario>
   ↓
[browser-tester]
   ├─ startet dev-web.sh (Flutter run -d chrome)
   ├─ wartet bis localhost:8123 erreichbar
   ├─ Playwright-MCP: navigate, fill, click, screenshot
   ├─ stoppt dev-web.sh
   └─ Report (markdown) + Screenshots in .claude/test-runs/<timestamp>/
```

## Risiken

1. **Flutter-Web-Build dauert beim ersten Mal lang** (~60s).
   `dev-web.sh` erkennt cached build und nutzt `--web-renderer html`
   für schnelleren Start.
2. **Selectors sind fragil** wenn Widgets keine `Key`s haben.
   Mitigation: Subagent benutzt accessible-name / Tooltip / Text-Match
   bevorzugt; bei Bedarf Keys nachträglich in lib/ einfügen.
3. **Test-Accounts müssen in Supabase Dev existieren.** Wenn `test@test.com`
   nicht eingerichtet ist, schlägt Login fehl. Manueller Setup-Schritt
   einmalig (siehe Workflow-Doku in CLAUDE.md).
4. **Headless vs Headed:** Lokal default headed (User sieht Klicks).
   In CI später headless via Env-Var.
5. **Port-Konflikt 8123:** `dev-web.sh` prüft Port und failt früh mit
   klarer Fehlermeldung.

## Tasks

- [x] T1 — Playwright MCP via `claude mcp add` project-scoped
- [x] T2 — `browser-tester` Subagent
- [x] T3 — `dev-web.sh` + `stop-web.sh` Helper-Scripts
- [x] T4 — `/test-ui` Slash-Command
- [x] T5 — `.env.test.example` + .gitignore Erweiterung
- [x] T6 — `CLAUDE.md` um Browser-Testing-Sektion erweitern
- [x] T7 — PR-Template (Phase 2 Rest)
- [ ] T8 — Commit + Push + PR
