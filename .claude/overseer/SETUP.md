# Overseer Setup

## Cost-Cap-Library Usage

Die Library `.claude/scripts/lib/cost-cap.sh` stellt drei öffentliche Funktionen bereit.

### Source

```bash
source .claude/scripts/lib/cost-cap.sh
```

### `cost_record <agent> <usd>`

Schreibt einen Ledger-Eintrag atomar (flock/lockf) in `cost-ledger.jsonl`.

```bash
# Worker-Skript nach Abschluss eines Items:
source .claude/scripts/lib/cost-cap.sh
cost_record "flutter-coder" "0.12"
cost_record "edge-fn-coder" "0.03"
```

Ledger-Format (JSONL):
```json
{"ts":"2026-05-09T14:30:00Z","agent":"flutter-coder","usd":0.12,"pid":12345}
```

### `cost_today_usd` / `cost_week_usd`

Aggregieren die Kosten für heute (UTC) bzw. die letzten 7 Tage.

```bash
source .claude/scripts/lib/cost-cap.sh
echo "Heute: $(cost_today_usd) USD"
echo "Woche: $(cost_week_usd) USD"
```

### `cost_check_or_die <max_today> <max_week>`

Prüft Budget-Grenzen. Bei Überschreitung: stderr-Ausgabe, Marker-File
`.claude/overseer/COST_CAP_REACHED` schreiben, exit 2.

```bash
source .claude/scripts/lib/cost-cap.sh

# Am Anfang jedes Worker-Runs:
cost_check_or_die 5.00 30.00   # exit 2 → Run wird abgebrochen

# Nach Abschluss:
cost_record "$AGENT_NAME" "$RUN_COST_USD"
```

Exit-Codes:
- `0` — Budget OK, weiter.
- `1` — Ungültige Argumente (kein Float übergeben).
- `2` — Hard-Stop: Budget überschritten, Marker-File geschrieben.

### Ledger-Pfad überschreiben (Tests / CI)

```bash
export COST_CAP_LEDGER_DIR=/tmp/my-test-ledger
source .claude/scripts/lib/cost-cap.sh
cost_record "test-agent" "1.00"
```

---

## Mensch-im-Loop: Anthropic Admin-API Hard-Limit (Mitigation 4)

Die lokale `cost-cap.sh` ist **Best-Effort**: Sie basiert auf Worker-Self-Report
(Agenten schreiben selbst ins Ledger). Ein kompromittierter oder abgestürzter Worker
könnte den Eintrag auslassen. Als zweite Verteidigungslinie muss ein
**Anthropic-seitiges Konto-Budget** eingestellt werden.

### Einrichtung (einmalig, manuell)

1. Browser öffnen → Anthropic Console:
   **`https://console.anthropic.com/settings/limits`**
   *(Alternativ: Console → Settings → Spend Limits / Usage Limits)*

2. "Monthly spend limit" aktivieren und Grenzwert setzen.
   Empfohlene Startwerte:
   - **Täglich:** $50 (sofern die Console das unterstützt — Stand 2026-05)
   - **Monatlich:** $200

3. Benachrichtigungs-E-Mail auf den Kontoinhaber setzen (Standard), sodass
   bei Annäherung an das Limit eine Warnung kommt.

> **Hinweis:** Die Anthropic Console bietet aktuell (Stand 2026-05) ein
> monatliches Spend-Limit, aber kein natives Tageslimit. Das Tageslimit wird
> durch `cost_check_or_die` in der lokalen Library abgebildet. Beide Schichten
> zusammen bilden "belt and braces": lokale Prüfung stoppt schnell, Anthropic-Limit
> ist die letzte Absicherung falls die lokale Library ausfällt.

### Warum beide Schichten?

| Schicht | Wer prüft | Latenz | Granularität |
|---|---|---|---|
| `cost_check_or_die` (lokal) | Bash-Library, vor jedem Worker-Run | sofort | täglich + wöchentlich |
| Anthropic Spend-Limit | Anthropic-Server, vor jeder API-Anfrage | API-Aufruf-Level | monatlich |

---

## Worker-Item Frontmatter Pflicht

Ab Phase 1 (P1-2 enforcement) muss **jedes Backlog-Item** in
`.claude/backlog/inbox/` ein `budget_usd`-Feld im YAML-Frontmatter enthalten.

### Format

```markdown
---
id: "00-my-feature"
priority: P1
budget_usd: 2.50
---
# Mein Feature

Beschreibung...
```

### Regeln

- `budget_usd` ist **required** — Items ohne dieses Feld werden vom
  Headless-Runner mit Fehler abgelehnt (nach P1-2-Implementierung).
- Der Wert ist ein Float in USD, z.B. `0.50`, `2.00`, `10.0`.
- Empfohlene Richtwerte nach Task-Größe:

  | Task-Größe | Empfehlung |
  |---|---|
  | Trivial (Typo, Config) | `0.10` – `0.30` |
  | Klein (einzelner Provider/Widget) | `0.50` – `1.00` |
  | Mittel (Feature mit Tests) | `1.00` – `3.00` |
  | Groß (Migration + Edge-Fn + UI) | `3.00` – `8.00` |

- Der Runner summiert nach Abschluss die tatsächlichen Kosten via
  `cost_record` ins Ledger — der `budget_usd`-Wert ist nur für
  Pre-Check-Entscheidungen (Reihenfolge, Throttling) relevant.

---

## Pre-Phase-2 Security Tasks (TODO vor LaunchAgent-Aktivierung)

