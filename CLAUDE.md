# inventory_management — Claude Code Project Guide

> Diese Datei ist verbindlich für ALLE Subagenten und Top-Level-Sessions.

## Stack

- **Frontend:** Flutter 3.11 (Dart SDK ^3.11.5), `provider`-State-Management (kein Riverpod)
- **Backend:** Supabase (Postgres + RLS) + Supabase Edge Functions in Deno/TypeScript
- **Auth:** Supabase Auth, Google Sign-In, Apple Sign-In
- **Push:** Firebase Messaging + `flutter_local_notifications`
- **Test:** `flutter_test` (Widget + Unit), aktuell minimal — wird ausgebaut
- **i18n:** Flutter `flutter_localizations` + ARB-Files in `lib/l10n/`
- **Lint:** `flutter_lints` ^6.0.0 via `analysis_options.yaml`

## Projekt-Status

**Pre-Launch / aktive Entwicklung.** Keine echten Nutzer, kein echtes Billing.
→ Aggressives Refactoring + Migrations sind OK, solange git-versioniert ist.
→ Auto-Push in Feature-Branches und Auto-Merge in `main` sind erlaubt (mit CI-Gates).

## Branching & Commits

- **NIE direkt auf `main` committen.** Immer `feature/<slug>` oder `fix/<slug>`.
- Branch-Naming: kebab-case, max 40 Zeichen.
- Commits dürfen automatisiert sein, aber:
  - `git add .` ist VERBOTEN. Kein Wildcard `.claude/*`. Nur explizite Whitelist (Single-Source-of-Truth: `.claude/whitelist.txt`):
    `git add lib/ supabase/migrations/ supabase/functions/ test/ pubspec.yaml pubspec.lock plans/ .github/ CLAUDE.md .claude/agents/ .claude/commands/ .claude/scripts/ .claude/settings.json .claude/stakeholder/ .claude/stakeholder/digest/ .claude/disputes/ .claude/audit/ .claude/overseer/ .claude/analyzer/ .claude/integrity/ .claude/git-hooks/ .claude/memory/ .claude/schemas/ .claude/metrics/ .claude/whitelist.txt`
  - Niemals `lib/config/supabase_config.dart`, `google-services.json`, `GoogleService-Info.plist`, `.env*`, `*.csv` mit Daten committen.
- Commit-Messages auf Deutsch oder Englisch, kurz und im Imperativ. Optional Co-Author-Line beibehalten.

## Workflow für nicht-triviale Tasks

1. **Plan zuerst.** `/plan <feature>` oder direkter Aufruf des `planner`-Agenten. Plan landet in `plans/YYYY-MM-DD_<slug>.md`.
2. **Implementation gegen den Plan.** `flutter-coder`, `ui-builder`, `db-migrator`, `edge-fn-coder` je nach Scope.
3. **Nach jeder größeren Änderung:** `dart analyze <pfad>` (passiert per Hook).
4. **Vor Commit:** `flutter test` + ggf. `security-reviewer`.
5. **Ship:** `/ship` Slash-Command → commit auf Feature-Branch + push + PR via `gh pr create`.

Triviale Tasks (Typo-Fix, einzelne Zeile) brauchen keinen Plan.

## Code-Konventionen

### Dart (`lib/`)
- **Provider-Pattern:** Neuer State → neuer Provider in `lib/providers/`, registriert in `main.dart`. Nicht mit Riverpod, GetX oder bloc mischen.
- **Services:** Reine Logik (keine Widgets) in `lib/services/`. Keine direkten Supabase-Calls aus Widgets — immer über `supabase_repository.dart` oder einen Service.
- **Theme:** Ausschließlich Farben/Tokens aus `lib/app_theme.dart` (`AppTheme.bgApp`, `AppTheme.accent`, etc.). Keine `Colors.blue` o.ä. ad hoc.
- **Strings:** Jeder UI-sichtbare Text muss in `lib/l10n/app_de.arb` UND `lib/l10n/app_en.arb`. Kein hardcoded String. Generiert via `flutter gen-l10n` (passiert automatisch beim Build).
- **Imports:** Relativ innerhalb `lib/`, absolut für Pakete. Kein Wildcard-Export.
- **Null-Safety:** Strikt, keine `!`-Bangs ohne klaren Grund.

### Mobile-First (PFLICHT für jede UI-Änderung)

Die App läuft primär auf iOS + Android. Tablet/Desktop sind sekundär.

