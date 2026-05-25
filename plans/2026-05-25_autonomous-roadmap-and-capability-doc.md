# [Committee-Approved 2026-05-25]

# Autonomous-Roadmap & Capability-Doc-Policy

**Datum:** 2026-05-25
**Author (Draft):** planner (Opus, Auto-Mode)
**Status:** Committee-approved nach 5-Reviewer-Council. Integration der 14
Pflicht-Änderungen (A1–A14) vollständig eingearbeitet.
**Original-User-Wunsch (EN):**
> "plan next steps which you can undertake by yourself, add that every change forces to update a tech doku what the application all possess"

---

## 0. Validierung der Moderator-Interpretation (Post-Council)

Die Moderator-Interpretation wird **bestätigt mit struktureller Konsolidierung**:

- **Teil A (Autonomous-Roadmap):** Übernommen. Score-Tabelle + Top-3-Picks
  + Stop-Liste. **NEU (A11):** Score-Tabelle wird **zusätzlich** als
  maschinenlesbares YAML unter
  `plans/2026-05-25_autonomous-roadmap-and-capability-doc.scores.yaml`
  abgelegt; der Worker liest YAML, nicht Markdown.
- **Teil B (Capability-Doc-Policy):** **Restruktiert (A1)**. Es entsteht
  **kein** neuer Top-Level-Doc `docs/CAPABILITIES.md` mehr — das wäre
  ein vierter Doku-Layer neben Handbuch, Hilfe und Page-Registry und
  bricht das bestehende Doc-Layer-Pattern. Stattdessen wird das
  Capability-Inventar als neues Handbuch-Kapitel
  **`docs/handbook/00-overview.md`** integriert. `_page-registry.md`
  bleibt canonical-source für Screens; das neue Kapitel **referenziert**
  sie, dupliziert sie nicht.
- **Sync-Mechanismus (A2):** Es entsteht **kein** neuer
  `capability-curator`-Agent. Stattdessen wird der bestehende
  `doc-updater` (`.claude/agents/doc-updater.md`) erweitert — er kennt
  bereits die Kapitel-Klassifikator-Map, das neue 00-Kapitel wird in
  diese Map aufgenommen.
- **CI-Enforcement (A3):** Workflow-Logik nutzt **fertige
  GitHub-Actions** (`tj-actions/changed-files@v45` für Diff-Erkennung,
  `danieljimeneznz/ensure-files-changed@v4` für Path-Allowlist) statt
  Eigenbau-Shell. Eigener Code schrumpft auf ~30 Zeilen
  Anchor-Validierung + Skip-Parser.
- **Self-Mod-Layer (A4, A5, A9):** Pre-Task-0 erweitert die
  Self-Mod-Blocklist um `.github/workflows/*.yml` und
  `.claude/whitelist.txt`. Task 1 (Whitelist-Update) ist
  `requires_human_dispute: true` und blockt via Overseer-Flag alle
  Folge-Tasks, solange nicht freigegeben.
- **Halluzinations-Schutz (A10):** Jede Capability-Zeile braucht einen
  **grep-validierbaren Anchor** (Klassen-Name, Function-Pfad,
  Tabellen-Name); `check-capability-drift.sh --evidence-mode` verifiziert.
- **Threat-Map-Leak-Schutz (A8):** Negative-Pattern-Liste verhindert,
  dass Env-Var-Namen / Secret-Bezeichner ins Doc gelangen.

---

## 1. Ziel

Zwei zusammengehörige Outcomes liefern:

1. **Autonomous-Roadmap:** Eine objektiv begründete Score-Tabelle aller
   16 offenen Backlog-Items (Markdown + YAML), ergänzt um Top-3-Self-Pick,
   Top-3-Council-First, und eine harte Stop-Liste — sodass die
   Swarm-Pipeline für die nächsten 5–7 Working-Days ohne weiteren
   User-Input arbeiten kann.
2. **Capability-Doc-Policy:** Ein neues Handbuch-Kapitel
   `docs/handbook/00-overview.md` ("Capability Inventory") als flache,
   scannbare Single-Page-Übersicht "Was kann diese App?" einführen,
   initial befüllen, und einen **CI-basierten** Enforcement-Mechanismus
   etablieren, der bei User-sichtbaren Änderungen ein Doc-Update
   verlangt — ohne den lokalen `git push`-Flow zu verlangsamen.

---

## 2. Betroffener Scope

### Neue Files
- `docs/handbook/00-overview.md` (NEU) — flacher Capability-Katalog als
  Handbuch-Kapitel. **Slot 00 wird neu vergeben** (existierende
  Kapitel-Nummern 01–10 bleiben, README-Tabelle wird ergänzt). Falls
  Slot 00 in Zukunft Konflikte erzeugt, bleibt die Datei umbenennbar
  ohne Strukturbruch.
- `.github/workflows/capability-doc-check.yml` (NEU) — CI-Check via
  `tj-actions/changed-files@v45` + `danieljimeneznz/ensure-files-changed@v4`.
- `.claude/scripts/check-capability-drift.sh` (NEU) — Lokaler Dry-Run
  + CI-Backbone (Anchor-Validierung, Threat-Map-Filter,
  `[capability-skip: …]`-Parser).
- `plans/2026-05-25_autonomous-roadmap-and-capability-doc.scores.yaml`
  (NEU) — maschinenlesbare Score-Tabelle für Worker-Pick.
- `.claude/audit/capability-skips.log` (NEU, append-only) — Audit-Trail
  jedes verwendeten Skip-Markers.
- `.claude/audit/capability-mute-events.log` (NEU, append-only) —
  Audit-Trail jedes Set/Unset von `CAPABILITY_CHECK_DISABLED`.
- `plans/2026-05-25_autonomous-roadmap-and-capability-doc.md` (dieser Plan).

### Geänderte Files
- `CLAUDE.md` — neue Sektion „Capability-Doc pflegen" analog zu
  „Handbook pflegen" und „Hilfeseite pflegen". **Self-Mod-Touch** →
  `requires_human_dispute: true` (CLAUDE.md ist in Blocklist).
- `docs/handbook/README.md` — Kapitel-Tabelle um Slot 00 erweitern,
  Navigations-Hinweis ergänzen. Regulär `doc-updater`, kein Self-Mod.
- `.claude/whitelist.txt` — neue Pfade aufnehmen
  (`docs/handbook/00-overview.md` ist bereits durch `docs/handbook/`
  abgedeckt → kein Whitelist-Edit für den Doc-Pfad selbst nötig;
  aber `.github/workflows/capability-doc-check.yml`,
  `.claude/scripts/check-capability-drift.sh` und
  `.claude/audit/capability-*.log` müssen explizit drin sein bzw.
  durch existierende Prefixes (`.github`, `.claude/scripts`,
  `.claude/audit`) abgedeckt sein — Pre-Task-0 verifiziert das).
  **Self-Mod-Touch**.
