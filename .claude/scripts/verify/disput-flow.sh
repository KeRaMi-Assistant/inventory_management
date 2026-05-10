#!/usr/bin/env bash
# verify/disput-flow.sh — Integrationstests für disput.sh (P3-2)
#
# Tests:
#   1. Round-1-Konsens (accept+accept) → Verdict accept, kein Round 2
#   2. Round-2-Tie-Break: R1 split, R2 weiter split → Pragmatist Verdict accept
#   3. Round-3-Patt → unresolved/ + Stakeholder-Notify
#   4. Cost-Cap-Hit → cost-cap-aborted
#   5. --status <id>: zeigt Verdict
#   6. --resume <id>: resume bei round-1-only → produziert round-2
#   7. Verdict-File-Format: valides YAML-Frontmatter + Markdown-Body
#
# Exit 0 = alle Tests bestanden. Exit 1 = mindestens ein Fehler.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPUT_SH="$SCRIPT_DIR/../disput.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

PASS=0
FAIL=0

pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Sandbox-Setup
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$SANDBOX'" EXIT

DISPUTES_DIR="$SANDBOX/disputes"
COST_CAP_LEDGER_DIR="$SANDBOX/overseer"
MOCK_BIN="$SANDBOX/mock-bin"
mkdir -p "$DISPUTES_DIR" "$COST_CAP_LEDGER_DIR" "$MOCK_BIN"

# Stub für cost_check_or_die und cost_record in Sandbox
# Wir setzen COST_CAP_LEDGER_DIR so dass die Library Ledger in Sandbox schreibt.
# cost_check_or_die wird via MOCK_COST_CAP_FAIL überschrieben.

# ---------------------------------------------------------------------------
# Mock-claude Stub
# ---------------------------------------------------------------------------
# Der Mock-Stub liest MOCK_VOTE_<AGENT>_R<N> Env-Vars und gibt synthetisches
# Markdown zurück, das den passenden "### Vote:" enthält.
# Agent-Name wird aus --agent Flag geparst.
# Round wird aus dem Count der bereits vorhandenen round-N-Files ermittelt.
#
# Aufruf: mock-claude --print --agent <agent-name> (stdin = context)

cat > "$MOCK_BIN/claude" <<'MOCK_EOF'
#!/usr/bin/env bash
set -uo pipefail

# Parst --agent <name> aus Args
AGENT_NAME=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--agent" ]]; then
    AGENT_NAME="${2:-}"
    shift 2
  else
    shift
  fi
done

# AGENT_NAME normieren (disput- prefix ist optional in env keys)
# Env-Keys: MOCK_VOTE_PROPONENT_R1, MOCK_VOTE_SKEPTIC_R1, MOCK_VOTE_PRAGMATIST_R2, ...
# Wir ermitteln die Round aus MOCK_ROUND (gesetzt durch Orchestrator-Wrapper).
ROUND="${MOCK_ROUND:-1}"

case "$AGENT_NAME" in
  *proponent*)  ROLE="PROPONENT" ;;
  *skeptic*)    ROLE="SKEPTIC" ;;
  *pragmatist*) ROLE="PRAGMATIST" ;;
  *)            ROLE="UNKNOWN" ;;
esac

# Vote-Env-Key: MOCK_VOTE_PROPONENT_R1 etc.
VOTE_KEY="MOCK_VOTE_${ROLE}_R${ROUND}"
VOTE="${!VOTE_KEY:-abstain}"

# Drucke synthetisches Markdown mit dem richtigen Vote
case "$ROLE" in
  PROPONENT)
    cat <<EOF
## Proponent (Round ${ROUND})

### Vorteile
- Mock-Argument: Proposal ist sinnvoll.

### Empfohlene Implementation
- Implementiere gemäß Proposal.

### Vote: ${VOTE}
EOF
    ;;
  SKEPTIC)
    cat <<EOF
## Skeptic (Round ${ROUND})

### Risiken
- [MITTEL] Mock-Risiko: nichts wirklich kritisch.

### Falsche Annahmen
- Keine.

### Maintenance-Lasten
- Keine signifikanten.

### Vote: ${VOTE}
EOF
    ;;
  PRAGMATIST)
    cat <<EOF
## Pragmatist Tie-Break (Round ${ROUND})

### Analyse
- **Proponent-Stärken:** Mock-Proponent-Argumente.
- **Skeptic-Stärken:** Mock-Skeptic-Argumente.

