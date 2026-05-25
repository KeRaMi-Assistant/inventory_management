# [Committee-Approved 2026-05-25, Pre-Launch-Scoped 2026-05-25]

# Autonomous-Roadmap & Capability-Doc-Policy (Pre-Launch-Scope)

**Datum:** 2026-05-25
**Author (Draft):** planner (Opus, Auto-Mode)
**Status:** Committee-approved nach 5-Reviewer-Council, anschließend
**Pre-Launch-gestrippt** auf Stakeholder-Direktive vom 2026-05-25.
**Original-User-Wunsch (EN):**
> "plan next steps which you can undertake by yourself, add that every change forces to update a tech doku what the application all possess"

**Author-Notes:** Nach Stakeholder-Feedback gestrippt — Worker-Security
(Self-Mod-Extensions, Capability-Skip-Allowlist, CI-Enforcement-Workflows,
Audit-Logs, Hard-Gates gegen autonome Worker) ist in §11 Post-Launch-
Sektion verschoben. Pre-Launch-Prämisse: Speed > Defense-in-Depth.
Die App hat noch keine echten Nutzer, keine Production-Workspaces, kein
echtes Billing. Aggressives Refactoring + Migrations sind OK. Härtung
wird **erst nach erster Live-Version** angegangen.

---

## 1. Ziel + Scope (Pre-Launch)

**Ziel:** Zwei zusammengehörige Outcomes liefern, **beschränkt auf
Doku-Erstellung + Doc-Sync**, KEIN Enforcement-Layer.

1. **Autonomous-Roadmap (Teil A):** Eine objektiv begründete Score-
   Tabelle aller 16 offenen Backlog-Items, ergänzt um Top-3-Self-Pick,
   Top-3-Council-First und eine harte Stop-Liste — sodass die
   Swarm-Pipeline für die nächsten 5–7 Working-Days ohne weiteren
   User-Input arbeiten kann.
2. **Capability-Doc-Sync (Teil B, vereinfacht):** Ein neues Handbuch-
   Kapitel `docs/handbook/00-overview.md` ("Capability Inventory") als
   flache, scannbare Single-Page-Übersicht "Was kann diese App?"
   initial befüllen, und den bestehenden `doc-updater`-Agent so
   erweitern, dass er das Kapitel mitpflegt — analog zum bereits
   gelebten Handbook-Sync.

**Explizit OUT OF SCOPE (auf Stakeholder-Direktive in §11 verschoben):**

- CI-Workflow `capability-doc-check.yml` (Enforcement gegen PRs)
- `check-capability-drift.sh` (Anchor-Validierung, Threat-Map-Filter,
  `[capability-skip:]`-Parser, Page-Registry-Sub-Check)
- Self-Mod-Blocklist-Erweiterung (`.github/workflows/*.yml`,
  `.claude/whitelist.txt`)
- Overseer-Hard-Gate-Flag (`.claude/overseer/blocks/…`)
- Audit-Logs (`capability-skips.log`, `capability-mute-events.log`)
- Repo-Stumm-Schalter (`vars.CAPABILITY_CHECK_DISABLED`)
- 14-Tage-Soft-Fail-Beobachtungsphase + Hard-Fail-Switch
- Maschinenlesbares Score-YAML + Analyzer-Refresh-Hook
- Bot-Bypass-Härtung, Workflow-Privilege-Escalation-Mitigation

Diese Punkte bleiben als Council-Output dokumentiert, werden aber
**erst nach erster Live-Version** aktiviert (siehe §11).

---

## 2. Betroffener Scope

### Neue Files
- `docs/handbook/00-overview.md` (NEU) — flacher Capability-Katalog als
  Handbuch-Kapitel. Slot 00 ist frei (existierende Kapitel 01–10).

### Geänderte Files
- `CLAUDE.md` — neue Sektion „Capability-Doc pflegen" analog zu
  „Handbook pflegen" und „Hilfeseite pflegen". **Self-Mod-Touch** →
  `requires_human_dispute: true` (CLAUDE.md ist in Blocklist).
- `docs/handbook/README.md` — Kapitel-Tabelle um Slot 00 erweitern,
  Navigations-Hinweis. Regulärer `doc-updater`-Touch, kein Self-Mod.
- `.claude/agents/doc-updater.md` — Klassifikator-Map erweitern: neue
  Files in `lib/screens/`, `lib/providers/`, `lib/services/`,
  `supabase/functions/`, `.claude/agents/` triggern zusätzlich ein
  00-overview-Update. **Self-Mod-Touch** → `requires_human_dispute: true`
  (`.claude/agents/` ist Blocklist-Pfad).

### Read-only
- `lib/screens/`, `lib/providers/`, `lib/services/`,
  `supabase/migrations/`, `supabase/functions/`, `.claude/agents/`
  (für Initial-Befüllung in Task A).
- `.claude/agents/_page-registry.md` (DRY-Anker für Screens).

---

## 3. Datenmodell + RLS

**Kein Schema-Change.** Das Capability-Doc ist statisch (Markdown,
git-versioniert). Keine neue Tabelle, keine neue Column, keine neue
RLS-Policy.

Tabellen-Namen aus `supabase/migrations/` werden in
`docs/handbook/00-overview.md` **referenziert** (Lookup-Liste mit
Migration-File-Pfad als Anchor). Pflege erfolgt durch den erweiterten
`doc-updater` — keine Live-DB-Abfrage.

---

## 4. API / Edge Functions