- `.claude/scripts/lib/self-mod-blocklist.sh` — **Pre-Task-0**
  erweitert die Blocklist um Glob `.github/workflows/*.yml` und um
  `.claude/whitelist.txt` (letzteres ist bereits implizit geschützt,
  wird aber explizit aufgenommen für Audit-Klarheit). **Self-Mod-Touch**,
  zwingend User-Session.
- `.claude/agents/doc-updater.md` — Klassifikator-Map erweitern:
  neue Screens / Edge-Functions / Tables triggern zusätzlich Update
  von `docs/handbook/00-overview.md`. **Self-Mod-Touch** →
  `requires_human_dispute: true` (`.claude/agents/` ist Blocklist-Pfad,
  alle disput-/stakeholder-Agents zeigen das Muster).
- `.claude/scripts/overseer.sh` (bzw. `.claude/scripts/lib/picker.sh`,
  je nachdem wo `pick_next_item` lebt — siehe Recon-Ergebnis:
  Definition in `lib/picker.sh:168`) — Pre-Pick-Check auf
  `.claude/overseer/blocks/capability-doc-tasks.flag`. **Self-Mod-Touch**
  (Pfad ist in Blocklist), wird **in derselben User-Session** wie
  Pre-Task-0 + Task 1 erledigt.
- `.claude/scripts/weekly-digest.sh` — Skip-Counter aus
  `.claude/audit/capability-skips.log` lesen; bei > 10 Skips/Woche
  Telegram-Alarm. **Self-Mod-relevant** (Script-Pfad), aber kein
  expliziter Blocklist-Eintrag — vorsorglich
  `requires_human_dispute: true`.

### Read-only
- Alle 16 Items in `.claude/backlog/inbox/` (für Score-Tabelle).
- `lib/screens/`, `lib/providers/`, `lib/services/`,
  `supabase/migrations/`, `supabase/functions/`, `.claude/agents/`
  (für Initial-Befüllung).
- `.claude/agents/_page-registry.md` (canonical-source-Cross-Check).

---

## 3. Datenmodell + RLS

**Kein Schema-Change.** Das Capability-Doc ist statisch (Markdown,
git-versioniert). Keine neue Tabelle, keine neue Column, keine neue
RLS-Policy.

Ein einzelner Punkt: in `docs/handbook/00-overview.md` werden
Tabellen-Namen aus `supabase/migrations/` **referenziert** (Lookup-
Liste mit Migration-File-Pfad als Anchor). Diese Referenz wird vom
erweiterten `doc-updater` gepflegt — keine Live-DB-Abfrage zur
Build-Zeit.

---

## 4. API / Edge Functions

**Keine neuen Edge Functions.** Existierende werden in
`docs/handbook/00-overview.md` **gelistet** (mit 1-Zeilen-Beschreibung
+ Function-Pfad-Anchor pro Function), aber nicht modifiziert.

---

## 5. UI + l10n-Keys

**Keine UI-Änderungen.** Dieses Feature ist Doc-/Policy-/Tooling-
fokussiert. Keine neuen ARB-Keys, keine neuen Screens, keine
Theme-Tokens.

**Nicht-Ziel:** Eine „Capabilities"-Sektion in `help_screen.dart` ist
**explizit out of scope** — der existierende Help-Screen ist user-
facing, das Capability-Kapitel ist dev-/stakeholder-facing. Diese
Trennung verhindert Doc-Bloat im User-UI.

---

## 6. Tests

### Unit / Static
- `.claude/scripts/check-capability-drift.sh` muss einen Self-Test
  haben (`--self-test`-Flag): drei synthetische Fixtures
  1. Diff mit `lib/screens/foo_screen.dart` (neu) + ohne
     `00-overview.md`-Update → Exit 1.
  2. Diff mit Refactor-only-Change und `[capability-skip: refactor-only]`
     → Exit 0 + Audit-Log-Eintrag.
  3. Doc mit erfundener Capability (Anchor ohne Code-Hit) im
     `--evidence-mode` → Exit 1 mit Anchor-Name.
- Idempotenz-Test: zweimal Aufruf ohne Diff → Exit 0, keine
  Side-Effects.
- **A10 Evidence-Test:** `check-capability-drift.sh --evidence-mode`
  grept jeden Anchor:
  - Screens: `class <Name>Screen extends`
  - Providers: `class <Name>Provider`
  - Edge-Functions: Function-Pfad `supabase/functions/<name>/`
  - Tabellen: Migration-File-Pfad ODER Table-Name-Hit in SQL
  Kein Hit → Exit 1 mit Liste der fehlenden Anchors.
- **A8 Threat-Map-Filter-Test:** Synthetisches Doc mit
  `SUPABASE_SERVICE_ROLE_KEY` im Body → Exit 1.
- **A14 Page-Registry-Konsistenz:** Synthetischer Mismatch (Screen-Route
  in 00-overview.md, aber nicht in `_page-registry.md`) → Exit 1.

### CI
- `.github/workflows/capability-doc-check.yml` läuft auf jedem PR:
  - Trigger: **nur `pull_request`** (NICHT `pull_request_target` —
    A3 / Security-Reviewer-Verdict, sonst läuft Workflow gegen
    Fork-PR im Repo-Context und kann Tokens leaken).
  - Path-Filter via `tj-actions/changed-files@v45`-Output.
  - Wenn capability-relevante Pfade geändert UND
    `docs/handbook/00-overview.md` **nicht** im Diff → PR-Comment +
    soft-fail in Phase 1, hard-fail ab Phase 2 (Task 10).
  - `[capability-skip: <reason>]` im PR-Body → Check passt mit
    Audit-Eintrag durch (Override). Allowed reasons (A6,
    5er-Allowlist): `refactor-only`, `internal-tooling-only`,
    `revert-pr`, `dependency-bump`, `ci-config-only`.
  - Bot-Authors (`github.event.pull_request.user.type == 'Bot'`)
    dürfen **keinen** Skip-Marker setzen — Skip wird ignoriert, Check
    läuft trotzdem.
  - Diff-only-Skip (A7): wenn der gesamte PR-Diff nur
    `docs/handbook/00-overview.md` (+ ggf. `_page-registry.md`) ändert,
    skipt der Workflow sich selbst (kein Loop bei
    doc-updater-Auto-Commits).
  - Repo-weite Stumm-Schaltung (A13): `${{ vars.CAPABILITY_CHECK_DISABLED
    != '1' }}`-Guard im Job.