### Pre-Launch-ROI-Bewertung
- Nutzer-Value-Schätzung: mittel
- Aufwand-Schätzung: 2h
- ROI-Verdict: mittel

### Verdict: ${VOTE}

### Begründung
- Mock-Verdict aufgrund Test-Vorgabe.
EOF
    ;;
  *)
    printf '## Unknown Agent\n\n### Vote: abstain\n'
    ;;
esac
MOCK_EOF
chmod +x "$MOCK_BIN/claude"

# ---------------------------------------------------------------------------
# Wrapper: setzt MOCK_ROUND und Env für disput.sh
# run_disput <extra-env-vars...> -- <disput.sh-args...>
# ---------------------------------------------------------------------------
run_disput_with_env() {
  local env_args=()
  local disput_args=()
  local in_disput=0
  for arg in "$@"; do
    if [[ "$arg" == "--" ]]; then in_disput=1; continue; fi
    if [[ "$in_disput" == "1" ]]; then disput_args+=("$arg")
    else env_args+=("$arg"); fi
  done

  # Wir müssen MOCK_ROUND für jede Round-Berechnung setzen.
  # Da der Mock-Claude keinen State hat, geben wir ein Wrapper-Script aus,
  # das MOCK_ROUND aus der Runden-Iteration ableitet.
  # Trick: statt MOCK_ROUND statisch zu setzen, merken wir uns den Call-Count
  # via Counter-File und erhöhen Round pro 2 Agent-Calls (pro/ske).

  # Jeder Test bekommt sein eigenes Ledger-Verzeichnis → keine Kostenakkumulation zwischen Tests
  local test_ledger_dir="$SANDBOX/ledger-$$-$RANDOM"
  mkdir -p "$test_ledger_dir"

  local counter_file="$SANDBOX/call-counter-$$"
  printf '0' > "$counter_file"

  # Ersetze claude durch ein Round-aware Wrapper
  local smart_claude="$SANDBOX/smart-claude-$$"
  cat > "$smart_claude" <<SMARTEOF
#!/usr/bin/env bash
set -uo pipefail

# Count-based Round-Erkennung
COUNTER_FILE="${counter_file}"
CNT=\$(cat "\$COUNTER_FILE" 2>/dev/null || echo 0)
CNT=\$((CNT + 1))
printf '%d' "\$CNT" > "\$COUNTER_FILE"

# Round-Mapping:
# Call 1,2 → Round 1 (proponent, skeptic)
# Call 3,4 → Round 2 (proponent, skeptic)
# Call 5   → Round 2 pragmatist
# Call 6   → Round 3 pragmatist
if   [ "\$CNT" -le 2 ]; then export MOCK_ROUND=1
elif [ "\$CNT" -le 4 ]; then export MOCK_ROUND=2
elif [ "\$CNT" -le 5 ]; then export MOCK_ROUND=2
else export MOCK_ROUND=3
fi

exec "${MOCK_BIN}/claude" "\$@"
SMARTEOF
  chmod +x "$smart_claude"

  env \
    PATH="${SANDBOX}:${MOCK_BIN}:${PATH}" \
    CLAUDE_CMD="$smart_claude" \
    DISPUTES_DIR="$DISPUTES_DIR" \
    COST_CAP_LEDGER_DIR="$test_ledger_dir" \
    DISPUT_MOCK=1 \
    REPO_ROOT="$SANDBOX" \
    NTFY_TOPIC="" \
    NOTIFY_DRY_RUN=1 \
    "${env_args[@]}" \
    bash "$DISPUT_SH" "${disput_args[@]}"
}

# Erstellt ein Test-Proposal-File
make_proposal() {
  local name="$1"
  local file="$SANDBOX/proposals/${name}.md"
  mkdir -p "$SANDBOX/proposals"
  cat > "$file" <<'PROP_EOF'
# Test-Proposal

Ziel: Teste den Disput-Orchestrator.

Scope: lib/test.dart
PROP_EOF
  printf '%s' "$file"
}

# ---------------------------------------------------------------------------
# Hilfsfunktionen zum Lesen von Verdict-Feldern
# ---------------------------------------------------------------------------
verdict_field() {
  local disput_id="$1" field="$2"
  local f="$DISPUTES_DIR/$disput_id/verdict.md"
  grep "^${field}:" "$f" 2>/dev/null | head -n1 | sed "s/^${field}:[[:space:]]*//"
}

