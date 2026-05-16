[Committee-Approved 2026-05-16]

# RuFlow / claude-flow Integration — Evaluation für `inventory_management`

> Datum: 2026-05-16
> Slug: `ruflow-integration-evaluation`
> Branch (geplant): `feature/ruflow-integration-evaluation`
> Stakeholder-Frage: „Kann man hier von github RuFlow einbauen um das Agentennetzwerk aufzuräumen und optimieren. Berate dich ob es gut ist und für gute ergebnisse führen würde und ob du das einbauen könntest"

**Council-Verdict:** D+E als Primär-Pfad freigegeben. A/B/C als Audit-Spur dokumentiert (nicht ausgeführt). Council-Synthesis-Datum: 2026-05-16. 5 Reviewer parallel (Architekt/Bug-Hunter/External-Scout/Security/UX-DX), 10 Pflicht-Änderungen eingearbeitet.

> **Quellen für RuFlow-Fakten:**
> - GitHub-Repo: [ruvnet/ruflo](https://github.com/ruvnet/ruflo) (vormals `ruvnet/claude-flow`, umbenannt aus Trademark-Gründen)
> - [README](https://github.com/ruvnet/ruflo/blob/main/README.md), [USERGUIDE](https://github.com/ruvnet/ruflo/blob/main/docs/USERGUIDE.md), [CLAUDE.md](https://github.com/ruvnet/ruflo/blob/main/CLAUDE.md)
> - Aktuelle Release-Linie laut Stakeholder-Input: v3.7.0-alpha.33 (Mai 2026). Public-Search bestätigt v3.6 stable (2026-04-29) mit 314 MCP-Tools, 16 Agent-Rollen, 19 AgentDB-Controller, 21 native Plugins, 6000+ Commits ([Pasquale Pillitteri Guide v3.5](https://pasqualepillitteri.it/en/news/774/claude-flow-ruflo-multi-agent-orchestration-guide), [Releases](https://github.com/ruvnet/ruflo/releases)).
> - Tool-/Hook-/Plugin-Zahlen aus dem Stakeholder-Briefing (210 MCP-Tools, 27 Hooks, 100+ Agents, 32 Plugins, 18 Browser-Tools) sind plausibel — die genaue Zahl driftet zwischen Releases. Annahme: Größenordnung stimmt.

---

## Ziel

Ehrliche Evaluation, ob die Integration von **RuFlow / claude-flow** ([github.com/ruvnet/ruflo](https://github.com/ruvnet/ruflo)) unser bestehendes Agenten-System ablöst, ergänzt oder ignoriert werden sollte — und welche konkrete Variante (Full / Hybrid / Lite / Status-Quo) für eine Pre-Launch Flutter+Supabase-App mit Solo-Stakeholder die richtige ist. Council hat entschieden: **Variante D (Aufräum-Track auf eigenem Stack) + Variante E (Native-Adoption-Evaluation) parallel ausführen.** Variante A/B/C sind in der Audit-Spur dokumentiert, werden aber nicht ausgeführt.

---

## Council-Findings (2026-05-16)

10 Pflicht-Änderungen aus dem 5-Reviewer-Council (Architekt, Bug-Hunter, External-Scout, Security, UX/DX):

1. `.mcp.json` enthält Playwright UND Supabase-MCP (Plan unterzählte) → Threat-Model korrigiert (siehe Annahme A10).
2. MCP-Hook-Matcher erweitern (`Bash|Edit|...|mcp__.*`) + neuer `guard-mcp.sh` → Pflicht (T-D11).
3. `integrity-check.sh` + `integrity-manifest-build.sh` in `SELF_MOD_BLOCKLIST` aufnehmen → Pflicht (T-D12).
4. NPM-Supply-Chain-Härtung: pinned Version, VM/Docker-Sandbox, `npm audit signatures` (nur für A/B relevant — beide ausgeschlossen).
5. MCP-Permission-Wildcard verboten (nur für A/B relevant — ausgeschlossen).
6. `ANTHROPIC_API_KEY`-Pre-Flight (nur für A/B relevant — ausgeschlossen).
7. Annahme A7 (Subscription) zum Block-Risiko (nur für A/B relevant).
8. Variante D Aufräum-Track ergänzen → T-D7/T-D8/T-D9/T-D10 (Stakeholder-Frage „aufräumen" beantworten).
9. Variante C unverifiziert → in Audit-Spur verschoben.
10. rooroo/RooFlow Kategorie-Fehler → Annahme A8.

---

## Annahmen (explizit, Council bitte hart hinterfragen)

A1. **RuFlow Full-CLI ist destruktiv-additiv:** `npx ruflo init` legt eigene `.claude/`-Struktur, `CLAUDE.md` und `.claude-flow/`-State an. Nicht via Read überprüft — basiert auf README + USERGUIDE-Inhaltsangabe. Wenn Council das anzweifelt, muss vor Variante A ein Sandbox-Test in einem Temp-Repo durchgeführt werden (Task T-A0).

A2. **RuFlow-Hooks (27 Stück) konkurrieren mit unseren Hooks:** Wir haben aktuell mindestens
- `.claude/scripts/guard-bash.sh` (Pre-Bash-Guard, blockt `git push -f`, `supabase db push` etc.),
- `.claude/scripts/guard-edit.sh` (Pre-Edit-Guard für Secret-Pfade),
- `.claude/scripts/post-edit.sh` (Post-Edit, ruft `dart analyze`),
- `.claude/scripts/auto-commit.sh` (Stop-Hook, Whitelist-Commit),
- `.claude/scripts/integrity-check.sh` (Out-of-Process Manifest-Hash-Check),
- `.claude/scripts/install-self-mod-guard.sh` (Self-Mod-Blocklist).

Annahme: RuFlow registriert seine Hooks im selben `.claude/settings.json`-Namespace. Conflict-Probability: hoch.

A3. **MCP-Tool-Inflation kostet Context:** Jeder MCP-Server lädt sein Tool-Manifest in den System-Prompt jedes Agents. 210 Tools × ~20-50 Tokens Description = ~4-10k Tokens Overhead **pro Agent-Call**. Bei ~30 Agent-Aufrufen pro autonomem Tag = 120-300k Tokens reiner Tool-Beschreibungs-Overhead. Annahme: RuFlow exposed das gesamte Tool-Set per default, kein opt-in pro Agent. Council möge das gegen die RuFlow-MCP-Manifest-Doku checken.

A4. **„100+ Agents" sind Templates, kein Lift-and-Drop:** Annahme: Generische SWE-Agents (Tester, Doc-Writer, Code-Reviewer), die nichts über Flutter+Supabase+Provider-Pattern wissen. Unsere 22 Agents sind stack-spezifisch (Provider-Pattern, RLS-Pflicht, Theme-Tokens, l10n-Pflicht).

A5. **Plugins sind grundsätzlich opt-in:** SONA, RAG, AgentDB, Testgen, CVE-Audit, IoT, Trading, Market-Plugins lassen sich einzeln aktivieren/deaktivieren. Annahme nicht verifiziert — wenn das Bundle „all or nothing" ist, kippt Variante B (Cherry-Pick).

A6. **„Selbstbeschreibung" ≠ Realität:** RuFlow nennt sich „enterprise-grade", „self-learning", „federated". Für eine Pre-Launch Solo-Flutter-App ohne Multi-Tenant, ohne Enterprise-IT, ohne mehrere Devs sind diese Versprechen größtenteils **Solution looking for a Problem**.

A7. **Maintenance-Last RuFlow upstream:** 6000+ Commits, alpha-Releases im Monatsrhythmus, v3.0 → v3.7 in unter 6 Monaten. Upstream-Breaking-Changes sind regelmäßig zu erwarten. Annahme: Wir würden bei Adoption auf eine schnelldrehende Library Bet — und müssten Stack-Upgrades als regelmäßigen Task einplanen.

A8. **rooroo / RooFlow Kategorie-Fehler:** rooroo und RooFlow gehören zum Roo-Code-VS-Code-Extension-Ökosystem, NICHT Claude-Code. Vergleich nicht anwendbar — diese Tools wurden in frühen Council-Iterationen fälschlich als Alternativen vorgeschlagen.

A10. **`.mcp.json` enthält Playwright UND Supabase-MCP:** Der Plan unterzählte ursprünglich — neben Playwright ist der Supabase-MCP mit `--project-ref=uzpkrdymlrrydtuxnvhy` registriert. Threat-Model in Risiken aktualisiert: zusätzlicher MCP-Server bedeutet zusätzliche Tool-Surface, die durch `guard-mcp.sh` (T-D11) abgedeckt werden muss.

---

## Betroffener Scope

Was im Falle einer Integration berührt würde (nicht: was wir tun, sondern was im Konflikt-Radius liegt):

- **`.claude/agents/`** — 22 eigene Agents (planner, flutter-coder, db-migrator, edge-fn-coder, ui-builder, security-reviewer, tester, l10n-checker, help-curator, doc-updater, browser-tester, plan-critic, stakeholder-triage, stakeholder-validator, intake-pragmatist, intake-skeptic, intake-validator, disput-proponent, disput-skeptic, disput-pragmatist, yota, _page-registry).
- **`.claude/commands/`** — 13 eigene Slash-Commands (plan, work, migrate, queue, check-l10n, update-help, update-docs, test-ui, ship, plan-critic, yota, council, auto-run).
- **`.claude/scripts/`** — 75+ eigene Scripts (overseer.sh, worker.sh, watchdog.sh, recover.sh, cleanup.sh, briefing.sh, weekly-digest.sh, audit-backup.sh, cloud-heartbeat-ping.sh, intake-council.sh, telegram-bot.py über install-telegram-bot.sh, integrity-check.sh, install-self-mod-guard.sh, validate-plan.sh, check-smoke-passed.sh, …).
- **`.claude/backlog/`, `.claude/overseer/`, `.claude/stakeholder/`, `.claude/disputes/`, `.claude/audit/`, `.claude/integrity/`, `.claude/memory/`, `.claude/analyzer/`, `.claude/metrics/`, `.claude/schemas/`, `.claude/whitelist.txt`** — alle Daten- und Audit-Pfade des Autonomous Council Swarms.
- **`CLAUDE.md`** — ~500 Zeilen Projekt-Doku, Single-Source-of-Truth.
- **`.mcp.json`** — Playwright-MCP + Supabase-MCP (siehe A10). RuFlow würde 1 weiteren MCP-Server registrieren.
- **`.github/workflows/`** — falls RuFlow CI-Komponenten mitbringt.
- **LaunchAgents** in `~/Library/LaunchAgents/` (com.inventory.overseer, com.inventory.heartbeat, com.kerami.inventory.headless [deprecated], evtl. Analyzer, Recovery, Cleanup, Briefing, Weekly-Digest, Audit-Backup, Yota-Watch, Telegram-Bot) — RuFlow bringt einen eigenen Background-Worker-Stack mit (12 Auto-Triggered Background-Workers laut Briefing).
- **`plans/`** — bestehende Plan-Dokumente, insbesondere `2026-05-07_automation_ecosystem.md` und `2026-05-09_autonomous_council_swarm.md`, wären inkonsistent zur neuen RuFlow-Welt.

---

## Datenmodell + RLS

n/a in der Variante D (Status Quo) und Variante C (Lite-Plugin).

**Variante A (Full-Replace):** RuFlow's AgentDB ist laut README ein separater Layer mit 19 Controllern — vermutlich SQLite-File-basiert im `.claude-flow/`-State. **Risiko:** Wenn AgentDB Embeddings für RAG/SONA aus unserem `lib/`-Code generiert und in einem unverschlüsselten SQLite-File ablegt, ist das eine **neue Secret-Exfiltration-Surface** (insb. wenn versehentlich in Git committet). Wenn die AgentDB optional auf einen Cloud-Endpoint syncen sollte → harter Stop, würde Service-Role-Key-äquivalente Trust-Boundary durchbrechen.

**Variante B (Cherry-Pick mit RAG/AgentDB):** Falls wir z.B. das RAG-Plugin auf unserem `lib/`-Codebase laufen lassen, müssten wir entscheiden:
- Wo lagern Embeddings (lokal `.claude-flow/`, Supabase-Tabelle, externer Vector-Store)?
- Wer hat Read-Access (Service-Role vs. Anon-Key vs. lokales File)?
- Kommt PII rein? Unser `lib/`-Code enthält keine User-Daten direkt, aber Test-Fixtures unter `test/` evtl. schon.

Entscheidung **vor Adoption** in einer separaten Mini-RFC zu klären, nicht in diesem Plan.

---

## API / Edge Functions

n/a. RuFlow ist eine Tooling-/Orchestrierungs-Schicht, keine Backend-Komponente.

**Indirekter Impact bei Variante A/B:** Wenn RuFlow's MCP-Tools (z.B. Database-Tools, Github-Tools) parallel zu unseren Edge Functions auf Supabase zugreifen wollen, brauchen sie Credentials. **Risiko:** Wir müssten entweder
- ihnen unseren Service-Role-Key geben (No-Go),
- einen separaten Read-Only-Key generieren (zusätzliche Maintenance),
- oder ihre Database-MCP-Tools komplett deaktivieren (was den Nutzen reduziert).

---

## UI + l10n-Keys

n/a — Meta-Infrastruktur-Plan, keine User-sichtbare UI.

---

## Tests

Was wir verifizieren müssen, bevor wir einer Variante grünes Licht geben:

1. **Sandbox-Test in Temp-Repo** (Pflicht für Variante A und B): `npx ruflo init` in einem leeren Repo ausführen, Files+Hooks katalogisieren, gegen unsere Liste diffen.
2. **Hook-Konflikt-Test:** Mock-Setup mit beiden Hook-Stacks parallel, prüfen ob `guard-bash.sh` weiter triggert wenn RuFlow ebenfalls `PreToolUse` registriert.
3. **MCP-Tool-Token-Cost-Messung:** Single `claude --print -p "ping"` mit aktiviertem RuFlow-MCP vs. ohne; `cached_input_tokens` und `input_tokens` aus dem JSON-Output vergleichen. Schwelle: Wenn Overhead > 5k Tokens pro Call, ist Cost-Profil kaputt.
4. **Self-Mod-Guard-Smoke:** Sicherstellen, dass unser `install-self-mod-guard.sh` RuFlow-Scripts NICHT in Blocklist hat (sonst können wir RuFlow nicht updaten) — UND umgekehrt, dass RuFlow's eigene Hooks nicht Files unter `.claude/scripts/integrity-check.sh` etc. modifizieren.
5. **Backlog-Drain-Continuity-Test:** Während der Migration läuft der Overseer weiter — pausieren wir ihn, gehen Items im `.claude/overseer/inbox/` schlafen. Wir müssen entweder atomar migrieren oder einen Drain-Stop-and-Resume planen.
6. **Audit-Trail-Integrität:** Unser Audit-Log (`.claude/audit/<date>.md`) hat Hash-Chain (siehe `plans/2026-05-09_autonomous_council_swarm.md` Sektion Phase 0). Bei einer Replace-Strategie müsste das Audit entweder migriert oder mit Stichtag eingefroren werden.
7. **Browser-Tester-Continuity:** Unser `browser-tester` nutzt Playwright-MCP. RuFlow bringt 18 eigene Browser-Tools mit. Konflikt-Test: Welcher MCP-Server gewinnt bei doppelter Registrierung? Funktioniert `/test-ui smoke-full-app-audit` noch?
8. **Verify-Suite weiter grün:** `bash .claude/scripts/verify/*.sh` (laut CLAUDE.md 43+ Tests) — keine darf nach Integration kaputtgehen.

---

## Risiken

### Block-Risiken (zwingen zu Abbruch oder Rollback)

- **R1 — `.claude/`-Overwrite (Variante A):** RuFlow's `init` überschreibt potenziell `CLAUDE.md` und Teile von `.claude/`. Selbst mit Backup ist die Wiederherstellung der genauen Hook-Chain + LaunchAgent-Topologie + Audit-Trail-Hash-Chain nicht trivial. Mitigation: Komplett-Backup-Branch vor `init`, Sandbox-Test in Temp-Repo zuerst. [archiviert — Variante A nicht ausgeführt]
- **R2 — Hook-Race-Conditions:** Wenn beide Stacks ihre Hooks gleichzeitig auf `PreToolUse` registrieren, ist Reihenfolge nicht garantiert. Unser Self-Mod-Guard könnte umgangen werden. Mitigation: vor Integration explizites Test-Setup. [archiviert — Variante A nicht ausgeführt]
- **R3 — Token-Cost-Explosion durch MCP-Tools:** 210 Tools im System-Prompt jedes Agents → Pre-Launch-Budget (z.B. Council $0.80/Run, Worker $5/Run) bricht. Mitigation: Tool-Whitelisting, falls RuFlow das anbietet. Sonst Block. [archiviert — Variante A nicht ausgeführt]
- **R4 — Audit-Trail-Bruch:** RuFlow hat kein Hash-Chain-Audit (laut Feature-Liste). Variante A verliert unser Audit-Layer komplett. [archiviert — Variante A nicht ausgeführt]
- **R5 — Self-Modification:** RuFlow's „self-learning" Pattern könnte versuchen, eigenen Code zu editieren. Wenn das in unser `.claude/scripts/`-Verzeichnis greift → Sicherheits-Block. [archiviert — Variante A nicht ausgeführt]
- **R6 — Vendor-Lock-in / Upstream-Velocity:** alpha-Releases monatlich, v3.0→v3.7 in <6 Monaten. Breaking-Changes wahrscheinlich. Pre-Launch-Inventory-Management kann sich keine Tooling-Migration-Sprints leisten. [archiviert — Variante A nicht ausgeführt]
- **R7 — Subscription-Constraint:** Anthropic blockiert seit 04.04.2026 Pro/Max für Drittanbieter-Wrapper (siehe `plans/2026-05-09_autonomous_council_swarm.md`, External-Scout-Hinweis). RuFlow nutzt explizit MCP + Claude-Code-Native-Integration, NICHT die API direkt — sollte also Max-Plan-kompatibel sein. **Aber:** wenn RuFlow's Background-Worker eigene Auth-Flows nutzen, ist das gegenzuchecken. Block-Risiko nur für ausgeschlossene Variante A/B; für D/E nicht relevant.

### Schleichende Risiken

- **R8 — Solution-looking-for-a-Problem:** RuFlow ist für Multi-Dev-Teams, Multi-Repo, Enterprise-Security-Audits gebaut. Wir sind ein 1-Person-Pre-Launch-Repo. Feature-Bloat ohne Use-Case.
- **R9 — Lernkurve:** 27 Hooks + 210 Tools + 32 Plugins zu verstehen, bevor wir produktiv damit arbeiten — Stakeholder hat selbst gesagt „aufräumen", nicht „komplexer machen".
- **R10 — Duplication:** Wir haben bereits Council, Disput, Analyzer, Overseer, Worker-Pool, Watchdogs, Off-Site-Audit-Backup, Cloud-Heartbeat, Telegram-Bridge, Intake-Council, Self-Mod-Guard, Plan-Validator. RuFlow's „Swarm/Federation/Autopilot" überlappen mit dem, was wir bereits gebaut haben — nicht ersetzen sie es.
- **R11 — Plan-Doku-Drift:** Unsere zwei tiefen Plan-Dokumente (`automation_ecosystem`, `autonomous_council_swarm`) werden obsolet → Dokumentations-Schulden in `docs/handbook/` und `.claude/`-internen Verweisen.
- **R12 — Stakeholder-Surface-Veränderung:** `/btw`, `/yota propose`, Telegram-Bridge sind etabliert. Ein RuFlow-Replace würde User-Workflow brechen — Stakeholder müsste neue Slash-Commands lernen.
- **R13 — Native-Catch-Up (NEU):** Anthropic releast schneller native Features als wir migrieren → Eigenbau-Tech-Debt akkumuliert. Mitigation: Variante E periodisch wiederholen (alle 6 Monate), ADR-Output aus T-E4 als Trigger für Migrations-Sprint.

### Rückzieh-Pfad

- **Variante D:** kein Rollback nötig (= keine Disruptions-Änderung; reine Aufräum-PRs einzeln revertierbar).
- **Variante E:** Sandbox-only; Rollback = Feature-Flag `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0` zurücksetzen.
- **Variante A/B/C:** siehe Audit-Spur unten.

---

## Varianten — atomarer Vergleich

### Variante D (PRIMÄR) — Aufräum-Track auf eigenem Stack

**Was passiert:** Statt einer RuFlow-Adoption investieren wir in gezielte Verbesserungen unseres bestehenden Setups. Stakeholder-Frage „aufräumen" wird direkt beantwortet: Analyzer-Spam reduzieren, Cost-Routing optimieren, Security-Härtung des Self-Mod-Layers, Doku-Audit.

**Aufwand-Schätzung:** 4-6 PT (Tasks T-D1 bis T-D12, parallelisierbar).

**Pro:** Kein Vendor-Lock-in, jeder Fix kommt direkt unserem Use-Case zugute, Audit-/Self-Mod-Guard-/Intake-Layer bleiben intakt. Stakeholder bekommt „aufgeräumter" ohne Disruption. T-D11/T-D12 schließen konkrete Sec-Lücken (MCP-Hook-Coverage, Manifest-Integrity).

**Contra:** Wir verzichten auf das Potenzial von RuFlow's RAG/AgentDB/SONA. Mitigation: Variante E parallel.

#### Tasks

```
### T-D1 — Bottleneck-Analyse Analyzer-Output
agent: planner
depends: -
Input: .claude/analyzer/ — letzte 30 Tage Items, Häufigkeit pro Modul, „pre-existing"-Dedupe-Rate.
Output: Markdown-Report mit Top-3-Spam-Analyzern.
```

```
### T-D2 — Test-Coverage-Audit
agent: tester
depends: -
Input: `flutter test --coverage` lokal.
Output: Coverage-Report parsen, Service-Layer-Coverage messen, Top-5 ungetestete Services.
```

```
### T-D3 — Test-Coverage-Increment-Plan
agent: planner
depends: T-D2
Output: Plan-File in plans/ mit Priorisierung der Top-5 Services.
```

```
### T-D4 — Prompt-Cache-Hit-Rate-Verifikation
agent: yota
depends: -
Input: `bash .claude/scripts/verify/prompt-cache-friendly.sh` + letzte 10 Worker-Runs (cached_input_tokens).
Output: Read-only Snapshot-Report.
```

```
### T-D5 — Agent-Modell-Routing-Review
agent: planner
depends: -
Output: Welche Agents nutzen Opus, könnten Sonnet? Mit Cost-Vergleich aus realen Runs.
```

```
### T-D6 — Slash-Command-Hygiene-Audit
agent: doc-updater
depends: -
Input: `.claude/audit/` letzte 30 Tage.
Output: Nutzungsstatistik der 13 Commands, Deprecation-Kandidaten.
```

```
### T-D7 — Analyzer-Spam reduzieren
agent: flutter-coder
depends: T-D1
Input: Top-3-Spam-Analyzer aus T-D1.
Output: 1 PR — Analyzer-Config-Changes oder Dedup-Hash-Verschärfung.
```

```
### T-D8 — Cost-Routing Opus→Sonnet (vorsichtig, pro Agent ein PR)
agent: flutter-coder
depends: T-D5
Output: A/B-Cost-Vergleich aus 5 Real-Runs; je Agent 1 separater PR.
```

```
### T-D9 — Sec-Audit Status-Quo
agent: security-reviewer (Review) + flutter-coder (Edits)
depends: -
Output:
- .env.test in .gitignore UND in audit-backup-exclude verifizieren
- .claude/overseer/oauth-status.json in .gitignore ergänzen falls nicht drin
- .claude/overseer/cost-ledger.jsonl Redaction-Policy in CLAUDE.md dokumentieren
```

```
### T-D10 — Help/Doku-Audit
agent: doc-updater + help-curator
depends: -
Output:
- Alle 13 Slash-Commands + Telegram-Commands in lib/screens/help_screen.dart referenziert?
- docs/handbook/05-architecture.md aktuell?
- Tote/missing benennen, 1 PR mit Korrekturen.
```

```
### T-D11 — MCP-Hook-Matcher erweitern (Sec-Härtung)
agent: flutter-coder + security-reviewer (Review)
depends: -
Output:
- .claude/settings.json Matcher: Bash|Edit|Write|MultiEdit|NotebookEdit → +|mcp__.*
- Neuer guard-mcp.sh: prüft MCP-Tool tool_input.file_path gegen SELF_MOD_BLOCKLIST
- Smoke-Test: mcp__supabase__execute_sql mit Path-Verstoß → MUSS blockieren
```

```
### T-D12 — Integrity-Manifest absichern (Sec-Härtung)
agent: security-reviewer + flutter-coder
depends: T-D11
Output:
- integrity-check.sh + integrity-manifest-build.sh in SELF_MOD_BLOCKLIST aufnehmen
- Off-Site-Manifest-Backup aktivieren (audit-backup.sh erweitern)
- Migration-Pfad dokumentieren: wie wird Update später möglich (z.B. Session-Marker-Schutz)
```

---

### Variante E (SEKUNDÄR, parallel zu D) — Native Anthropic Adoption

Goal: Evaluieren, ob Anthropic-Native-Features (Mai 2026: Agent Teams, /goal, Agent View) Teile unseres Eigenbau-Stacks effizienter ersetzen.

Aufwand gesamt: ~2.5 PT.

```
### T-E1 — Agent-Teams-Sandbox-Test (1 PT)
agent: planner
depends: -
- CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 aktivieren
- Sandbox-Test gegen 2-3 Multi-Agent-Workflows (Council, Disput)
- ADR-Output: Eignung als Worker-Pool-Ersatz?
```

```
### T-E2 — /goal-Command-Test (1 PT)
agent: planner
depends: -
- /goal an konkretem Backlog-Item, inkl. Supervisor-Validation
- ADR-Output: Eignung als Disput-Tie-Break-Ersatz?
```

```
### T-E3 — Agent-View vs. yota-snapshot.sh (0.5 PT)
agent: planner
depends: -
- Vergleich Featureset + Token-Cost
- Output: pro/contra Yota-Migration
```

```
### T-E4 — ADR Native-Adoption-Decision
agent: planner
depends: T-E1, T-E2, T-E3
- Synthese aus T-E1/E2/E3
- ADR im plans/ — behalten oder migrieren?
```

---

## Audit-Spur (Variante A/B/C — nicht ausgeführt)

### Variante A — Full-Replace (RuFlow Full-CLI ersetzt unser Setup) — AUSGESCHLOSSEN

**Warum nicht ausgeführt:**
- Block-Risiken R1–R6 (siehe oben, alle archiviert).
- Audit-Hash-Chain-Verlust, 210-MCP-Tool-Token-Overhead, Hook-Race mit Self-Mod-Guard.
- Stakeholder-Workflow-Bruch (`/btw`, `/yota propose`, Telegram-Bridge).

[entfernt — siehe Audit-Spur. Originale T-A0..T-A11 wurden aufgrund Council-Verdict gestrichen.]

### Variante B — Hybrid / Cherry-Pick (einzelne RuFlow-Plugins) — AUSGESCHLOSSEN

**Warum nicht ausgeführt:**
- NPM-Supply-Chain-Risiko ohne Sandbox unverhältnismäßig.
- MCP-Permission-Wildcard-Bedarf widerspricht Sec-Policy.
- Testgen/CVE-Audit-Mehrwert kleiner als Variante-D-Aufräum-Track + Eigenbau-Tests.

[entfernt — siehe Audit-Spur. Originale T-B1..T-B7 wurden aufgrund Council-Verdict gestrichen.]

### Variante C — Lite-Plugin (nur Slash-Commands aus RuFlow) — AUSGESCHLOSSEN

**Warum nicht ausgeführt:**
- Council-Finding #9: unverifiziert. Lite-Plugin-Behauptung „0 workspace files" wurde nicht durch Sandbox-Test verifiziert.
- Mehrwert generischer Slash-Commands für Flutter+Supabase-Stack zu klein.

[entfernt — siehe Audit-Spur. Originale T-C1..T-C3 wurden aufgrund Council-Verdict gestrichen.]

---

## Pro/Contra-Matrix (zusammengefasst, post-Council)

| Kriterium | D: Aufräum-Track (PRIMÄR) | E: Native-Eval (SEKUNDÄR) | A/B/C: Audit-Spur |
|---|---|---|---|
| Aufwand | 4-6 PT | 2.5 PT | n/a (nicht ausgeführt) |
| Reversibilität | hoch (PR-granular) | sehr hoch (Flag) | n/a |
| Audit-Trail erhalten | ja | ja | NEIN (A) |
| Self-Mod-Guard erhalten | ja (gehärtet via T-D12) | ja | unklar (A) |
| Intake-Council erhalten | ja | ja | NEIN (A) |
| Token-Cost-Risiko | sinkt (T-D8) | niedrig | hoch (A) |
| Stack-Spezifität | bleibt | bleibt | sinkt (A) |
| Upstream-Drift-Risiko | keiner | Anthropic-Native | hoch (A/B) |
| Stakeholder-Workflow-Bruch | keiner | keiner | hoch (A) |
| Mehrwert vs. Pre-Launch-ROI | direkt messbar | mittelfristig | negativ (A) |

---

## Stop-Kriterien

Plan ist fertig zur Ausführung, sobald:

1. Tasks T-D1..T-D12 und T-E1..T-E4 in `.claude/backlog/inbox/` queued sind (mit `agent:`-Tag).
2. Variante E darf nur Eigenbau-Schichten ersetzen, wenn ADR (T-E4) Sicherheits-Gate (Audit-Hash-Chain, HMAC, Self-Mod-Guard) + DX-Gate (Telegram-Bridge + Yota-Surface) verifiziert hat.
3. T-D11/T-D12 (Sec-Härtung) sind unabhängig von D/E-Entscheidung Pflicht.
4. Annahmen A1-A10 entweder bestätigt, widerlegt oder explizit als „weiter offen" markiert sind.

---

## Implementation-Aufwand (final)

- Variante D (T-D1–T-D12): ~4-6 PT
- Variante E (T-E1–T-E4): ~2.5 PT
- Gesamt: 6.5-8.5 PT
- Vergleich Variante A: 3-5 PT mit hohem Block-Risiko + Tech-Debt → bewusst nicht gewählt.

---

## Referenzen

- [`CLAUDE.md`](../CLAUDE.md) — Projekt-Doku, Single-Source-of-Truth
- [`plans/2026-05-07_automation_ecosystem.md`](2026-05-07_automation_ecosystem.md) — Phase-1-Architektur unseres Subagenten-Setups
- [`plans/2026-05-09_autonomous_council_swarm.md`](2026-05-09_autonomous_council_swarm.md) — Phase-2-Architektur Overseer + Council + Stakeholder-Bridge
- [`.claude/agents/`](../.claude/agents/) — 22 eigene Agents
- [`.claude/commands/`](../.claude/commands/) — 13 eigene Slash-Commands
- [`.claude/scripts/`](../.claude/scripts/) — 75+ eigene Scripts
- RuFlow GitHub: [ruvnet/ruflo](https://github.com/ruvnet/ruflo)
- RuFlow USERGUIDE: [docs/USERGUIDE.md](https://github.com/ruvnet/ruflo/blob/main/docs/USERGUIDE.md)
- RuFlow CLAUDE.md: [CLAUDE.md](https://github.com/ruvnet/ruflo/blob/main/CLAUDE.md)
- RuFlow Releases: [Releases](https://github.com/ruvnet/ruflo/releases)
- Externe Übersicht v3.5: [Pasquale Pillitteri Guide](https://pasqualepillitteri.it/en/news/774/claude-flow-ruflo-multi-agent-orchestration-guide)

---

Plan finalisiert 2026-05-16, Council-Approved (5 Reviewer parallel + Stakeholder-Decision).
Primär: Variante D (Aufräum-Track) + Sekundär: Variante E (Native-Adoption-Eval) parallel.
Ready for `/work` — T-D11/T-D12 als Sec-Härtungs-Priorität, T-E4-ADR als 6-Monats-Trigger.
