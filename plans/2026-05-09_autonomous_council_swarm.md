[Committee-Approved 2026-05-09]

# Autonomous Council Swarm — Self-Sustaining Multi-Agent Pipeline

> Datum: 2026-05-09
> Slug: `autonomous-council-swarm`
> Branch (geplant): `feature/autonomous-council-swarm`
> Pre-Launch — User = Stakeholder, System = autonom für ~1 Woche.
> **Voraussetzung:** Plan `2026-05-09_ai_automation_quality_uplift.md` (Committee-Approved 2026-05-09) Block A + B0/B2 sind Pre-Requisite. Dieser Plan löst dort die offenen B-/C-Blöcke teilweise ab.
>
> **Committee-Status (2026-05-09):** 5-Reviewer-Committee (Architekt, Bug-Hunter, External-Scout, Security, UX/Mobile) hat 23 Pflicht-Änderungen identifiziert. Alle eingearbeitet — siehe Sektion „Committee-mitigations applied (2026-05-09)" am Plan-Ende.

---

## Ziel

Ein **autonomer Multi-Agent-Schwarm** entwickelt das Projekt selbständig weiter:
- Ein **Overseer-Daemon** orchestriert N parallele Claude-Code-Worker in isolierten `git worktree`-Branches.
- Ein **Continuous-Analyzer-Daemon** scannt das Projekt kontinuierlich auf Tech-Debt, Drift, Security- und UX-Regressionen und schreibt Backlog-Items.
- Ein **Disput-Council** (3 Reviewer) entscheidet, ob ein Analyzer- oder Stakeholder-Vorschlag tatsächlich implementiert wird.
- Eine **Stakeholder-Inbox** (`btw <text>`-CLI + Telegram-Bot Tier-2 + ntfy-Action-Buttons als sekundärer Kanal) ist der einzige menschliche Eingriffspunkt.