# Findet letzten Disput der das Proposal-Pattern im Namen trägt
# Arg 1: proposal_basename (Suffix des Disput-ID)
find_disput_by_proposal() {
  local basename_pattern="$1"
  ls -1t "$DISPUTES_DIR" 2>/dev/null | grep -v '^unresolved$' | grep -- "-${basename_pattern}$" | head -n1 || printf ''
}

find_latest_disput() {
  ls -1t "$DISPUTES_DIR" | grep -v '^unresolved$' | head -n1 2>/dev/null || printf ''
}

# ---------------------------------------------------------------------------
# Test-Overrides für cost_check_or_die
# ---------------------------------------------------------------------------
# Normalerweise nutzen wir die echte Bibliothek. Für Cost-Cap-Tests mocken wir
# cost_check_or_die via einen gefaketen cost-cap.sh override.

make_cost_cap_override() {
  local override_dir="$SANDBOX/cost-cap-override"
  mkdir -p "$override_dir"
  cat > "$override_dir/cost-cap.sh" <<'OVERRIDE_EOF'
#!/usr/bin/env bash
# Mock-Override: cost_check_or_die gibt immer exit 2 zurück
cost_check_or_die() { return 2; }
cost_record() { return 0; }
cost_today_usd() { printf '999.00\n'; }
cost_week_usd() { printf '999.00\n'; }
OVERRIDE_EOF
  printf '%s' "$override_dir"
}

# ---------------------------------------------------------------------------
# Test 1: Round-1-Konsens (accept+accept) → Verdict accept, kein Round 2
# ---------------------------------------------------------------------------
printf '\n--- Test 1: Round-1-Konsens (accept+accept) ---\n'
proposal1="$(make_proposal "t1-consensus-accept")"
output1="$(run_disput_with_env \
  MOCK_VOTE_PROPONENT_R1=accept \
  MOCK_VOTE_SKEPTIC_R1=accept \
  -- "$proposal1" 2>&1)" || true

disput1="$(find_disput_by_proposal "t1-consensus-accept")"
if [ -n "$disput1" ]; then
  status1="$(verdict_field "$disput1" "status")"
  rounds1="$(verdict_field "$disput1" "rounds")"
  decided_by1="$(verdict_field "$disput1" "decided_by")"

  if [ "$status1" = "accept" ]; then
    pass "T1: Verdict status=accept"
  else
    fail "T1: Verdict status='$status1' erwartet 'accept'"
  fi

  if [ "$rounds1" = "1" ]; then
    pass "T1: Nur 1 Runde (kein Round 2)"
  else
    fail "T1: rounds='$rounds1' erwartet '1'"
  fi

  if [ "$decided_by1" = "consensus" ]; then
    pass "T1: decided_by=consensus"
  else
    fail "T1: decided_by='$decided_by1' erwartet 'consensus'"
  fi

  # Sicherstellen kein round-2-file
  if [ ! -f "$DISPUTES_DIR/$disput1/round-2-proponent.md" ]; then
    pass "T1: Kein round-2-proponent.md vorhanden"
  else
    fail "T1: round-2-proponent.md existiert obwohl Konsens in Round 1"
  fi
else
  fail "T1: Kein Disput-Folder gefunden"
fi

# ---------------------------------------------------------------------------
# Test 2: Round-2-Tie-Break: R1 split → R2 split → Pragmatist accept
# ---------------------------------------------------------------------------
printf '\n--- Test 2: Round-2-Tie-Break ---\n'
proposal2="$(make_proposal "t2-round2-tiebreak")"
output2="$(run_disput_with_env \
  MOCK_VOTE_PROPONENT_R1=accept \
  MOCK_VOTE_SKEPTIC_R1=reject \
  MOCK_VOTE_PROPONENT_R2=accept \
  MOCK_VOTE_SKEPTIC_R2=reject \
  MOCK_VOTE_PRAGMATIST_R2=accept \
  -- "$proposal2" 2>&1)" || true

disput2="$(find_disput_by_proposal "t2-round2-tiebreak")"
if [ -n "$disput2" ]; then
  status2="$(verdict_field "$disput2" "status")"
  decided_by2="$(verdict_field "$disput2" "decided_by")"
  rounds2="$(verdict_field "$disput2" "rounds")"

  if [ "$status2" = "accept" ]; then
    pass "T2: Verdict status=accept (Pragmatist-Tie-Break)"
  else
    fail "T2: Verdict status='$status2' erwartet 'accept'"
  fi

  if [ "$decided_by2" = "pragmatist" ]; then
    pass "T2: decided_by=pragmatist"
  else
    fail "T2: decided_by='$decided_by2' erwartet 'pragmatist'"
  fi

  if [ -f "$DISPUTES_DIR/$disput2/round-2-pragmatist.md" ]; then
    pass "T2: round-2-pragmatist.md existiert"
  else
    fail "T2: round-2-pragmatist.md fehlt"
  fi