Phase 0+1 ist commit-ready, aber bevor der LaunchAgent dauerhaft läuft
(Phase 2), müssen die folgenden 5 High-Findings adressiert werden.
Sie sind bewusst NICHT Teil der Phase-0/1-Critical-Fixes — der Worker
ist im aktuellen Stand sicher, weil die LaunchAgenten noch nicht
geladen sind und der Worker per Hand gestartet wird.

### Pre-Phase-2 Security Findings (5× high)

1. **Finding #4 — `cost-cap.sh` Concurrency Race**
   - Problem: `cost_today_usd` ohne flock; zwei parallele Worker können
     gleichzeitig prüfen und beide unter Cap durchrutschen, danach
     beide aggregierte Kosten überschreiten Cap deutlich.
   - Fix: `cost_check_or_die` muss aggregation+check atomar machen
     (gemeinsamer flock auf ledger-lock), nicht zwei separate Reads.
   - Tracking: PR-Subitem für Phase 2.

2. **Finding #5 — Worker-PID-Enforcement**
   - Problem: `OVERSEER_WORKER_PID` ist trivial fakable — Worker kann
     `unset OVERSEER_WORKER_PID` und `HEADLESS_MODE=0` setzen.
   - Fix: Statt nur env-var prüfen, soll guard-bash zusätzlich
     `pgrep -f overseer.sh` prüfen ODER Marker-File mit PID + signed
     hash (analog session-marker) verwenden.
   - Tracking: PR-Subitem für Phase 2.

3. **Finding #6 — LaunchAgent-Plist Permissions**
   - Problem: `~/Library/LaunchAgents/com.kerami.inventory.*.plist`
     ist nicht in der SELF_MOD_BLOCKLIST_GLOBS-Validierung —
     install-overseer.sh schreibt ohne Mode-0644-Enforcement.
   - Fix: install-overseer.sh + install-integrity-check.sh schreiben
     plists explizit mit `chmod 0644` und prüfen `stat -f '%Lp'` vor
     `launchctl load`.
   - Tracking: PR-Subitem für Phase 2.

4. **Finding #7 — Notify-URL Injection via Item-Title**
   - Problem: `notify.sh` baut ntfy-URL ohne Header-Escaping; ein
     Backlog-Item mit `\r\nX-Forwarded-For: ...` könnte HTTP-Header
     injizieren.
   - Fix: Title/Tag-Strings vor `curl` mit `tr -d '\r\n'` strippen
     UND length-cap (max 200 Zeichen).
   - Tracking: PR-Subitem für Phase 2.

5. **Finding #8 — Audit-Verify Run-as-LaunchAgent fehlt**
   - Problem: `audit-verify.sh` wird aktuell nur on-demand aufgerufen.
     Wenn ein Worker am Ende seines Runs den lokalen Hash-Chain
     fälscht UND auch das letzte Item gut aussieht, fällt das erst
     beim nächsten manuellen Verify auf.
   - Fix: Eigener Nightly-LaunchAgent (`com.kerami.inventory.audit-verify`)
     der täglich `audit-verify.sh` mit `CLAUDE_AUDIT_VERIFY_SYSLOG=1`
     ausführt und bei FAIL ntfy-Alert triggert.
   - Tracking: PR-Subitem für Phase 2.

### Already Addressed (Phase-0+1-Critical-Fixes)

Die folgenden 3 Critical-Findings sind in dieser Phase fixiert:

- **Finding #1 (Session-Marker-Bypass):** `.claude/.user-session-active`
  ist jetzt in der Blocklist UND enthält einen signierten Hash, der
  mit `~/.claude/inventory-session-secret` (mode 0400, repo-extern)
  korreliert + alle 1 Min rotiert + 5 Min TTL.
  → `_is_self_mod_protection_active` prüft via `_is_session_marker_valid`.
  → `bash session-start.sh` regelmäßig wiederholen für Sessions > 5 Min.

- **Finding #2 (Manifest-Build Self-Mod):** `integrity-manifest-build.sh`
  + `integrity-check.sh` + `session-start.sh` + `session-end.sh` sind
  jetzt in der Blocklist. `integrity-manifest-build.sh` refuses Run
  unter HEADLESS_MODE ohne valid signed marker (exit 3). Manifest
  enthält jetzt `# signature: <hex>` Zeile, die `integrity-check.sh`
  out-of-band gegen `~/.claude/inventory-session-secret` verifiziert.

- **Finding #3 (Audit-Append-Only):** `lib/audit.sh` mirrored jeden
  Eintrag via `logger -t claude-audit` nach syslog (out-of-band tamper-
  detector). `audit-verify.sh` cross-checked beide Stores wenn
  `CLAUDE_AUDIT_VERIFY_SYSLOG=1` oder `CLAUDE_AUDIT_SYSLOG_FILE` gesetzt.
  Plus: Rate-Limit `CLAUDE_AUDIT_MAX_PER_MINUTE` (default 100) gegen
  DoS via runaway-worker.

### Optional: chflags sappnd Setup

Als zusätzliche Verteidigungslinie kann der User die Audit-Dateien mit
dem System-Append-Only-Flag `sappnd` versehen (erfordert root):

```bash
sudo chflags sappnd .claude/audit/*.md
```

Damit kann selbst root außerhalb von append-Mode nicht mehr
überschreiben — nur Single-User-Mode + `chflags nosappnd` erlauben das.
Nicht Pflicht, weil der syslog-Mirror bereits out-of-band-Schutz bietet.