### Manual / Smoke
- Nach Initial-Befüllung: Stakeholder liest
  `docs/handbook/00-overview.md` einmal komplett durch und meldet via
  `/yota propose "capability-doc-korrektur: …"` Lücken/Halluzinationen.
- Cross-Check gegen `.claude/agents/_page-registry.md`:
  `check-capability-drift.sh --check-page-registry-consistency` muss
  grün durchlaufen.

---

## 7. Risiken (mit Mitigations, R1–R11)

| # | Risiko | Wahrsch. | Impact | Mitigation |
|---|---|---|---|---|
| R1 | **False-Positives bei Capability-Drift** — Refactoring ohne Capability-Change löst Update-Pflicht aus | Hoch | Mittel | Path-Allowlist via `tj-actions/changed-files@v45` + `[capability-skip: <reason>]`-Override mit 5er-Allowlist (A6). Erste 14 Tage Soft-Fail (Task 10 sammelt False-Positive-Rate). |
| R2 | **Doc-Bloat** — Capabilities-Liste wird unlesbar | Mittel | Hoch | Strikte 1-Zeilen-Caps pro Eintrag, max 10 Sektionen, Inhaltsverzeichnis vorne. Hard-Cap pro Sektion (max 30 Screens; bei Overflow Sub-Doc unter `docs/handbook/00-overview/<area>.md`). |
| R3 | **Enforcement-Friction** — jeder PR braucht Update → Frust | Mittel | Mittel | (a) Soft-fail Default für 14d, (b) `[capability-skip: <reason>]`-Escape mit Allowlist, (c) doc-updater-Erweiterung übernimmt den Update als Sub-Task im PR-Branch. (d) Repo-weite Stumm-Schaltung via `vars.CAPABILITY_CHECK_DISABLED=1` (A13). |
| R4 | **Initial-Befüllung-Halluzination** — KI erfindet Capabilities | Hoch | Hoch | Evidence-Required-Constraint (A10): jeder Eintrag braucht grep-validierbaren Anchor (Klassen-Name / Function-Pfad / Table-Name). `--evidence-mode` validiert. Plus Stakeholder-Review-Pass (Task 4). |
| R5 | **Self-Mod-Block** — doc-updater-Edit, CLAUDE.md-Edit, Whitelist-Update, Blocklist-Erweiterung sind Self-Mod | Sicher | Mittel | Alle vier Tasks (Pre-Task-0, Task 1, Task 6, Task 9) sind explizit `requires_human_dispute: true` und in EINER zusammenhängenden User-Session ausführbar. Plan stellt klar: ohne diese 4 läuft der Rest auch (CI-Check + Initial-Doc als MVP-Phase reichen). |
| R6 | **CI-Workflow-Loop** — Auto-Update pusht Doc → triggert wieder CI → Endlosschleife | Niedrig | Hoch | A7: Diff-only-Skip — Workflow skipt sich selbst, wenn der gesamte PR-Diff nur `docs/handbook/00-overview.md` (+ ggf. `_page-registry.md`) ändert. Username-Check (`!= 'bot-name'`) wurde verworfen (bypass-anfällig). |
| R7 | **Plan-Score-Veraltung** — Inbox-State ändert sich täglich | Hoch | Niedrig | Score-Tabelle ist Snapshot per 2026-05-25 (Header explizit). Refresh-Trigger im Analyzer-Hook (A11): bei jedem neuen `00-`/`01-`-Inbox-Item wird `.scores.yaml` re-generiert. Manueller Refresh via Task 13 alle 14 Tage. |
| R8 | **Soft-fail-Ignoranz** — Devs ignorieren Warnings, Doc veraltet trotzdem | Mittel | Hoch | Task 10: nach 14d Soft-Fail-Beobachtung Metrik prüfen; wenn >30% PRs Warning ignorieren → Hard-Fail-Switch. Weekly-Digest enthält Capability-Drift-Score + Skip-Counter (Alarm bei >10/Woche). |
| **R9** | **Bot-Bypass** — Hardcoded Username-Match (`if user.login != 'capability-curator-bot'`) ist trivial bypass-bar (Fork-PR mit gleichem Username, oder echter Bot-Account) | Mittel | Hoch | **Username-Check verworfen** (A7). Stattdessen Diff-only-Logic: wenn PR-Diff komplett innerhalb der Allowlist-Doc-Pfade liegt → Workflow skipt. Zusätzlich Bot-Authors dürfen keine Skip-Marker setzen (A6, `user.type == 'Bot'` → Skip ignoriert). |
| **R10** | **Workflow-Privilege-Escalation** — autonomer Worker kann via Workflow-File-Edit beliebige `run: bash`-Steps in CI ausführen (GH-Token mit `contents: write` + secrets verfügbar) | Hoch | **Kritisch** | **Pre-Task-0 (A4):** Self-Mod-Blocklist erweitert um `.github/workflows/*.yml`-Glob. Workflow-Permissions least-priv (A5): nur `contents: read` + `pull-requests: write`, kein `id-token`, kein `actions: write`. Trigger nur `pull_request` (kein `pull_request_target` — keine Secrets bei Fork-PRs). Concurrency-Group verhindert Race. |
| **R11** | **Threat-Map-Leak** — Capability-Doc listet Env-Var-Namen / Service-Role-Bezeichner, gibt Angreifern eine fertige Threat-Map | Mittel | Hoch | A8: Negative-Pattern-Liste in `check-capability-drift.sh`: Regex-Match auf `Deno\.env\.get\(['"][^'"]+['"]\)`, `SUPABASE_SERVICE_ROLE`, `_TOKEN`, `_KEY`, `_SECRET`, `PASSWORD` → Exit 1 mit Hinweis „Env-Variable-Namen in Capability-Doc verboten (Threat-Map-Leak)". |

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
  `.claude/hooks/*`, `.claude/whitelist.txt`,
  `.github/workflows/*.yml` → braucht Stakeholder-Approval.
  `false` = autonom pickbar.
- **Size:** XS (< 50 LoC), S (50–200), M (200–500), L (500+),
  XL (> 1k).

### 8.2 Score-Tabelle (Snapshot 2026-05-25, Markdown-View)

> Maschinenlesbares Pendant: `plans/2026-05-25_autonomous-roadmap-and-capability-doc.scores.yaml` (A11). Worker liest YAML, nicht Markdown.

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

### 8.3 Empfehlung — Top-3 für sofortigen Self-Pick

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

### 8.4 Empfehlung — Top-3 die zwar autonom machbar wären, aber `/council` davor sinnvoll wäre