else
  fail "T2: Kein Disput-Folder gefunden"
fi

# ---------------------------------------------------------------------------
# Test 3: Round-3-Patt → unresolved + Stakeholder-Notify
# ---------------------------------------------------------------------------
printf '\n--- Test 3: Round-3-Patt → unresolved ---\n'
proposal3="$(make_proposal "t3-round3-unresolved")"
output3="$(run_disput_with_env \
  MOCK_VOTE_PROPONENT_R1=accept \
  MOCK_VOTE_SKEPTIC_R1=reject \
  MOCK_VOTE_PROPONENT_R2=accept \
  MOCK_VOTE_SKEPTIC_R2=reject \
  MOCK_VOTE_PRAGMATIST_R2=unresolved \
  MOCK_VOTE_PRAGMATIST_R3=unresolved \
  -- "$proposal3" 2>&1)" || true

disput3="$(find_disput_by_proposal "t3-round3-unresolved")"
if [ -n "$disput3" ]; then
  status3="$(verdict_field "$disput3" "status")"
  decided_by3="$(verdict_field "$disput3" "decided_by")"

  if [ "$status3" = "unresolved" ]; then
    pass "T3: Verdict status=unresolved"
  else
    fail "T3: Verdict status='$status3' erwartet 'unresolved'"
  fi

  if [ "$decided_by3" = "stakeholder-escalation" ]; then
    pass "T3: decided_by=stakeholder-escalation"
  else
    fail "T3: decided_by='$decided_by3' erwartet 'stakeholder-escalation'"
  fi

  # Check unresolved/ Symlink oder Kopie
  if [ -e "$DISPUTES_DIR/unresolved/$disput3" ]; then
    pass "T3: disputes/unresolved/<id> existiert"
  else
    fail "T3: disputes/unresolved/$disput3 fehlt"
  fi

  # Check round-3-pragmatist.md
  if [ -f "$DISPUTES_DIR/$disput3/round-3-pragmatist.md" ]; then
    pass "T3: round-3-pragmatist.md existiert"
  else
    fail "T3: round-3-pragmatist.md fehlt"
  fi
else
  fail "T3: Kein Disput-Folder gefunden"
fi

# ---------------------------------------------------------------------------
# Test 4: Cost-Cap-Hit → cost-cap-aborted
# ---------------------------------------------------------------------------
printf '\n--- Test 4: Cost-Cap-Hit → cost-cap-aborted ---\n'
proposal4="$(make_proposal "t4-cost-cap")"

# Wir nutzen einen gefakten cost-cap.sh, der cost_check_or_die immer exit 2 gibt.
# Trick: CLAUDE_PROJECT_DIR auf Sandbox setzen + cost-cap.sh darin überschreiben.
OVERRIDE_DIR="$(make_cost_cap_override)"

# Erstelle temp-disput.sh der die override cost-cap.sh sourcet
PATCHED_DISPUT="$SANDBOX/patched-disput.sh"
# Wir patchen via env: COST_CAP_LIB_OVERRIDE
cat > "$PATCHED_DISPUT" <<PATCHED_EOF
#!/usr/bin/env bash
set -uo pipefail
# Override: source gefaktes cost-cap.sh VOR dem echten
source "${OVERRIDE_DIR}/cost-cap.sh"
# Dann disput.sh ab der Dispatch-Stelle aufrufen
# Wir setzen die Funktion call_agent direkt
export DISPUT_MOCK=1
export DISPUTES_DIR="${DISPUTES_DIR}"
export COST_CAP_LEDGER_DIR="${COST_CAP_LEDGER_DIR}"
export REPO_ROOT="${SANDBOX}"
export NTFY_TOPIC=""
export NOTIFY_DRY_RUN=1
export CLAUDE_CMD="${MOCK_BIN}/claude"

# Source original disput.sh aber überschreibe cost_check_or_die
source "${DISPUT_SH}"
PATCHED_EOF
chmod +x "$PATCHED_DISPUT"