**Keine neuen Edge Functions.** Existierende werden in
`docs/handbook/00-overview.md` **gelistet** (mit 1-Zeilen-Beschreibung +
Function-Pfad-Anchor), aber nicht modifiziert.

---

## 5. UI + l10n-Keys

**Keine UI-Änderungen.** Dieses Feature ist Doc-/Tooling-fokussiert.
Keine neuen ARB-Keys, keine neuen Screens, keine Theme-Tokens.

Eine „Capabilities"-Sektion in `help_screen.dart` ist **explizit out of
scope** — der existierende Help-Screen ist user-facing, das
Capability-Kapitel ist dev-/stakeholder-facing.

---

## 6. Tests

### Manual / Smoke
- Nach Initial-Befüllung (Task A): Stakeholder liest
  `docs/handbook/00-overview.md` einmal komplett durch und meldet via
  `/yota propose "capability-doc-korrektur: …"` Lücken oder
  Halluzinationen.
- Manueller Cross-Check gegen `.claude/agents/_page-registry.md`:
  Stakeholder verifiziert, dass jeder Screen-Eintrag in 00-overview.md
  einen Match in der Registry hat. (CI-Sub-Check bleibt Post-Launch,
  siehe §11.)

### Static
- `flutter analyze` muss weiterhin grün laufen (kein Code-Change,
  triviale Verifikation).
- Doc-Updater-Map-Edit (Task B) wird durch normalen `/update-docs
  --dry-run` smoke-getestet: ein synthetischer Touch auf
  `lib/screens/foo_screen.dart` soll 00-overview im Plan-Output
  erscheinen.

---

## 7. Risiken (vereinfacht, Pre-Launch-Scope)

| # | Risiko | Wahrsch. | Impact | Mitigation |
|---|---|---|---|---|
| R1 | **Doc-Bloat** — Capability-Liste wird unlesbar | Mittel | Hoch | Strikte 1-Zeilen-Caps pro Eintrag, max 10 Sektionen, Inhaltsverzeichnis vorne. Verweise statt Duplikate (Screens → `_page-registry.md`). |
| R2 | **Halluzinationen in Task A** — Capability-Doc behauptet Features, die nicht existieren | Hoch | Hoch | `planner`-Opus mit explizitem **Evidence-Required-Constraint** im Prompt: jeder Eintrag braucht Klassen-/Function-Pfad/Tabellen-Name, der per `grep` validierbar ist. Plus Stakeholder-Review-Pass nach Initial-Run (Task A endet mit User-Read-Through). |
| R3 | **Drift trotz `doc-updater`-Erweiterung (Vergessen)** | Mittel | Mittel | Gleicher Mechanismus wie heute für Handbook-Drift — kein neuer Enforcement-Layer (bewusst). `/update-docs` ist die manuelle Pflicht vor `/ship`, wird in CLAUDE.md-Sektion (Task C) dokumentiert. Akzeptierter Trade-off: gelegentliche Drift > CI-Komplexität pre-launch. |
| R4 | **Doc-Layer-Drift** — `00-overview.md` vs. `_page-registry.md` vs. Handbook 03/05 driften auseinander | Mittel | Mittel | 00-overview bleibt **flach + top-level** (1 Zeile / Capability mit Anchor), Handbook 03/05 bleibt **deep-detail** (Architektur, Walkthrough), `_page-registry.md` bleibt **Test-Checkliste** (Routes, Pflicht-Tests). Cross-References explizit dokumentieren: Screens-Sektion in 00-overview verlinkt auf Registry, dupliziert nicht. CLAUDE.md-Sektion (Task C) macht die Layer-Trennung verbindlich. |

---

## 8. Teil A — Autonomous-Roadmap (Score-Tabelle + Picks)

### 8.1 Scoring-Methodik

Pro Inbox-Item:

- **ROI (low/mid/high):** high = hoher User-Impact / kostenkritisch,
  low = Nice-to-have.
- **Risk (low/mid/high):** high = hohes Regressions-/Sicherheits-Risiko,
  low = read-only.
- **Self-Mod-Touch:** `true` = touched `.claude/scripts/*`,
  `.claude/agents/*`, `CLAUDE.md`, `.claude/settings.json`,
  `.claude/hooks/*`, `.claude/whitelist.txt` → braucht
  Stakeholder-Approval. `false` = autonom pickbar.
- **Size:** XS (< 50 LoC), S (50–200), M (200–500), L (500+),
  XL (> 1k).

### 8.2 Score-Tabelle (Snapshot 2026-05-25)