Akzeptanz auf System-Ebene: 7-Tage-autonomer Lauf ODER 48h ohne neue Stakeholder-Items (siehe „Konvergenz-Definition" unten), vollständig auditierbar via git, mit täglichem Heartbeat-Briefing + Sonntag-Wochen-Digest.

**Subscription-Constraint (External-Scout):** Anthropic blockiert seit 04.04.2026 Pro/Max-Subscriptions für Drittanbieter-Frameworks. Plan setzt ausschließlich `claude --print` voraus → bleibt Max-Plan-kompatibel. Wenn das System je auf Drittanbieter-Wrapper migriert würde, müssten alle Cost-Caps neu kalkuliert werden.

---

## Scope

### IST drin

- **Phase 0** — Migration + Foundation: Self-Mod-Blocklist (P0-0), Whitelist-Erweiterung, Cost-Cap-Library, Worktree-Helper, Resource-Watchdog-Skripte, Audit-Trail-Schema mit Hash-Chain, OAuth-Watch, **Notification-Wrapper** (P0-7).
- **Phase 1** — Single-Worker-Overseer (LaunchAgent, long-running): nimmt Backlog-Items aus separatem Pfad `.claude/overseer/inbox/`, spawnt EINEN Worker in einem Worktree, parallel zum bestehenden Headless-Loop (kein Konflikt mit `.claude/backlog/inbox/`).
- **Phase 2** — Worker-Pool (N=2, Hard-Cap N=3), Stakeholder-Inbox-CLI (`btw.sh` Tier-1) + **Telegram-Bot-Adapter Tier-2** (Pflicht für „1 Woche ohne Laptop"), Triage + **Validator-Agent**, Analyzer-MVP mit drei Modulen.
- **Phase 3** — Disput-Council (3 Agents: `proponent`, `skeptic`, `pragmatist` — letzterer nur Tie-Break, mit WebSearch), volle Analyzer-Suite (7 Module **atomar gesplittet**), Auto-Recovery-Watchdogs, Cleanup-Daemons, **Cloud-Heartbeat**, **Off-Site-Audit-Backup**.
- **Phase 4** — Inbox-Pfad-Migration (`.claude/overseer/inbox/` → `.claude/backlog/inbox/`), Hard-Switch des LaunchAgents, 48h/72h/7-Tage-Akzeptanz mit klar definiertem Konvergenz-Kriterium.
- **Sicherheits-Härtung** auf jeder Phase: Self-Mod-Blocklist, Sandwich-Markers + Validator für Stakeholder-Input, Branch-Allowlist, Cost-Cap-Bypass-Schutz, OAuth-Token-Refresh-Watch, Trust-Tier-Markierung pro Item.
- **Audit-Trail** in `.claude/audit/<date>.md` mit Hash-Chain, Append-Only-Lock, wöchentlichem Off-Site-Backup.
- **Heartbeat-Briefing** + **Wochen-Digest** via `notify.sh` (severity-routed, dedup, quiet-hours).

### NICHT drin (bewusst rausgeschnitten)

- **Web-Dashboard** (localhost:8124): Pre-Launch, ntfy-Push + Plain-Markdown reicht. Wieder aufnehmen, wenn Anzahl paralleler Worker > 3 wird.
- **Container/VM-Isolation pro Worker**: `git worktree` reicht für Pre-Launch.
- **Embedding-Search in Failure-Memory**.
- **Signal-Bot, Email-Watcher als Stakeholder-Channel**.
- **Eigenes Job-Queue-System (Redis/SQLite)**.
- **Anthropic-API-Wrapper**: `claude --print` reicht (siehe Subscription-Constraint).
- **5-Reviewer-Disput**: 3 Agents.
- **Auto-Promotion zu Prod**.
- **Multi-Repo-Support**.

---

## Datenmodell + RLS

n/a — Tooling-Schicht. Audit-Trail und Disput-Files sind reine Markdown-Files im Repo.

---

## API/Edge Functions

**Phase 3 ergänzt** (Pflicht-Änderung 21): `supabase/functions/overseer-heartbeat-cloud/` — Scheduled Edge Function (oder GitHub-Actions-Cron als Alternative) erwartet alle 4h Ping vom Overseer. Bleibt der Ping aus → Push an User („Overseer is dead, system stopped"). Dient als Off-Box-Watchdog gegen LaunchAgent-Death (macOS-Updates kicken LaunchAgents).

---

## UI + l10n-Keys

n/a für die App. Stakeholder-Mechanismus:

- **Tier-1:** `bash .claude/scripts/btw.sh "<freitext>"` (lokaler Shell-Zugang).
- **Tier-2:** Telegram-Bot (HMAC-signiertes rotierendes Token, User-ID-Allowlist via `TELEGRAM_ALLOWED_USER_IDS`). **Pflicht für Phase-4-Akzeptanz** „1 Woche ohne Laptop".
- **Sekundärer Kanal:** ntfy.sh mit fixen Action-Buttons („Pause overseer", „Approve disput #N", „Show details") — KEIN Freitext-Reply (technisch nicht unterstützt).
- README in `.claude/stakeholder/README.md` dokumentiert Format + Trust-Tiers.

---

## Tests

1. **Worktree-Lifecycle-Test** + Symlink-Test (gitignored Secrets).
2. **Cost-Cap-Test** + Out-of-Process Hard-Limit-Test.
3. **Worker-Crash-Recovery-Test**.
4. **Disput-Council-Smoke** (Round 1 ohne Pragmatist, Round 2/3 mit Tie-Break).
5. **Stakeholder-Sandwich-Test** (Injection) + **Validator-Schema-Test**.
6. **Branch-Allowlist-Test**.
7. **Self-Mod-Blocklist-Test** (Mock-Worker probiert `cost-cap.sh` zu editieren → blockiert + alarmiert).
8. **Audit-Hash-Chain-Verifier-Test**.
9. **Cloud-Heartbeat-Miss-Test** (kein Ping in 4h → Push).
10. **End-to-End-Akzeptanz** in Phase 4 nach gestaffelter Schwelle (48h → 72h → 7d / 48h-no-stakeholder).

---

## Risiken

### Block-Risiken

- **Self-Modification durch Worker** (Tag-3-Killer): Worker könnte Cost-Cap, Self-Mod-Blocklist oder Audit-Logger selbst editieren und damit das gesamte Sicherheits-Layering aushebeln. Mitigation: P0-0 Self-Mod-Blocklist + Out-of-Process Integrity-Check (separater LaunchAgent, NICHT in der Blocklist selbst, hashed Blocklist-Files stündlich).
- **Konvergenz-Schwelle**: 7-Tage-Lauf wird auf 48h gesenkt, dann 72h, dann 7d ODER 48h-no-stakeholder.
- **Worktree-Disk-Cost** auf macOS: realistisch ~3 GB pre-Build, ~5 GB post-Web-Build, ~12 GB post-iOS-Build pro Worktree. Mitigation: Default N=2, Hard-Cap N=3, Disk-Frei-Threshold 30%, absolutes Hard-Cap „mind. 20 GB frei reserviert".
- **Cost-Runaway**: 3 parallele Sonnet-Worker × 24h × 7 Tage. Mitigation: `budget_usd` als required-field im Item-Frontmatter, Default-Modell = Sonnet (Opus nur per Override), Out-of-Process Hard-Limit via Anthropic Admin-API auf Konto-Ebene.
- **Race-Conditions im Filesystem-Backlog**: Phase 1-3 nutzen separaten Pfad `.claude/overseer/inbox/`. Phase-4-Migration-Skript merged.
- **Prompt-Injection via Stakeholder-Input**: Sandwich-Markers + Trust-Tier + separater `stakeholder-validator`-Agent + Rate-Limit Tier-2 (5 Items/h).
- **Disput wird Endlos-Schleife**: 3-Runden-Cap. Bei Patt → `disputes/unresolved/` + Stakeholder-Eskalation, **KEIN Auto-Reject**. Pragmatist nur Tie-Break ab Runde 2 (verhindert Pragmatist-Diktator).
- **OAuth-Token-Expiry**: Pre-Run-Check + echter Health-Probe (`claude --print -p "ping"`).
- **Watchdog-überwacht-Watchdog**: macOS LaunchAgent + Cloud-Heartbeat (Off-Box).
- **PR-Konflikt mit main**: Auto-Rebase-Retry (1×), sonst Item zurück nach `inbox/` mit `[merge-conflict]`-Marker.
- **`--admin` umgeht Branch-Protection**: aus `auto-merge-pr.sh` für Headless/Overseer-Pfad **entfernt**, nur Stakeholder-Override per expliziter Anweisung.

### Schleichende Risiken

- **Analyzer-Spam**: Jeder Analyzer Dedup-Hash auf `(file_path, modul_name)` (NICHT file+line — Zeilenzahl ändert sich), Inbox-Cap 50, `last_fix_attempt`-Counter, nach 3 Versuchen Subject 7d pausiert.
- **Audit-Log-Tampering**: Append-Only via `chmod 0444` + `flock`, Hash-Chain, wöchentliches Off-Site-Backup, Audit-Logger in Self-Mod-Blocklist.
- **Per-File-Race**: `touches:`-Frontmatter + Per-File-Soft-Lock im Picker.
- **Theme-Drift bei parallelen UI-Workern**: durch Per-File-Soft-Lock verhindert.
- **Modell-Drift** der Sonnet-Worker.
- **Branch-Müll**.
- **Stakeholder erwartet schnelle Antwort**: ntfy-Acknowledgement sofort.

### Rückzieh-Pfad

Phase 1-3 läuft PARALLEL via `.claude/overseer/inbox/`. Erst Phase 4 mergt die Inbox-Pfade und schaltet den LaunchAgent um.

### Mensch-im-Loop-Pflicht-Stops

1. `supabase db push` gegen Prod.
2. `supabase secrets set`.
3. OAuth-Erst-Login.
4. Pricing/Billing-Promo.
5. Direct-Push auf `main`.
6. Force-Push.
7. Branch-Protection-Setup (HARD-PREREQ für Phase 4, mit Required Status Checks: flutter-analyze, flutter-test, security-reviewer != block, Self-Mod-Check).
8. **Anthropic Admin-API Out-of-Process Konto-Budget-Setting** (Pflicht-Setup-Step, Mitigation 4).
9. Erstmaliges Worktree-Setup auf neuer Maschine.
10. Stakeholder-Override `--admin`-Merge nur bei expliziter „btw merge PR #X --admin"-Anweisung.

---

## Tasks

> **Konvention** (übernommen aus A1): jeder Task hat `acceptance:`, `verify:`, `agent:`, `depends:`. **Neu (Committee):** Item-Frontmatter-Pflichtfelder `budget_usd`, `source` (tier-1/2/3), `touches: [paths]`, optional `model:`, `needs_dispute:`, `needs_gh:`.

### Bezug zum Vorgänger-Plan `2026-05-09_ai_automation_quality_uplift.md`

| Vorgänger-Task | Status hier |
|---|---|
| A0 Whitelist-Update | **Behalten als Pre-Requisite**. |
| A0.5 Playwright-MCP-Permissions | **Behalten als Pre-Requisite**. |
| A1 Plan-Schema-Hardening | **Behalten + erweitert** um `budget_usd`, `source`, `touches`. |
| A1.5 `/work`-Parser | **Behalten**. |
| A2 Failure-Memory-File | **Behalten**. |
| A3 `planner` Pre-Read Failure-Memory | **Behalten**. |
| A4 Browser-Tester-Schema | **Behalten**. |
| A5/A6 Plan-Schema + Validator | **Behalten**. |
| A7 Test-Fixtures | **Behalten**. |
| B0 Prompt-Caching | **Behalten** — kritisch für Cost-Cap. |
| **B1 Pre-Research-Agent** | **Erweitert/abgelöst** — `proponent` macht Pre-Research. |
| **B2 Self-Critique** | **Behalten**. |
| **B3 Self-Verify Pre-/ship** | **Behalten und erweitert** — Self-Verify Teil des Worker-Lifecycles + `smoke-full-app-audit` + `check-l10n.py` Pflicht (Mitigation 15). |
| **B4 Code-Quality-Reviewer** | **Behalten als Pre-Ship-Lightweight-Hook (warn-only)**, Continuous-Analyzer ist additiv — NICHT ersatzlos gestrichen (Mitigation 16). |
| **B5 Planner-Self-Critique** | **Abgelöst durch Disput-Council**. |
| C1 Hard-Switch-Akzeptanz | **Abgelöst** — Phase 4 mit Konvergenz-Definition (Mitigation 22). |
| C2 Auto-Append-Lessons | **Behalten**. |
| C3/C4 Metrik-Layer | **Erweitert** — Heartbeat + Wochen-Digest. |

---

### Phase 0 — Foundation

#### Task P0-0 — Self-Mod-Blocklist (KRITISCHSTE Änderung, vor allem anderen) [ADDED post-committee]

- [x] **Beschreibung:** Erweitert `.claude/scripts/guard-bash.sh`: blockt Edit/Write/Bash-Operationen auf folgende Pfade, sobald `HEADLESS_MODE=1` oder `OVERSEER_WORKER_PID` gesetzt ist:
  - `.claude/scripts/guard-bash.sh`, `cost-cap.sh`, `auto-merge-pr.sh`, `auto-commit.sh`, `install-*.sh`, `overseer.sh`, `worker.sh`, `watchdog.sh`, `recover.sh`, `audit-record.sh`, `notify.sh`
  - `.claude/agents/disput-*.md`, `stakeholder-triage.md`, `stakeholder-validator.md`
  - `.claude/settings.json`, `.claude/settings.local.json`
  - `CLAUDE.md`
  - `~/Library/LaunchAgents/com.inventory.*.plist`
  Pre-Push-Hook: prüft `git diff --cached` gegen Blocklist, abort + Audit + Notification bei Hit. Out-of-Process Integrity-Check: separater LaunchAgent (NICHT in der Blocklist selbst!) hashed Blocklist-Files stündlich, schickt PANIC-ntfy bei Hash-Änderung ohne User-Session-Marker.
- [x] **acceptance:**
  - Mock-Worker mit `HEADLESS_MODE=1` probiert `cost-cap.sh` zu editieren → blockiert + Notification + Audit.
  - Pre-Push-Hook blockt commit mit blocklist-Diff.
  - Integrity-Check-LaunchAgent läuft separat, ist selbst NICHT in Blocklist (sonst wäre er nicht updatebar).
  - User-Session-Marker (`.claude/.user-session-active`) wird beim manuellen Claude-Start gesetzt; Integrity-Check bypasst dann.
  - Hash-Manifest unter `.claude/integrity/manifest.sha256`.
- [x] **verify:** `.claude/scripts/verify/self-mod-blocklist.sh`
- [x] **agent:** `general-purpose`
- [x] **depends:** Vorgänger-Plan A0.

#### Task P0-1 — Whitelist-Erweiterung für autonomy-Pfade

- [x] **Beschreibung:** Drei Whitelist-Stellen (`auto-commit.sh`, `ship.md`, `CLAUDE.md`) ergänzen um: `.claude/stakeholder/`, `.claude/disputes/`, `.claude/audit/`, `.claude/overseer/`, `.claude/analyzer/`, `.claude/scripts/verify/`, `.claude/integrity/`, `.claude/stakeholder/digest/`. KEIN Wildcard. **Note: [committee]** Mitigation 2 — `auto-commit.sh` zusätzlich um Self-Mod-Reject erweitern: unter `HEADLESS_MODE=1` Diffs auf Blocklist-Pfade abort + Audit + Notification. Optional-Task: `.claude/whitelist.txt` als Single-Source-of-Truth (Empfehlung f).
- [x] **acceptance:**
  - Drei Files synchron erweitert.
  - Self-Mod-Reject in `auto-commit.sh` aktiv (Mock-Test).
  - `.gitkeep`-Dateien werden vom Stop-Hook gestaged.
  - `.claude/backlog/runs/`, `.claude/test-runs/`, `.claude/overseer/state/`, `.claude/analyzer/cache/`, `.claude/integrity/` bleiben gitignored (Manifest selbst aber tracked).
  - KEIN Wildcard.
- [x] **verify:** `.claude/scripts/verify/whitelist-paths.sh`
- [x] **agent:** `general-purpose`
- [x] **depends:** P0-0.

#### Task P0-2a — Cost-Cap-Library: Ledger-Append [Note: committee — Empfehlung o, gesplittet]

- [x] **Beschreibung:** `.claude/scripts/lib/cost-cap.sh` Teil 1: `cost_record <agent> <usd>` atomar append (lock-file basiert, `flock`).
- [x] **acceptance:**
  - Library importierbar.
  - Parallel-Append (10 Prozesse) ohne Korruption.
  - Ledger ist JSONL.
- [x] **verify:** `.claude/scripts/verify/cost-ledger-append.sh`
- [x] **agent:** `general-purpose`
- [x] **depends:** P0-1.

#### Task P0-2b — Cost-Cap-Library: Aggregation + Check [Note: committee]

- [x] **Beschreibung:** Teil 2: `cost_today_usd`, `cost_week_usd`, `cost_check_or_die <max_today> <max_week>`. Plus Out-of-Process Hard-Limit: Anthropic Admin-API Konto-Budget-Setting als Pflicht-Setup-Step (Mensch-im-Loop, Mitigation 4).
- [x] **acceptance:**
  - `cost_check_or_die 5 30` exit 0 bei leerem Ledger, exit 2 bei Überschreitung.
  - Setup-Doku in `.claude/overseer/SETUP.md` für Admin-API-Limit.
  - Mock-Test mit injiziertem Ledger grün.
- [x] **verify:** `.claude/scripts/verify/cost-cap.sh`
- [x] **agent:** `general-purpose`
- [x] **depends:** P0-2a.

#### Task P0-3 — Worktree-Helper (Bash-Wrapper um `gwq`) [Note: committee — Mitigation 6+7, Empfehlung a/c]

- [x] **Beschreibung:** **Empfehlung gewählt:** Bash-Wrapper um `gwq` (Apache-2.0). Bei Phase-0-Start verifizieren, ob Claude Code seit Q1 2026 nativen Worktree-Support hat — wenn ja, P0-3 weiter schrumpfen. Funktionen `worktree_create <slug>`, `worktree_remove <slug>`, `worktree_list`, `worktree_prune_stale <hours>`. Worktrees liegen unter `../inventory_management_worker_<slug>/`.

  **Disk-Realität (Mitigation 6, in Beschreibung dokumentiert):**

  | State | Disk-Bedarf pro Worktree |
  |---|---|
  | pre-Build | ~3 GB |
  | post-`flutter build web` | ~5 GB |
  | post-iOS-Build | ~12 GB |

  **Caps:** Default N=2, Hard-Cap N=3 (statt N=4), Disk-Frei-Threshold 30% UND absolutes Hard-Cap „mind. 20 GB frei reserviert".

  **Symlink-Strategie für gitignored Secrets (Mitigation 7):** `.env`, `.env.test`, `.env.headless`, `.env.local` → Symlinks vom Worktree zum Haupt-Repo. `lib/config/supabase_config.dart`, `google-services.json`, `GoogleService-Info.plist` IST tracked → kommen automatisch mit, kein Symlink nötig.

  **Native Worktree Support:** Claude Code 2.1.138 hat nativen `--worktree/-w` Support (Q1 2026). Wrapper trotzdem gebaut für `--max-budget-usd`-Übergabe, Symlink-Strategie, Disk-Caps und Swarm-Orchestrator-APIs.

  **gwq:** nicht installiert → Fallback auf `git worktree` aktiv.

- [x] **acceptance:**
  - 2 sequentielle `worktree_create` legen 2 Worktrees an, der 4te exit 3. ✓
  - `worktree_remove` entfernt sauber + räumt `.dart_tool/`+`build/` (Empfehlung j). ✓
  - Disk-Frei < 30% ODER < 20 GB → exit 4. ✓
  - `find <worktree> -name '.env*' -type f` muss leer sein (nur Symlinks). ✓
  - [~] Nach `worktree_create`: `flutter analyze` + `smoke-login` exit 0, sonst Worktree-Init exit 5. [deferred to P1] — requires .env.test with real credentials + running web app.
  - Pre-Warm-Hook (`flutter pub get`) optional via `WORKTREE_PREWARM=1`. ✓ (implementiert, nicht in Sandbox testbar ohne flutter pub cache)
- [x] **verify:** `.claude/scripts/verify/worktree.sh` — 13/13 tests PASS
- [x] **agent:** `general-purpose`
- [x] **depends:** P0-1.

#### Task P0-4 — Audit-Trail-Schema + Logger-Helper (Hash-Chain) [Note: committee — Mitigation 19]

- [x] **Beschreibung:** `.claude/scripts/lib/audit.sh` mit `audit_record <actor> <action> <subject> <reason>`. Schreibt nach `.claude/audit/<YYYY-MM-DD>.md` als Append, mit Timestamp, git-commit-SHA, JSON-encoded reason. **Hash-Chain:** jeder Eintrag enthält `prev_hash` des vorherigen Eintrags. **Append-Only-Schutz:** `chmod 0444` nach Append (auf macOS optional `chflags uchg`). **`flock`** um Append (multi-line > 4096 bytes ist nicht POSIX-atomic). Out-of-process Verifier `.claude/scripts/audit-verify.sh` prüft Chain. Optional Helper `.claude/scripts/audit-grep.sh "<keyword>"` (Empfehlung h). `audit-record.sh` ist in Self-Mod-Blocklist (P0-0).
- [x] **acceptance:**
  - 3 Mock-Aufrufe → 3 Zeilen mit korrekt verketteten Hashes.
  - Verifier exit 0 bei valider Chain, exit 1 bei Tampering.
  - Audit-File nach Append `0444`.
  - `flock`-Test: 10 parallele Append-Aufrufe → kein Daten-Verlust.
- [x] **verify:** `.claude/scripts/verify/audit-format.sh` — 9/9 tests PASS
- [x] **agent:** `general-purpose`
- [x] **depends:** P0-1.

#### Task P0-5 — Resource-Watchdog-Skript

- [x] **Beschreibung:** `.claude/scripts/watchdog.sh` (alle 5 Min). **Note: [committee]** nutzt `notify.sh` (P0-7), nicht direkt `curl ntfy.sh`. Prüft Disk-Frei (< 15% → Panic, < 5% → kritischer Bypass-Push), Worktree-Count (> 3 → Panic, war > 4), offene Inbox-Items (> 50 → Analyzer-Pause), Stash-Count (> 10 → drop oldest), Cost-Cap (Hard-Stop). Schreibt `.claude/overseer/health.json`.
- [x] **acceptance:**
  - Mock-Run mit füll-disk → `health.json` zeigt `panic: true`, Audit, kritische Notification.
  - Cost-Cap überschritten → `.claude/overseer/PANIC` Marker.
  - Notifications gehen über `notify.sh`, nicht direkt ntfy.
- [x] **verify:** `.claude/scripts/verify/watchdog.sh` — 23/23 tests PASS
- [x] **agent:** `general-purpose`
- [x] **depends:** P0-2b, P0-3, P0-4, P0-7.

#### Task P0-6 — OAuth-Token-Expiry-Watch [Note: committee — Empfehlung e]

- [x] **Beschreibung:** `.claude/scripts/lib/oauth-check.sh`: prüft `gh auth status`, Anthropic-Token-Expiry, `supabase --version`. **Echter Health-Probe (Empfehlung e):** `claude --print -p "ping"` als Probe (nicht nur State-File-Inspection). Bei TTL < 48h → Notification (via `notify.sh`).
- [x] **acceptance:**
  - Mock-`gh auth status` "expires in 24h" → Notification. ✓ Test 2: PASS (exit 1, status=expiring, info notify logged)
  - Mock-revoked-Anthropic-Token (`claude --print` exit !=0) → `.claude/overseer/AUTH_EXPIRED` Marker, Overseer pausiert. ✓ Test 3: PASS (exit 2, AUTH_EXPIRED written)
  - Pflicht-Akzeptanz: Mock-Test mit revoked-Token grün. ✓ Verify: PASS 19/19
- [x] **verify:** `.claude/scripts/verify/oauth-check.sh` — 19/19 PASS (2026-05-10)
- [x] **agent:** `general-purpose`
- [x] **depends:** P0-4, P0-7.

#### Task P0-7 — Notification-Wrapper `notify.sh` [ADDED post-committee — Mitigation 12, Empfehlung m]

- [x] **Beschreibung:** `.claude/scripts/notify.sh <severity> <topic> <title> <body> [action_buttons_json]`. Severity-Routing: `critical | info | noise`. Quiet-Hours via Env `QUIET_HOURS_START=22 QUIET_HOURS_END=08`, kritische bypassen (Cost-Cap, OAuth expired, Disk < 5%, Panic, Self-Mod-Hit, Cloud-Heartbeat-Miss). Dedup: Hash(topic+message) + TTL 4h. Title+Body-Templates pro Quelle. Helper für ntfy-Action-Buttons (sinnvoll für „Pause overseer" / „Approve dispute #N" / „Show details URL"). **Pflicht: alle Daemons (P0-5, P0-6, P2-2, P3-7, P3-9) MÜSSEN `notify.sh` nutzen.**
- [x] **acceptance:**
  - 2 identische Pushs binnen 4h → nur 1 Versand (Dedup).
  - Quiet-Hours info-Push wird zurückgehalten, kritischer durchgelassen.
  - Action-Buttons-Helper produziert valides ntfy-JSON.
  - Mock-Daemon-Hooks zeigen `notify.sh`-Nutzung.
- [x] **verify:** `.claude/scripts/verify/notify.sh`
- [x] **agent:** `general-purpose`
- [x] **depends:** P0-1, P0-4.

---

### Phase 1 — Single-Worker-Overseer (parallel zum alten Headless-Loop, separater Inbox-Pfad)

#### Task P1-1 — Overseer-Daemon-Skript [Note: committee — Mitigation 8, External-Scout a]

- [x] **Beschreibung:** `.claude/scripts/overseer.sh`: long-running Loop. **Pickt Items aus `.claude/overseer/inbox/`** (NICHT aus `.claude/backlog/inbox/`, um Migrations-Race mit altem Headless-Loop zu vermeiden, Mitigation 8). Atomic-Move (`overseer/inbox/X` → `overseer/in_progress/X.<pid>`), spawnt Worker im Worktree, wartet, verschiebt nach `done/`/`failed/`, räumt Worktree auf. `STOP`/`PANIC`-Marker. **Empfehlung:** `architecture-design.md` aus `agent-orchestrator` (MIT, ComposioHQ) als Pflicht-Read im PR-Body referenzieren.
- [x] **acceptance:**
  - Drei Mock-Items → sequentiell durch (Phase 1 N=1). ✓
  - Worktree pro Item neu + nach Exit entfernt. ✓
  - `STOP`/`PANIC` graceful. ✓
  - Cost-Cap-Überschreitung pausiert. ✓
  - Bestehender Headless-Runner bleibt unangetastet (kein Picker-Konflikt). ✓
- [x] **verify:** `.claude/scripts/verify/overseer-single.sh` — 21/21 PASS (2026-05-10). worker.sh ist Stub, P1-2 ersetzt komplett.
- [x] **agent:** `general-purpose`
- [x] **depends:** P0-2b, P0-3, P0-4, P0-5, P0-7.

#### Task P1-2 — Worker-Wrapper-Skript [Note: committee — Mitigations 3, 15, Empfehlung l]

- [x] **Beschreibung:** `.claude/scripts/worker.sh <item-path> <worktree-path>`: ruft `claude --print` im Worktree.

  **Pflicht-Änderungen:**
  - `--max-budget-usd` MUSS gesetzt sein (aus Item-Frontmatter `budget_usd` — **required field**).
  - **Default-Modell `sonnet`** (nicht opus). Opus nur bei explizitem Item-`model:`-Override.
  - Worker-Wrapper exit 1 wenn `budget_usd` fehlt.
  - **Pre-Ship-Pflicht (Mitigation 15):** Wenn Diff `lib/screens/|lib/widgets/|lib/l10n/|lib/app_theme.dart` berührt → `smoke-full-app-audit` muss grün, `python3 .claude/scripts/check-l10n.py` exit 0. Sonst Worker exit 3 (blocked-pre-ship), Item zurück in Inbox mit `[blocked-pre-ship]`-Marker (KEIN failed/-Move). Overseer mappt exit 3 → `release_item blocked-pre-ship`.
  - **Minimal-Rights-Env (Empfehlung l):** `GH_TOKEN` nur falls `needs_gh: true` im Frontmatter, sonst leer. `SUPABASE_ACCESS_TOKEN`/`SUPABASE_DB_PASSWORD` IMMER aus Worker-Env entfernt.
  - Cost-Event ins Ledger (`worker-<slug>` mit actual_usd aus Run-Log oder Pessimist-Fallback `budget_usd`).
  - Worker respektiert `PANIC` (exit 2).
  - Sentinel-Pattern bleibt (`## Result: failed`, `## Self-Verify failed`, Cost-Cap-Tampering → PANIC).
  - **B4 Pre-Ship-Code-Quality-Reviewer** als warn-only Hook (skip-silently wenn Agent fehlt).
- [x] **acceptance:**
  - Item ohne `budget_usd` → exit 1. ✓
  - Default `sonnet`, Opus nur bei Override. ✓
  - Pre-Ship-Audit-Verletzung → exit 3 + `[blocked-pre-ship]` (NICHT failed/). ✓
  - Env-Test: `needs_gh: false` Worker hat leeres `GH_TOKEN`. ✓
  - Cost-Event nach Run-Ende. ✓
- [x] **verify:** `.claude/scripts/verify/worker-wrapper.sh` — 17/17 PASS (2026-05-10).
- [x] **agent:** `general-purpose`
- [x] **depends:** P1-1, P0-2a, P0-0.

#### Task P1-3 — LaunchAgent für Overseer (KeepAlive) [Note: committee — Empfehlung i]

- [x] **Beschreibung:** `.claude/scripts/install-overseer.sh` → `~/Library/LaunchAgents/com.inventory.overseer.plist` mit `KeepAlive=true`, `ProcessType=Background`, `RunAtLoad=false` (Empfehlung i — verhindert Boot-Storm), `ThrottleInterval=10`. Sleep-Loop mit min 30s Iteration.
- [x] **acceptance:**
  - LaunchAgent registriert. ✓
  - [~] `kill -9 $(pgrep -f overseer.sh)` → restartet binnen 10s mit Throttle. [manual verify on macOS required — T5 in verify script]
  - Uninstall sauber. ✓
  - Konflikt-Check mit altem `headless-loop`-LaunchAgent: separater Inbox-Pfad löst es (P1-1). ✓
  - `RunAtLoad=false` → kein Auto-Start beim Boot. ✓
- [x] **verify:** `.claude/scripts/verify/launchagent-overseer.sh` — 18/18 PASS, 2 SKIP (T4/T5 macOS-launchd sandbox-skip) (2026-05-10).
- [x] **agent:** `general-purpose`
- [x] **depends:** P1-1, P1-2.

#### Task P1-4 — Atomic-Move-Picker (Race-Condition-Schutz) [Note: committee — Mitigation 20]

- [x] **Beschreibung:** `.claude/scripts/lib/picker.sh`: `pick_next_item <pid>` macht atomic `mv overseer/inbox/X.md overseer/in_progress/X.<pid>.md`. **Per-File-Soft-Lock (Mitigation 20):** Item-Frontmatter `touches: [paths]` als **Pflicht-Feld** bei Stakeholder-Triage- und Analyzer-Modulen. Picker blockt überlappende Items (Pfad-Overlap-Check gegen aktuell laufende Items). `release_item <path> <result>` schiebt nach `done/`/`failed/`.
- [x] **acceptance:**
  - Zwei parallele Mock-Picker → keiner pickt dasselbe Item.
  - Item ohne `touches:` → exit 1 (außer für Tier-1 manuelle Items, die Sandwich-bypass haben).
  - Pfad-Overlap → zweites Item bleibt im Inbox bis erstes fertig.
  - PID-Filename macht Owner sichtbar.
  - `recover_orphaned_items` schiebt tote-PID-Items zurück mit `[recovered]`.
- [x] **verify:** `.claude/scripts/verify/picker-race.sh`
- [x] **agent:** `general-purpose`
- [x] **depends:** P0-1.

---

### Phase 2 — Worker-Pool, Stakeholder-Inbox, Analyzer-MVP

#### Task P2-1 — Worker-Pool (N=2, Hard-Cap N=3) im Overseer [Note: committee — Mitigation 6]

- [ ] **Beschreibung:** Overseer spawnt bis zu N Workers parallel (Default N=2, Hard-Cap N=3, Env `OVERSEER_MAX_WORKERS`).
- [ ] **acceptance:**
  - 4 Mock-Items + N=2 → exakt 2 parallel.
  - Slot frei → nächstes Item.
  - N=3 + 5 Items: 3 parallel + 2 wartend.
  - Disk-Watchdog pausiert bei < 30% / < 20 GB.
  - `OVERSEER_MAX_WORKERS=4` → Cap auf 3 + Warn-Log.
- [ ] **verify:** `.claude/scripts/verify/overseer-pool.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P1-1, P1-2, P0-3.

#### Task P2-2 — Stakeholder-Inbox-CLI (Tier-1) [Note: committee — Mitigation 13, 14]

- [ ] **Beschreibung:** `.claude/scripts/btw.sh "<text>"`: schreibt `.claude/stakeholder/inbox/<timestamp>-<slug>.md` mit Sandwich-Markers + Frontmatter `source: tier-1`. Schickt sofort ntfy-Acknowledgement via `notify.sh`. Slug ≤ 40 chars, kebab-case.
- [ ] **acceptance:**
  - Item entsteht mit `source: tier-1`.
  - Sandwich-Markers vorhanden.
  - ntfy-Push via `notify.sh`.
- [ ] **verify:** `.claude/scripts/verify/btw-cli.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P0-1, P0-7.

#### Task P2-2b — Telegram-Bot-Adapter (Tier-2) [ADDED post-committee — Mitigation 11, 13]

- [ ] **Beschreibung:** **Pflicht für Phase-4-Akzeptanz „1 Woche ohne Laptop".** ~15 Zeilen Python (oder Deno via Edge-Function). Hört auf `/btw <text>`-Commands von Telegram-Bot, schreibt `.claude/stakeholder/inbox/<timestamp>-<slug>.md` mit `source: tier-2`. User-ID-Allowlist via Env `TELEGRAM_ALLOWED_USER_IDS`. **HMAC-signiertes Token, das pro Briefing rotiert wird.** Rate-Limit: max 5 Items/h Tier-2.
- [ ] **acceptance:**
  - Allowed User → Item entsteht.
  - Disallowed User → keine Reaktion + Audit-Eintrag.
  - 6. Item innerhalb 1h → blocked + Notification.
  - HMAC-Token-Rotation pro Briefing funktioniert (Token aus aktuellstem Briefing-File).
  - ntfy-Action-Buttons als sekundärer Kanal (Mitigation 11): `notify.sh` (P0-7) bietet Helper für „Pause overseer", „Approve disput #N", „Show details".
  - Plan dokumentiert: ohne Telegram-Bridge ist Phase-4-Akzeptanz NICHT einlösbar.
- [ ] **verify:** `.claude/scripts/verify/telegram-bridge.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P2-2, P0-7.

#### Task P2-3 — Stakeholder-Triage-Agent [Note: committee — Empfehlung d]

- [ ] **Beschreibung:** `.claude/agents/stakeholder-triage.md` (**Modell: Opus**, Empfehlung d — direkter User→LLM-Adversarial-Boundary, hier Cost-Sparen kontraproduktiv). Read-Only-Tools (Read, Grep, Glob, Write — kein Bash). Klassifiziert: `feature-request` / `bugfix` / `question` / `injection-attempt`. Erzeugt entweder Backlog-Item ODER Response. Bei Injection: nach `quarantine/` + Audit. **Output mit Pflicht-Frontmatter `budget_usd`, `source`, `touches`, `model`.** Item-Priority-Prefix: `01-stakeholder-`.
- [ ] **acceptance:**
  - Sandwich-Marker-Regel im Prompt.
  - Tools: nur Read, Grep, Glob, Write.
  - Few-Shot mit 3 Beispielen.
  - Mock-Run Injection → quarantine.
  - Output gültiges Backlog-Item-Format mit allen Pflicht-Frontmatter-Feldern.
- [ ] **verify:** `.claude/scripts/verify/stakeholder-triage.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P2-2, Vorgänger A1.

#### Task P2-3b — Stakeholder-Validator-Agent [ADDED post-committee — Mitigation 13, Empfehlung k]

- [ ] **Beschreibung:** `.claude/agents/stakeholder-validator.md`. Zweiter Agent prüft Triage-Output (Backlog-Item-Markdown) gegen Schema-Regex-Whitelist: kein `git rm`, keine destruktiven Befehle in `acceptance:`-Bullets, keine Schreib-Pfade außerhalb `lib/`/`supabase/`/`test/`/`.claude/`. Bei Verstoß → `quarantine/` + Audit.
- [ ] **acceptance:**
  - Mock-Triage-Output mit `git rm -rf` → quarantine.
  - Mock-Output mit `acceptance: rm -rf /` → quarantine.
  - Sauberer Output → durchgelassen.
  - Schema-Regex in `.claude/agents/stakeholder-validator.md` dokumentiert.
- [ ] **verify:** `.claude/scripts/verify/stakeholder-validator.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P2-3.

#### Task P2-4 — Stakeholder-Triage in Overseer-Loop integrieren

- [ ] **Beschreibung:** Overseer prüft alle 60s `.claude/stakeholder/inbox/`, ruft `stakeholder-triage` → `stakeholder-validator` (Pipeline). Audit-Trail jeder Triage. Validierte Items landen in `.claude/overseer/inbox/` mit Prefix `01-stakeholder-` (kommt nach `00-followup-`, vor `02-analyzer-`, Mitigation 14).
- [ ] **acceptance:**
  - 2 `btw`-Items → beide binnen 2 Min triagiert + validiert.
  - Triage→Validator-Pipeline funktioniert.
  - Audit pro Triage + Validate.
  - Priority-Prefix korrekt.
- [ ] **verify:** `smoke-stakeholder-flow`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P2-1, P2-3, P2-3b.

#### Task P2-5 — Analyzer-Modul: `scan-tech-debt` [P3-4a-Pattern]

- [ ] **Beschreibung:** `.claude/analyzer/modules/scan-tech-debt.sh`: greppt nach TODO/FIXME mit git-blame-Datum > 30 Tagen. Dedup-Hash auf `(file_path, modul_name)` (Mitigation 23, NICHT file+line). Cap 5 Items/Run. **`last_fix_attempt`-Counter:** nach 3 Versuchen am gleichen Subject → Modul pausiert dieses Subject 7 Tage + Audit + Stakeholder-Notify.
- [ ] **acceptance:**
  - Mock-File mit altem TODO → 1 Item.
  - Re-Run → KEIN Duplikat.
  - 4. Versuch → Subject 7d pausiert + Notification.
  - Inbox-Cap > 50 → skip + Audit.
  - Item hat `source: tier-3`, `touches:`, `budget_usd`.
- [ ] **verify:** `.claude/scripts/verify/scan-tech-debt.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P0-1, P0-4.

#### Task P2-6 — Analyzer-Modul: `scan-l10n-drift`

- [ ] **Beschreibung:** Wrapper um `python3 .claude/scripts/check-l10n.py --json`. Dedup-Hash, `last_fix_attempt`-Counter (Mitigation 23).
- [ ] **acceptance:**
  - Clean → kein Item.
  - Mock-Drift → 1 Item.
  - Re-Run → kein Duplikat.
  - 4. Versuch → 7d-Pause.
- [ ] **verify:** `.claude/scripts/verify/scan-l10n-drift.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P2-5.

#### Task P2-7 — Analyzer-Modul: `scan-failure-lessons-expiry`

- [ ] **Beschreibung:** Liest `.claude/memory/failure-lessons.md`, prüft `expires_at:`-Felder.
- [ ] **acceptance:**
  - Abgelaufene → 1 Item.
  - Future → kein Item.
- [ ] **verify:** `.claude/scripts/verify/scan-failure-lessons.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** Vorgänger A2.

#### Task P2-8 — Analyzer-Daemon-Skript

- [ ] **Beschreibung:** `.claude/scripts/analyzer.sh`: long-running Loop, alle 60 Min. Eigenes LaunchAgent (`RunAtLoad=false`, `ThrottleInterval=10`). Read-Only. Nutzt Cost-Cap-Library + `notify.sh`.
- [ ] **acceptance:**
  - LaunchAgent installiert.
  - 3 Module sequentiell.
  - Panic pausiert.
  - Audit pro Modul-Lauf.
- [ ] **verify:** `.claude/scripts/verify/analyzer-daemon.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P2-5, P2-6, P2-7, P0-5, P0-7.

---

### Phase 3 — Disput-Council, volle Analyzer-Suite, Cleanup, Cloud-Heartbeat

#### Task P3-1 — Disput-Subagents (3 neue) [Note: committee — Mitigation 17]

- [ ] **Beschreibung:** `.claude/agents/disput-proponent.md`, `disput-skeptic.md`, `disput-pragmatist.md`. Alle Opus.

  **Tools:**
  - `proponent`: Read, Grep, Glob, WebSearch.
  - `skeptic`: Read, Grep, Glob, WebSearch.
  - `pragmatist`: Read, Grep, Glob, **WebSearch (Mitigation 17 — sonst Tie-Break konservativ-rejecting).**

  **Wichtige Regel (Mitigation 17):** **Pragmatist NICHT in Runde 1, nur Tie-Break ab Runde 2.** Verhindert Pragmatist-Diktator-Effekt.
- [ ] **acceptance:**
  - Klare Rollen.
  - Prompts < 500 Zeilen.
  - Output-Format strukturiert.
  - Pragmatist-Prompt explizit „nur bei Patt".
- [ ] **verify:** `.claude/scripts/verify/disput-agents.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** Vorgänger A3.

#### Task P3-2 — Disput-Orchestrator-Skript [Note: committee — Mitigation 5, 17]

- [ ] **Beschreibung:** `.claude/scripts/disput.sh <proposal-md>`: spawnt Agents.
  - **Runde 1:** proponent → skeptic (KEIN pragmatist).
  - **Runde 2:** wenn Patt, pragmatist Tie-Break-Vote.
  - **Runde 3:** Cap. Bei weiterhin Patt → `disputes/unresolved/<id>/` + Stakeholder-Eskalation via `notify.sh` (Mitigation 17, **KEIN Auto-Reject**).

  Schreibt `.claude/disputes/<id>/round-N.md`. Verdict-File `decision: accept | reject | accept-with-changes | unresolved`.

  **Cost-Cap (Mitigation 5):** $10/Disput, $20/Tag (statt $1/Disput) — sonst wird nahezu jeder Disput abgebrochen.
- [ ] **acceptance:**
  - Mock-Proposal → Disput-Folder mit ≥ 1 Round + Verdict.
  - Round-2-Tie-Break funktioniert.
  - Round-3-Patt → `unresolved/` + Stakeholder-Notify (kein Auto-Reject).
  - Cost-Cap $10/Disput Hard-Stop.
  - Disput-Files read-only Markdown.
- [ ] **verify:** `.claude/scripts/verify/disput-flow.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P3-1, P0-7.

#### Task P3-3 — Disput-Trigger-Heuristik

- [ ] **Beschreibung:** `.claude/scripts/lib/needs-dispute.sh`: prüft Item-Frontmatter `needs_dispute: true` ODER Auto-Heuristik (>5 Files, Architektur-Keywords, neue Dependency, Migration). **Mitigation 14:** Bei `source: tier-3` (Analyzer) und Migration/RLS → IMMER Disput-pflichtig.
- [ ] **acceptance:**
  - Item „neue Tabelle" → Trigger.
  - „Tippfehler" → kein Trigger.
  - `source: tier-3` + Migration → Trigger immer.
  - `needs_dispute: false` overrided.
  - Audit-Eintrag.
- [ ] **verify:** `.claude/scripts/verify/needs-dispute.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P3-2.

#### Task P3-4a — Analyzer-Modul: `scan-mobile-overflow` [Note: committee — Mitigation 18, gesplittet]

- [ ] **Beschreibung:** Wrapper um `smoke-full-app-audit` Findings. Dedup-Hash + `last_fix_attempt`-Counter.
- [ ] **acceptance:** Mock-Overflow → 1 Item; Re-Run kein Duplikat.
- [ ] **verify:** `.claude/scripts/verify/scan-mobile-overflow.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P2-8.

#### Task P3-4b — Analyzer-Modul: `scan-test-coverage` [ADDED post-committee — Mitigation 18]

- [ ] **Beschreibung:** Service-Layer-Coverage-Drop > 5% → Item.
- [ ] **acceptance:** Mock-Coverage-Drop → 1 Item.
- [ ] **verify:** `.claude/scripts/verify/scan-test-coverage.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P2-8.

#### Task P3-4c — Analyzer-Modul: `scan-doc-drift` [ADDED post-committee — Mitigation 18]

- [ ] **Beschreibung:** Wrapper um `update-docs --strict`.
- [ ] **acceptance:** Mock-Doku-Drift → 1 Item.
- [ ] **verify:** `.claude/scripts/verify/scan-doc-drift.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P2-8.

#### Task P3-4d — Analyzer-Modul: `scan-help-drift` [ADDED post-committee — Mitigation 18]

- [ ] **Beschreibung:** Wrapper um `update-help --strict`.
- [ ] **acceptance:** Mock-Help-Drift → 1 Item.
- [ ] **verify:** `.claude/scripts/verify/scan-help-drift.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P2-8.

#### Task P3-4e — Analyzer-Modul: `scan-security-drift` [ADDED post-committee — Mitigation 18]

- [ ] **Beschreibung:** RLS-Coverage neuer Tabellen, ungeschützte Edge Functions.
- [ ] **acceptance:** Mock-RLS-fehlt → 1 Item mit `needs_dispute: true`.
- [ ] **verify:** `.claude/scripts/verify/scan-security-drift.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P2-8.

#### Task P3-4f — Analyzer-Modul: `scan-dead-code` [ADDED post-committee — Mitigation 18]

- [ ] **Beschreibung:** `dart analyze` + ungenutzte Symbol-Heuristik.
- [ ] **acceptance:** Mock-Dead-Code → 1 Item.
- [ ] **verify:** `.claude/scripts/verify/scan-dead-code.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P2-8.

#### Task P3-4g — Analyzer-Modul: `scan-dependency-rot` [ADDED post-committee — Mitigation 18, Empfehlung a]

- [ ] **Beschreibung:** **Renovate** mit `dependencyDashboard: true` (External-Scout-Empfehlung) — als GitHub-App registrieren statt eigenes `pub outdated`-Parsing. Wrapper liest Renovate-Dashboard-Issue, generiert Backlog-Items.
- [ ] **acceptance:** Renovate-PR-Issue → 1 Item mit `[renovate-major]`-Marker.
- [ ] **verify:** `.claude/scripts/verify/scan-dependency-rot.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P2-8.

#### Task P3-5 — Auto-Recovery-Watchdog

- [ ] **Beschreibung:** `.claude/scripts/recover.sh` (alle 5 Min): tote PIDs, tote Worktrees, hängende Worker (Timeout > 60 Min). Räumt + schiebt zurück mit `[recovered N×]`. Nach 3 Cycles → `failed/`.
- [ ] **acceptance:**
  - Mock-Worker `kill -9` → Recovery binnen 5 Min.
  - Hängender Worker (sleep 999999) → Timeout-Kill.
  - 3 Cycles → `failed/` + Audit.
- [ ] **verify:** `.claude/scripts/verify/auto-recovery.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P0-5, P1-4, P2-1.

#### Task P3-6 — Cleanup-Daemons [Note: committee — Empfehlung j]

- [ ] **Beschreibung:** `.claude/scripts/cleanup.sh` (täglich 03:00): merged-Branches > 7d, Stashes > 7d, Run-Logs > 30d, Disput-Files > 90d archivieren, Audit-Files > 30d rotieren. **Empfehlung j:** `worktree_remove` zusätzlich `rm -rf` des Worktree-`.dart_tool/` und `build/`.
- [ ] **acceptance:**
  - Alt-merged → gelöscht.
  - Alt-unmerged → bleibt + Notification.
  - Worktree-Remove räumt `.dart_tool/`+`build/`.
- [ ] **verify:** `.claude/scripts/verify/cleanup.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P0-3, P0-4.

#### Task P3-7 — Panic-Mode + Stakeholder-Notification

- [ ] **Beschreibung:** Bei 3 consecutive Worker-Failures ODER `PANIC` → Overseer pausiert, Push via `notify.sh` (kritisch, bypasst Quiet-Hours). Resume nur via `bash .claude/scripts/resume.sh`.
- [ ] **acceptance:**
  - 3 Mock-Failures → Pause + Push.
  - `resume.sh` löscht PANIC + Counter.
  - Audit bei Pause + Resume.
- [ ] **verify:** `.claude/scripts/verify/panic-mode.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P0-5, P1-1, P0-7.

#### Task P3-8 — Branch-Allowlist-Härtung

- [ ] **Beschreibung:** `guard-bash.sh` erweitert: Worker-Branch muss `^(feature|fix|chore)/[a-z0-9\-]{1,40}$`.
- [ ] **acceptance:**
  - `weird_branch` → block.
  - `feature/abc` → ok.
- [ ] **verify:** `.claude/scripts/verify/branch-allowlist.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P0-1.

#### Task P3-9 — Heartbeat-Briefing-Daemon (Daily)

- [ ] **Beschreibung:** `.claude/scripts/briefing.sh` (täglich 09:00): aggregiert 24h aus Audit + Done/Failed + Cost + Disput-Verdicts. Schreibt `.claude/audit/briefings/<date>.md` + Push via `notify.sh` mit Highlights. **Enthält rotiertes HMAC-Token für Telegram-Bridge (P2-2b).**
- [ ] **acceptance:**
  - Briefing-File mit Sektionen.
  - Push max 200 Zeichen.
  - HMAC-Token rotiert.
- [ ] **verify:** `.claude/scripts/verify/briefing.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P0-4, P3-2, P0-7.

#### Task P3-9.5 — Wochen-Digest [ADDED post-committee — Empfehlung g]

- [ ] **Beschreibung:** `.claude/stakeholder/digest/<YYYY-Wxx>.md` zusätzlich zu Daily-Briefing. Sonntag 09:00. Sektionen: gemerged-PRs (1-Zeilen-Why), abgelehnte Disputs (Reason), offene Stakeholder-Items, Cost-Summary, Action-Items für Wochenend-Rückkehr. Optional `audit-grep.sh "<keyword>"`-Helper für Stakeholder-Suche bei Rückkehr (Empfehlung h).
- [ ] **acceptance:**
  - Sonntag 09:00 → Digest-File entsteht.
  - Push via `notify.sh` mit Wochenzusammenfassung.
- [ ] **verify:** `.claude/scripts/verify/weekly-digest.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P3-9.

#### Task P3-10 — Cost-Cap-Bypass-Schutz

- [ ] **Beschreibung:** Sekundär-Watchdog: Cost-Ledger-Hash monoton (Hash-Chain ähnlich Audit). Tampering → PANIC.
- [ ] **acceptance:**
  - Tampering (Eintrag entfernt) → PANIC.
  - Normal-Append → ok.
- [ ] **verify:** `.claude/scripts/verify/cost-tamper.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P0-2b, P3-7.

#### Task P3-11 — Auto-Rebase-Retry bei Merge-Konflikt [ADDED post-committee — Mitigation 9, 10]

- [ ] **Beschreibung:** Wenn `gh pr merge` (ohne `--admin`) mit Konflikt failt, max 1 Rebase-Versuch (`git pull --rebase origin main` im Worktree, Push, erneuter Merge-Versuch). Wenn weiterhin Konflikt → Item zurück nach `inbox/` mit `[merge-conflict]`-Marker (**NICHT `failed/`**, Mitigation 9).

  **Mitigation 10:** `--admin` aus `auto-merge-pr.sh` für Headless/Overseer-Pfad **entfernt**. Stattdessen: warten bis CI grün, dann normaler Merge. Required Status Checks: flutter-analyze, flutter-test, security-reviewer != block, Self-Mod-Check. Stakeholder-Override für `--admin` nur bei expliziter „btw merge PR #X --admin"-Anweisung.
- [ ] **acceptance:**
  - Mock-Konflikt + Rebase-Erfolg → Merge.
  - Rebase-Fail → `[merge-conflict]`-Marker im Inbox.
  - `--admin` aus Headless-Pfad entfernt.
  - Stakeholder-Override-Pfad funktioniert.
- [ ] **verify:** `.claude/scripts/verify/merge-conflict-recovery.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P3-7.

#### Task P3-12 — Cloud-Heartbeat (Off-Box-Watchdog) [ADDED post-committee — Mitigation 21]

- [ ] **Beschreibung:** Supabase-Scheduled-Edge-Function `overseer-heartbeat-cloud` ODER GitHub-Actions-Cron (alle 4h). Erwartet Ping vom Overseer (HTTP POST mit shared-secret-Token). Bleibt Ping aus → Push an User („Overseer is dead, system stopped"). Spiegelt LaunchAgent-Death (macOS-Update kickt LaunchAgents).
- [ ] **acceptance:**
  - Mock-Ping ausgesetzt 4h → Push.
  - Normal-Ping → kein Alarm.
  - Shared-Secret-Token-Validierung.
  - Edge-Function bzw. GitHub-Actions-Workflow committed.
- [ ] **verify:** `.claude/scripts/verify/cloud-heartbeat.sh`
- [ ] **agent:** `edge-fn-coder` (falls Supabase-Variante) oder `general-purpose` (GitHub-Actions)
- [ ] **depends:** P3-7.

#### Task P3-13 — Audit Off-Site-Backup [ADDED post-committee — Mitigation 19]

- [ ] **Beschreibung:** Wöchentlich `.claude/audit/` an separates Ziel pushen (separates GitHub-Repo, nur read-write von User). Cron Sonntag 04:00.
- [ ] **acceptance:**
  - Mock-Backup-Ziel → push erfolgt.
  - Failure (Ziel offline) → Notification, kein Daten-Verlust.
- [ ] **verify:** `.claude/scripts/verify/audit-offsite-backup.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P0-4.

---

### Phase 4 — Inbox-Migration, Hard-Switch, Akzeptanz

#### Task P4-0 — Inbox-Pfad-Migration [ADDED post-committee — Mitigation 8]

- [ ] **Beschreibung:** Migrations-Skript `.claude/scripts/migrate-inbox.sh`: merged `.claude/overseer/inbox/` und `.claude/backlog/inbox/`. Neuer einheitlicher Pfad: `.claude/backlog/inbox/`. Overseer-Picker auf neuen Pfad umkonfigurieren. Alter Headless-Loop muss vorher deaktiviert sein (P4-1).
- [ ] **acceptance:**
  - Beide Inboxen leer vor Migration (Acceptance-Gate).
  - Skript merged Konfig-Pfad.
  - Post-Migration läuft Overseer auf `.claude/backlog/inbox/`.
- [ ] **verify:** `.claude/scripts/verify/inbox-migration.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P3-1 bis P3-13 grün.

#### Task P4-1 — Alten Headless-LaunchAgent deaktivieren

- [ ] **Beschreibung:** `bash .claude/scripts/uninstall-headless.sh`. Skript bleibt im Repo als Fallback.
- [ ] **acceptance:**
  - `launchctl list | grep headless` → leer.
  - `launchctl list | grep overseer` → vorhanden.
  - CLAUDE.md Hinweis ergänzt.
- [ ] **verify:** `.claude/scripts/verify/launchagent-state.sh`
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P4-0.

#### Task P4-2 — Branch-Protection Setup als HARD-PREREQ [ADDED post-committee — Mitigation 10]

- [ ] **Beschreibung:** Mensch-im-Loop: `bash .claude/scripts/setup-branch-protection.sh` mit Required Status Checks (flutter-analyze, flutter-test, security-reviewer != block, Self-Mod-Check). HARD-PREREQ vor jedem Auto-Merge in Phase 4.
- [ ] **acceptance:**
  - GitHub-Branch-Protection auf `main` aktiv.
  - Required Status Checks alle vier sichtbar.
  - User bestätigt manuell + Audit-Eintrag.
- [ ] **verify:** Manuelle Überprüfung via `gh api`-Call (in `.claude/scripts/verify/branch-protection.sh`).
- [ ] **agent:** `general-purpose`
- [ ] **depends:** P4-1.

#### Task P4-3 — Doku-Update + Handbook-Sync

- [ ] **Beschreibung:** CLAUDE.md neue Sektion „Autonomous Council Swarm" mit Architektur-Diagramm. `docs/handbook/05-architecture.md`. `update-docs --apply`.
- [ ] **acceptance:**
  - CLAUDE.md mit allen Daemon-Typen, Mensch-im-Loop-Stops.
  - Handbook verlinkt.
  - `/update-docs --strict` exit 0.
- [ ] **verify:** `smoke-help`
- [ ] **agent:** `doc-updater`
- [ ] **depends:** P4-2.

---

### Phase-4-Akzeptanz-Gates (Mitigation 22, NICHT als Tasks — separate Sektion) [ADDED post-committee — Empfehlung n]

> P4-3 (7-Tage-Wartezeit) ist KEIN PR-Task, sondern Akzeptanz-Gate.

**Konvergenz-Definition (Mitigation 22):** Autonomer Lauf endet nach **7 Tagen ODER nach 48h ohne neue Stakeholder-Items** (was zuerst eintritt).

**Gestaffelte Schwellen:**

1. **Gate 4-A (48h):** Keine Crashes, keine PANIC. ≥ 50% Items als `done`. Disk-Frei > 30%. Cost-Cap nicht überschritten. Briefing täglich. Stakeholder-Items binnen 4h triagiert. Cloud-Heartbeat alle 4h. **Telegram-Bridge funktioniert (Mitigation 11).**
2. **Gate 4-B (72h):** Wie 4-A + ≥ 1 Disput erfolgreich (auch `unresolved/`-Eskalation zählt als „erfolgreich gelaufen"). Auto-Recovery ≥ 1× erfolgreich. Self-Mod-Blocklist hat 0 Hits (oder bei Hits korrekt blockiert + alarmiert).
3. **Gate 4-C (7d ODER 48h-no-stakeholder):** Wie 4-B + ≥ 5 Analyzer-Items + Wochen-Digest am Tag 7 + Off-Site-Audit-Backup ≥ 1× durchgelaufen.

**Bei Failure auf einem Gate:** Item-Audit + Plan-Rückführung → neuer Backlog-Item für Fix, Akzeptanz-Lauf neu starten.

---

## Begründungs-Block

- **Worktree statt Container/VM**: Disk-Cost < Container-Setup-Komplexität auf macOS. Mit Mitigation-6-Realismus (Hard-Cap N=3, 30% / 20 GB) ist es tragbar.
- **Filesystem-Backlog statt Redis/SQLite**: alles git-versioniert. Phase 1-3 separater Pfad, Phase-4-Migration explizit (Mitigation 8).
- **3-Agent-Disput statt 5**: Cost-Halving. Pragmatist nur Tie-Break (Mitigation 17).
- **LaunchAgent + Cloud-Heartbeat**: macOS-native + Off-Box-Watchdog (Mitigation 21) gegen LaunchAgent-Death.
- **Kein Web-Dashboard**: Audit-Files + ntfy + Telegram reicht.
- **Hard-Cost-Cap**: $5/Tag pro Worker, $20/Tag Disput-Sum, plus Out-of-Process Anthropic-Admin-API-Limit (Mitigation 4).
- **Modell-Routing**: Stakeholder-Triage = **Opus** (Empfehlung d, Adversarial-Boundary). Disput-Agents = Opus. Worker = **Sonnet Default** (Mitigation 3). Analyzer = pure Bash + bestehende Skripte.
- **Subscription-Survivability**: nur `claude --print`, keine Wrapper.

---

## Phasen-Deliverables (Zusammenfassung, post-committee)

| Phase | Deliverable | Wall-Clock |
|---|---|---|
| 0 | P0-0 Self-Mod-Blocklist, Whitelist+Self-Mod-Reject, Cost-Cap (split), Worktree (gwq), Audit (Hash-Chain), Watchdog, OAuth, **`notify.sh`** | 2-3 Tage |
| 1 | Single-Worker-Overseer (separater Inbox-Pfad), Worker-Wrapper mit Pre-Ship-Pflicht, LaunchAgent, Atomic-Picker mit `touches`-Lock | 1-2 Tage |
| 2 | Pool N=2 (Cap N=3), `btw.sh` Tier-1, **Telegram-Bot Tier-2**, Triage (Opus) + Validator, 3 Analyzer-Module | 3-4 Tage |
| 3 | Disput-Council (Tie-Break-Pragmatist), 7 Analyzer-Module (atomar), Cleanup, Panic, Briefing+Digest, Cost-Tamper-Schutz, Auto-Rebase-Retry, **Cloud-Heartbeat**, **Off-Site-Audit-Backup** | 4-5 Tage |
| 4 | Inbox-Migration, Hard-Switch, **Branch-Protection HARD-PREREQ**, Doku, gestaffelte Akzeptanz | 2 Tage Code + 7d Akzeptanz |

---

## Mensch-im-Loop-Punkte (alphabetisch)

1. Anthropic-API-Quota-Erhöhung.
2. **Anthropic Admin-API Konto-Budget-Setting (Out-of-Process Hard-Limit, Mitigation 4).**
3. Branch-Protection-Setup mit Required Status Checks (Mitigation 10, HARD-PREREQ Phase 4).
4. Cost-Cap-Anhebung bei Hard-Stop.
5. OAuth-Erst-Login.
6. Panic-Resume.
7. Pricing/Billing-Promo zu Prod.
8. Secrets-Rotation.
9. Stakeholder-Disput-Override (`btw "override <id>: ..."`).
10. **Stakeholder `--admin`-Merge-Override** (`btw "merge PR #X --admin"`, Mitigation 10).
11. `supabase db push` gegen Prod.
12. Telegram-Bot-Setup (User-ID-Allowlist initial).
13. Worktree-Pfad-Erstgenehmigung.

---

## Open Questions (post-committee, restlich offen)

1. Renovate als Drittanbieter-App vs. eigene `pub outdated`-Wrapper — Empfehlung: Renovate, aber Setup-Cost prüfen.
2. Cloud-Heartbeat: Supabase-Edge-Function vs. GitHub-Actions-Cron — beide OK, Entscheidung beim Implementer.
3. `Stop`-Hook + `TeammateIdle`-Hook (External-Scout): native Anthropic Claude Code Hooks für Self-Verify-Loop nutzen, oder eigenes Custom?

---

## Committee-mitigations applied (2026-05-09)

5-Reviewer-Committee (Architekt ⚠️, Bug-Hunter 4× KRITISCH, External-Scout HYBRID, Security BLOCK, UX/Mobile 🔴) hat 23 Pflicht-Änderungen + 15 Empfehlungen geliefert. Alle eingearbeitet:

1. **P0-0 Self-Mod-Blocklist** als kritischste Änderung vor allem anderen — schützt `guard-bash.sh`, `cost-cap.sh`, `auto-merge-pr.sh`, `auto-commit.sh`, Overseer/Worker/Watchdog/Recover-Skripte, Disput- und Stakeholder-Agents, `.claude/settings*.json`, `CLAUDE.md`, LaunchAgent-Plists. Out-of-Process Integrity-Check als separater LaunchAgent.
2. **`auto-commit.sh` Self-Mod-Reject** unter `HEADLESS_MODE=1` (P0-1).
3. **Worker-`budget_usd` als required-field**, Default-Modell Sonnet (P1-2).
4. **Out-of-Process Anthropic Admin-API Konto-Budget-Setting** als Pflicht-Setup (P0-2b, Mensch-im-Loop).
5. **Disput-Cost-Cap auf $10/Disput, $20/Tag** (P3-2).
6. **Worktree-Disk-Realität dokumentiert** (3/5/12 GB), Default N=2/Hard-Cap N=3, 30% / 20 GB Threshold (P0-3).
7. **Symlink-Strategie für gitignored Secrets** + Post-Init-`flutter analyze`+`smoke-login` (P0-3).
8. **Separater Inbox-Pfad `.claude/overseer/inbox/`** für Phase 1-3, Phase-4-Migrations-Skript P4-0.
9. **Auto-Rebase-Retry P3-11**, `[merge-conflict]`-Marker statt `failed/`.
10. **`--admin` aus Headless/Overseer-Pfad entfernt**, Required Status Checks, Stakeholder-Override (P3-11, P4-2).
11. **Telegram-Bot-Adapter Tier-2 P2-2b** als Pflicht-Task (statt nicht-existenter ntfy-Reply); ntfy-Action-Buttons als sekundärer Kanal.
12. **`notify.sh` P0-7** mit Severity-Routing, Quiet-Hours, Dedup, Action-Buttons-Helper. Pflicht für alle Daemons.
13. **Stakeholder Trust-Tiers + HMAC-Auth** (Tier-1/2/3) + Validator-Agent P2-3b mit Schema-Regex.
14. **`source: <tier>` Frontmatter-Pflichtfeld** + Item-Priority-Prefix `01-stakeholder-`. Migration/RLS bei tier-3 immer Disput-pflichtig.
15. **Pre-Ship-Pflicht erweitert** im Worker-Lifecycle (`smoke-full-app-audit` + `check-l10n.py`, `[blocked-pre-ship]`-Marker).
16. **B4 Code-Quality-Reviewer NICHT gestrichen**, bleibt als Pre-Ship-warn-only-Hook neben Continuous-Analyzer (P1-2).
17. **Pragmatist nur Tie-Break ab Runde 2**, bei Patt nach Runde 3 → `disputes/unresolved/` + Stakeholder-Eskalation (KEIN Auto-Reject). Pragmatist erhält WebSearch.
18. **P3-4 in 7 atomare Subtasks gesplittet** (P3-4a bis P3-4g).
19. **Audit-Append-Only-Schutz** (`chmod 0444` + `flock`), Hash-Chain, Off-Site-Backup P3-13, `audit-record.sh` in Self-Mod-Blocklist.
20. **Per-File-Soft-Lock** im Picker (`touches:`-Frontmatter Pflicht).
21. **Cloud-Heartbeat P3-12** (Supabase Edge Function ODER GitHub-Actions-Cron).
22. **Konvergenz-Definition** explizit: 7d ODER 48h-no-stakeholder. Gestaffelte Akzeptanz-Gates 4-A/4-B/4-C.
23. **`last_fix_attempt`-Counter pro Analyzer-Modul** mit semantic-Subject (Hash auf `(file_path, modul_name)`, NICHT file+line). Nach 3 Versuchen 7d Pause + Stakeholder-Notify.

**Empfehlungen eingearbeitet (nicht-blockierend):** `gwq` als P0-3-Wrapper (a), `agent-orchestrator`-Pattern (a), Renovate für `scan-dependency-rot` (a), Anthropic-Subscription-Constraint dokumentiert (b), Built-in-Worktree Phase-0-Verify (c), Triage-Modell Opus (d), Token-Health-Probe (e), `audit-grep.sh` (h), LaunchAgent-Settings `RunAtLoad=false`+`ThrottleInterval=10` (i), Disk-Cleanup Worktree-Remove (j), Triage-Output-Validator (k), Worker-Env-Minimal-Rights (l), ntfy-Action-Buttons-Helper (m), Phase-4-Akzeptanz-Gate aus Tasks-Liste rausgezogen (n), P0-2 Split (o). Optional offen: `.claude/whitelist.txt` Single-Source-of-Truth (f), Wochen-Digest umgesetzt als P3-9.5 (g), `Stop`/`TeammateIdle`-Hooks als Open Question.

---

## Dependency-Graph + Phasen-Reihenfolge (post-committee)

```
Phase 0 (Foundation, kritischer Pfad zuerst):
  P0-0 (Self-Mod-Blocklist) ← VOR ALLEM ANDEREN
    ↓
  P0-1 (Whitelist + Self-Mod-Reject)
    ↓
  P0-2a (Cost-Ledger-Append) → P0-2b (Aggregation + Admin-API-Setup)
  P0-3 (Worktree via gwq)         [parallel zu P0-2]
  P0-4 (Audit + Hash-Chain)       [parallel zu P0-2]
  P0-7 (notify.sh)                [parallel zu P0-2, depends P0-1+P0-4]
    ↓
  P0-5 (Watchdog) ← deps P0-2b, P0-3, P0-4, P0-7
  P0-6 (OAuth-Watch + Health-Probe) ← deps P0-4, P0-7

Phase 1:
  P1-4 (Atomic-Picker mit touches-Lock) ← deps P0-1
  P1-1 (Overseer separater Inbox-Pfad) ← deps P0-2b/3/4/5/7
    ↓
  P1-2 (Worker-Wrapper Pre-Ship-Pflicht) ← deps P1-1, P0-2a, P0-0
  P1-3 (LaunchAgent KeepAlive) ← deps P1-1, P1-2

Phase 2:
  P2-1 (Worker-Pool N=2/Cap=3) ← deps P1-1, P1-2, P0-3
  P2-2 (btw.sh Tier-1) ← deps P0-1, P0-7
    ↓
  P2-2b (Telegram-Bot Tier-2) ← deps P2-2, P0-7   [PFLICHT für Phase-4]
  P2-3 (Triage Opus) ← deps P2-2
    ↓
  P2-3b (Validator) ← deps P2-3
  P2-4 (Triage→Validator-Pipeline) ← deps P2-1, P2-3, P2-3b
  P2-5 (scan-tech-debt) ← deps P0-1, P0-4
  P2-6 (scan-l10n-drift) ← deps P2-5
  P2-7 (scan-failure-lessons) ← deps Vorgänger A2
  P2-8 (Analyzer-Daemon) ← deps P2-5/6/7, P0-5, P0-7

Phase 3:
  P3-1 (Disput-Subagents) ← deps Vorgänger A3
  P3-2 (Disput-Orchestrator $10/$20) ← deps P3-1, P0-7
  P3-3 (Trigger-Heuristik) ← deps P3-2
  P3-4a..g (7 Analyzer-Module atomar parallel) ← deps P2-8
  P3-5 (Auto-Recovery) ← deps P0-5, P1-4, P2-1
  P3-6 (Cleanup + Worktree-Remove) ← deps P0-3, P0-4
  P3-7 (Panic-Mode) ← deps P0-5, P1-1, P0-7
  P3-8 (Branch-Allowlist) ← deps P0-1
  P3-9 (Daily-Briefing) ← deps P0-4, P3-2, P0-7
  P3-9.5 (Wochen-Digest) ← deps P3-9
  P3-10 (Cost-Tamper-Schutz) ← deps P0-2b, P3-7
  P3-11 (Auto-Rebase-Retry) ← deps P3-7
  P3-12 (Cloud-Heartbeat) ← deps P3-7
  P3-13 (Off-Site-Audit-Backup) ← deps P0-4

Phase 4:
  P4-0 (Inbox-Migration) ← deps Phase-3-grün
  P4-1 (Headless-LaunchAgent off) ← deps P4-0
  P4-2 (Branch-Protection HARD-PREREQ) ← deps P4-1   [Mensch-im-Loop]
  P4-3 (Docs) ← deps P4-2

Akzeptanz-Gates (NICHT als Tasks):
  Gate 4-A (48h) → Gate 4-B (72h) → Gate 4-C (7d ODER 48h-no-stakeholder)
```
