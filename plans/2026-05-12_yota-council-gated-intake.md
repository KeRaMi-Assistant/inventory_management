# Yota Council-Gated Intake

**[Committee-Approved 2026-05-12]**

> Post-Phase-4-Add-On zu [`plans/2026-05-09_autonomous_council_swarm.md`](2026-05-09_autonomous_council_swarm.md).
> ERWEITERT den bestehenden `btw`/Triage/Validator-Pfad — ersetzt ihn NICHT.
> Tooling-Layer (`.claude/`-Scripts + Agents + Telegram-Bot). Keine Flutter-/Supabase-Änderungen.

---

## 0) Meta — Strukturanalyse des bestehenden Systems

Pflicht-Sektion gemäß User-Wunsch: „analysiere die jetzige Struktur für eine schlaue qualitative Arbeit". Diese Analyse begründet, warum das Intake-Council-Feature überhaupt nötig ist und an welcher Stelle es eingreift.

### 0.1 Was läuft heute konkret gut (nur belegbare Stärken)

- **Sandwich-Marker-Disziplin durchgehend.** `btw.sh` rejected Sentinel-Strings hart (exit 2), `stakeholder-triage` und `stakeholder-validator` haben einen klaren Untrusted-Block-Vertrag. Das ist der einzige Grund warum Tier-2 (Telegram) überhaupt sicher öffnen darf — bestätigt durch die drei dokumentierten Few-Shot-Examples in `.claude/agents/stakeholder-triage.md`.
- **Validator als Schema-Wall vor Overseer-Inbox.** Pfad-Blacklist (`.env`, `lib/config/supabase_config.dart`, `~/Library/`) und Regex-Pattern-Liste (`git rm -rf`, `drop table`, …) sind eine harte zweite Stufe, die LLM-Halluzinationen abfängt bevor sie in `overseer/inbox/` ankommen. Test-Mode pro Pipeline (`triage-stakeholder.sh`) erlaubt isolierte Re-Runs.
- **Cost-Caps explizit, nicht implizit.** `TRIAGE_BUDGET=0.50`, `VALIDATOR_BUDGET=0.20`, `disput.sh`-Pro-Disput-Cap `$10`, Tagescap `$20`. Jeder neuer Pfad MUSS sich an dieses Schema halten (siehe Cost-Sektion unten).
- **Disput-Council existiert + ist getestet.** Proponent / Skeptic / Pragmatist mit 3-Runden-Cap, Tie-Break-Regel, Mock-`claude`-Stub-Pattern in den Tests. Re-Use spart 60-80% der Implementations-Arbeit für das Intake-Council.
- **Yota als read-only Companion etabliert.** Tool-Whitelist (kein `gh pr merge`, kein `git push`), `yota-snapshot.sh` als Single-Source-of-Truth, HMAC-Token-Rotation pro Briefing in `telegram-bot.py`. Wir haben das Vertrauens-Modell schon, müssen es nur erweitern.
- **Audit-Trail in `lib/audit.sh` durchgängig.** Jeder relevante Schritt (btw_received, triage_started, triage_quarantined, validator_pass, …) hat einen Audit-Record. Das macht Post-mortem auf Bug-Reports machbar.

### 0.2 Wo bremst die Architektur Qualität (konkret, mit Beleg)

| # | Bottleneck | Beleg | Wirkung |
|---|---|---|---|
| Q1 | **Triage geht zu schnell von Idee → Backlog.** `stakeholder-triage.md` klassifiziert nur `feature-request \| bugfix \| question \| injection-attempt`. Kein ROI-Check, keine Doppelt-zu-Backlog-Suche, keine Pre-Launch-Kompatibilitäts-Bewertung. | Few-Shot-Example 1 macht aus „CSV-Export" sofort ein Backlog-Item mit Budget `$8` ohne Prüfung ob Inventar-Screen das Feature heute überhaupt braucht. | False-Positive-Backlog-Items. Worker baut Features, die Pre-Launch keinen Value liefern → Kosten + Maintenance ohne Nutzen. |
| Q2 | **`needs_dispute`-Heuristik ist false-negative-anfällig.** Worker pickt Items ohne Disput, wenn das Frontmatter-Flag nicht gesetzt wurde. Die Triage setzt das Flag heute nicht. | `stakeholder-triage.md` Few-Shot-Output enthält kein `needs_dispute`-Feld. Backlog-Item geht direkt zum Worker. | Strittige Features (z. B. Theme-Drift, Mobile-First-Verstoß) werden ohne Disput-Sicherung gebaut → Re-Work. |
| Q3 | **Kein User-im-Loop zwischen „Idee gehabt" und „PR auf main".** `/btw` → triaged → overseer/inbox → worker → PR → auto-merge. User sieht das Ergebnis erst nachdem es gemergt ist. | `btw.sh` + `triage-stakeholder.sh` + `overseer.sh` + `worker.sh` haben keinen Approval-Step. | Spät-Entdeckung von „das ist nicht was ich meinte". Refactor-Kosten höher als wenn User vor dem Bauen Veto eingelegt hätte. |
| Q4 | **Volles 5-Reviewer-Council (`.claude/commands/council.md`) ist zu teuer für jeden btw.** Disput-Council ($10/Run) ist auf strittige Entscheidungen kalibriert, nicht auf täglich-mehrere Intake-Filterungen. | `disput.sh` hat `DISPUT_CAP=10`. Bei 5 `btw`/Tag = $50 — überschreitet `DISPUT_CAP_DAY=20`. | Kein bestehender Kostendeckel passt zum Intake-Use-Case → braucht eigenes Cost-Profil. |
| Q5 | **`btw` ist single-shot.** Kein Iterations-Pfad (Idee → Council-Vorschlag → User-Change-Request → erneuter Vorschlag). User muss bei Missverstehen komplett neu queuen. | `btw.sh` schreibt 1 File und ist fertig. Keine Reply-Logik. | Schlechtere Idee-zu-Item-Qualität. Items werden so wie sie reinkamen verarbeitet, auch wenn 5 Minuten Klarstellung sie um Welten besser gemacht hätten. |
| Q6 | **`yota` ist nur Beobachter.** Keine Hebel zum Eingreifen — User muss zum Terminal wechseln um zu intervenieren. | `.claude/agents/yota.md` Tool-Whitelist verbietet alles Schreibende. | Friction zwischen Insight (Yota) und Aktion (btw / approve / reject) — User-Engagement leidet. |

### 0.3 Welche Schritte würden Qualität substanziell heben

Abgeleitet aus Q1-Q6 als Prinzipien (NICHT als Tasks — Tasks weiter unten):