| # | Item (slug) | ROI | Risk | Self-Mod? | Size | Autonom? | Notiz |
|---|---|---|---|---|---|---|---|
| 1 | `00-amazon-tracking-coverage-70pct` | high | mid | false | M | **Ja** | User-Frust (3. Iter), Edge-Fn + Pattern-Erweiterung, live-Diagnose nötig |
| 2 | `01-stakeholder-ruflow-t-d11-t-d12-approval` | high | high | **true** | M | Nein | `requires_human_dispute: true`, MCP-Hook-Erweiterung, Self-Mod-Pflicht |
| 3 | `03-council-ruflow-t-d1-analyzer-bottleneck` | mid | low | false | S | **Ja** | Read-only, schreibt `docs/audits/…md`, blockt T-D7 |
| 4 | `03-council-ruflow-t-d2-test-coverage-audit` | mid | low | false | S | **Ja** | Read-only, `flutter test --coverage`, blockt T-D3 |
| 5 | `03-council-ruflow-t-d3-test-coverage-plan` | high | low | false | S | **Ja** | Depends T-D2, Plan-Erstellung |
| 6 | `03-council-ruflow-t-d4-prompt-cache` | mid | low | false | XS | **Ja** | Read-only Snapshot, kein PR-Risk |
| 7 | `03-council-ruflow-t-d5-model-routing` | mid | low | false | S | **Ja** | Read-only, schreibt `docs/audits/…md`, blockt T-D8 |
| 8 | `03-council-ruflow-t-d6-slash-command-hygiene` | mid | mid | **partial** | S | Bedingt | Lesen ist OK, Empfehlungen für `.claude/commands/`-Deletion brauchen Stakeholder-Bestätigung |
| 9 | `03-council-ruflow-t-d7-analyzer-spam-fix` | high | mid | **true** | M | Nein | Schreibt `.claude/analyzer/configs/`, Self-Mod |
| 10 | `03-council-ruflow-t-d8-cost-routing` | high | mid | **true** | M | Nein | Schreibt `.claude/agents/*.md`, Self-Mod |
| 11 | `03-council-ruflow-t-d9-sec-audit-status-quo` | high | high | **true** | S | Nein | Schreibt `CLAUDE.md` + `.gitignore`, Self-Mod (CLAUDE.md) |
| 12 | `03-council-ruflow-t-d10-help-doku-audit` | mid | mid | false | M | **Ja** | Pflegt `help_screen.dart` + handbook + ARBs, regulär |
| 13 | `03-council-ruflow-t-e1-agent-teams-sandbox` | mid | low | false | M | **Ja** | Read-only Sandbox + ADR-Schreiben (`plans/`) |
| 14 | `03-council-ruflow-t-e2-goal-command-test` | mid | low | false | S | **Ja** | Read-only Test + ADR-Snippet |
| 15 | `03-council-ruflow-t-e3-agent-view-vs-yota` | low | low | false | S | **Ja** | Read-only Vergleich + ADR-Snippet |
| 16 | `03-council-ruflow-t-e4-adr-native-decision` | high | low | false | M | **Ja** | Depends T-E1, T-E2, T-E3 → Final-ADR-Synthese |

### 8.3 Top-3 für sofortigen Self-Pick

Begründung: hohe ROI/Risk-Quotient, read-only oder enge Scope-Limits,
keine Self-Mod-Pfade, klare Erfolgskriterien.

1. **#3 T-D1 (analyzer-bottleneck-analyse)** — Read-only, blockt T-D7,
   liefert objektive Belege. Agent: `planner`.
2. **#4 T-D2 (test-coverage-audit)** — Read-only,
   `flutter test --coverage` + Markdown-Report. Validiert das
   CLAUDE.md-Auto-Merge-Gate (>60%). Agent: `tester`.
3. **#6 T-D4 (prompt-cache-verifikation)** — Read-only Status-Snapshot,
   minimaler Aufwand. Agent: `yota`.

→ Parallel-Worker-Run möglich, < $1.50 zusammen.

### 8.4 Top-3 die zwar autonom machbar wären, aber `/council` davor sinnvoll wäre

1. **#1 Amazon-Tracking-Coverage 70%** — User-Frust, 3. Iteration,
   Coverage-Metrik potentiell gameable. Agent: `planner` → `edge-fn-coder`
   + `flutter-coder`.
2. **#13 T-E1 (agent-teams-sandbox)** — Architektur-relevant
   (Anthropic-Native vs. Eigenbau). Agent: `planner`.
3. **#16 T-E4 (ADR Native-Adoption-Decision)** — Synthese-ADR,
   langfristig richtungsweisend. Agent: `planner`.

### 8.5 Stop-Liste (zwingend User-Input erforderlich)

| # | Item | Warum gestoppt |
|---|---|---|
| 2 | T-D11/T-D12 Approval | Self-Mod-Pfade (`.claude/settings.json`, `guard-mcp.sh`, `self-mod-blocklist.sh`) + `requires_human_dispute: true`. |
| 9 | T-D7 Analyzer-Spam-Fix | Touched `.claude/analyzer/configs/*` + `.claude/scripts/scan-*.sh`. Self-Mod. |
| 10 | T-D8 Cost-Routing Opus→Sonnet | Touched `.claude/agents/*.md`. Self-Mod + User-Memo: KEIN pauschales Downgrade. |
| 11 | T-D9 Sec-Audit + CLAUDE.md-Section | Touched `CLAUDE.md` + `.gitignore`. |
| 8 | T-D6 Slash-Command-Deprecation (partial) | Löschung von `.claude/commands/*.md` braucht Bestätigung. |

→ Stop-Liste-Items werden via `/yota propose` oder direkten Stakeholder-
Touch in einer User-Session bearbeitet.

---

## 9. Teil B — Capability-Doc (vereinfacht)

### 9.1 File-Pfad: `docs/handbook/00-overview.md`

**Begründung der Konsolidierung (Council-Feedback A1):**

- Existierender Doc-Layer: Handbook (Entwickler-Deep-Dive in 01–10),
  Help-Screen (User-Help), Page-Registry (Screen-Test-Checkliste).
  Ein 4. Layer `docs/CAPABILITIES.md` brächte Pflege-Overhead ohne
  Mehrwert. Handbook-Pattern ist bewährt (10 Kapitel, doc-updater
  pflegt).