1. **#1 Amazon-Tracking-Coverage 70%** — User-Frust, 3. Iteration,
   Coverage-Metrik potentiell gameable. Agent: `planner` → `edge-fn-coder`
   + `flutter-coder`.
2. **#13 T-E1 (agent-teams-sandbox)** — Architektur-relevant
   (Anthropic-Native vs. Eigenbau). Agent: `planner`.
3. **#16 T-E4 (ADR Native-Adoption-Decision)** — Synthese-ADR, langfristig
   richtungsweisend. Agent: `planner`.

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

### 8.6 Score-YAML-Schema (A11)

`plans/2026-05-25_autonomous-roadmap-and-capability-doc.scores.yaml`:

```yaml
schema_version: 1
generated_at: 2026-05-25T00:00:00Z
generated_by: planner-opus
items:
  - slug: 00-amazon-tracking-coverage-70pct
    roi: high
    risk: mid
    self_mod: false
    autonom: true
    depends_on: []
    estimated_pr_size: M
    notes: "User-Frust 3. Iter, Edge-Fn + Pattern-Erweiterung"
  - slug: 03-council-ruflow-t-d1-analyzer-bottleneck
    roi: mid
    risk: low
    self_mod: false
    autonom: true
    depends_on: []
    estimated_pr_size: S
    notes: "Read-only, blockt T-D7"
  # … (16 Einträge insgesamt, analog zur Markdown-Tabelle §8.2)
```

**Refresh-Trigger:** Hook in `.claude/scripts/analyzer.sh` (oder
analoger Analyzer-Loop) — bei jedem neu eingehenden
`00-`/`01-`-Inbox-Item wird das YAML re-generiert (delta-merge: neuer
Eintrag angehängt, gelöschtes Item markiert mit `archived: true`).
Worker liest YAML via `yq` / Python in `pick_next_item`.

---

## 9. Teil B — Capability-Doc-Policy

### 9.1 File-Pfad: `docs/handbook/00-overview.md` (A1)

**Begründung der Konsolidierung (gegen den Erst-Draft):**
- Existierender Doc-Layer: Handbook (Entwickler-Deep-Dive), Help-Screen
  (User-Help), Page-Registry (Screen-Test-Checkliste). Ein 4. Layer
  `docs/CAPABILITIES.md` brächte Pflege-Overhead ohne Mehrwert —
  Handbook-Pattern ist bewährt (10 Kapitel, doc-updater pflegt).