- **Test-Viewports im Kopf:** 360×640 (kleinster Phone), 390×844 (iPhone-Default), 768×1024 (Tablet), 1440×900 (Desktop). Alle vier müssen funktionieren — Phone darf NICHT abschneiden oder horizontal scrollen.
- **Touch-Targets:** mind. 48×48 dp.
- **Keine Hover-Only-Logik.** Tooltips OK, aber Funktionen müssen per Tap erreichbar sein.
- **Bottom-Nav** für Top-Level-Routen auf Phone (`MediaQuery.sizeOf(context).width < 600`), Sidebar/Drawer nur auf Desktop.
- **Responsive Switches:** `LayoutBuilder` / `MediaQuery.sizeOf` — niemals `Platform.is*`.
- **`SafeArea`** um Content (Notch, Home-Indicator); bei TextFields `MediaQuery.viewInsetsOf` damit Tastatur den Input nicht verdeckt.
- **Listen:** auf Phone vertikale Cards, nicht Tabellen mit horizontalem Scroll.
- **Browser-Tester** prüft jedes UI-Smoke-Szenario zuerst auf Phone-Viewport (390×844). Desktop nur via `--also-desktop`.

### Supabase

- **Migrations:** `supabase/migrations/YYYYMMDDHHMMSS_<slug>.sql`. Erstellen via `supabase migration new <slug>`.
- **RLS ist PFLICHT** für jede neue Tabelle. Policies orientieren sich an bestehenden Workspace-Policies (siehe `20260504000300_workspace_rls_fix.sql`, `20260504000500_data_workspace_scope.sql`).
- **Migrations lokal testen:** `supabase db reset` muss erfolgreich durchlaufen, bevor committed wird.
- **`supabase db push` gegen Prod:** NIEMALS automatisch. Nur User explizit nach Bestätigung.
- **Edge Functions:** TypeScript/Deno in `supabase/functions/<name>/index.ts`. Shared Code in `supabase/functions/_shared/`. Kein Secret hartcodieren — `Deno.env.get('NAME')`.

### Tests

- Service-Layer: Unit-Tests in `test/<service>_test.dart`.
- Provider mit gemockten Services testen, nicht mit Live-Supabase.
- Widget-Tests für komplexe Custom-Widgets, nicht für triviale Wrapper.
- Coverage-Ziel: Service-Layer > 60% bevor Auto-Merge auf `main` aktiviert wird.

## Sicherheit

- **Secrets:** Nie in Code. `.env` lokal, Supabase-Secrets via `supabase secrets set` (manuell).
- **RLS:** Jede neue Tabelle braucht Policies — Default-Deny.
- **Input-Validation:** In Edge Functions zod-artig per Hand validieren (kein zod-Paket nötig). Auf Client-Seite Form-Validation in `lib/widgets/`.
- **SQL-Injection:** Niemals raw SQL in Migrations mit Variablen — Supabase Client nutzt prepared statements.
- **Logs:** Keine Tokens, Mail-Adressen oder PII in `print()` oder Edge-Function-Logs. Adapter in `supabase/functions/_shared/inbox_adapters.ts` zeigt das Pattern.

## Verbotene Aktionen (Auto-Guard via Hook)

- `git push -f origin main`
- `git reset --hard origin/*`
- `rm -rf` außerhalb `build/`, `.dart_tool/`, `coverage/`
- `flutter pub publish`
- Schreiben in `lib/config/supabase_config.dart`, `google-services.json`, `GoogleService-Info.plist`
- `supabase link --project-ref <prod>` (sobald Prod-Project existiert)

## Subagent-Modell-Routing

| Aufgabe | Modell |
|---|---|
| Plan-Erstellung, Architektur | Opus |
| Security-Review, RLS-Audit | Opus |
| Migrations (RLS-kritisch) | Opus |
| Routine-Coding (Provider, Service, Widget) | Sonnet |
| UI-Polish, l10n, kleine Widgets | Sonnet (oder Haiku für Trivial) |
| Test-Loop / Bug-Fix mit klarem Stack-Trace | Sonnet |

## Sicherheit-Layering

- **Lokal vor Push:** `security-reviewer`-Subagent (läuft auf Max-Plan-Quota, kostet nichts extra). Wird vom `/ship`-Command automatisch aufgerufen.
- **In CI auf PRs:** `claude-code-action@v1` Code-Review (auch via Max-Plan-OAuth-Token). Macht Security-Check als Teil des Reviews.
- **Nicht aktiviert:** `claude-code-security-review@main` Action — braucht zwingend einen bezahlten API-Key, deckt aber nichts ab, was der lokale `security-reviewer` nicht auch findet.

## Prompt-Caching (Cost-Tuning)