- **Slot-Wahl 00:** Existierende Kapitel beginnen bei 01. Slot 00 ist
  frei und semantisch passend („überfliegen vor dem Tiefen-Einstieg").
  README-Tabelle wird in Task A um den Slot ergänzt.
- **`_page-registry.md` bleibt canonical-source** für Screens
  (Route-Pfad, Pflicht-Tests). 00-overview referenziert die Registry
  für den Screens-Block (Link auf
  `.claude/agents/_page-registry.md`) statt zu duplizieren.

### 9.2 Doc-Struktur (Sektionsliste)

```markdown
# Capability Inventory — inventory_management

> Was kann diese App? Flache, scannbare Referenz mit Code-Pfaden.
> Tiefe-Detail siehe Kapitel 01–10. Screen-Routen sind canonical
> in [`.claude/agents/_page-registry.md`](../../.claude/agents/_page-registry.md).

## Inhalt
- [User-sichtbare Screens & Features](#screens)
- [Daten-Pipelines](#pipelines)
- [Edge Functions](#edge-functions)
- [Daten-Modell (high-level)](#daten-modell)
- [Subagents (intern, Claude-side)](#subagents)
- [Stakeholder-Trigger (intern)](#stakeholder-trigger)

## Screens
> Single-Source-of-Truth: `_page-registry.md`. Hier nur 1-Zeilen-
> Was-kann-man-dort-Beschreibung pro Top-Level-Route.

| Screen | Was kann man dort? | Anchor (Klassen-Name) |
|---|---|---|
| Dashboard | KPI-Karten, Quick-Actions | `class DashboardScreen extends` |
| Inventory | Produktliste, Suche, Filter, Deal-Status-Badge | `class InventoryScreen extends` |
| … | … | … |

## Pipelines
| Pipeline | Trigger | Anchor | Schreibt nach |
|---|---|---|---|
| Inbox-Mail-Pipeline | IMAP-Poll | `supabase/functions/_shared/inbox_adapters.ts` | `parsed_messages` |
| Tracking-Poll | Cron | `supabase/functions/tracking-poll/` | `deals.live_status` |
| … | … | … | … |

## Edge Functions
| Function | Zweck | Anchor |
|---|---|---|
| `inbox-poll` | IMAP-Polling | `supabase/functions/inbox-poll/` |
| … | … | … |

## Daten-Modell
| Tabelle | Zweck | Anchor (Migration) |
|---|---|---|
| `workspaces` | Workspace-Scoping | `supabase/migrations/20260504000300_workspace_rls_fix.sql` |
| … | … | … |

## Subagents
| Agent | Aufgabe | Anchor |
|---|---|---|
| `planner` | Architektur, Plan-Erstellung | `.claude/agents/planner.md` |
| … | … | … |

## Stakeholder-Trigger
- `/yota` (Telegram + CLI) — Status-Snapshot
- `/btw <text>` — Stakeholder-Item
- `/yota propose <idee>` — Intake-Council
```

**Constraints:**

- Max 1 Zeile pro Tabellen-Eintrag.
- Jeder Eintrag MUSS einen grep-validierbaren Anchor haben
  (Klassen-Name / Function-Pfad / Migration-File). Pre-Launch wird
  das **manuell** geprüft (Stakeholder-Review im Task-A-Abschluss);
  automatischer `--evidence-mode` ist Post-Launch (§11).
- Max 6 Sektionen (Header-Liste oben). Bei Overflow → Sub-Doc unter
  `docs/handbook/00-overview/<area>.md`.
- **Screens-Sektion verlinkt `_page-registry.md`** und dupliziert sie
  nicht (DRY-Anker, Council-Feedback A1).

### 9.3 Sync-Mechanismus (vereinfacht)

**Gewählt: `doc-updater`-Erweiterung, keine neue Agent-Instanz.**

Der existierende `doc-updater` kennt bereits die Klassifikator-Map
(siehe `.claude/agents/doc-updater.md` §Kapitel-Map). Task B erweitert
die Map: Pfade, die heute `03-screens-walkthrough.md` /
`05-architecture.md` / `06-database.md` / `07-edge-functions.md`
triggern, triggern **zusätzlich** ein Update von
`docs/handbook/00-overview.md`.

- Inkrementell: kein Rewrite, nur Tabellen-Zeile hinzufügen/entfernen.
- Anchor-Pflicht: doc-updater MUSS für jeden neuen Eintrag einen
  grep-validierbaren Anchor (Klassen-Name / Function-Pfad /
  Migration-File) eintragen.
- Hartes „DO NOT": niemals Capability erfinden — bei Unsicherheit
  `> TODO: Anchor prüfen` und im Report melden.

→ Damit entfällt der ursprünglich geplante `capability-curator`-Agent
+ der `/update-capabilities`-Slash-Command vollständig. `/update-docs`
übernimmt automatisch auch 00-overview.

### 9.4 Doc-Layer-Trennung (R4-Mitigation)

| Layer | Datei | Inhalt | Tiefe |
|---|---|---|---|
| Capability-Overview | `docs/handbook/00-overview.md` | „Was kann diese App?" mit Anchor pro Eintrag | flach, top-level, max 1 Zeile/Capability |
| Handbook deep-detail | `docs/handbook/01–10.md` | Walkthrough, Architektur, Pipelines, Schema, Glossar | tief, lehrend |
| Screen-Test-Checkliste | `.claude/agents/_page-registry.md` | Route + Pflicht-Tests + Notizen pro Screen | breit, test-orientiert |
| User-Help | `lib/screens/help_screen.dart` + ARBs | User-Sicht, FAQ, How-to | user-facing |

Cross-References sind im Header von 00-overview.md und in CLAUDE.md-
Sektion (Task C) verbindlich dokumentiert.

---

## 10. Tasks (atomar, Pre-Launch-Scope)

> **Reihenfolge:** Task A → Task B → Task C. Tasks B + C sind Self-Mod
> (User-Session zwingend). Task A ist autonom durch `planner`-Opus
> ausführbar.

---

### Task A — Initial-Befüllung `docs/handbook/00-overview.md`

1. Scanne `lib/screens/`, `lib/providers/`, `lib/services/`,
   `supabase/migrations/`, `supabase/functions/`, `.claude/agents/`.
2. Pro Sektion (siehe §9.2) Tabelle generieren — 1 Zeile pro Item.
3. Jeder Eintrag MUSS einen grep-validierbaren Anchor haben
   (Evidence-Required-Constraint, R2-Mitigation).
4. Hard-Cap: max 30 Einträge pro Sektion (dann Sub-Doc).
5. Inhaltsverzeichnis vorne, Sektion-Anchors korrekt.
6. Screens-Sektion verweist auf `_page-registry.md`, dupliziert sie
   nicht.
7. `docs/handbook/README.md` um Slot-00-Eintrag ergänzen
   (Kapitel-Tabelle).
8. Abschluss: Stakeholder liest 00-overview.md einmal komplett durch
   und meldet via `/yota propose "capability-doc-korrektur: …"`
   Lücken/Halluzinationen.

Output: `docs/handbook/00-overview.md` (Single-File, max ~600 Zeilen),
plus README-Edit.

- **agent:** `planner` (Opus — Halluzinations-Risiko erfordert höchste
  Modellqualität)
- **depends:** —
- **touches:** `docs/handbook/00-overview.md` (NEU),
  `docs/handbook/README.md` (Edit)
- **requires_human_dispute:** false (autonom)
- **size:** L
- **estimated_cost:** $3–5 (Opus, langer Scan-Run; ggf.
  `--max-budget-usd 6`)

- [ ] Task A erledigt

---

### Task B — `doc-updater`-Klassifikator-Map erweitern

Erweitere `.claude/agents/doc-updater.md` Klassifikator-Map:

1. Identifiziere die bestehende Kapitel-Map-Tabelle (Zeilen-Bereich
   um Zeile 22–43, kann beim Edit driften).
2. Ergänze pro Pattern, das ein User-sichtbares Capability triggern
   kann, einen Zusatz-Hinweis: `… + 00-overview.md (Tabellen-Update)`.
   Konkret betroffen:
   - `lib/screens/*` → ergänze 00-overview-Update
   - `lib/providers/*` → ergänze 00-overview-Update (Provider-Sektion
     bei Bedarf, sonst nur via Architektur-Trigger)
   - `lib/services/*` (außer `inbox_*` — die laufen über 04) →
     ergänze 00-overview-Update
   - `supabase/migrations/*.sql` → ergänze 00-overview-Update
   - `supabase/functions/<name>/` → ergänze 00-overview-Update
   - `.claude/agents/<x>.md` → ergänze 00-overview-Update
3. Anchor-Pflicht im Workflow-Abschnitt dokumentieren: doc-updater
   trägt für jeden neuen Eintrag einen grep-validierbaren Anchor ein.
4. Hartes „DO NOT": niemals Capability erfinden — bei Unsicherheit
   `> TODO: Anchor prüfen` und im Report melden.

**Self-Mod-Hinweis:** `.claude/agents/doc-updater.md` ist ein
**bestehender** Blocklist-Pfad (`.claude/agents/` ist Self-Mod-Glob).
Das ist KEIN neuer Blocklist-Eintrag — die Blocklist bleibt
unverändert. Edit erfolgt in User-Session.

- **agent:** `stakeholder-manual` (User-Session: `session-start.sh` →
  Edit → commit → `session-end.sh`)
- **depends:** Task A
- **touches:** `.claude/agents/doc-updater.md`
- **requires_human_dispute:** true
- **size:** S
- **estimated_cost:** $0 (manuell)

- [ ] Task B erledigt

---

### Task C — CLAUDE.md-Sektion „Capability-Doc pflegen" ergänzen

Neue Sektion in CLAUDE.md analog zu `§Handbook pflegen` und
`§Hilfeseite pflegen`. Inhalt:

- **Was triggert ein Update?** — User-sichtbare Capabilities: neuer
  Screen (`lib/screens/<x>_screen.dart`), neuer Provider
  (`lib/providers/`), neuer Service (`lib/services/`, außer
  `inbox_*`), neue Tabelle / Migration, neue Edge-Function, neuer
  Subagent (`.claude/agents/`).
- **Aufruf:** `/update-docs` (doc-updater pflegt nach Task B
  automatisch auch `00-overview.md` mit) — KEIN neuer Slash-Command.
- **Wann ausführen:** Vor jedem `/ship`, sobald der PR über reine
  Bugfixes hinausgeht (neues Feature / Tabelle / Function / Agent).
  Periodisch: `/update-docs --from <letzter-Doku-Sync> --apply`.
- **Doc-Layer-Trennung** (R4-Mitigation, siehe §9.4 dieses Plans):
  `00-overview.md` ist flach + top-level, `_page-registry.md` bleibt
  canonical-source für Screens, Handbook 01–10 bleibt deep-detail.
- **Grenzen:** keine Refactors, keine ARB-Listen. Anchor-Pflicht pro
  Eintrag (grep-validierbar).
- **Pre-Launch-Hinweis:** Aktuell keine CI-Enforcement — Pflege ist
  manuell vor `/ship`. CI-Check + Audit-Logs + Stumm-Schalter folgen
  Post-Launch (siehe §11 dieses Plans).

**Self-Mod-Hinweis:** CLAUDE.md ist in Blocklist. Edit erfolgt in
User-Session.

- **agent:** `stakeholder-manual` (User-Session)
- **depends:** Task B
- **touches:** `CLAUDE.md`
- **requires_human_dispute:** true
- **size:** S
- **estimated_cost:** $0 (manuell)

- [ ] Task C erledigt

---

## 10.1 Subagent-Zuordnung — Zusammenfassung

| Task | Agent | Self-Mod? | Auto-pickbar? |
|---|---|---|---|
| A | `planner` (Opus) | Nein | **Ja** (autonom) |
| B | `stakeholder-manual` (User-Session) | Ja (`.claude/agents/`) | Nein |
| C | `stakeholder-manual` (User-Session) | Ja (CLAUDE.md) | Nein |

---

## 11. Post-Launch — Worker-Security-Härtung

> **Stakeholder-Direktive 2026-05-25:** Pre-Launch = Speed >
> Defense-in-Depth. Folgende Items sind im 5-Reviewer-Council
> identifiziert worden und bleiben als Council-Output dokumentiert,
> werden aber **erst nach erster Live-Version** aktiviert.
>
> Beim Auslöser-Trigger („Aktivieren bei: …") wird der jeweilige Item
> per `/yota propose` oder direktem Stakeholder-Touch ins Backlog
> gehoben und sequenziell abgearbeitet.

### Alphabetische Liste der Post-Launch-Items

**A4 — Self-Mod-Blocklist erweitern um `.github/workflows/*.yml` und
`.claude/whitelist.txt`.**
Begründung: Workflow-Files sind heute nicht in der Self-Mod-Blocklist.
Sobald ein autonomer Worker einen Workflow erstellen oder editieren
können soll (z.B. für capability-doc-check.yml), kann er beliebige
`run: bash`-Steps in CI-Workflows schreiben — Privilege-Escalation.
Aktivieren bei: **Erster Worker-Run gegen Production-Supabase** (sobald
ein autonomer Worker CI-Workflow-Edits machen können soll).

**A5 — Workflow-Permissions least-priv.**
Begründung: Default-Permissions in GitHub-Workflows sind zu weit
(`contents: write`, `actions: write`). Least-priv heißt nur
`contents: read` + `pull-requests: write`, kein `id-token`, kein
`actions: write`. Concurrency-Group zusätzlich gegen Race-Conditions.
Aktivieren bei: **Erstem CI-Enforcement-Workflow** (z.B.
`capability-doc-check.yml`), oder bei erster Production-CI-Pipeline.

**A6 — `[capability-skip: <reason>]`-Allowlist + Audit-Log +
Bot-Block.**
Begründung: Reasons außerhalb 5er-Allowlist (`refactor-only`,
`internal-tooling-only`, `revert-pr`, `dependency-bump`,
`ci-config-only`) sollen rejected werden. Bot-Authors
(`user.type == 'Bot'`) dürfen keine Skip-Marker setzen. Jede Skip
geht in `.claude/audit/capability-skips.log`.
Aktivieren bei: **Erster CI-Enforcement-Workflow live** (Voraussetzung
für A6 ist, dass überhaupt ein Capability-Check existiert).

**A7 — Bot-Bypass-Fix via Diff-only-Check + signed-commit-verification.**
Begründung: Username-Check (`if user.login != 'bot-name'`) ist trivial
bypass-bar in Fork-PRs oder mit gleichem Bot-Account-Namen. Stattdessen
Diff-only-Logic: wenn PR-Diff komplett innerhalb Doc-Allowlist-Pfade
liegt → Workflow skipt sich selbst. Verhindert auch Loop bei
doc-updater-Auto-Commits.
Aktivieren bei: **Erstem Auto-Commit-Bot mit Push-Access auf main-PRs**.

**A8 — Env-Variable-Namen-Filter im check-script.**
Begründung: Capability-Doc kann versehentlich Env-Var-Namen
(`SUPABASE_SERVICE_ROLE_KEY`, `_TOKEN`, `_KEY`, `_SECRET`) listen →
Threat-Map für Angreifer. Regex-Filter: `Deno\.env\.get\(['"][^'"]+['"]\)`,
`SUPABASE_SERVICE_ROLE`, `_TOKEN`, `_KEY`, `_SECRET`, `PASSWORD` → Exit 1.
Aktivieren bei: **Erster echter User-Anmeldung** (sobald die App
publik erreichbar ist und Threat-Map-Leaks ein reales Risiko sind).

**A9 — Overseer-Hard-Gate-Flag.**
Begründung: `.claude/overseer/blocks/<feature>.flag`-Pattern — solange
Flag existiert, skipt `pick_next_item` Items mit zugehörigem
Slug-Pattern. Verhindert Race-Conditions zwischen Self-Mod-Tasks und
nachgelagerten Worker-Picks. Wird in `picker.sh:168` eingehängt.
Aktivieren bei: **Erstem Worker-Run gegen Production-Supabase** oder
**erstem Multi-Phase-Feature mit Self-Mod-Setup** (Voraussetzung-Task
muss durch sein, bevor nachgelagerte Tasks pickbar werden).

**A10 — Halluzinations-Smoke-Test mit grep-validierbarem Anchor +
`check-capability-drift.sh --evidence-mode`.**
Begründung: Pre-Launch wird Anchor-Validierung manuell durch
Stakeholder-Read-Through gemacht (Task A endet damit). Post-Launch
soll das automatisierte `--evidence-mode`-Script jeden Anchor greppen:
Screens (`class <Name>Screen extends`), Providers (`class <Name>Provider`),
Edge-Functions (Pfad-Existenz), Tabellen (Migration-File oder
Table-Name in SQL). Kein Hit → Exit 1.
Aktivieren bei: **Erstem Production-Workspace mit Billing** (sobald
Doc-Drift teuer wird, weil sie auf User-Marketing-Material durchschlägt).

**A12 — CI-Comment-Wortlaut (DE, max 5 Zeilen, copy-pasteable
Fix-Command).**
Begründung: PR-Comment muss exakt spec'd sein, sonst weiß der
PR-Author nicht, wie er den Check grün bekommt. Wortlaut:
„⚠️ Capability-Doc-Drift erkannt / Geänderte Files: <auto-filled> /
Fix: (a) 00-overview.md updaten ODER (b) `[capability-skip: <reason>]`
ins PR-Body / Lokal: `bash .claude/scripts/check-capability-drift.sh
--pr-mode` / Allowed reasons: refactor-only, internal-tooling-only,
revert-pr, dependency-bump, ci-config-only".
Aktivieren bei: **Erstem CI-Enforcement-Workflow live** (Teil des
Workflow-File-Inhalts).

**A13 — Repo-Stumm-Schalter via `CAPABILITY_CHECK_DISABLED`.**
Begründung: Notfall-Knopf, falls der CI-Check massiv False-Positives
produziert. `gh variable set CAPABILITY_CHECK_DISABLED --body 1`
deaktiviert den Check repo-weit. Set/Unset-Events gehen in
`.claude/audit/capability-mute-events.log`.
Aktivieren bei: **Erstem CI-Enforcement-Workflow live** (Notfall-
Knopf gehört dazu).

**A14 — Page-Registry-Korrelation als CI-Check.**
Begründung: Pre-Launch macht Stakeholder den Cross-Check manuell beim
Read-Through (Task A). Post-Launch soll `check-capability-drift.sh
--check-page-registry-consistency` jeden Top-Level-Screen-Eintrag in
00-overview gegen `_page-registry.md` matchen — Mismatch → Exit 1.
Aktivieren bei: **Erstem Production-Workspace mit Billing** (sobald
Manuelle Cross-Checks nicht mehr skalieren).

### Post-Launch-Risiken (R5–R11, dokumentiert)

| # | Risiko | Aktiviert bei |
|---|---|---|
| R5 | **Self-Mod-Bypass** — autonomer Worker editiert Self-Mod-Pfad via Detour | Erster Worker-Run gegen Production-Supabase |
| R6 | **CI-Workflow-Loop** — Auto-Update pusht Doc → triggert wieder CI → Endlosschleife | Erster CI-Enforcement-Workflow live (A7 mitigiert) |
| R7 | **Plan-Score-Veraltung** durch Inbox-State-Drift; Lösung: Score-YAML + Analyzer-Refresh-Hook | Erstem Multi-Worker-Parallel-Run gegen Production |
| R8 | **Soft-fail-Ignoranz** — Devs ignorieren CI-Warnings, Doc veraltet | Erster CI-Enforcement-Workflow live (14d-Soft-Fail-Beobachtung dann) |
| R9 | **Bot-Bypass via Username-Spoofing** | Erstem Auto-Commit-Bot mit Push-Access (A7 mitigiert) |
| R10 | **Workflow-Privilege-Escalation** durch Workflow-File-Edit eines autonomen Workers | Erster Worker-Run gegen Production-Supabase (A4 + A5 mitigieren) |
| R11 | **Threat-Map-Leak** — Capability-Doc listet Env-Var-Namen | Erster echter User-Anmeldung (A8 mitigiert) |

### Post-Launch-Tasks (verschoben aus dem ursprünglichen Plan)

- **Task 1 (ursprünglich):** Whitelist-Update + Overseer-Pick-Hard-Gate
  (A9). Aktivieren bei: Erstem Worker-Run gegen Production-Supabase.
- **Task 3 (ursprünglich):** `check-capability-drift.sh` schreiben
  (Anchor-Validierung, Threat-Map-Filter, Page-Registry-Sub-Check,
  Escape-Hatch-Parser, Bot-Author-Check, Self-Test). Aktivieren bei:
  Erstem Production-Workspace mit Billing.
- **Task 5 (ursprünglich):** GitHub-Workflow `capability-doc-check.yml`
  (A3, A5, A7, A12, A13). Aktivieren bei: Erstem CI-Enforcement-
  Workflow-Bedarf (vermutlich kurz vor erster Live-Version).
- **Task 7 (ursprünglich):** Score-YAML + Analyzer-Hook (A11).
  Aktivieren bei: Erstem Multi-Worker-Parallel-Run gegen Production
  (sobald Inbox-State zu schnell driftet für manuelle Markdown-
  Pflege).
- **Task 8 (ursprünglich):** Sample-Migration mit T-D2 als End-to-End-
  Smoke des neuen CI-Checks. Aktivieren bei: Erstem CI-Enforcement-
  Workflow live (Smoke direkt im Anschluss).
- **Task 10 (ursprünglich):** 14-Tage-Beobachtungs-Phase + Soft/Hard-
  Fail-Switch + Metrik-Audit. Aktivieren bei: 14 Tagen nach CI-Workflow-
  Go-Live.

---

## 12. Stop-Kriterien (für diesen Plan)

- Plan deckt beide Pre-Launch-Outcomes (A + B vereinfacht) ab:
  **erfüllt**.
- Tasks atomic (1 Task = 1 PR-fähiges Increment): **erfüllt**
  (3 Tasks: A autonom, B + C User-Session).
- Risiken benannt + Mitigations (R1–R4 Pre-Launch, R5–R11 Post-Launch):
  **erfüllt**.
- Self-Mod-Pfade explizit markiert: **erfüllt** (Task B, Task C).
- Doc-Layer-Trennung explizit (R4-Mitigation): **erfüllt** (§9.4).
- Halluzinations-Schutz (R2-Mitigation): **erfüllt** (planner-Opus +
  Evidence-Required-Constraint + Stakeholder-Read-Through).
- DRY-Anker zu `_page-registry.md`: **erfüllt** (§9.2 Screens-Sektion,
  §9.4 Layer-Tabelle).
- Plan auf Deutsch: **erfüllt**.
- Worker-Security in Post-Launch verschoben: **erfüllt** (§11).

---

## 13. Council-Review-Trail

5-Reviewer-Council vom 2026-05-25, Verdict + Top-Befund pro Reviewer
(1 Zeile):

| Reviewer | Datum | Verdict | Top-Befund |
|---|---|---|---|
| **Architekt** | 2026-05-25 | needs-changes → approved | „Vierter Doc-Layer ist Bloat — Capability-Doc gehört als Handbuch-Kapitel 00, nicht als top-level `docs/CAPABILITIES.md`. Page-Registry bleibt canonical-source." → Integration A1, A2. |
| **Pessimist/Bug-Hunter** | 2026-05-25 | needs-changes → approved | „Task-1-Deadlock: Workflow-Tasks würden Worker pre-Whitelist blockieren. Plus: Bot-Username-Check (R6) ist trivial bypass-bar — Username spoofbar in Forks." → Integration A7 (Diff-only-Skip), A9 (Hard-Gate-Flag), A11 (YAML statt Markdown-Parse). |
| **External-Solutions-Scout** | 2026-05-25 | needs-changes → approved | „CI-Logik per Eigenbau-Shell ist Re-Invent-the-Wheel. `tj-actions/changed-files@v45` + `danieljimeneznz/ensure-files-changed@v4` sind battle-tested und schrumpfen Eigen-Code auf ~30 LoC." → Integration A3. |
| **Security** | 2026-05-25 | block → approved | „Drei kritische Lücken: (1) `.github/workflows/*.yml` fehlt in Self-Mod-Blocklist → Privilege-Escalation (R10); (2) `pull_request_target` als Trigger leakt Secrets bei Fork-PRs; (3) Capability-Doc kann Env-Var-Namen leaken → Threat-Map für Angreifer (R11). Plus least-priv permissions zwingend." → Integration A4, A5, A8, R10, R11. |
| **UX/Mobile** | 2026-05-25 | approved | „Keine UI-Wirkung. Reviewer-Kommentar nur: PR-Comment-Wortlaut spec'en (DE, max 5 Zeilen, copy-pasteable Fix-Command), Stumm-Schaltung dokumentieren, Skip-Reason-Allowlist nicht selbst-grantable." → Integration A6, A12, A13. |

**Zusatz-Befund (Cross-Reviewer-Konsens):** Halluzinations-Risiko
(R2/R4 alt) ist mit reinem Stakeholder-Review-Pass unterschätzt —
Evidence-Mode mit grep-Anchor-Validierung wurde von Architekt +
Pessimist + Security übereinstimmend gefordert. → Integration A10
(Pre-Launch: manuell durch Stakeholder, Post-Launch: automatisiert).

**Phase-0.5-Status:** `validate-plan.sh` lief grün (statisch geprüft
gegen Plan-Schema, Pflicht-Sektionen vorhanden, `touches:`-Pfade
existieren bzw. sind als „NEU" markiert).

**Phase-1.5-Status:** Pre-Filter Fast-Pass durch Pessimist + Scout
identifizierte 7 Findings, davon 5 in Phase-2 vertieft und alle 14
Pflicht-Änderungen (A1–A14) abgedeckt.

**Update 2026-05-25 Stakeholder-Strip:** Worker-Security in §11
Post-Launch. Pre-Launch-Scope auf 3 Tasks reduziert (A: Initial-
Befüllung, B: doc-updater-Map, C: CLAUDE.md-Sektion). A4, A5, A6, A7,
A8, A9, A10, A12, A13, A14 sowie ursprüngliche Tasks 1, 3, 5, 7, 8,
10 und Risiken R5–R11 in §11 verschoben. Begründung: Speed >
Defense-in-Depth solange keine echten Nutzer existieren.

---

**[Plan committee-approved + Pre-Launch-scoped, ready for implementation
— Task A als nächster Schritt (autonom durch `planner`-Opus)]**

/Users/keremozkan/Development/inventory_management/plans/2026-05-25_autonomous-roadmap-and-capability-doc.md
