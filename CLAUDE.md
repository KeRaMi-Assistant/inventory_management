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
  - `git add .` ist VERBOTEN. Nur Whitelist: `git add lib/ supabase/migrations/ supabase/functions/ test/ pubspec.yaml pubspec.lock plans/ .github/ CLAUDE.md .claude/`
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

## Referenzen

- Plan-Archiv: [`plans/`](plans/)
- Architektur-Plan dieses Setups: [`plans/2026-05-07_automation_ecosystem.md`](plans/2026-05-07_automation_ecosystem.md)
- Browser-Testing: [`plans/2026-05-07_browser_testing.md`](plans/2026-05-07_browser_testing.md)
- Headless-Loop: [`plans/2026-05-07_headless_loop.md`](plans/2026-05-07_headless_loop.md)
- Strategie-Doku: [`docs/STRATEGY.md`](docs/STRATEGY.md)
- Supabase-Setup: [`SUPABASE_SETUP.md`](SUPABASE_SETUP.md)