1. **Gate-vor-Backlog statt Auto-zu-Backlog.** Eine Intake-Beratung zwischen `btw` und `overseer/inbox/` bewertet ROI + Doppelung + Pre-Launch-Fit. User entscheidet final.
2. **Leichtgewichtiges Council, eigenes Cost-Profil.** Nicht der 5-Reviewer-Heavy-Council. 3-Agent-Mini-Council mit `$0.50-$0.80/Run` (Sonnet-Default für Bewertung, Opus nur für Tie-Break). Re-Use von Proponent (mit Intake-Mode-Flag) + dedicated `intake-skeptic.md` + dedicated `intake-pragmatist.md` (siehe Committee-Mitigation #4).
3. **User-Approval-Schritt mit klaren Optionen.** „Go" / „Reject" / „Change <text>". Change-Path triggert eine zweite Runde mit User-Korrektur als Zusatz-Kontext.
4. **Yota wird zum aktiven Vermittler.** Neue Yota-Commands (`/yota propose`, `/yota go`, `/yota reject`, `/yota change`) — die einzige schreibende Erweiterung, ABER scoped auf Approval-Queue, nicht auf Backlog/Code direkt.
5. **Beide Pfade behalten — aber `/yota propose` als Default.** `btw` bleibt der „power-user-fast-lane"-Pfad (User weiß was er will). `/yota propose` ist der neue Default. Siehe Committee-Mitigation #14.
6. **Stop-Loop-Mechanismus.** Wenn 5 Intake-Vorschläge in einem 48h-Fenster rejected werden → User-Notify „check deine Vorschläge, irgendwas ist off". Schützt vor LLM-Cost-Drift wenn User in einem Brainstorm-Modus steckt der nichts produziert.

---

## 1) Ziel

Ein **Council-gated Intake-Pfad** als neuer Default neben dem bestehenden `btw`-Direkt-Pfad (jetzt „power-user fast lane"): User schickt via Telegram `/yota propose <idee>` (oder CLI `bash .claude/scripts/yota-propose.sh "<idee>"`), ein kleines 3-Agent-Intake-Council (Proponent + dedicated Intake-Skeptic + dedicated Intake-Pragmatist) berät ROI + Pre-Launch-Fit + Doppelung, schreibt ein Verdict in eine Pending-Approval-Queue, User entscheidet via Telegram-Reply (`go <id> [<token>]` / `reject <id>` / `change <id> <text>`). Erst nach `go` wandert ein durch den **dedizierten `intake-validator`** validiertes Backlog-Item nach `.claude/overseer/inbox/`. Stop-Loops, Cost-Caps, Creator-Binding + HMAC-Token-Echo identisch / strenger als beim bestehenden Sicherheits-Modell.

---

## 2) Scope

### IST drin

- Neuer CLI-Pfad: `.claude/scripts/yota-propose.sh "<idee>"` (Tier-1, analog `btw.sh`).
- Neue Telegram-Commands: `/yota propose <idee>`, `/yota pending`, `/yota go <id> [<token>]`, `/yota reject <id> [<grund>]`, `/yota change <id> <text>`.
- Neuer Pfad in `.claude/stakeholder/pending-proposal/` (rohe User-Idee, vor Council).
- Neuer Pfad in `.claude/stakeholder/pending-approval/` (Council-Verdict, wartet auf User-Entscheidung).
- Neuer Pfad in `.claude/stakeholder/rejected/` (User-rejected, archiv).
- Neuer Orchestrator: `.claude/scripts/intake-council.sh` (3-Agent-Mini-Council).
- **Dedicated Intake-Agents** (Committee-Mitigation #4): `intake-skeptic.md`, `intake-pragmatist.md`. `disput-proponent` wird re-used mit Intake-Mode-Header.
- **Dedicated `intake-validator.md`** (Committee-Mitigation #1): eigener Schema-Validator-Agent für Council-Outputs (`created_from: intake-council`). NICHT in Self-Mod-Blocklist.
- Verdict-Writer-Step (deterministic-Bash + Synthese aus Round-1/2-Votes).
- Erweiterte `telegram-bot.py`: Reply-Verarbeitung für `go` / `reject` / `change` mit Creator-Binding + HMAC-Token-Echo + ID-Regex-Strict-Validation + ID-Disambiguation bei Slug-Prefix-Match.
- **Verdict-Push als Bot-Filesystem-Watcher** (Committee-Mitigation #6): Bot pollt `pending-approval/*.md` mit `pushed_at`-Marker, idempotenter Push.
- Cost-Caps: `INTAKE_CAP_PER_PROPOSAL=2.00` (lifetime, deckt Change-Runden), `INTAKE_CAP_PER_DAY=10.00`, `INTAKE_REJECT_STREAK_THRESHOLD=5` (48h-Fenster).
- Re-Use `stakeholder-validator` NICHT — neuer Validator-Pfad via `intake-validator` (Mitigation #1).
- Audit-Records für alle neuen Events (`intake_proposed`, `intake_council_started`, `intake_verdict_written`, `intake_user_go`, `intake_user_reject`, `intake_user_change`, `intake_rejected_streak_alarm`, `intake_round_advanced`, `intake_go_wrong_user`, `intake_id_invalid`, `intake_token_mismatch`, `intake_self_mod_blocked`, `intake_council_crashed`, `intake_resumed`).
- Doku-Update: `CLAUDE.md` § Autonomous Council Swarm bekommt einen Sub-Abschnitt „Intake-Council" mit `/yota propose` als Default-Pfad.

### NICHT drin

- Kein Flutter/Supabase. Tooling-Layer only.
- Kein neuer Persistenz-Layer (alles File-basiert in `.claude/stakeholder/`).
- Kein Ersatz für `btw.sh` — bleibt als Power-User-Fast-Lane.
- Kein neuer 5-Reviewer-Full-Council für Intake. Voller Council bleibt auf strittige Architektur-Entscheidungen beschränkt — wird aber von `intake-validator` getriggert wenn Council Self-Mod-Pfade berühren will (Mitigation #2).
- Keine Auto-Approval nach Timeout. Stale-Items werden nach 7 Tagen markiert (`pending-approval/stale/`), aber nicht auto-rejected oder auto-approved.
- Kein Telegram-Inline-Button-UI (nur Text-Reply). Begründung im Begründungs-Block 11.B.
- Keine Cross-User-Approvals. Wer `propose` triggert, ist der einzige der `go`/`reject`/`change` darf (Creator-Binding via `from.id == frontmatter.user_id`, Committee-Mitigation #3).

---

## 3) Datenmodell + RLS

**n/a** — Tooling-Layer. Kein Supabase-Schema, keine RLS-Policy. Alle State-Files unter `.claude/stakeholder/`.

**File-Schemas (deterministisch validierbar):**

### 3.1 `pending-proposal/<id>.md` (rohe User-Idee)

```yaml
---
id: <ISO-Timestamp>-<slug>             # Regex: ^[0-9]{8}-[0-9]{6}-[a-z0-9-]{1,40}$
source: tier-1 | tier-2
trust_tier: 1 | 2
user_id: <telegram-user-id-or-local>
created_at: <ISO-UTC>
state: pending-proposal
round: 1                                # MAX_INTAKE_ROUNDS=3 (Mitigation, R5)
content_hash: <sha256>                  # gegen Spam-Dedup
---

<<<UNTRUSTED_STAKEHOLDER_INPUT tier=N>>>
<user-idee>
<<<END_UNTRUSTED_STAKEHOLDER_INPUT>>>
```

### 3.2 `pending-approval/<id>.md` (Council-Verdict)

```yaml
---
id: <gleicher-id-wie-proposal>
source: tier-1 | tier-2
trust_tier: 1 | 2
user_id: <user-id>                      # Creator-Binding (Mitigation #3)
created_at: <ISO-UTC>
council_finished_at: <ISO-UTC>
state: pending-approval
verdict: propose | propose-with-changes | reject | needs-full-council
round: 1 | 2 | 3
council_cost_usd: <float>
hmac_token: <sha256-hex>                # rotiert pro proposal — Echo-Pflicht (Mitigation #3)
pushed_at: <iso-or-empty>               # Bot-Watcher-Marker (Mitigation #6)
requires_human_dispute: true | false    # gesetzt wenn touches: Self-Mod-Pfad trifft (Mitigation #2)
touches: [<pfade>]                      # vom Council vorgeschlagene Pfade
created_from: intake-council            # → intake-validator (NICHT stakeholder-validator!)
---

## Verdict-Summary

[1-3 Sätze Council-Begründung]

## Vorgeschlagenes Backlog-Item

[Vollständiger Markdown-Block. Validator-fähig: enthält slug:, source:, priority:, budget_usd:,
 model:, touches:, created_from: intake-council.]

## Council-Begründung (Long)

### Proponent-Vote
[content]

### Skeptic-Vote (intake-skeptic)
[content]

### Pragmatist-Tie-Break (intake-pragmatist, nur wenn Patt)
[content]

## Stakeholder-Original

<<<UNTRUSTED_STAKEHOLDER_INPUT>>>
<user-idee unverändert, sentinel-stripped (Round-1-LLM-Output-Sanitize)>
<<<END_UNTRUSTED_STAKEHOLDER_INPUT>>>
```

### 3.3 `rejected/<id>.md` (nach User-Reject)

```yaml
---
id: <id>
state: rejected
rejected_by: user
rejected_at: <ISO-UTC>
user_reason: <text-oder-leer>
council_verdict_was: propose | propose-with-changes | reject | needs-full-council
---

[Full snapshot des pending-approval-Files für Audit.]
```

### 3.4 `pending-approval/<id>.superseded.md` (Round-Advance-Atomic-Move, Mitigation #5)

Vor jedem `change <id> <text>` wird das Live-File atomic via `mv` umbenannt zu `.superseded.md`. `go`-Handler findet nur Live-Pfade. Verhindert Race zwischen `change` und `go` (Bug-Hunter #3).

---

## 4) API / Edge Functions

**n/a** — keine Supabase Edge Functions. Alle Logik in `.claude/scripts/` und `.claude/agents/`.

---

## 5) UI + l10n-Keys

**n/a** — Kein Flutter-UI. User-Interface ist CLI (`yota-propose.sh`) + Telegram-Chat.

**Telegram-Strings** (Deutsch, in `telegram-bot.py` als String-Konstanten, NICHT in `lib/l10n/`):

- `intake_proposal_queued` — „Vorschlag erhalten. Council berät jetzt (~$0.50-0.80, dauert 1-3 min). Du bekommst eine Nachricht sobald das Verdict da ist."
- **`intake_verdict_propose`** (Mini-Format, Mitigation #10) — `✅ {slug}\n{1-satz-begründung}\n→ go {id} {token} · reject {id} · change {id} <text>\n💰 ${day_cost} heute`
- **`intake_verdict_changes`** — `✏️ {slug}\n{1-satz-begründung}\n→ go {id} {token} · reject {id} · change {id} <text>\n💰 ${day_cost} heute`
- **`intake_verdict_reject`** — `❌ {slug}\n{1-satz-begründung}\n→ trotzdem: go-anyway {id} {token} <reason> · reject {id} (close)\n💰 ${day_cost} heute`
- `intake_verdict_needs_council` — „⚠ Vorschlag berührt Self-Mod-Pfad ({touches}). Vollständiges Council nötig: starte `/council {id}` manuell."
- `intake_go_accepted` — „Item nach overseer/inbox/ weitergegeben. Worker pickt es im nächsten Tick."
- `intake_pending_disambiguate` — „Mehrere offen, welches?\n1. {slug1} (vor {age1}h)\n2. {slug2} (vor {age2}h)\n→ antworte mit Ziffer (60s)"
- `intake_rejected_streak` — „⚠ 5 Vorschläge in 48h rejected. Check kurz deine Liste — eventuell brauchst du andere Granularität."
- `intake_cap_exceeded` — „Intake-Cap des Tages ($10) erreicht. Versuche es morgen wieder, oder nutze den Power-User-Pfad `/btw` wenn du sicher bist."
- `intake_id_invalid` — „Ungültige ID-Form. Erwartet: `YYYYMMDD-HHMMSS-<slug>` oder Listen-Index."
- `intake_round_limit_reached` — „Item hat 3 Runden erreicht — bitte mit `go` oder `reject` schließen, dann neu vorschlagen."
- `intake_yota_intro_once` — (Onboarding-Hinweis bei erstem `/btw` nach Roll-out, Mitigation #14) „Tipp: `/yota propose <idee>` lässt das Council ROI + Fit + Doppelung prüfen bevor das Item in den Worker geht. `/btw` bleibt der Power-User-Pfad."

**Routing:** Alle Verdict-Pushes laufen durch `notify.sh info intake-verdict ...` (Quiet-Hours-respektierend, Mitigation #11). `intake_cap_exceeded` / `intake_rejected_streak` / `intake_council_crashed` laufen als `notify.sh critical ...` (bypass).

---

## 6) Tests

### 6.1 Mock-`claude`-Stub-Pattern

Analog zum bestehenden P2-4-Test in `test/scripts/stakeholder_flow_test.sh`: PATH-prepended Stub, der je nach Argument deterministisch einen Output schreibt.

### 6.2 Test-Liste

| # | Test | Pfad | Pflicht |
|---|---|---|---|
| T1 | `yota-propose.sh` schreibt korrektes Frontmatter + Sentinel-Reject + ID-Regex-Validation | `test/scripts/yota_propose_test.sh` | Ja |
| T2 | `intake-council.sh` happy-path: Mock-Proponent + Mock-Intake-Skeptic → `propose`-Verdict | `test/scripts/intake_council_happy_test.sh` | Ja |
| T3 | `intake-council.sh` patt-path: Round 1 Patt → Intake-Pragmatist getriggert → Verdict | `test/scripts/intake_council_tiebreak_test.sh` | Ja |
| T4 | `intake-council.sh` cost-cap-per-proposal: 3 Calls × $1 → 4. Call blockiert | `test/scripts/intake_council_cap_test.sh` | Ja |
| T5 | `intake-council.sh` cost-cap-per-day: Tagescap $10 erreicht → exit 2 + notify | `test/scripts/intake_council_daycap_test.sh` | Ja |
| T6 | `telegram-bot.py` parsed `/yota propose <text>` → schreibt nach `pending-proposal/` + scheduled Council-Job | `test/scripts/telegram_yota_propose_test.sh` | Ja |
| T7 | `telegram-bot.py` parsed `go <id> <token>` korrekt + allowlist + creator-binding + token-echo greifen + alle 3 Auth-Checks | `test/scripts/telegram_go_reject_test.sh` | Ja |
| T8 | `telegram-bot.py` parsed `change <id> <text>` → atomic-mv zu `.superseded.md` + zweite Runde, NICHT direkt nach overseer | `test/scripts/telegram_change_test.sh` | Ja |
| T9 | `go`-Flow: pending-approval → `intake-validator` → overseer/inbox/ (mocked) | `test/scripts/intake_go_to_overseer_test.sh` | Ja |
| T10 | Reject-Streak (48h-Fenster): 5 Rejects in 48h → Notify | `test/scripts/intake_reject_streak_test.sh` | Ja |
| T11 | HMAC-Replay: alter Token aus pending-approval/<id> nach `rejected/<id>` darf nicht erneut `go` triggern | `test/scripts/intake_hmac_replay_test.sh` | Ja |
| T12 | Sandwich-Marker-Escape im User-Vorschlag → `pending-proposal`-Write rejected analog `btw.sh` | `test/scripts/yota_propose_sentinel_reject_test.sh` | Ja |
| T13 | Pending-Approval-Stale: File älter als 7d wird in `pending-approval/stale/` verschoben, KEIN Auto-Reject | `test/scripts/intake_stale_test.sh` | Ja |
| T14 | `/yota pending` listet offene Approvals des User korrekt | `test/scripts/telegram_yota_pending_test.sh` | Ja |
| T15 | **Self-Mod-Block:** Council schlägt `touches: [.claude/scripts/]` vor → `intake-validator` setzt `verdict: needs-full-council` + `requires_human_dispute: true` | `test/scripts/intake_self_mod_block_test.sh` | Ja |
| T16 | **Verdict-Push-Watcher:** Bot pollt `pending-approval/`, idempotent (kein Doppel-Push bei Restart) | `test/scripts/telegram_verdict_watcher_test.sh` | Ja |
| T17 | **ID-Disambiguation:** N>1 pending → numbered-list reply, 60s-Wartezeit auf Ziffer | `test/scripts/telegram_id_disambig_test.sh` | Ja |
| T18 | **Wrong-User silent-ignore:** `from.id != frontmatter.user_id` → kein State-Change + audit | `test/scripts/intake_wrong_user_test.sh` | Ja |
| T19 | **ID-Regex-Strict:** ungültige ID-Form → reply `intake_id_invalid` + audit | `test/scripts/intake_id_regex_test.sh` | Ja |
| T20 | **ANTHROPIC_API_KEY Pre-Flight:** wenn env-var gesetzt → `intake-council.sh` exit 1 mit Klartext | `test/scripts/intake_api_key_preflight_test.sh` | Ja |
| T21 | **Reply-Parser-Regex-Tabelle:** alle DE/EN-Aliase (`go`/`👍`/`ok`/`ja`/`approve`, `reject`/`nein`/`nö`/`stop`, `change`/`ändere`/`aber`) matchen | `test/scripts/telegram_reply_aliases_test.sh` | Ja |

Coverage-Ziel: Alle 21 Tests grün lokal + in CI. Integration-Smoke-Run: 1× End-to-End mit echtem `claude --print` (manuell, nicht in CI — kostet Geld).

---

## 7) Risiken

R1 — **LLM-Cost-Drift bei häufigen Vorschlägen.** User in „Brainstorm"-Modus → 20 Vorschläge/h → täglicher Cap reicht nicht. *Mitigation:* Per-User-Hourly-Cap (`5 proposals/h`, analog `RATE_LIMIT_MAX` für `/btw`) + Reject-Streak-Alarm bei 5 in 48h. *Restrisiko:* User kann den Cap nicht erhöhen ohne Code-Edit.

R2 — **Council-Verdict ist selbst LLM-generierter Markdown — Injection-Surface.** Der Verdict-File enthält den `## Vorgeschlagenes Backlog-Item`-Block, der nach User-`go` durch Validator läuft. *Mitigation:* Pflicht-Run von **`intake-validator`** (NICHT `stakeholder-validator` — siehe Mitigation #1) auf den Backlog-Item-Block VOR der Übergabe an Overseer. Self-Mod-Pfad-Match → `verdict: needs-full-council` (Mitigation #2). Round-1-LLM-Output wird sentinel-stripped bevor er in Round-2-Context geht.

R3 — **User-ID-Spoofing bei Telegram-Replies.** Wenn `change`-Reply nicht an einen Thread gebunden ist, könnte ein anderer Allowlist-User fremde Approvals bewegen. *Mitigation:* Drei-Schicht-Auth (Mitigation #3): (a) Allowlist-Check, (b) `from.id == pending_approval.user_id` strict-match (Creator-Binding), (c) HMAC-Token-Echo Pflicht im User-Reply oder via `reply_to_message_id`. Mismatch → silent ignore + audit `intake_go_wrong_user` / `intake_token_mismatch`.

R4 — **HMAC-Token-Replay.** User cancelt mit `reject`, später feuert er versehentlich `go <id>` mit altem Token. *Mitigation:* Token pro Proposal generiert. State-File-Existenz im Live-Pfad ist die Quelle der Wahrheit; `rejected/<id>.md` oder `.superseded.md` invalidiert.

R5 — **Round-2-Change-Eskalation: User schickt `change` 10× nacheinander.** Council-Kosten explodieren. *Mitigation:* Hard-Cap `MAX_INTAKE_ROUNDS=3` per `id` via Frontmatter-`round`-Counter. 4. `change` → Reply `intake_round_limit_reached`, kein neuer Council-Run.

R6 — **Pragmatist-Tie-Break passt nicht zum Intake-Frame.** *Mitigation:* **Dedicated `intake-pragmatist.md` von Anfang an** (Committee-Mitigation #4). Disput-Pragmatist wird im Intake-Pfad NICHT verwendet. Pre-Merge-Eval N=25 (Mitigation #16) misst Match-Rate.

R7 — **Pending-Approval-Queue füllt sich, User reagiert nicht.** Council-Kosten waren umsonst. *Mitigation:* Stale-Move nach 7d in `pending-approval/stale/`. Kein Auto-Reject. Telegram-Stale-Reminder optional.

R8 — **Telegram-Bot-Concurrency: zwei parallel reinkommende `propose` blockieren sich.** *Mitigation:* Pro Council-Run In-Flight-Lock-File analog `yota_inflight_acquire`. Mehrere parallele Councils OK, aber max 1 pro `user_id` gleichzeitig.

R9 — **Direkter `btw`-Pfad bleibt offen, User vergisst den Council-Pfad.** *Mitigation:* `/yota propose` ist neuer Default (Committee-Mitigation #14). Onboarding-Hinweis bei erstem `/btw` nach Roll-out (State-File `~/.claude/state/yota-intake-introduced-{user_id}`). `/help` empfiehlt `/yota propose` zuerst. Erfolg gemessen an Council-Pfad-Anteil ≥ 70% nach 2 Wochen.

R10 — **`change <text>` mit Sandwich-Marker-Escape im `<text>`.** *Mitigation:* `change`-Handler ruft `_sentinel_reject` aus `btw.sh`-Pattern auf, verwirft bei Match + audit. Token-Redactor läuft auf User-Input vor dem Write.

R11 — **Council-Output schlägt Self-Mod-Pfade vor.** *Mitigation:* `intake-validator` prüft `touches:` gegen DENY-Liste (Mitigation #2). Match → `verdict: needs-full-council`, User muss `/council` manuell triggern.

R12 — **`ANTHROPIC_API_KEY` env-var aktiv → Max-Plan-Drift zu API-Pay-per-Token.** *Mitigation:* Pre-Flight-Check in `intake-council.sh` (Mitigation #8). Exit 1 mit Klartext-Stderr wenn gesetzt.

R13 — **Pre-Merge-Eval N=5 ist statistisch zu schwach.** *Mitigation:* N=25 + Inter-Annotator-Agreement (Mitigation #16). Threshold 80% Match.

---

## 8) Datenfluss-Diagramm

```
                                          ┌─────────────────────────┐
                                          │ btw.sh (POWER-USER-PATH)│
                                          │ unchanged               │
                              ┌──────────►│ → stakeholder/inbox/    │
                              │           │ → triage → validator    │
                              │           │ → overseer/inbox/       │
                              │           └─────────────────────────┘
                              │
   User                       │
  /btw <idee>  ───────────────┘   (Power-User-Fast-Lane)
  /yota propose <idee>  ──────┐   (DEFAULT-PATH)
                              │
                              ▼
                   ┌──────────────────────────────────┐
                   │ yota-propose.sh   (or telegram)  │
                   │ • ID-Regex-Validation             │
                   │ • Slug-Regex strict (kebab≤40)    │
                   │ • Content-Hash-Dedup              │
                   │ • Token-Redactor auf User-Input   │
                   │ writes pending-proposal/<id>.md  │
                   └──────────────┬───────────────────┘
                                  │
                                  ▼
                   ┌──────────────────────────────────┐
                   │ intake-council.sh                │
                   │ • Pre-Flight: ANTHROPIC_API_KEY  │
                   │   absent? sonst exit 1            │
                   │ • Round 1: Proponent + Skeptic   │
                   │   (Sonnet, $0.20 ea)             │
                   │ • Patt? → Intake-Pragmatist      │
                   │   (Opus, $0.40)                  │
                   │ • Cost-Cap $2/proposal-lifetime  │
                   │   $10/day                        │
                   └──────────────┬───────────────────┘
                                  │
                                  ▼
                   ┌──────────────────────────────────┐
                   │ intake-validator (DEDICATED)     │
                   │ • Schema-Check (created_from:    │
                   │   intake-council)                │
                   │ • Self-Mod-Pfad-DENY-Scan        │
                   │   .claude/scripts/, agents/, ... │
                   │   → verdict: needs-full-council  │
                   │ • Slug/ID-Regex                  │
                   └──────────────┬───────────────────┘
                                  │
                                  ▼
                   ┌──────────────────────────────────┐
                   │ pending-approval/<id>.md         │
                   │ verdict: propose | -with-changes │
                   │          | reject | needs-full-c │
                   │ + HMAC-Token pro Proposal        │
                   │ + pushed_at: "" (Watcher-Marker) │
                   └──────────────┬───────────────────┘
                                  │
                          telegram-bot WATCHER pollt
                          pending-approval/, push wenn
                          pushed_at leer, dann setzen
                          (idempotent, Bot-Crash-Safe)
                                  │
                                  ▼
                       ┌──────────────────────┐
                       │ User-Reply:          │
                       │  go <id> [<token>]   │
                       │  reject <id> [grund] │
                       │  change <id> <text>  │
                       │  go-anyway <id>      │
                       │    <token> <reason>  │
                       │ ─────────────────────│
                       │ Auth: allowlist +    │
                       │  creator-binding +   │
                       │  token-echo          │
                       └─────┬───┬────────┬───┘
                             │   │        │
              ┌──────────────┘   │        └────────────────┐
              ▼                  ▼                         ▼
   ┌──────────────────┐  ┌───────────────┐   ┌──────────────────────┐
   │ go-handler:       │ │ reject:       │   │ change <text>:       │
   │  intake-validator │ │ atomic mv     │   │ atomic mv live-file  │
   │  pass?            │ │ → rejected/   │   │ → .superseded.md     │
   │  → overseer/inbox │ │ → audit       │   │ → pending-proposal/  │
   │  fail (Self-Mod)? │ │ → notify      │   │   <id>-r2.md         │
   │  → reply needs-   │ └───────────────┘   │ → intake-council.sh  │
   │     full-council  │                     │   (Round 2, MAX=3)   │
   └──────────────────┘                      └──────────────────────┘
```

---

## 9) Bestehende Agents — Re-Use vs. Neu

| Komponente | Re-Use | Neu | Begründung |
|---|---|---|---|
| `disput-proponent.md` | ✅ | — | Mit „Intake-Mode"-Frame im Proposal-File (Header-Block). Pro-Side-Frame passt für Proponent. |
| `disput-skeptic.md` | — | — | **NICHT verwendet.** Skeptic-Frame im Disput ist „relentlessly reject" — falscher Bias für Intake (Committee #4). |
| `intake-skeptic.md` | — | ✅ | **Dedicated** mit weicherem System-Prompt: „evaluate, don't relentlessly reject — flag concerns proportional to evidence" (Committee #4). Modell: Sonnet (Mitigation #13). |
| `disput-pragmatist.md` | — | — | **NICHT verwendet.** Disput-Tie-Break-Frame ist auf Implementation-Detail kalibriert, nicht auf Intake-ROI (Committee #4). |
| `intake-pragmatist.md` | — | ✅ | **Dedicated**, expliziter Intake-Frame: Pre-Launch-ROI, Doppelung, Mobile-First-Risiko, Theme-Drift-Risiko, Migration/RLS-Trigger. Modell: Opus (Tie-Break-Qualität wichtig). |
| `stakeholder-validator.md` | — | — | **NICHT verwendet im Intake-Pfad** (Committee #1) — Schema-Konflikt mit `created_from: intake-council`. |
| `intake-validator.md` | — | ✅ | **Dedicated Schema-Validator-Agent** für Council-Outputs. Tools: Read, Grep, Glob, Write. NICHT in Self-Mod-Blocklist. Prüft `touches:` gegen DENY-Liste (Mitigation #2). |
| `stakeholder-triage.md` | — | — | Im Council-Pfad nicht aufgerufen. Council ist der Ersatz. |
| `yota.md` | ✅ | (erweitert) | Neue lesende Sub-Commands `/yota pending`. Schreibende Commands (`go`/`reject`/`change`) leben in `telegram-bot.py` — Yota bleibt read-only. |
| `intake-council.sh` | — | ✅ | Neuer Orchestrator. Form-Vorlage: `disput.sh`. |
| `yota-propose.sh` | — | ✅ | Neue CLI, ~80% von `btw.sh` re-used. |
| `telegram-bot.py` | ✅ | (erweitert) | Neue Command-Handler + Verdict-Push-Watcher. |
| `.claude/scripts/lib/slug.sh` | — | ✅ | Helper-Lib für Slug-/ID-Regex (Mitigation #9), re-used aus `btw.sh._make_slug`. |
| `.claude/scripts/lib/disput-common.sh` | — | ✅ | Helper-Refactor (T18). |

---

## 10) Cost-Management

| Schalter | Default | Begründung |
|---|---|---|
| `INTAKE_CAP_PER_PROPOSAL` | `$2.00` (lifetime, deckt Change-Runden) | Sonnet-Proponent ($0.20) + Sonnet-Intake-Skeptic ($0.20) + optional Opus-Pragmatist ($0.40) = $0.40-$0.80/Round. 3 Runden möglich → $2.00 als Lifetime-Hard-Cap (Mitigation #13). |
| `INTAKE_CAP_PER_DAY` | `$10.00` | Bei 5 Proposals/Tag à durchschnittlich $0.60 = $3 — $10 lässt Headroom für Change-Runden ohne Brainstorm-Drift zu finanzieren (Mitigation #13). |
| `INTAKE_RATE_LIMIT_HOUR` | `5/h` per user | Übernahme von `RATE_LIMIT_MAX`. |
| `MAX_INTAKE_ROUNDS` | `3` | 1 initial + 2 Change-Iterationen. Frontmatter-`round`-Counter. |
| `INTAKE_REJECT_STREAK_THRESHOLD` | `5 / 48h` | 5 User-Rejects in 48h-Fenster → Notify (UX #4 verfeinert vom Committee). |
| `INTAKE_STALE_DAYS` | `7` | Stale-Move ohne Auto-Reject. |

**Cost-Tracking:** `cost_record "intake-council" "$cost"` in `intake-council.sh`. Cap-Check: `cost_check_or_die "$INTAKE_CAP_PER_PROPOSAL" "$INTAKE_CAP_PER_DAY"` (Argument-Order korrigiert per Committee #7, identisch `disput.sh` Z. 129).

---

## 11) Begründungs-Block (Pflicht, lt. User-Spezifikation)

### 11.A — Warum 3-Agent-Mini-Council mit dedizierten Intake-Agents

**Verworfen: 1-Agent (`intake-critic`).**
- Pro: Kostet ~$0.30/Run.
- Contra: Single-LLM-Bewertung → Sycophancy-Bias. Kein Adversarial-Gegengewicht.
- Entscheidung: **NEIN.**

**Verworfen: 5-Reviewer-Full-Council.**
- Pro: Max-Qualität.
- Contra: $10+/Run × 5/Tag = $50 — sprengt jeden Cap. Latenz 5-10 min.
- Entscheidung: **NEIN.** Aber: Council kann via `intake-validator` einen Full-Council triggern wenn Self-Mod-Pfade berührt werden (Mitigation #2).

**Verworfen: Disput-Agents (Proponent + Skeptic + Pragmatist) via Header-Flag re-usen.**
- Pro: Spart 3 neue Agent-Files.
- Contra (Committee Architect #1): Disput-Skeptic-Prompt ist „relentlessly reject" — falscher Bias für Intake-Bewertung. Disput-Pragmatist auf Implementation-Detail-Tie-Break trainiert, nicht ROI-Bewertung.
- Entscheidung: **Re-Use nur für Proponent** (Pro-Side-Frame passt). Skeptic + Pragmatist als **dedicated Intake-Agents** (`intake-skeptic.md`, `intake-pragmatist.md`).

**Gewählt: 3-Agent-Mini-Council = Disput-Proponent (Sonnet) + Intake-Skeptic (Sonnet, dedicated, weich) + optional Intake-Pragmatist (Opus, dedicated, ROI-Frame).**
- Adversariales Setup (Pro vs. Con) ohne Sycophancy-Drift.
- Cost: $0.40-$0.80/Round, Lifetime-Cap $2 für bis zu 3 Runden (Mitigation #13).
- **Eval-Pflicht:** N=25 Test-Proposals via `eval-intake-council.sh` (Task T19/T19b), Threshold 80% Match (Mitigation #16).

### 11.B — Warum Text-Reply statt Telegram-Inline-Buttons

**Verworfen: Inline-Buttons (`callback_query`).**
- Contra: Callback-Payload-Limit 64 Byte, HMAC-Token-Embed leakt in Telegram-Server-Log, `change <text>` braucht eh Free-Form-Reply.
- Entscheidung: **NEIN für Phase 1.**

**Gewählt: Text-Reply mit Pflicht-Format + DE/EN-Alias-Regex-Tabelle** (Mitigation #15):
- `^(go|Go|GO|👍|okay|ok|ja|approve)\s+(<id>|\d+)\s*(<token>)?$`
- `^(reject|nope|nein|nö|stop)\s+(<id>|\d+)(\s+<reason>)?$`
- `^(change|ändere|aber)\s+(<id>|\d+)\s+<text>$`
- `^(go-anyway)\s+(<id>|\d+)\s+(<token>)\s+(<reason>)$` (Reject-Override mit Begründungs-Pflicht).
- Sekundärer Pfad: `reply_to_message_id` aus Telegram-Update matcht Pending — User muss `<id>` nicht tippen.

### 11.C — Warum Pending-Queue statt Auto-Apply-mit-Recall

Verworfen: Auto-Apply mit 5-Min-Recall — User-Vision-Lock-in-Risiko (Q3). Gewählt: Pending-Queue mit 7-Tage-Stale-Marker (kein Auto-Reject).

### 11.D — Warum `/yota propose` als DEFAULT (Committee #14)

`btw` und `/yota propose` parallel sind beibehalten — aber Default-Empfehlung kehrt sich um:

- **`/yota propose` = Default.** Council bewertet ROI / Fit / Doppelung. User entscheidet mit Verdict-Kontext.
- **`/btw` = Power-User-Fast-Lane.** User weiß was er will, will Council-Latenz/-Kosten sparen.

Onboarding: bei erstem `/btw` nach Roll-out hängt der Bot einmalig `intake_yota_intro_once` an die Quittung (State-File `~/.claude/state/yota-intake-introduced-{user_id}` verhindert Wiederholung). `/help` listet `/yota propose` zuerst. Erfolg gemessen: Council-Pfad-Anteil ≥ 70% nach 2 Wochen.

### 11.E — Committee-mitigations applied (2026-05-12)

Das Planning Committee hat 5 parallele Reviews durchgeführt (Architekt ⚠️ÜBERARBEITUNG, Bug-Hunter 16 Probleme/3 KRITISCH, External-Scout HYBRID, Security BLOCK 2c/5h, UX/Mobile ⚠️5 Pflicht). Alle 16 Pflicht-Änderungen sind eingearbeitet:

1. **Validator-Schema-Konflikt (Bug-Hunter #1, Showstopper):** dedicated `intake-validator.md` (Task T11.0), NICHT `stakeholder-validator`. Validiert `created_from: intake-council`. T11 ruft `intake-validator`.
2. **`touches:` Self-Mod-Domain-Disput (Security #2):** Task T11.5 — `intake-validator` (oder Pre-Hook in `intake-council.sh`) scannt `touches:` gegen DENY-Liste (`.claude/scripts/`, `.claude/agents/`, `.claude/settings*.json`, `.claude/.user-session-active`, `CLAUDE.md`, `.github/workflows/`, `~/Library/LaunchAgents/com.inventory.*`). Match → `requires_human_dispute: true` + `verdict: needs-full-council` → User muss `/council` manuell triggern.
3. **Creator-Binding statt nur Allowlist (Security #1):** `from.id == frontmatter.user_id` strict-match in T11/T14/T15. HMAC-Token-Echo Pflicht (`go <id> <token>` oder via `reply_to_message`). Token im Verdict-Push enthalten. Acceptance T14: alle 3 Auth-Checks. Wrong-user → silent ignore + `intake_go_wrong_user`.
4. **Dedicated `intake-pragmatist.md` + `intake-skeptic.md` direkt (Architect #1):** Tasks T05a + T05b vor T05. `disput-proponent` bleibt re-used (Pro-Frame passt).
5. **`change`-Race fixen (Bug-Hunter #3):** T12 — atomic `mv pending-approval/<id>.md → .superseded.md` BEVOR Round-2 startet. T11 findet nur Live-Pfade. Audit `intake_round_advanced`.
6. **Verdict-Push als Bot-Filesystem-Watcher (Architect/Bug-Hunter #4):** T13 → T13a (Watcher) + T13b (Message-Template). Pollt `pending-approval/*.md` mit `pushed_at`-Marker. Idempotent. NICHT Subprozess-Push (Bot-Crash-Safe).
7. **Cost-Cap-Args fixen (Bug-Hunter #5):** T08 `cost_check_or_die "$INTAKE_CAP_PER_PROPOSAL" "$INTAKE_CAP_PER_DAY"` (Order identisch `disput.sh` Z. 129).
8. **`ANTHROPIC_API_KEY` Pre-Flight (External-Scout):** Task T08a — `intake-council.sh` startup-check: env-var gesetzt → exit 1 + Klartext-Stderr. Follow-up Stretch für `worker.sh`/`disput.sh`/`triage-stakeholder.sh`.
9. **Slug/ID-Regex strict (Security #3):** Slug `^[a-z0-9][a-z0-9-]{0,39}$`, ID `^[0-9]{8}-[0-9]{6}-[a-z0-9-]{1,40}$`. Helper-Lib `.claude/scripts/lib/slug.sh`. T11/T12 validieren VOR File-Path-Construction. Mismatch → `intake_id_invalid` + audit.
10. **Verdict-Push Mini-Format (UX #3):** 3-Zeilen — Verdict-Tag (✅/✏️/❌) + Slug + 1-Satz + Action-Hint + Cost-Tag. Volltext in `pending-approval/<id>.md` für `/yota show <id>`.
11. **Quiet-Hours via `notify.sh` (UX #4):** Verdict-Push routet durch `notify.sh info intake-verdict ...`. Critical-Bypass für Cap/Streak/Crash.
12. **ID-Disambiguation (UX #2):** 0 pending → "nichts offen". 1 → auto-target mit Bestätigung. N>1 → numbered list, 60s warten auf Ziffer. Slug-Prefix-Match als zweiter Pfad.
13. **Modell-Routing umgeschrieben (Architect #3):** Proponent + Intake-Skeptic = Sonnet (Bewertung). Intake-Pragmatist = Opus (Tie-Break-Qualität). Realistisch $0.50-$0.80/Run. `INTAKE_CAP_PER_PROPOSAL=$2` lifetime, `INTAKE_CAP_PER_DAY=$10`.
14. **Default-Pfad: `/yota propose`:** Sektion 11.D umgeschrieben. T23 erwähnt `/yota propose` zuerst. Task T23b: Onboarding-Hinweis bei erstem `/btw` (State-File einmalig). R9-Erfolg: ≥70% Council-Anteil.
15. **Reply-Parser-Regex-Tabelle (Bug-Hunter #6, UX #2):** explizit in T11-Acceptance (siehe 11.B). DE-Aliase normalisiert. `reply_to_message_id` als sekundärer Pfad.
16. **Pre-Merge-Eval N=25 (Architect/Bug-Hunter #2):** T19 acceptance N=25 (`.claude/intake-council/eval-set.json`). Inter-Annotator-Agreement. T19b: `eval-intake-council.sh`-Driver. Threshold 80%. Dedicated Agents schon vorgezogen → kein Fallback-Trigger nötig, aber als Warning dokumentiert.

**Optional eingearbeitet:** Content-Hash-Dedup (3.1 Frontmatter), `round`-Counter (3.1), `go-anyway <id> <token> <reason>` (Reject-Override mit Pflicht-Begründung, 11.B), Round-1-LLM-Output sentinel-strip (3.2), Token-Redactor auf User-Input (Datenfluss-Diagramm), Reject-Streak-Window 48h (R1/Cost-Tabelle), Audit-Action-Names erweitert (2.IST).

**External-Scout-Empfehlungen (HYBRID):** LangGraph 4-Decision-API (`approve | edit | reject | respond`) als Reply-Vokabular adoptiert (`go` / `change` / `reject` / `go-anyway`). Backlog.md Frontmatter-Felder als Vorlage für 3.1/3.2. GitHub Issue-Triage Label-Vokabular für Verdict-Tags. Claude Code `PreToolUse`-Hook als optionaler Worker-Spawn-Gate (Stretch).

---

## 12) Tasks

Atomar geordnet. Jeder Task: `acceptance:` + `verify:` + `agent:`. Reihenfolge: Foundation → Dedicated-Agents → CLI → Council → Validator → Telegram → Auth → Stale/Streak → Eval → Doku → Watchdog.

---

### Foundation (Schema + Queues + Helper)

#### T01 — Pending-Queue-Verzeichnis-Layout + Gitignore-Whitelist
- [x] **acceptance:** Verzeichnisse `pending-proposal/`, `pending-approval/`, `pending-approval/stale/`, `rejected/` unter `.claude/stakeholder/` existieren mit `.gitkeep`. `.gitignore` lässt `.gitkeep`-Files durch. `.claude/whitelist.txt` enthält die neuen Pfade.
- [x] **verify:** `ls .claude/stakeholder/{pending-proposal,pending-approval,pending-approval/stale,rejected}/.gitkeep` exit 0.
- **agent:** `flutter-coder`.

#### T02 — JSON-Schemas für File-Frontmatter
- [x] **acceptance:** `.claude/schemas/pending-proposal.schema.json` + `pending-approval.schema.json` + `rejected.schema.json` mit allen Feldern aus Sektion 3 (inkl. `pushed_at`, `requires_human_dispute`, `round`, `content_hash`).
- [x] **verify:** `python3 .claude/scripts/validate-schema.py <example-file> pending-approval` exit 0 / 1.
- **agent:** `flutter-coder`.

#### T02a — Slug/ID-Helper-Lib `[ADDED post-committee]`
- [x] **acceptance:** `.claude/scripts/lib/slug.sh` mit `_make_slug`, `_validate_slug` (Regex `^[a-z0-9][a-z0-9-]{0,39}$`), `_validate_intake_id` (Regex `^[0-9]{8}-[0-9]{6}-[a-z0-9-]{1,40}$`). Re-use aus `btw.sh._make_slug` extrahiert.
- [x] **verify:** Unit-Test `test/scripts/lib_slug_test.sh` mit 8 Cases (valid/invalid kebab, valid/invalid id, max-length).
- **agent:** `flutter-coder`. Note: [committee: Pflicht-9]

---

### Dedicated Intake-Agents `[ADDED post-committee]`

#### T05a — `intake-pragmatist.md` (dedicated) `[ADDED post-committee]`
- [x] **acceptance:** Neuer Agent in `.claude/agents/intake-pragmatist.md`. System-Prompt explizit auf Intake-Frame: Pre-Launch-ROI, Doppelung-zu-Backlog, Mobile-First-Risiko, Theme-Drift-Risiko, Migration/RLS-Trigger. Modell: Opus. Tools: Read, Grep, Glob. Untrusted-Block-Vertrag wie Disput-Agents.
- [x] **verify:** Mock-Run mit 3 Test-Proposals (Pre-Launch-fit, Theme-drift, Doppelung) — Vote-Struktur korrekt parsbar.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-4]

#### T05b — `intake-skeptic.md` (dedicated, weicher) `[ADDED post-committee]`
- [x] **acceptance:** Neuer Agent `.claude/agents/intake-skeptic.md`. System-Prompt: „evaluate, don't relentlessly reject — flag concerns proportional to evidence". Modell: Sonnet. Tools: Read, Grep, Glob. Untrusted-Block-Vertrag.
- [x] **verify:** Mock-Run mit 3 Test-Proposals — keine 100%-Reject-Quote bei vernünftigem Input.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-4]

---

### CLI-Entry (`yota-propose.sh`)

#### T03 — `yota-propose.sh` Skript
- [x] **acceptance:** `bash .claude/scripts/yota-propose.sh "<idee>"` schreibt `pending-proposal/<id>.md` mit korrektem Frontmatter (id über `_validate_intake_id`, slug über `_validate_slug`, source=tier-1, trust_tier=1, user_id=local-$USER, state=pending-proposal, hmac_token, round=1, content_hash). Sandwich-Marker-Sentinel-Reject identisch `btw.sh`. Token-Redactor auf User-Input. Max-Length 4096. Audit `intake_proposed`.
- [x] **verify:** T1 + T12.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-9, Pflicht-Optional-Token-Redactor]

#### T04 — Sentinel-Reject + HMAC-Token + Content-Hash
- [x] **acceptance:** HMAC-Token aus `~/.claude/telegram-hmac-secret` + `<id>`. Lokal-Fallback: SHA256 random-32 + `<id>`. Content-Hash `sha256(normalized-body)` für Dedup gegen Spam — wenn identischer Hash binnen 1h existiert → reject mit Reply.
- [x] **verify:** T12 + ergänzter Dedup-Test.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-Optional-Dedup]

---

### Council-Orchestrator (`intake-council.sh`)

#### T05 — `intake-council.sh` Grundgerüst
- [x] **acceptance:** `bash .claude/scripts/intake-council.sh <pending-proposal-file>` startet Council, schreibt am Ende `pending-approval/<id>.md`. Liest Proposal, baut Proposal-File mit Intake-Mode-Header. Cost-Cap per-proposal-lifetime `$2`, per-day `$10`. Ruft `intake-skeptic` + `disput-proponent` (mit Intake-Header).
- [x] **verify:** T2.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-4, Pflicht-13]

#### T06 — Round-1: Proponent + Intake-Skeptic parallel
- [x] **acceptance:** Beide Agents mit demselben Proposal-File (Intake-Mode-Header). Outputs in `disputes/intake-<id>/round-1/{proponent,intake-skeptic}.md`. Vote-Extraction via `extract_vote` aus `lib/disput-common.sh`.
- [x] **verify:** T2 + T3.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-4]

#### T07 — Verdict-Synthese (deterministic)
- [x] **acceptance:** Vote-Match → Direkt-Verdict. Patt → `intake-pragmatist` als Round-2-Tie-Break. Synthese-Result in `pending-approval/<id>.md` (Markdown-Template Sektion 3.2). Round-1-LLM-Output wird sentinel-stripped bevor er als Context in Round-2 geht.
- [x] **verify:** T3.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-4, Pflicht-Optional-Sentinel-Strip]

#### T08 — Cost-Cap + Tagescap-Enforcement (Args-Reihenfolge fix)
- [x] **acceptance:** Vor jedem Agent-Call: `cost_check_or_die "$INTAKE_CAP_PER_PROPOSAL" "$INTAKE_CAP_PER_DAY"` (identisch `disput.sh` Z. 129). Bei Cap-Hit → `state: failed-cap`, notify (critical), exit 2. `cost_record` mit Modell-deterministischen Werten: Sonnet $0.20, Opus $0.40.
- [x] **verify:** T4 + T5.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-7, Pflicht-13]

#### T08a — `ANTHROPIC_API_KEY` Pre-Flight-Check `[ADDED post-committee]`
- [x] **acceptance:** `intake-council.sh` startup: wenn `$ANTHROPIC_API_KEY` non-empty → exit 1 mit Klartext-Stderr „Refusing to run — ANTHROPIC_API_KEY would charge Max-Plan as pay-per-token (Anthropic issue #39903). Unset and retry."
- [x] **verify:** T20.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-8]

---

### Validator (dedicated) `[ADDED post-committee]`

#### T11.0 — `intake-validator.md` (dedicated Agent) `[ADDED post-committee]`
- [x] **acceptance:** `.claude/agents/intake-validator.md`. Tools: Read, Grep, Glob, Write. NICHT in Self-Mod-Blocklist. System-Prompt: Schema-Check für `created_from: intake-council`-Items + Slug/ID-Regex + `touches:` DENY-Scan + Backlog-Item-Format-Check (analog `stakeholder-validator` aber für Council-Output).
- [x] **verify:** Mock-Run mit 3 Council-Outputs (1 valid, 1 schema-broken, 1 self-mod-touches) — korrekte Verdicts.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-1]

#### T11.5 — Self-Mod-Pfad-DENY-Scan `[ADDED post-committee]`
- [x] **acceptance:** `intake-validator` (oder Pre-Hook in `intake-council.sh`) scannt Council-vorgeschlagene `touches:` gegen DENY-Liste: `.claude/scripts/`, `.claude/agents/`, `.claude/settings*.json`, `.claude/.user-session-active`, `CLAUDE.md`, `.github/workflows/`, `~/Library/LaunchAgents/com.inventory.*`. Match → setze `requires_human_dispute: true` + `verdict: needs-full-council` (NICHT `propose`). User-Reply `go` triggert dann NICHT Worker, sondern Hint zu manuellem `/council`.
- [x] **verify:** T15.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-2]

---

### Telegram-Integration (`telegram-bot.py`)

#### T09 — `/yota propose <text>` Command-Handler
- [x] **acceptance:** Erkennt `/yota propose`. Schreibt via `yota-propose.sh`. Triggert `intake-council.sh` als nohup-Subprozess. Initial-Reply `intake_proposal_queued`.
- [x] **verify:** T6.
- **agent:** `flutter-coder`.

#### T10 — `/yota pending` Listing
- [x] **acceptance:** Erkennt `/yota pending`. Liest `pending-approval/` (nicht `stale/`) mit `user_id == caller`. Markdown-Liste mit `id`, `verdict`, `created_at`, `age`.
- [x] **verify:** T14.
- **agent:** `flutter-coder`.

#### T11 — `go <id> [<token>]` / `reject <id>` / `go-anyway` Reply-Handler
- [x] **acceptance:** Drei-Schicht-Auth: (a) Allowlist, (b) `from.id == frontmatter.user_id` (silent ignore + `intake_go_wrong_user` bei Mismatch), (c) HMAC-Token-Echo Pflicht (oder via `reply_to_message_id`) — Mismatch → audit `intake_token_mismatch`. ID-Regex-Strict-Validation VOR File-Path-Construction (Mismatch → reply `intake_id_invalid` + `intake_id_invalid`-audit). Reply-Parser-Regex-Tabelle (siehe 11.B). ID-Disambiguation: 0 pending → "nichts offen"; 1 → auto-target mit Bestätigung; N>1 → numbered list 60s; Slug-Prefix-Match als sekundärer Pfad. Bei `go`: `intake-validator` (NICHT `stakeholder-validator`!) → bei `propose`-Verdict-Pass → move nach `overseer/inbox/01-stakeholder-<slug>.md`; bei `needs-full-council` → Hint-Reply. Bei `reject`: move nach `rejected/<id>.md`. `go-anyway` erfordert Reject-Override-Begründung.
- [x] **verify:** T7 + T9 + T17 + T18 + T19 + T21.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-1, Pflicht-3, Pflicht-9, Pflicht-12, Pflicht-15, Pflicht-Optional-Override-Reason]

#### T12 — `change <id> <text>` Re-Deliberation mit atomic-mv `[modified post-committee]`
- [x] **acceptance:** Vor Round-2: atomic `mv pending-approval/<id>.md pending-approval/<id>.superseded.md`. Schreibt `pending-proposal/<id>-r2.md` mit User-Change als Zusatz-Kontext (Token-Redactor!) und `round: 2`. Triggert `intake-council.sh`. `MAX_INTAKE_ROUNDS=3`. Audit `intake_round_advanced` pro Übergang. 4. Versuch → Reply `intake_round_limit_reached`.
- [x] **verify:** T8.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-5, Pflicht-10-Token-Redactor]

#### T13a — Verdict-Push Bot-Filesystem-Watcher `[modified post-committee]`
- [x] **acceptance:** Bot pollt in jeder Loop-Iteration `pending-approval/*.md` mit `pushed_at:`-leer. Push via Telegram → setzt `pushed_at: <iso>` atomic. Idempotent. NICHT Subprozess-Push. Bei Bot-Crash zwischen Council-Finish und Push → nächste Loop-Iteration pickt auf.
- [x] **verify:** T16.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-6]

#### T13b — Verdict-Mini-Format-Template `[ADDED post-committee]`
- [x] **acceptance:** 3-Zeilen-Template (Sektion 5: `intake_verdict_propose` / `_changes` / `_reject` / `_needs_council`). Verdict-Tag-Emoji + Slug + 1-Satz-Begründung + Action-Hint + Cost-Tag. Routet durch `notify.sh info intake-verdict ...` (Quiet-Hours-Respekt). Volltext bleibt im File für `/yota show <id>`.
- [x] **verify:** Snapshot-Test gegen Mock-Telegram-API-Dir.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-6, Pflicht-10, Pflicht-11]

---

### Sicherheit + Auth

#### T14 — HMAC-Replay-Schutz + Token-Echo-Pflicht `[modified post-committee]`
- [x] **acceptance:** `go`-Handler prüft (a) File existiert im Live-Pfad `pending-approval/<id>.md` (nicht `.superseded.md`, nicht `rejected/`, nicht `stale/`), (b) Token aus User-Reply == Frontmatter `hmac_token`, (c) `from.id == user_id`. Bei (a)-Mismatch → "bereits verarbeitet" + `intake_replay_blocked`. Atomic-Move via `mv` verhindert Double-Process. **Implementiert via T11 (telegram-bot.py) + T26 (lib/intake-actions.sh).**
- [x] **verify:** T11 verify-Suite + verify/yota-cli-actions.sh.
- **agent:** `general-purpose`. Note: [committee: Pflicht-3]

#### T15 — User-ID-Spoofing-Schutz `[modified post-committee]`
- [x] **acceptance:** Drei-Schicht-Auth wie T11 (Allowlist + Creator-Binding + Token-Echo). Local CLI setzt `user_id: local-$USER`. Wrong-user → silent ignore + `intake_go_wrong_user`-audit. **Implementiert via T11 (telegram-bot.py) + T26.**
- [x] **verify:** verify/telegram-bridge.sh + verify/yota-cli-actions.sh.
- **agent:** `general-purpose`. Note: [committee: Pflicht-3]

---

### Stale + Streak-Logik

#### T16 — Stale-Move-Cron-Hook + optionaler Reminder
- [x] **acceptance:** `intake-stale-sweep.sh` wird vom overseer-tick aufgerufen. Files älter `INTAKE_STALE_DAYS=7` → move nach `stale/`. Optional: Telegram-Reminder bei Übergang (Stretch).
- [x] **verify:** T13.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-Optional-Stale-Reminder]

#### T17 — Reject-Streak-Notify (48h-Fenster) `[modified post-committee]`
- [x] **acceptance:** `reject`-Handler prüft letzte 5 `rejected/`-Files des Users mit `rejected_at` in den letzten 48h. Alle 5 → critical-notify `intake_rejected_streak`. Reset bei dazwischenliegendem `go`.
- [x] **verify:** T10.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-Optional-48h]

---

### Eval + Quality-Gate

#### T18 — Helper-Refactor: `lib/disput-common.sh`
- [x] **acceptance:** `extract_vote`, `make_proposal_header`, `tally_round` nach `.claude/scripts/lib/disput-common.sh`. `disput.sh` + `intake-council.sh` sourcen beide.
- [x] **verify:** Bestehende `disput_*`-Tests grün.
- **agent:** `flutter-coder`.

#### T19 — Pre-Merge-Eval N=25 (PRE-MERGE-GATE) `[modified post-committee]`
- [x] **acceptance:** Eval-Datensatz `.claude/intake-council/eval-set.json` mit 25 manuell konstruierten Proposals (Mix aus: CSV-Export, Theme-Drift, Migration-Pflicht, Mobile-First-Verstoß, Doppelung-zu-Backlog, Self-Mod-Trigger, Out-of-Scope-Supabase, …). User + 1 zweiter Reviewer annotieren Erwartung (oder selbst-Re-Test nach 24h für Stabilität). Inter-Annotator-Agreement berechnet.
- [x] **verify:** Match-Rate (Council-Verdict vs. User-Erwartung) ≥ 80%. Report unter `plans/2026-05-12_yota-council-eval.md`. Verifikations-Skript: `.claude/scripts/verify/intake-eval-quality.sh`. Doku für echten Run: `.claude/intake-council/REAL_EVAL.md`.
- **agent:** `planner`. Note: [committee: Pflicht-16]

#### T19b — `eval-intake-council.sh` Driver `[ADDED post-committee]`
- [x] **acceptance:** Skript `.claude/scripts/eval-intake-council.sh` läuft alle 25 Proposals aus `eval-set.json` durch `intake-council.sh` (echte `claude --print`-Calls), schreibt Outputs nach `.claude/intake-council/eval-runs/<timestamp>/`, berechnet Match-Rate gegen `eval-set.json` `expected_verdict`. Cost-Cap-Override für Eval (50$ einmalig).
- [x] **verify:** Dry-Run mit Mock-`claude` produziert Match-Rate-Report.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-16]

#### T20 — (DEPRECATED) Conditional Fallback `[modified post-committee]` `[OBSOLETE]`
- [~] **acceptance:** **N/A — bereits durch T05a/T05b ersetzt.** `intake-pragmatist.md` ist in T05a vorgezogen. Bei T19 < 80%: iterativ `intake-pragmatist.md` + `intake-skeptic.md` System-Prompt verbessern + Eval re-run (dokumentiert in `REAL_EVAL.md`). Kein neuer Trigger-Mechanismus nötig.
- [~] **verify:** n/a — Task ist durch T05a/T05b vollständig abgedeckt.
- **agent:** `planner`. Note: [committee: Pflicht-4 — hochgezogen zu T05a]

---

### Doku + Migration

#### T21 — CLAUDE.md Update
- [x] **acceptance:** Neuer Unter-Abschnitt § Autonomous Council Swarm: „Intake-Council (gated, DEFAULT-PATH)". `/yota propose` als Default empfohlen, `/btw` als Power-User-Fast-Lane.
- [x] **verify:** `grep -A20 "Intake-Council" CLAUDE.md`.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-14]

#### T22 — Yota-Agent-Doku-Update
- [x] **acceptance:** `.claude/agents/yota.md` neuer Abschnitt „Pending-Approvals abfragen" — Read-only. Tool-Whitelist unverändert.
- [x] **verify:** `grep "pending-approval" .claude/agents/yota.md`.
- **agent:** `flutter-coder`.

#### T23 — `/help`-Command in Telegram-Bot
- [x] **acceptance:** `/help` listet `/yota propose` ZUERST (Default), dann `/btw` (Power-User). Plus `/yota pending`, `go <id> <token>`, `reject <id>`, `change <id> <text>`, `go-anyway <id> <token> <reason>`.
- [x] **verify:** Telegram-bot.py-Unit-Test. (covered by verify/intake-onboarding.sh T5)
- **agent:** `flutter-coder`. Note: [committee: Pflicht-14, Pflicht-15]

#### T23b — Onboarding-Hinweis bei erstem `/btw` `[ADDED post-committee]`
- [x] **acceptance:** Bei erstem `/btw` nach Roll-out: State-File `~/.claude/state/yota-intake-introduced-{user_id}` check. Wenn nicht existiert → hänge einmalig `intake_yota_intro_once`-String an die `/btw`-Quittung, lege File an.
- [x] **verify:** Unit-Test: 1. `/btw` → Intro-Anhang; 2. `/btw` → kein Anhang. (verify/intake-onboarding.sh — 9/9 pass)
- **agent:** `flutter-coder`. Note: [committee: Pflicht-14]

#### T24 — Update `docs/handbook/05-architecture.md`
- [x] **acceptance:** Neuer Sub-Abschnitt „Stakeholder-Pfade — Intake-Council (Default)". Datenfluss-Diagramm aus Sektion 8. Subagenten-Tabelle erweitert um `intake-skeptic`, `intake-pragmatist`, `intake-validator`.
- [x] **verify:** `grep -A5 "Intake-Council" docs/handbook/05-architecture.md`.
- **agent:** `flutter-coder`. Note: [committee: Pflicht-1, Pflicht-4]

---

### Headless/Watchdog-Integration

#### T25 — Headless-Loop pickt `intake-council.sh`-Hänger auf
- [x] **acceptance:** `recover.sh --once` Check 5: `.claude/intake-council/<id>/` älter als 10 min OHNE `pending-approval/<id>*.md` → abort orphan PID + write reject-verdict + cleanup + notify. Audit `intake_council_hung_recovered`.
- [x] **verify:** `verify/intake-recovery.sh` — 6/6 passed (T1–T5 incl. fresh-dir guard).
- **agent:** `flutter-coder`.

#### T26 — Local-CLI-Approval-Pfad `yota-go.sh` `[ADDED post-committee]`
- [x] **acceptance:** `.claude/scripts/yota-go.sh <id> [<token>]`, `yota-reject.sh <id> [<reason>]`, `yota-change.sh <id> <text>` — lokale CLI-Pendants zu Telegram-`go`/`reject`/`change`. Shared-lib `lib/intake-actions.sh` (DRY). Creator-binding + HMAC-verify + validator-call. `user_id=local-$USER`.
- [x] **verify:** `verify/yota-cli-actions.sh` — 15/15 passed (T1–T5 incl. creator-binding mismatch).
- **agent:** `flutter-coder`. Note: [committee: Pflicht-Optional-Local-CLI]

---

## 13) Modell-Routing `[modified post-committee]`

| Komponente | Modell | Begründung |
|---|---|---|
| `disput-proponent` (Intake-Mode) | **Sonnet** | Pro-Side-Bewertung leichter als Code-Plan-Disput. (Mitigation #13) |
| `intake-skeptic` (dedicated) | **Sonnet** | dito. Bewertung, nicht relentless rejection. (Mitigation #4, #13) |
| `intake-pragmatist` (Tie-Break, dedicated) | **Opus** | Tie-Break-Qualität wichtig — finaler Verdict-Schritt. (Mitigation #4, #13) |
| `intake-validator` (dedicated) | **Sonnet** | Schema-Regex-Check, deterministisch. (Mitigation #1) |
| `yota` (Listing-Erweiterung) | Sonnet (bereits konfiguriert) | Read-only. |
| Worker nach `go` | Bleibt wie heute (Sonnet default, Opus bei Migration-Tasks) | Kein Eingriff. |

---

## 14) Lieferform-Zusammenfassung `[updated post-committee]`

- **34 atomare Tasks** (vorher 25; +T02a, T05a, T05b, T08a, T11.0, T11.5, T13a, T13b, T19b, T23b, T26).
- **21 Tests** (vorher 14; +T15 Self-Mod, +T16 Watcher, +T17 Disambig, +T18 Wrong-User, +T19 ID-Regex, +T20 API-Key, +T21 Alias-Regex).
- **1 manueller Eval-Run mit N=25** (T19/T19b) als Pre-Merge-Gate, Threshold 80%, Inter-Annotator-Agreement.
- **Reihenfolge:** Foundation (T01-T02a) → Dedicated Agents (T05a-b) → CLI (T03-T04) → Council (T05-T08a) → Validator (T11.0-T11.5) → Telegram (T09-T13b) → Auth (T14-T15) → Stale/Streak (T16-T17) → Helper-Refactor (T18) → Eval (T19-T19b) → Doku (T21-T24) → Watchdog (T25) → CLI-Approval (T26).
- **Critical-Path:** T01 → T02a → T05a/T05b (parallel) → T03 → T05-T08a → T11.0-T11.5 → T09-T13b → T19/T19b. T20 obsolet.
- **Dependency-Graph-Highlights:**
  - T11 hängt von **T11.0** (`intake-validator`) + **T02a** (`slug.sh`) + T13b (Token-Format).
  - T05 hängt von **T05a + T05b** (dedicated Agents müssen existieren bevor Council sie aufruft).
  - T08 hängt von T08a (Pre-Flight).
  - T13a hängt von T13b (Template-Definition).
  - T19/T19b hängt vom kompletten Council-Pfad (T05a-T11.5).
  - T23b hängt von T23 (Help-Command bestehend).

---

## 15) Bezug zum Bestehenden — explizit

- **Erweitert:** [`plans/2026-05-09_autonomous_council_swarm.md`](2026-05-09_autonomous_council_swarm.md) — als Post-Phase-4-Add-On.
- **Berührt nicht:** Worker-Pipeline (`worker.sh`), Overseer-Tick (`overseer.sh`), Stakeholder-Triage-Pfad (bleibt für `btw`-Power-User-Modus).
- **Re-Use:** `disput-proponent`, `btw.sh`-Pattern, `disput.sh`-Pattern, `cost-cap.sh`, `audit.sh`, `notify.sh`, `telegram-bot.py`-Dispatcher.
- **NICHT re-used:** `disput-skeptic`, `disput-pragmatist`, `stakeholder-validator` (Committee #1, #4).
- **Neu in `.claude/scripts/`:** `yota-propose.sh`, `intake-council.sh`, `intake-stale-sweep.sh`, `eval-intake-council.sh`, `yota-go.sh`, `lib/disput-common.sh`, `lib/slug.sh`.
- **Neu in `.claude/agents/`:** `intake-skeptic.md`, `intake-pragmatist.md`, `intake-validator.md`.
- **Neu in `.claude/stakeholder/`:** `pending-proposal/`, `pending-approval/`, `pending-approval/stale/`, `rejected/`.
- **Neu in `.claude/intake-council/`:** `eval-set.json`, `eval-runs/`.

---

## Plan-Pfad

**`plans/2026-05-12_yota-council-gated-intake.md`**