# Eigenes Ledger-Verzeichnis für T4 mit vorgeladenen Kosten ($15 → über $10-Cap)
T4_LEDGER_DIR="$SANDBOX/t4-ledger"
mkdir -p "$T4_LEDGER_DIR"
TODAY_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{"ts":"%s","agent":"fake","usd":15.00,"pid":1}\n' "$TODAY_TS" > "$T4_LEDGER_DIR/cost-ledger.jsonl"

# T4 nutzt simplen mock-claude (kein round-aware wrapper nötig, da sofortiger Abbruch)
T4_COUNTER="$SANDBOX/t4-counter"
printf '0' > "$T4_COUNTER"
T4_SMART="$SANDBOX/t4-smart-claude"
cat > "$T4_SMART" <<T4SMARTEOF
#!/usr/bin/env bash
export MOCK_ROUND=1
exec "${MOCK_BIN}/claude" "\$@"
T4SMARTEOF
chmod +x "$T4_SMART"

output4="$(env \
  PATH="${MOCK_BIN}:${PATH}" \
  CLAUDE_CMD="$T4_SMART" \
  DISPUTES_DIR="$DISPUTES_DIR" \
  COST_CAP_LEDGER_DIR="$T4_LEDGER_DIR" \
  DISPUT_MOCK=1 \
  REPO_ROOT="$SANDBOX" \
  NTFY_TOPIC="" \
  NOTIFY_DRY_RUN=1 \
  MOCK_VOTE_PROPONENT_R1=accept \
  MOCK_VOTE_SKEPTIC_R1=accept \
  bash "$DISPUT_SH" "$proposal4" 2>&1)" || true

disput4="$(find_disput_by_proposal "t4-cost-cap")"
if [ -n "$disput4" ]; then
  status4="$(verdict_field "$disput4" "status")"
  if [ "$status4" = "cost-cap-aborted" ]; then
    pass "T4: Verdict status=cost-cap-aborted bei Budget-Überschreitung"
  else
    fail "T4: Verdict status='$status4' erwartet 'cost-cap-aborted'"
  fi
else
  fail "T4: Kein Disput-Folder gefunden"
fi

# ---------------------------------------------------------------------------
# Test 5: --status <id> zeigt Verdict
# ---------------------------------------------------------------------------
printf '\n--- Test 5: --status <id> ---\n'
# Nutze disput1 aus Test 1
if [ -n "${disput1:-}" ]; then
  status_output="$(env \
    DISPUTES_DIR="$DISPUTES_DIR" \
    bash "$DISPUT_SH" --status "$disput1" 2>/dev/null)" || true

  if printf '%s' "$status_output" | grep -q "^status:"; then
    pass "T5: --status gibt Verdict-File aus (status:-Zeile vorhanden)"
  else
    fail "T5: --status gibt kein valides Verdict aus"
  fi

  if printf '%s' "$status_output" | grep -q "^id: $disput1"; then
    pass "T5: --status zeigt korrekte id"
  else
    fail "T5: --status zeigt falsche oder fehlende id"
  fi
else
  fail "T5: disput1 aus Test 1 nicht verfügbar"
fi

# ---------------------------------------------------------------------------
# Test 6: --resume <id> — Mock mit nur round-1-files → produziert round-2
# ---------------------------------------------------------------------------
printf '\n--- Test 6: --resume <id> ---\n'
# Erzeuge manuell einen Teil-Disput (nur Round 1)
RESUME_ID="20990101T000000-resume-test-proposal"
RESUME_DIR="$DISPUTES_DIR/$RESUME_ID"
mkdir -p "$RESUME_DIR"

proposal_r="$(make_proposal "resume-test-proposal")"

# Proposal-sandwiched anlegen
{
  printf '<<<UNTRUSTED_PROPOSAL>>>\n'
  cat "$proposal_r"
  printf '\n<<<END_UNTRUSTED>>>\n'
} > "$RESUME_DIR/proposal-sandwiched.md"

# Round-1-Files anlegen (Patt: accept vs reject)
cat > "$RESUME_DIR/round-1-proponent.md" <<'R1_PRO'
## Proponent (Round 1)

### Vorteile
- Mock: sinnvoll.

### Empfohlene Implementation
- Implementiere.

### Vote: accept
R1_PRO

cat > "$RESUME_DIR/round-1-skeptic.md" <<'R1_SKP'
## Skeptic (Round 1)

### Risiken
- [MITTEL] Mock-Risiko.

### Falsche Annahmen
- Keine.