- **Slot-Wahl 00:** Existierende Kapitel beginnen bei 01. Slot 00 ist
  frei und semantisch passend („überfliegen vor dem Tiefen-Einstieg").
  README-Tabelle wird in Task 7 um den neuen Slot ergänzt
  (`| 00 | Capability-Overview | Was kann diese App in einer
  Single-Page-Übersicht |`).
- **`_page-registry.md` bleibt canonical-source** für Screens
  (Route-Pfad, Pflicht-Tests). `00-overview.md` referenziert die
  Registry für den Screens-Block (Link auf
  `.claude/agents/_page-registry.md`) statt zu duplizieren.
  `check-capability-drift.sh --check-page-registry-consistency` (A14)
  prüft, dass jeder Screen-Eintrag in `00-overview.md` einen Match in
  der Registry hat.

### 9.2 Doc-Struktur (konkrete Sektionsliste)

```markdown
# Capability Inventory — inventory_management

> Was kann diese App? Flache, scannbare Referenz mit Code-Pfaden.
> Tiefe-Detail siehe Kapitel 01–10. Screen-Routen sind canonical
> in [`.claude/agents/_page-registry.md`](../../.claude/agents/_page-registry.md).

## Inhalt
- [User-sichtbare Screens & Features](#screens)
- [Daten-Pipelines](#pipelines)
- [Integrationen (extern)](#integrationen)
- [Daten-Modell (high-level)](#daten-modell)
- [Edge Functions](#edge-functions)
- [Auth & Identity](#auth)
- [Plan-/Billing-Capabilities](#billing)
- [Notifications & Push](#notifications)
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
- Jeder Eintrag MUSS einen grep-validierbaren Anchor haben (A10).
- Max 10 Sektionen. Bei Overflow → Sub-Doc unter
  `docs/handbook/00-overview/<area>.md`.
- **Verboten (A8):** Env-Variable-Namen, Secret-Bezeichner,
  Service-Role-Tokens.

### 9.3 Enforcement: CI-Check

**Workflow-File:** `.github/workflows/capability-doc-check.yml`.

**Trigger:** **nur `pull_request`** (NICHT `pull_request_target` — A3
Security-Härtung).

**Permissions (A5, least-priv):**

```yaml
name: Capability Doc Check
on:
  pull_request:
    paths:
      - 'lib/screens/**'
      - 'lib/providers/**'
      - 'lib/services/**'
      - 'supabase/migrations/**'
      - 'supabase/functions/**/index.ts'
      - '.claude/agents/**'
      - 'docs/handbook/00-overview.md'

permissions:
  contents: read
  pull-requests: write

concurrency:
  group: capability-doc-${{ github.ref }}
  cancel-in-progress: true

jobs:
  check:
    if: ${{ vars.CAPABILITY_CHECK_DISABLED != '1' }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }

      - name: Diff-Erkennung
        id: changed
        uses: tj-actions/changed-files@v45
        with:
          files: |
            lib/screens/**
            lib/providers/**
            lib/services/**
            supabase/migrations/**
            supabase/functions/**/index.ts
            .claude/agents/**

      - name: Diff-only-Skip (A7)
        id: diffonly
        run: |
          # Wenn ALLE geänderten Files in der Doc-Allowlist liegen → skip
          ALL_FILES="${{ steps.changed.outputs.all_changed_files }}"
          NON_DOC=$(echo "$ALL_FILES" | tr ' ' '\n' \
            | grep -vE '^(docs/handbook/00-overview\.md|\.claude/agents/_page-registry\.md)$' \
            || true)
          if [ -z "$NON_DOC" ]; then
            echo "skip=true" >> "$GITHUB_OUTPUT"
          else
            echo "skip=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Ensure Capability-Doc updated
        if: steps.diffonly.outputs.skip != 'true'
        uses: danieljimeneznz/ensure-files-changed@v4
        with:
          files: docs/handbook/00-overview.md
          require-changes-to: |
            lib/screens/**
            lib/providers/**
            lib/services/**
            supabase/migrations/**
            supabase/functions/**/index.ts
            .claude/agents/**

      - name: Anchor + Threat-Map-Filter + Page-Registry-Check
        if: steps.diffonly.outputs.skip != 'true'
        run: bash .claude/scripts/check-capability-drift.sh --pr-mode

      - name: PR-Comment bei Soft-Fail
        if: failure() && steps.diffonly.outputs.skip != 'true'
        uses: actions/github-script@v7
        with:
          script: |
            const body = [
              '⚠️ Capability-Doc-Drift erkannt',
              'Geänderte Files: ${{ steps.changed.outputs.all_changed_files }}',
              'Fix: (a) `docs/handbook/00-overview.md` updaten, ODER (b) ins PR-Body schreiben: `[capability-skip: <reason-from-allowlist>]`.',
              'Lokal testen: `bash .claude/scripts/check-capability-drift.sh --pr-mode`',
              'Allowed reasons: refactor-only, internal-tooling-only, revert-pr, dependency-bump, ci-config-only'
            ].join('\n');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body
            });
```

**Exact PR-Comment-Wortlaut (A12, copy-pasteable):**

```
⚠️ Capability-Doc-Drift erkannt
Geänderte Files: <auto-filled by tj-actions>
Fix: (a) `docs/handbook/00-overview.md` updaten, ODER (b) ins PR-Body schreiben: `[capability-skip: <reason-from-allowlist>]`.
Lokal testen: `bash .claude/scripts/check-capability-drift.sh --pr-mode`
Allowed reasons: refactor-only, internal-tooling-only, revert-pr, dependency-bump, ci-config-only
```

**Stumm-Schaltung (A13):**
- Repo-Variable `CAPABILITY_CHECK_DISABLED` setzen:
  `gh variable set CAPABILITY_CHECK_DISABLED --body 1`.
- Audit-Log: Pre-Push-Hook cached `gh variable list` und vergleicht;
  Set/Unset-Events → `.claude/audit/capability-mute-events.log`
  (append-only, Format: `timestamp | actor | from_value | to_value`).
- Default: deaktiviert (Variable nicht gesetzt → Check läuft).

### 9.4 `[capability-skip: <reason>]`-Allowlist (A6)

| Reason | Bedeutung |
|---|---|
| `refactor-only` | Rein interne Code-Umorganisation, keine neue Capability |
| `internal-tooling-only` | Änderung an Build-/Test-/Dev-Tools ohne User-Wirkung |
| `revert-pr` | Revert eines vorherigen PRs, der bereits dokumentiert war |
| `dependency-bump` | Reines Dependency-Update ohne Feature-Änderung |
| `ci-config-only` | CI/Workflow/Linter-Konfig ohne App-Verhaltensänderung |

- Reasons außerhalb der Liste → Check failed mit Liste der erlaubten
  Werte.
- Bot-Authors (`user.type == 'Bot'`) dürfen keine Skip-Marker setzen
  → Marker wird ignoriert, Check läuft normal.
- Jede Verwendung wird in `.claude/audit/capability-skips.log` geloggt
  (Format: `timestamp | pr-num | author | reason | files-changed-count`).
- Weekly-Digest zählt Skips; bei > 10/Woche Telegram-Alarm
  (`.claude/scripts/weekly-digest.sh`-Erweiterung).

### 9.5 Initial-Befüllung — Wer schreibt die erste Version?

**Gewählt: Einmaliger `planner`-Agent-Run** (Task 2), nicht ein neuer
Cataloger-Agent.

Begründung:
- Ein dedizierter Cataloger-Agent wäre `.claude/agents/`-Self-Mod →
  braucht Stakeholder-Approval.
- Der `planner` (Opus) ist mächtig genug.
- Halluzinations-Risiko (R4) wird durch Evidence-Required-Constraint
  (A10) mitigiert: `--evidence-mode` grept jeden Anchor.
- Stakeholder-Review-Pass (Task 4) als Doppel-Sicherung.

### 9.6 Synchronisation — Wer hält das Doc up-to-date?

**Gewählt: `doc-updater`-Erweiterung (A2), keine neue Agent-Instanz.**

Der existierende `doc-updater` kennt bereits die Klassifikator-Map
(siehe `.claude/agents/doc-updater.md` §Kapitel-Map). Task 6 erweitert
die Map: Pfade, die heute `03-screens-walkthrough.md` /
`05-architecture.md` / `06-database.md` / `07-edge-functions.md`
triggern, triggern **zusätzlich** ein Update von
`docs/handbook/00-overview.md`.

- Inkrementell: kein Rewrite, nur Tabellen-Zeile hinzufügen/entfernen.
- Anchor-Pflicht: doc-updater MUSS für jeden neuen Eintrag einen
  grep-validierbaren Anchor (Klassen-Name / Function-Pfad /
  Migration-File) eintragen — sonst `check-capability-drift.sh
  --evidence-mode` failt.

→ Damit entfällt der ursprünglich geplante `capability-curator`-Agent
+ der `/update-capabilities`-Slash-Command vollständig.

---

## 10. Tasks (atomar, in Pflicht-Reihenfolge nach Committee-Review)

> **Reihenfolge-Constraint:** Pre-Task-0 → Task 1 → Task 2 → Task 3 →
> Task 4 ist Pflicht-Sequenz. Tasks 5–7 können nach Task 4 parallel
> laufen. Self-Mod-Tasks (Pre-Task-0, 1, 6, 9) sind explizit als
> User-Session-gebunden markiert.
>
> **Hard-Gate (A9):** Solange Pre-Task-0 + Task 1 nicht durch sind,
> setzt der Overseer das Flag
> `.claude/overseer/blocks/capability-doc-tasks.flag`. `pick_next_item`
> (Definition in `.claude/scripts/lib/picker.sh:168`) prüft das Flag
> vor jedem Pick — Capability-Doc-Tasks (2–10) werden skipped, solange
> Flag existiert. **Einzige Ausnahme:** Pre-Task-0 selbst (User
> entfernt das Flag manuell nach Task 1).

---

### Pre-Task-0: Self-Mod-Blocklist erweitern (A4)

Pflicht: VOR allem anderen. Erweitert
`.claude/scripts/lib/self-mod-blocklist.sh`:

1. Glob `.github/workflows/*.yml` in `SELF_MOD_BLOCKLIST_GLOBS`
   aufnehmen.
2. `.claude/whitelist.txt` als expliziten Eintrag in
   `SELF_MOD_BLOCKLIST` aufnehmen (heute nicht enthalten).
3. Verify-Test: `bash .claude/scripts/verify/self-mod-blocklist.sh` muss
   nach Edit weiterhin grün laufen.
4. Overseer setzt das Hard-Gate-Flag
   `.claude/overseer/blocks/capability-doc-tasks.flag` (A9) bis Task 1
   abgeschlossen ist.

Begründung: ohne diesen Schutz ist Task 5 (Workflow-Creation) ein
Privilege-Escalation-Vektor (R10) — autonomer Worker könnte beliebige
`run: bash`-Steps in CI-Workflows schreiben.

- agent: Stakeholder manuell (in User-Session via
  `session-start.sh` → edit → commit → `session-end.sh`)
- depends: —
- touches: `.claude/scripts/lib/self-mod-blocklist.sh`,
  `.claude/overseer/blocks/capability-doc-tasks.flag` (NEU)
- requires_human_dispute: true
- size: XS
- estimated_cost: $0 (manuell)

---

### Task 1: Whitelist-Update + Overseer-Pick-Hard-Gate (A9)

1. `.claude/whitelist.txt` ergänzen:
   - `.claude/audit/capability-skips.log` (von existierendem
     `.claude/audit`-Prefix abgedeckt, aber explizit dokumentiert)
   - `.claude/audit/capability-mute-events.log` (ditto)
   - `.claude/overseer/blocks/` (NEU, falls noch nicht gedeckt)
2. `.claude/scripts/lib/picker.sh` (Funktion `pick_next_item` bei
   Zeile 168) ergänzen: vor dem Item-Pick prüfen, ob
   `.claude/overseer/blocks/capability-doc-tasks.flag` existiert. Wenn
   ja → Items mit Slug-Pattern `*capability-doc*` skippen, andere
   Items normal pickbar.
3. Nach erfolgreichem Setup: Flag manuell entfernen
   (`rm .claude/overseer/blocks/capability-doc-tasks.flag`).

- agent: Stakeholder manuell (User-Session)
- depends: Pre-Task-0
- touches: `.claude/whitelist.txt`,
  `.claude/scripts/lib/picker.sh`
- requires_human_dispute: true
- size: S
- estimated_cost: $0 (manuell)

---

### Task 2: Initial-Befüllung `docs/handbook/00-overview.md`

1. Scanne `lib/screens/`, `lib/providers/`, `lib/services/`,
   `supabase/migrations/`, `supabase/functions/`, `.claude/agents/`.
2. Pro Sektion (siehe §9.2) Tabelle generieren — 1 Zeile pro Item.
3. Jeder Eintrag MUSS einen grep-validierbaren Anchor haben (A10).
4. Hard-Cap pro Sektion (max 30 Screens, dann Sub-Doc).
5. Inhaltsverzeichnis vorne, Sektion-Anchors korrekt.
6. **Verbotene Patterns (A8):** keine Env-Var-Namen, keine
   Secret-Bezeichner — `check-capability-drift.sh --threat-map-scan`
   muss nach Befüllung grün laufen.
7. Screens-Sektion referenziert `_page-registry.md` als canonical-source,
   dupliziert sie nicht.

Output: `docs/handbook/00-overview.md` (Single-File), max ~600 Zeilen.

- agent: `planner` (Opus — Halluzinations-Risiko erfordert höchste
  Modellqualität)
- depends: Task 1
- touches: `docs/handbook/00-overview.md` (neu)
- requires_human_dispute: false
- size: L
- estimated_cost: $3–5 (Opus, langer Scan-Run)

---

### Task 3: `check-capability-drift.sh` schreiben (~50 LoC + Sub-Checks)

Read-only Skript, validiert:

1. **Anchor-Validität (A10, `--evidence-mode`):** Jeder Eintrag in
   `docs/handbook/00-overview.md` braucht einen grep-Hit:
   - Screens: `class <Name>Screen extends`
   - Providers: `class <Name>Provider`
   - Edge-Functions: `supabase/functions/<name>/` (Pfad existiert)
   - Tabellen: Migration-File-Pfad ODER Table-Name in SQL
   Fehlende → Exit 1 mit Liste der fehlenden Anchors.
2. **PR-Mode (`--pr-mode`):** Pure Anchor-Check + Threat-Map-Filter
   + Page-Registry-Consistency. Die Diff/Allowlist-Logik liegt im
   Workflow (A3, `tj-actions/changed-files` +
   `ensure-files-changed`); das Skript ist Sub-Check.
3. **Threat-Map-Filter (A8):** Regex-Match auf
   `Deno\.env\.get\(['"][^'"]+['"]\)`, `SUPABASE_SERVICE_ROLE`,
   `_TOKEN`, `_KEY`, `_SECRET`, `PASSWORD`. Match → Exit 1 mit
   Message „Env-Variable-Namen in Capability-Doc verboten
   (Threat-Map-Leak)".
4. **Page-Registry-Consistency (A14,
   `--check-page-registry-consistency`):** Jeder Top-Level-Screen-
   Eintrag in `00-overview.md` braucht einen Match in
   `.claude/agents/_page-registry.md` (gleicher Route-Pfad). Mismatch
   → Exit 1.
5. **Escape-Hatch-Parser (A6):** Liest `$GITHUB_PR_BODY` oder
   `--skip-reason <val>`; Reason gegen 5er-Allowlist matchen; bei Match
   Exit 0 + Audit-Eintrag in `.claude/audit/capability-skips.log`.
6. **Bot-Author-Check (A6):** Wenn `$GITHUB_PR_AUTHOR_TYPE == 'Bot'`,
   Skip-Marker ignorieren (Check läuft normal).
7. **Self-Test (`--self-test`):** drei synthetische Fixtures (siehe §6).

Output-Format: JSON bei `--json`-Flag, sonst Markdown.

LoC-Ziel: ~50 Zeilen Kern + ~30 Zeilen Sub-Checks. Diff-Logik
**nicht** im Skript — die übernimmt der Workflow via
`tj-actions/changed-files` (A3).

- agent: `flutter-coder` (Bash-Skill; alternativ `edge-fn-coder`)
- depends: Task 2
- touches: `.claude/scripts/check-capability-drift.sh` (neu)
- requires_human_dispute: false
- size: M
- estimated_cost: $0.30 (Sonnet)

---

### Task 4: Stakeholder-Review der Initial-Befüllung

Stakeholder liest `docs/handbook/00-overview.md` komplett durch und
meldet via `/yota propose "capability-doc-korrektur: …"` Lücken,
Halluzinationen oder Struktur-Issues.

Erfolgskriterium: Stakeholder gibt explizit `go`-Bestätigung
(Telegram oder CLI) ODER eröffnet Follow-Up-Tasks.

- agent: `stakeholder-validator` (passiv, wartet auf User-Bestätigung)
- depends: Task 2, Task 3
- touches: — (read-only)
- requires_human_dispute: true (User-Input zwingend)
- size: XS
- estimated_cost: $0 (Mensch)

---

### Task 5: GitHub-Workflow `capability-doc-check.yml` schreiben (A3, A5, A7, A12, A13)

Erstelle `.github/workflows/capability-doc-check.yml` exakt nach
YAML-Block aus §9.3 mit:

- Trigger nur `pull_request` (NICHT `pull_request_target`).
- Permissions `contents: read`, `pull-requests: write`.
- Concurrency-Group `capability-doc-${{ github.ref }}`,
  `cancel-in-progress: true`.
- `${{ vars.CAPABILITY_CHECK_DISABLED != '1' }}`-Guard.
- `tj-actions/changed-files@v45` für Diff-Erkennung.
- `danieljimeneznz/ensure-files-changed@v4` für Allowlist-Check.
- Diff-only-Skip-Logik (A7) als Inline-Bash-Step.
- Aufruf `bash .claude/scripts/check-capability-drift.sh --pr-mode` für
  Anchor + Threat-Map + Page-Registry-Sub-Checks.
- PR-Comment-Wortlaut (A12) exakt wie §9.3.
- Soft-fail in Phase 1 (`continue-on-error: true` auf
  `ensure-files-changed` + nachgelagerter Comment-Step). Hard-fail-
  Switch in Task 10.

**Hinweis:** `.github/workflows/*.yml` ist seit Pre-Task-0 in der
Self-Mod-Blocklist. Task 5 läuft daher **in derselben User-Session**
wie Pre-Task-0 + Task 1, ODER der Stakeholder triggert Task 5
explizit nach Session-Marker-Re-Setup.

- agent: `edge-fn-coder` (in User-Session — wegen
  Self-Mod-Blocklist)
- depends: Task 3, Task 4
- touches: `.github/workflows/capability-doc-check.yml` (neu)
- requires_human_dispute: true
- size: S
- estimated_cost: $0.30

---

### Task 6: `doc-updater`-Erweiterung (A2)

Erweitere `.claude/agents/doc-updater.md` Klassifikator-Map:

1. Identifiziere bestehende Map-Einträge (Kapitel-Map ist die Tabelle
   um Zeile 22–43).
2. Ergänze pro Pattern, das ein User-sichtbares Capability triggern
   kann, einen Zusatz-Hinweis: `… + 00-overview.md (Tabellen-Update)`.
   Konkret betroffen:
   - `lib/screens/*` → ergänze 00-overview-Update
   - `supabase/migrations/*.sql` → ergänze 00-overview-Update
   - `supabase/functions/<name>/` → ergänze 00-overview-Update
   - `.claude/agents/<x>.md` → ergänze 00-overview-Update
3. Anchor-Pflicht im Workflow-Abschnitt dokumentieren: doc-updater
   trägt für jeden neuen Eintrag einen grep-validierbaren Anchor ein.
4. Hartes „DO NOT": niemals Capability erfinden — bei Unsicherheit
   `> TODO: Anchor prüfen` und im Report melden.

**Self-Mod-Touch** (`.claude/agents/` ist Blocklist-Pfad,
`disput-*.md` und `stakeholder-*.md` sind explizit in Blocklist; weitere
`.claude/agents/*.md` sind durch Glob-Konvention geschützt).

- agent: Stakeholder manuell ODER `doc-updater` (rekursiv in
  User-Session)
- depends: Task 5
- touches: `.claude/agents/doc-updater.md`
- requires_human_dispute: true
- size: S
- estimated_cost: $0.20 (Sonnet, wenn Agent)

---

### Task 7: Score-YAML + Analyzer-Hook (A11)

1. Erzeuge initiale
   `plans/2026-05-25_autonomous-roadmap-and-capability-doc.scores.yaml`
   mit allen 16 Items aus §8.2 (Schema siehe §8.6).
2. Erweitere `.claude/scripts/analyzer.sh` (oder den zentralen
   Analyzer-Loop, je nachdem wo Inbox-Items klassifiziert werden) um
   einen Refresh-Hook: bei jedem neuen `00-`/`01-`-Inbox-Item wird die
   YAML re-generiert (delta-merge).
3. Worker-Pick (`pick_next_item`) liest die YAML via `yq` oder
   Python — Markdown-Tabelle bleibt nur Mensch-View.

Wenn `analyzer.sh` Self-Mod ist (vermutlich ja, Blocklist-Glob
`.claude/scripts/*`), wird auch Task 7 als
`requires_human_dispute: true` markiert.

- agent: `flutter-coder` (Bash + YAML; in User-Session)
- depends: Task 2
- touches:
  `plans/2026-05-25_autonomous-roadmap-and-capability-doc.scores.yaml`
  (neu), `.claude/scripts/analyzer.sh` (Edit), evtl.
  `.claude/scripts/lib/picker.sh` (YAML-Read-Logik in
  `pick_next_item`).
- requires_human_dispute: true
- size: M
- estimated_cost: $0.40

---

### Task 8: Sample-Migration mit T-D2 (End-to-End-Smoke)

Wähle T-D2 (Test-Coverage-Audit, autonom, kleine Scope) aus §8.3 und
führe ihn als End-to-End-Smoke des neuen CI-Checks durch:

- T-D2 schreibt nur `docs/audits/…md` → kein Capability-Update nötig
  → CI-Check muss mit `[capability-skip: refactor-only]` (oder
  `internal-tooling-only` — die genaue Wahl ist Teil des Tests)
  durchpassen.
- Alternativ: falls T-D2 unerwartet Capability-relevante Pfade berührt
  → `00-overview.md` updaten und CI grün bekommen.

Output: ein normaler Feature-PR + Audit-Eintrag in
`.claude/audit/capability-skips.log`, dass der CI-Check funktioniert.

- agent: `tester` (orchestriert), `flutter-coder` macht die
  eigentliche Audit-Arbeit
- depends: Task 5
- touches: PR-spezifisch
- requires_human_dispute: false
- size: M (PR-Inhalt) + XS (CI-Check)
- estimated_cost: variabel je nach gepicktem Item

---

### Task 9: CLAUDE.md — Sektion „Capability-Doc pflegen" ergänzen

Neue Sektion analog zu „Handbook pflegen" und „Hilfeseite pflegen".
Inhalt:

- Was triggert ein Update? (User-sichtbare Capabilities — neuer
  Screen, neue Edge-Function, neue Tabelle).
- Aufruf: `/update-docs` (doc-updater übernimmt jetzt auch
  `00-overview.md`) — kein neuer Slash-Command.
- CI-Check-Verhalten: Soft-Fail in Phase 1 / Hard-Fail ab Phase 2;
  Skip-Allowlist-Reasons.
- Threat-Map-Filter (A8): keine Env-Var-Namen.
- Page-Registry-Konsistenz (A14): `_page-registry.md` bleibt
  canonical-source.
- Stumm-Schaltung (A13): `gh variable set CAPABILITY_CHECK_DISABLED
  --body 1` mit Audit-Log.
- Grenzen: keine Refactors, keine ARB-Listen.

**Self-Mod-Touch** (CLAUDE.md ist in Blocklist).

- agent: `doc-updater` (in User-Session)
- depends: Task 5, Task 6
- touches: `CLAUDE.md`
- requires_human_dispute: true
- size: S
- estimated_cost: $0.30

---

### Task 10: 14-Tage-Beobachtungs-Phase + Soft/Hard-Fail-Switch

Nach 14 Tagen Soft-Fail in Produktion:

1. Metriken aus CI-Logs + `.claude/audit/capability-skips.log`
   sammeln:
   - Wie viele PRs hatten Warning?
   - Wie viele Authors haben Doc aktualisiert vs. ignoriert?
   - Wie viele Skip-Marker, welche Reasons dominieren?
2. Wenn ≥ 70% PRs Doc aktualisiert → Hard-Fail aktivieren
   (Workflow-Step `continue-on-error: false`).
3. Wenn < 70% → Soft-fail weiter, Root-Cause analysieren.

Output: `docs/audits/2026-06-08_capability-soft-fail-metric.md` +
optionaler PR der Workflow auf Hard-Fail umstellt.

- agent: `tester`
- depends: Task 5 (14d Beobachtung)
- touches: `docs/audits/…md`, optional
  `.github/workflows/capability-doc-check.yml`
- requires_human_dispute: **true** (Workflow-Edit ist seit
  Pre-Task-0 Self-Mod)
- size: S
- estimated_cost: $0.40

---

## 11. Subagent-Zuordnung — Zusammenfassung

| Task | Agent | Self-Mod? | Auto-pickbar? |
|---|---|---|---|
| Pre-0 | Stakeholder manuell | Ja | Nein (User-Session) |
| 1 | Stakeholder manuell | Ja | Nein (User-Session) |
| 2 | `planner` (Opus) | Nein | **Ja** (nach Pre-0 + 1) |
| 3 | `flutter-coder` | Nein | **Ja** |
| 4 | `stakeholder-validator` | n/a | Nein (User-Input zwingend) |
| 5 | `edge-fn-coder` (User-Session) | Ja (`.github/workflows/*.yml`) | Nein |
| 6 | `doc-updater` (User-Session) | Ja (`.claude/agents/*`) | Nein |
| 7 | `flutter-coder` (User-Session) | Ja (`.claude/scripts/*`) | Nein |
| 8 | `tester` + `flutter-coder` | Nein | **Ja** (nach Task 5) |
| 9 | `doc-updater` (User-Session) | Ja (CLAUDE.md) | Nein |
| 10 | `tester` | Ja (Workflow-Edit) | Nein nach 14d |

**Autonom in einer Welle (nach User-Session für Pre-0 + 1):**
Tasks 2, 3 (+ Task 8 nach Task 5). Stufe-2 (Tasks 5–10) erfordert
weitere User-Session-Zeit.

---

## 12. Offene Fragen (Post-Council, für Implementation)

1. **Slot 00-Wahl bestätigen:** README-Tabelle ergänzen oder
   existierende Nummerierung umnummerieren? Empfehlung: ergänzen, kein
   Rename.
2. **`pick_next_item`-Edit-Pfad:** Definition liegt in
   `.claude/scripts/lib/picker.sh:168`, nicht direkt in `overseer.sh`.
   Task 1 muss in `lib/picker.sh` editieren, nicht in `overseer.sh`.
3. **Analyzer-Hook für YAML-Refresh:** wo genau in `analyzer.sh`
   einhängen? Task 7 muss das identifizieren.

---

## 13. Cost-Cap-Sektion

| Phase | Cost-Schätzung |
|---|---|
| Pre-Task-0 + Task 1 + Task 9 (User-Session) | $0 (manuell) |
| Task 2 (planner Opus, Initial-Befüllung) | $3–5 |
| Task 3 (Sonnet, Skript) | $0.30 |
| Task 5 (Sonnet, Workflow) | $0.30 |
| Task 6 (Sonnet, doc-updater-Map) | $0.20 |
| Task 7 (Sonnet, YAML + Hook) | $0.40 |
| Task 8 (variabel, PR-Pick) | $0.50–$2 |
| Task 10 (Sonnet, Metrik-Pass) | $0.40 |
| **Gesamt** | **~$5–8.50** über 14+ Tage |

Hard-Cap pro Worker-Run: $5 (CLAUDE.md-Default). Task 2 muss daher
in einer User-Session ODER mit explizitem `--max-budget-usd 6` laufen.

---

## 14. Stop-Kriterien (für diesen Plan)

- Plan deckt beide Outcomes (A + B) ab: **erfüllt**.
- Tasks atomic (1 Task = 1 PR-fähig): **erfüllt** (Self-Mod-Tasks sind
  by design User-Session-gebunden).
- Risiken benannt + Mitigations (R1–R11): **erfüllt**.
- Score-Tabelle objektiv begründet + maschinenlesbar (YAML):
  **erfüllt** (§8.2 + §8.6).
- Self-Mod-Pfade explizit markiert: **erfüllt** (Pre-0, 1, 5, 6, 7,
  9, 10).
- Threat-Map-Schutz: **erfüllt** (A8).
- Halluzinations-Schutz: **erfüllt** (A10 Evidence-Mode).
- Page-Registry-Konsistenz: **erfüllt** (A14 Sub-Check).
- Plan auf Deutsch: **erfüllt**.

---

## 15. Council-Review-Trail

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
(R4) ist mit reinem Stakeholder-Review-Pass unterschätzt — Evidence-
Mode mit grep-Anchor-Validierung wurde von Architekt + Pessimist +
Security übereinstimmend gefordert. → Integration A10. Plus:
`_page-registry.md`-Konsistenz-Sub-Check (A14) als Mismatch-Detector
zwischen den beiden Screen-Inventaren.

**Phase-0.5-Status:** `validate-plan.sh` lief grün (statisch geprüft
gegen Plan-Schema, Pflicht-Sektionen vorhanden, `touches:`-Pfade
existieren bzw. sind als „NEU" markiert).

**Phase-1.5-Status:** Pre-Filter Fast-Pass durch Pessimist + Scout
identifizierte 7 Findings, davon 5 in Phase-2 vertieft und alle 14
Pflicht-Änderungen (A1–A14) abgedeckt.

---

**[Plan committee-approved, ready for implementation — Pre-Task-0 als nächster Schritt in User-Session]**

/Users/keremozkan/Development/inventory_management/plans/2026-05-25_autonomous-roadmap-and-capability-doc.md