Anthropic's Prompt-Cache hält stabile System-Prompts (Subagent-Definitionen) 5 min im Cache —
**~90% Cost-Reduktion + ~85% Latency-Reduktion** für wiederholte Agent-Calls innerhalb eines
Headless-Runs. Aktiviert sich automatisch ab ~1024 Tokens (keine explizite API-Konfiguration
nötig bei Claude Code OAuth-Flows).

**Status:** Aktiviert für `browser-tester`, `stakeholder-triage`, `disput-proponent`,
`disput-skeptic`, `disput-pragmatist`, `ui-builder`. Kurze Agents (`planner`, `security-reviewer`,
`flutter-coder`) liegen unter dem 1024-Token-Schwellenwert — kein Cache-Hit erwartet.

**Pflicht-Regel:** Caller (`worker.sh`, `disput.sh`, `triage-stakeholder.sh`) müssen User-Input
**ans PROMPT-ENDE** setzen — via `-p "..."` nach allen anderen Flags oder via stdin. Dynamischen
Content VOR dem Agent-Body injizieren = Cache-Miss auf jedem Call.

**Helper:** `.claude/scripts/lib/cache-friendly-invoke.sh`
- `invoke_agent_cached <agent> <budget-usd> [user-input]`
- `_validate_cache_friendly_invocation <cmd-string>` — Heuristik-Check

**Skripte mit cache-friendly Invocation:**
- `worker.sh` — nutzt `-p "$PROMPT_HEADER"` am Ende der CLAUDE_ARGS.
- `disput.sh` — nutzt `< "$prompt_file"` (stdin, prompt-body zuerst).
- `triage-stakeholder.sh` — nutzt `"..."` als letztes Argument (direkt hinter --agent).

**Verifizierbar via:**
```bash
bash .claude/scripts/verify/prompt-cache-friendly.sh
```
Exit 0 = alle Checks grün. Auch: `cached_input_tokens > 0` in `claude --print --output-format json`.

## Auto-Merge (Pre-Launch-Modus)

Da die App Pre-Launch ist und alles git-versioniert ist, darf Claude PRs
direkt mergen, sobald die lokalen Quality-Gates grün sind:

- `flutter analyze` ✓
- `flutter test` ✓
- `security-reviewer` ohne `verdict: block` ✓

**Befehl im /ship-Slash:** `gh pr merge <num> --squash --delete-branch`
(kein `--auto`, das bräuchte Branch-Protection auf privaten Repos = Pro).

**Helper:** `bash .claude/scripts/auto-merge-pr.sh [<pr-num>]`
- Ohne Argument: nimmt PR des aktuellen Branches.
- Switched nach Erfolg auf `main` + `git pull`.

**Wenn Merge fehlschlägt** (Konflikt mit main): KEIN automatisches Reset/
Force, sondern Abort mit klarer Fehlermeldung. User entscheidet manuell.

## Headless-Loop (Phase 4)

Claude kann unbeaufsichtigt Backlog-Items abarbeiten, während du nicht
am Laptop sitzt. Setup einmalig:

1. `bash .claude/scripts/install-headless.sh` — installiert macOS
   LaunchAgent (Default: alle 30 Min). Override-Intervall:
   `HEADLESS_INTERVAL=600 bash .claude/scripts/install-headless.sh`.