### Maintenance-Lasten
- Keine.

### Vote: reject
R1_SKP

# Verdict-File (cost-cap-aborted Vorversion)
cat > "$RESUME_DIR/verdict.md" <<RESUME_VERDICT
---
id: ${RESUME_ID}
proposal: ${proposal_r}
status: cost-cap-aborted
decided_by: orchestrator
rounds: 1
total_cost_usd: 0.00
created_at: 2099-01-01T00:00:00Z
decided_at: 2099-01-01T00:00:01Z
---

## Verdict

Abgebrochen.

## Round-Summary

- Round 1: proponent=accept, skeptic=reject
RESUME_VERDICT

output6="$(env \
  PATH="${MOCK_BIN}:${PATH}" \
  CLAUDE_CMD="$MOCK_BIN/claude" \
  DISPUTES_DIR="$DISPUTES_DIR" \
  COST_CAP_LEDGER_DIR="$COST_CAP_LEDGER_DIR" \
  DISPUT_MOCK=1 \
  REPO_ROOT="$SANDBOX" \
  NTFY_TOPIC="" \
  NOTIFY_DRY_RUN=1 \
  MOCK_VOTE_PROPONENT_R2=accept \
  MOCK_VOTE_SKEPTIC_R2=accept \
  MOCK_ROUND=2 \
  bash "$DISPUT_SH" --resume "$RESUME_ID" 2>&1)" || true

if [ -f "$RESUME_DIR/round-2-proponent.md" ] || [ -f "$RESUME_DIR/round-2-skeptic.md" ]; then
  pass "T6: --resume produziert round-2-files"
else
  fail "T6: --resume produziert keine round-2-files (output: $output6)"
fi

# Verdict muss aktualisiert sein (nicht mehr cost-cap-aborted)
resumed_status="$(verdict_field "$RESUME_ID" "status" 2>/dev/null || printf 'unknown')"
if [ "$resumed_status" != "cost-cap-aborted" ]; then
  pass "T6: Resume aktualisiert Verdict (status=$resumed_status)"
else
  fail "T6: Verdict-Status nach Resume noch 'cost-cap-aborted'"
fi

# ---------------------------------------------------------------------------
# Test 7: Verdict-File-Format — valides YAML-Frontmatter + Markdown-Body
# ---------------------------------------------------------------------------
printf '\n--- Test 7: Verdict-File-Format ---\n'
if [ -n "${disput1:-}" ]; then
  verdict_file="$DISPUTES_DIR/$disput1/verdict.md"

  # YAML-Frontmatter: beginnt und endet mit ---
  first_line="$(head -n1 "$verdict_file")"
  if [ "$first_line" = "---" ]; then
    pass "T7: Verdict-File beginnt mit ---"
  else
    fail "T7: Verdict-File beginnt nicht mit --- (ist: '$first_line')"
  fi

  # Pflicht-Felder im Frontmatter
  for field in id proposal status decided_by rounds total_cost_usd created_at decided_at; do
    if grep -q "^${field}:" "$verdict_file"; then
      pass "T7: Frontmatter-Feld '$field' vorhanden"
    else
      fail "T7: Frontmatter-Feld '$field' fehlt"
    fi
  done

  # Markdown-Body: ## Verdict und ## Round-Summary
  if grep -q "^## Verdict" "$verdict_file"; then
    pass "T7: ## Verdict-Sektion vorhanden"
  else
    fail "T7: ## Verdict-Sektion fehlt"
  fi

  if grep -q "^## Round-Summary" "$verdict_file"; then
    pass "T7: ## Round-Summary-Sektion vorhanden"
  else
    fail "T7: ## Round-Summary-Sektion fehlt"
  fi

  # total_cost_usd ist eine Zahl
  total_cost="$(verdict_field "$disput1" "total_cost_usd")"
  if printf '%s' "$total_cost" | grep -qE '^[0-9]+\.[0-9]+$'; then
    pass "T7: total_cost_usd='$total_cost' ist valide Zahl"
  else
    fail "T7: total_cost_usd='$total_cost' ist keine valide Zahl"
  fi
else
  fail "T7: disput1 nicht verfügbar für Format-Test"
fi

# ---------------------------------------------------------------------------
# Ergebnis
# ---------------------------------------------------------------------------
printf '\n========================================\n'
printf 'Ergebnis: %d PASS, %d FAIL\n' "$PASS" "$FAIL"
printf '========================================\n'

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