2. Optional `cp .env.headless.example .env.headless` und `NTFY_TOPIC`
   setzen für Mobile-Push-Notifications via [ntfy.sh](https://ntfy.sh).
3. Stoppen: `bash .claude/scripts/uninstall-headless.sh`.

**Workflow:**
- `/queue <text>` legt ein Backlog-Item an (`.claude/backlog/inbox/`).
- LaunchAgent oder `/auto-run` triggert `headless-runner.sh`:
  pickt nächstes Item → `claude --print --permission-mode auto
  --max-budget-usd 5 --model sonnet` → verschiebt nach `done/` oder
  `failed/` → schickt Notification.
- Logs: `.claude/backlog/runs/<timestamp>-<slug>.log`.

**Sicherheitsmechanismen:**
- Lock-File verhindert parallele Runs.
- Budget-Cap pro Run.
- Hard-Block: niemals auf `main` direkt — Runner switcht zu Auto-Branch.
- Bestehende Bash-Guards bleiben aktiv (`supabase db push`, force-push, …).

**Auto-Merge:**
- `/ship` aktiviert nach Push automatisch `gh pr merge --auto --squash --delete-branch`.
- Vorausgesetzt Branch-Protection ist aktiv (einmalig via
  `bash .claude/scripts/setup-branch-protection.sh` setzen).

### Phase-4-Migration: Headless-Loop auf Autonomous Swarm umgestellt

**Phase-4-Migration (2026-05-10):** Der alte `com.kerami.inventory.headless`
LaunchAgent ist deaktiviert und entfernt. Der Overseer (`com.inventory.overseer`)
übernimmt den Inbox-Loop auf `.claude/backlog/inbox/` im Autonomous-Swarm-Betrieb.
`uninstall-headless.sh` bleibt als Fallback im Repo erhalten.

Verify: `bash .claude/scripts/verify/launchagent-state.sh`

## Browser-Smoke-Tests (Playwright MCP)

Claude kann die Flutter-Web-App in Chrome starten, einloggen und durchklicken,
um Regressionen zu finden, die `flutter analyze` + `flutter test` nicht sehen.

**Setup (einmalig, manuell):**
1. `cp .env.test.example .env.test` — `.env.test` ist gitignored.
2. Test-Accounts in Supabase Dev: `test@test.com` / `passwort` und `test2@test.com` / `passwort` müssen existieren (sonst Login-Fehler).
3. Playwright-MCP ist project-scoped registriert in `.mcp.json` — der erste `npx`-Run lädt Chromium (~1× pro Maschine).

**Nutzung:**
- `/test-ui smoke-login` → ruft `browser-tester`, läuft Login-Flow durch.
- `/test-ui smoke-inbox` → Login + Inbox + "Alle als gelesen markieren".
- `/test-ui smoke-theme-toggle` → alle 10 Top-Level-Routen Light + Dark.
- `/test-ui smoke-help` → Hilfeseite (Search, FAQ, Phone, Theme, EN).
- `/test-ui smoke-full-app-audit` → Mega-Audit: läuft jede Route aus
  [`.claude/agents/_page-registry.md`](.claude/agents/_page-registry.md)
  ab (Light + Dark × Desktop + Phone), prüft Pixel-Overflow,
  Console-Errors und Theme-Konsistenz, schreibt pro Befund einen
  Auto-Requeue-Task `00-followup-…` ins Inbox.
- `/test-ui <freitext>` → Klartext-Anweisung, der Agent übersetzt sie selbst.

**Pre-Ship-Pflicht (UI-Änderungen):** Vor jedem `/ship` einer
User-sichtbaren UI-Änderung (neuer Screen, Theme/Color-Tweak,
Layout-Refactor, neue Sub-Route) muss `smoke-full-app-audit`
mindestens einmal grün durchlaufen — sonst kein Merge. Bei
`Result: failed` schreibt der Tester automatisch
`00-followup-…`-Items, die der Drain als Allererstes pickt;
manuelle Trigger-Tasks sind nicht nötig. Bugfixes ohne UI-Wirkung
dürfen mit dem engeren Smoke-Szenario auskommen
(z. B. `smoke-inbox`, `smoke-help`).

**Web-Server:** `bash .claude/scripts/dev-web.sh` startet `flutter build web` + `python -m http.server 8123`. `bash .claude/scripts/stop-web.sh` stoppt sauber.

**Reports:** Markdown + Screenshots landen unter `.claude/test-runs/<timestamp>/` (gitignored).

**Selector-Regel:** Browser-Tester nutzt Accessibility-Names / Roles / Tooltips, keine brittle CSS-Selektoren. Wenn ein Widget keinen erkennbaren Anker hat, schlägt der Tester eine `Key('...')`-Ergänzung in `lib/...` vor — Implementer fügt sie nachträglich ein.

## Ressourcen-Check

Statische Validierung von Projekt-Ressourcen (Strings, künftig auch Assets/
Theme-Tokens). Dient als Sicherheitsnetz gegen schleichende Inkonsistenzen,
die `flutter analyze` nicht sieht.

### l10n-Konsistenz

**Was geprüft wird:**
- Schlüssel-Symmetrie zwischen `lib/l10n/app_de.arb` und `lib/l10n/app_en.arb`.
- Platzhalter-Symmetrie pro Key (`{name}`, `{count}` etc. müssen identisch sein).
- ARB-JSON-Validität + `@key`-Metadata-Sanity.
- Hardcoded deutsche UI-Strings in `lib/` (Heuristik: `Text('…')`,
  `tooltip:`, `hintText:`, … mit Umlauten oder typischen DE-Tokens).

**Aufruf:**
- `/check-l10n` — Audit-Pass (read-only Markdown-Report).
- `/check-l10n --fix` — ergänzt fehlende EN-Keys mit `[TODO en] <DE>`-Markern,
  die der Agent anschließend idiomatisch übersetzt.
- `/check-l10n --json` — JSON-Output für Pipelines.
- `/check-l10n --no-hardcoded` — nur ARB-Symmetrie, ohne lib-Scan.

**Direkt ohne Agent:**
```bash
python3 .claude/scripts/check-l10n.py [--fix] [--json] [--no-hardcoded]
```
Exit-Codes: `0` = clean, `1` = Findings, `2` = ARB-IO/Parse-Fehler.

**Wann ausführen:**
- Vor jedem `/ship` einer UI-Änderung (gehört zur PFLICHT-Mobile-First-Checkliste).
- Nach jedem Refactor, der ARBs anfasst.
- Periodisch im Headless-Loop (separates Backlog-Item ist sinnvoll).

**Grenzen:** Hardcoded-Strings werden nur gemeldet, nicht refaktoriert —
das übernimmt ein `flutter-coder`-Agent. Übersetzungen für `[TODO en]`-
Marker macht der `l10n-checker` selbst (nicht maschinell, idiomatisch).

## Handbook pflegen

Das Handbuch liegt in [`docs/handbook/`](docs/handbook/) und ist die
verbindliche Referenz zu Stack, Konzepten, Screens, Pipelines und Schema.
Bei Code-Änderungen muss es synchron bleiben — sonst veraltet die
Quelle, an der neue Entwickler:innen einsteigen.

**Was triggert ein Update:**

- Neuer Screen (`lib/screens/<x>_screen.dart`) → `03-screens-walkthrough.md`.
- Neuer Provider (`lib/providers/`) oder neuer Service (`lib/services/`,
  außer `inbox_*`) → `05-architecture.md`.
- Inbox-Pipeline-Änderung (`lib/services/inbox_*`,
  `supabase/functions/_shared/inbox_adapters.ts`,
  `supabase/functions/_shared/tracking_adapters.ts`) →
  `04-inbox-mail-pipeline.md`.
- Neue Tabelle / Migration → `06-database.md` + Glossar (`10-glossary.md`).
- Neue Edge-Function → `07-edge-functions.md` + Glossar.
- Neuer Subagent (`.claude/agents/`) → `05-architecture.md` (Subagenten-
  Tabelle).
- CI-/Workflow-Änderung (`.github/workflows/`) → `08-deployment.md`.
- Neuer Domain-Begriff im Code (Klassen-/Modellname, der mehrfach
  auftaucht) → Eintrag in `10-glossary.md`, alphabetisch + verlinkt.

**Aufruf:**

- `/update-docs` — Dry-Run, listet Plan + geplante Diff-Snippets.
- `/update-docs --apply` — schreibt die Edits durch (inkrementell, kein
  Rewrite).
- `/update-docs --from origin/main --apply --strict` — strenge Variante
  für CI-Gates (exit 1, wenn unklassifizierte Pfade übrig bleiben).

**Wann ausführen:**

- Vor `/ship`, sobald der PR über reine Bugfixes hinausgeht (neues
  Feature, neue Tabelle, neue Function, neuer Agent).
- Im Headless-Loop optional als eigenes Backlog-Item (`/queue ...`),
  damit Doku-Drift nicht stillschweigend wächst.
- Periodisch: `/update-docs --from <letzter-Doku-Sync> --apply`.

**Grenzen:** Der Agent schreibt nicht alles um, sondern ergänzt. Bei
Strukturproblemen (veraltetes Kapitel, falsche Sektionen) meldet er
das im Schluss-Block — die Überarbeitung macht ein `planner` →
`flutter-coder`-Workflow.

## Page-Registry

Die Datei [`.claude/agents/_page-registry.md`](.claude/agents/_page-registry.md)
ist die **Single-Source-of-Truth** über alle User-sichtbaren Screens
(Top-Level + Auth + Onboarding) und User-sichtbaren Sub-Routes
(Modal-Dialogs, Bottom-Sheets). Ohne sie hat der Browser-Tester keine
Audit-Checkliste — neue Screens würden bei UI-Audits unsichtbar
durchrutschen.

**Wer pflegt sie:**

- Initial angelegt + manuell kuratiert (Pflicht-Tests, Notizen).
- **Inkrementell automatisch** durch den `doc-updater`-Agent: bei
  jedem `/update-docs`-Run werden Adds/Removes von Files unter
  `lib/screens/` und Sub-Route-Files unter `lib/widgets/`
  (`add_edit_*`, `*_dialog`, `*_sheet`) erkannt und Tabellen-Einträge
  ergänzt bzw. entfernt. Reihenfolge bleibt erhalten.

**Wer liest sie:**

- `browser-tester` nutzt sie als Pflicht-Checkliste für Full-App-
  Audits (siehe Backlog #04).
- Maintainer beim PR-Review: "Ist der neue Screen drin? Stimmen die
  Pflicht-Tests?"

**Format:** Markdown bleibt das Format (kein JSON), damit Menschen
direkt lesen und greppen können. Tabellen-Spalten:
`Route | File | Pflicht-Tests | Notizen`. Pflicht-Tests-Schlüssel
sind unten in der Datei selbst dokumentiert.

**Default-Pflicht-Tests** für neu hinzugefügte Screens:
`smoke-theme, mobile-overflow`. Auth-Screens bekommen `smoke-<slug>,
smoke-theme`. Spezifische Test-Sets (`charts-render`, `all-6-tabs`,
`deal-flow`, …) werden manuell ergänzt — der Agent setzt nur Defaults.

**Wann manuell editieren:**

- Wenn ein neuer Pflicht-Test-Schlüssel hinzukommt (Definitionsblock
  am Ende der Datei pflegen).
- Wenn die Bottom-Nav-Reihenfolge in `MainScreen` umgebaut wird —
  dann passt der Agent die Tabellen nicht automatisch um, das macht
  ein `flutter-coder`-Workflow.

## Hilfeseite pflegen

Die User-sichtbare Hilfeseite liegt in
[`lib/screens/help_screen.dart`](lib/screens/help_screen.dart) +
`lib/l10n/app_*.arb`. Sie ist die **erste Anlaufstelle für neue Nutzer**
— alles, was ein Anwender wissen muss, soll dort findbar sein, ohne in
interne Dev-Doku abzudriften. Pendant zum Handbuch (Entwickler-Sicht)
ist die Hilfeseite die User-Sicht.

**Was triggert ein Update:**

- Neuer Screen (`lib/screens/<x>_screen.dart`) → eigene Hilfe-Sektion +
  ggf. Quick-Start-Eintrag.
- Neuer Setting/Toggle in `settings_screen.dart` → FAQ-Eintrag.
- Geänderte Status-/Pipeline-Logik (`lib/services/inbox_*`,
  `tracking_*`, `push_*`) → passende Sektion (Postfach/Deals/Push)
  + Troubleshooting.
- Neue Edge-Function mit User-Wirkung
  (`supabase/functions/<name>/`) → passende Sektion.
- Neuer User-sichtbarer ARB-Key, der ein Feature dokumentiert →
  Erwähnung in der zugehörigen Sektion.
- Pricing-/Limits-Änderung (`lib/screens/pricing_screen.dart`,
  Billing-Provider) → Sektion Workspace + FAQ Downgrade.

**Aufruf:**

- `/update-help` — Dry-Run, listet Plan + geplante ARB-Keys + geplante
  Screen-Edits.
- `/update-help --apply` — schreibt die Edits durch (inkrementell, kein
  Rewrite). DE+EN-ARBs bleiben symmetrisch.
- `/update-help --from origin/main --apply --strict` — strenge Variante
  für CI-Gates (exit 1, wenn unklassifizierte Pfade übrig bleiben).

**Wann ausführen:**

- Vor `/ship`, sobald der PR User-sichtbares Verhalten ändert (neuer
  Screen, neuer Toggle, neue Status-Logik, neue Edge-Function mit
  UI-Wirkung). Bugfixes ohne UI-Änderung brauchen kein Help-Update.
- Im Headless-Loop optional als eigenes Backlog-Item, damit die
  Hilfe nicht still veraltet.
- Periodisch: `/update-help --from <letzter-Hilfe-Sync> --apply`.

**Grenzen:** Der Agent schreibt nicht alles um, sondern ergänzt
inkrementell. Übersetzungen für DE+EN macht der Agent idiomatisch
selbst (keine maschinelle Übersetzung). Bei strukturellen Problemen
(z. B. „Sektion X ist komplett veraltet") meldet er das im
Schluss-Block — die Überarbeitung übernimmt ein `planner` →
`flutter-coder`-Workflow.

## Autonomous Council Swarm

Vollständig autonomer Multi-Agent-Loop. Plan: [`plans/2026-05-09_autonomous_council_swarm.md`](plans/2026-05-09_autonomous_council_swarm.md). Phase 0-3 implementiert (PRs #52, #53, #54).

### Architektur

```
Stakeholder
    │ /btw "..."             ntfy-Reply (Action-Buttons)
    ▼                                    ▲
btw.sh (tier-1)        Telegram-Bot (tier-2, HMAC)
    │                            │
    ▼                            ▼
.claude/stakeholder/inbox/<slug>.md
    │
    ▼  (60s tick)
stakeholder-triage (Opus, sandwich-markers)
    │
    ▼
stakeholder-validator (Sonnet, schema-regex)
    │  pass        │ quarantine
    ▼              ▼
.claude/backlog/inbox/01-stakeholder-<slug>.md   .claude/stakeholder/quarantine/

Analyzer-Daemon (stündlich) ──► .claude/backlog/inbox/02-analyzer-<modul>-<slug>.md
  ├─ scan-tech-debt        ├─ scan-mobile-overflow
  ├─ scan-l10n-drift       ├─ scan-test-coverage
  ├─ scan-failure-lessons  ├─ scan-doc-drift
                           ├─ scan-help-drift
                           ├─ scan-security-drift   (needs_dispute: true)
                           ├─ scan-dead-code
                           └─ scan-dependency-rot   (needs_dispute: true)

Overseer (KeepAlive-Daemon)
  ├─ pick_next_item (atomic-move + per-file-soft-lock)
  ├─ needs_dispute? → disput.sh (3 Runden, Pragmatist Tie-Break)
  ├─ worktree_create + worker.sh (claude --print, budget_usd req)
  └─ release_item done/failed/blocked-pre-ship/[merge-conflict]

Watchdogs (parallel):
  ├─ watchdog.sh (5min: Disk, Worktrees, Cost-Cap, Cost-Tampering)
  ├─ recover.sh (5min: tote PIDs, hängende Worker, 3-Cycle-Limit → failed/)
  ├─ cleanup.sh (täglich 03:00: branches/stashes/run-logs/disputes/audit)
  ├─ briefing.sh (täglich 09:00 → .claude/audit/briefings/)
  ├─ weekly-digest.sh (Sonntag 09:00 → .claude/stakeholder/digest/)
  ├─ audit-backup.sh (Sonntag 04:00 → separates Off-Site-Repo)
  └─ cloud-heartbeat-ping.sh (60min → ntfy.sh)
       └─ GitHub-Action checkt alle 4h → Push wenn aus
```

### Mensch-im-Loop-Stops

System pausiert UNBEDINGT bei (User-Aktion erforderlich):

1. `supabase db push` gegen Prod
2. `gh pr merge --admin` (außer Stakeholder-Override via `MERGE_ADMIN_OVERRIDE=1`)
3. `supabase secrets set`
4. OAuth-Token-Expiry (gh, claude, supabase)
5. Cost-Cap überschritten (Hard-Stop, manueller Reset via `resume.sh`)
6. PANIC nach 3 consecutive failures (resume.sh nur via valider user-session)
7. Self-Mod-Hit (Worker hat Blocklist-Pfad gewollt)
8. Disput unresolved nach 3 Rounds → Stakeholder-Notify
9. Anthropic Admin-API-Spend-Limit
10. Branch-Protection-Setup (einmalig)

### Intake-Council (User-Gated Backlog-Aufnahme)

Neuer Default-Pfad für User-Ideen: `/yota propose <idee>` (Telegram oder CLI).

**Flow:**
1. User: `/yota propose "Dunkler Footer auf Inventory"` (Telegram) oder `bash .claude/scripts/yota-propose.sh "..."` (CLI).
2. 3-Agent-Mini-Council (Proponent + Intake-Skeptic + Intake-Pragmatist) berät ROI, Doppelung, Mobile-First-Fit, Maintenance-Last.
3. Council schreibt Verdict-File in `.claude/stakeholder/pending-approval/<id>.md`.
4. Telegram-Bot pushed Mini-Verdict (3 Zeilen) an User mit HMAC-Token.
5. User antwortet:
   - `go <id> <token>` → intake-validator → `.claude/overseer/inbox/01-stakeholder-<slug>.md` → Worker pickt.
   - `reject <id> [<reason>]` → `.claude/stakeholder/rejected/<id>.md`.
   - `change <id> <text>` → Round 2 mit Korrektur (max 3 Runden).
   - `go-anyway <id> <token> <reason>` → Override für reject-Verdicts (Begründung Pflicht).

**Cost-Profil:** $0.50-$0.80/Council-Run (Sonnet für Proponent+Skeptic, Opus für Pragmatist-Tie-Break). Lifetime-Cap $2/Proposal (deckt 3 Runden), Tagescap $10. Reject-Streak: 5 in 48h → kritische Notify.

**Sicherheit:**
- Creator-Binding: nur der originale User darf `go`/`reject`/`change` (Telegram `from.id` == Frontmatter `user_id`).
- HMAC-Token-Echo Pflicht bei `go`.
- Self-Mod-Pfade in `touches:` (z.B. `.claude/scripts/`) triggern automatisch `verdict: needs-full-council` → User muss `/council` separat aufrufen.
- intake-validator (eigener Agent, NICHT in Self-Mod-Blocklist) als Schema-Wall.

**Default vs. Power-User:**
- `/yota propose` ist neuer Default (Council vor Worker).
- `/btw` bleibt als Power-User-Fast-Lane (direkt zum Worker, kein Gate).

**Pre-Flight:** `ANTHROPIC_API_KEY` env-var darf NICHT gesetzt sein (sonst kippt Max-Plan auf API-Pay-per-Token, Anthropic Bug #39903). `intake-council.sh` failt loud.

**Verify:** `bash .claude/scripts/verify/intake-council.sh` (21 Tests), `bash .claude/scripts/verify/telegram-bridge.sh` (45 Tests inkl. /yota propose).

### Setup

```bash
bash .claude/scripts/install-self-mod-guard.sh
bash .claude/scripts/install-integrity-check.sh
bash .claude/scripts/install-overseer.sh --load-now
bash .claude/scripts/install-analyzer.sh --load-now
bash .claude/scripts/install-recovery.sh --load-now
bash .claude/scripts/install-cleanup.sh --load-now
bash .claude/scripts/install-briefing.sh --load-now
bash .claude/scripts/install-weekly-digest.sh --load-now
bash .claude/scripts/setup-cloud-heartbeat.sh   # Token, dann gh secret set ...
bash .claude/scripts/install-audit-backup.sh --load-now  # nach AUDIT_BACKUP_REMOTE in .env.headless
```

User-Session-Marker bei manueller Arbeit:
```bash
bash .claude/scripts/session-start.sh   # vor Beginn
# ... arbeite
bash .claude/scripts/session-end.sh     # nach Abschluss
```

### Verify-Suite

`bash .claude/scripts/verify/*.sh` — 43+ Tests grün als CI-Smoke.

### Yota — Chat-Companion

Read-only Beobachter des Swarms. Erklärt auf Deutsch in 3-7 Zeilen, was
gerade läuft, wieviel verbrannt wurde und warum etwas hakt. Schreibt
keinen Code, edit-tet keine Files.

- `/yota` — Status-Snapshot (5-7 Zeilen).
- `/yota was läuft auf worker fix-x?` — Detail-Frage.
- `bash .claude/scripts/yota-snapshot.sh [--human]` — JSON/Markdown
  direkt ohne Agent.
- `bash .claude/scripts/install-yota-watch.sh --load-now` — 15-Minuten-
  Push an ntfy.
- `bash .claude/scripts/uninstall-yota-watch.sh` — Daemon stoppen.

Code-Wünsche im Chat → `bash .claude/scripts/btw.sh "..."` oder `/queue`.

### Yota auf Telegram

Bidirektionaler Chat vom Phone via Telegram-Bot.

Setup: siehe [`.claude/scripts/SETUP_TELEGRAM.md`](.claude/scripts/SETUP_TELEGRAM.md)
(~5 min, einmalig — BotFather-Token + User-ID in `.env.headless`).

Commands im Telegram-Chat:
- `/yota` — Snapshot.
- `/yota <frage>` — Yota-LLM-Antwort (~$0.05, max 10/h).
- `/status` — Alias zu `/yota`.
- `/btw <text>` — Stakeholder-Item ins Triage-Inbox (max 5/h).
- `/help` — Commands.

Installation nach Setup:

```bash
bash .claude/scripts/session-start.sh
bash .claude/scripts/install-telegram-bot.sh --load-now
```

```bash
# Intake-Council aktivieren (kein extra Install — läuft automatisch
# wenn telegram-bot.py geladen ist und intake-council.sh ausführbar ist).
ls -la .claude/scripts/intake-council.sh .claude/scripts/yota-propose.sh
```

## Referenzen

- Plan-Archiv: [`plans/`](plans/)
- Architektur-Plan dieses Setups: [`plans/2026-05-07_automation_ecosystem.md`](plans/2026-05-07_automation_ecosystem.md)
- Browser-Testing: [`plans/2026-05-07_browser_testing.md`](plans/2026-05-07_browser_testing.md)
- Headless-Loop: [`plans/2026-05-07_headless_loop.md`](plans/2026-05-07_headless_loop.md)
- Strategie-Doku: [`docs/STRATEGY.md`](docs/STRATEGY.md)
- Supabase-Setup: [`SUPABASE_SETUP.md`](SUPABASE_SETUP.md)
