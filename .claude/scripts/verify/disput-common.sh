#!/usr/bin/env bash
# verify/disput-common.sh — Unit-Tests für lib/disput-common.sh
#
# Tests:
#   1. extract_vote mit gültigem Output → gibt decision, exit 0
#   2. extract_vote ohne Vote-Zeile → gibt "abstain", exit 0 (file exists)
#   3. extract_vote mit nicht-existenter Datei → exit 1
#   4. call_agent mit Mock-claude → mock-stdout zurück
#   5. compute_consensus [accept, accept] → consensus_accept
#   6. compute_consensus [accept, reject] → needs_tiebreak
#   7. compute_consensus [reject, reject] → consensus_reject
#   8. write_round_file schreibt korrekten Pfad
#   9. disput_cost_record ruft cost_record auf
#  10. Bestehende disput-flow.sh Tests grün nach source-Kompatibilität

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
LIB="$LIB_DIR/disput-common.sh"
DISPUT_FLOW_VERIFY="$SCRIPT_DIR/disput-flow.sh"

PASS=0
FAIL=0

pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

SANDBOX="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$SANDBOX'" EXIT

# ---------------------------------------------------------------------------
# Setup: stub cost_check_or_die + cost_record + audit_record
# ---------------------------------------------------------------------------
cost_check_or_die() { return 0; }
cost_record()       { return 0; }
audit_record()      { return 0; }
export -f cost_check_or_die cost_record audit_record 2>/dev/null || true

# Source der Lib
DISPUTES_DIR="$SANDBOX/disputes"
CLAUDE_CMD="echo"   # wird in T4 durch einen richtigen Mock ersetzt
COST_PER_AGENT_CALL="0.10"
DISPUT_CAP_PER_DISPUTE="10"
DISPUT_CAP_PER_DAY="20"
export DISPUTES_DIR CLAUDE_CMD COST_PER_AGENT_CALL
export DISPUT_CAP_PER_DISPUTE DISPUT_CAP_PER_DAY DISPUT_MOCK=0
# INTAKE_COUNCIL_DIR deliberately NOT exported here; tests manage it individually.
unset INTAKE_COUNCIL_DIR

mkdir -p "$DISPUTES_DIR" "$SANDBOX/intake-council"

# shellcheck source=lib/disput-common.sh
source "$LIB"

# ---------------------------------------------------------------------------
# Test 1: extract_vote mit gültigem Output → gibt decision, exit 0
# ---------------------------------------------------------------------------
printf '\n--- Test 1: extract_vote mit gültigem Vote ---\n'
T1_FILE="$SANDBOX/t1-agent.md"
cat > "$T1_FILE" <<'EOF'
## Agent Output

### Risiken
- Keine.

### Vote: accept
EOF

result1="$(extract_vote "$T1_FILE")"
rc1=$?
if [ "$result1" = "accept" ]; then
  pass "T1: extract_vote gibt 'accept'"
else
  fail "T1: extract_vote gibt '$result1' statt 'accept'"
fi

# ---------------------------------------------------------------------------
# Test 2: extract_vote ohne Vote-Zeile → gibt "abstain"
# ---------------------------------------------------------------------------
printf '\n--- Test 2: extract_vote ohne Vote-Zeile ---\n'
T2_FILE="$SANDBOX/t2-no-vote.md"
cat > "$T2_FILE" <<'EOF'
## Agent Output

Kein Vote in diesem Dokument.
EOF

result2="$(extract_vote "$T2_FILE")"
if [ "$result2" = "abstain" ]; then
  pass "T2: extract_vote gibt 'abstain' wenn keine Vote-Zeile"
else
  fail "T2: extract_vote gibt '$result2' statt 'abstain'"
fi

# ---------------------------------------------------------------------------
# Test 3: extract_vote mit nicht-existenter Datei → exit 1
# ---------------------------------------------------------------------------
printf '\n--- Test 3: extract_vote mit nicht-existenter Datei ---\n'
# Capture exit code without swallowing via || true
extract_vote "$SANDBOX/does-not-exist.md" > /dev/null 2>&1
rc3=$?
# extract_vote gibt exit 1 bei nicht-existenter Datei
if [ "$rc3" = "1" ]; then
  pass "T3: extract_vote exit 1 bei nicht-existenter Datei"
else
  fail "T3: extract_vote exit=$rc3 erwartet 1"
fi

# Test auch mit ### Verdict: (Fallback)
T3B_FILE="$SANDBOX/t3b-verdict.md"
cat > "$T3B_FILE" <<'EOF'
## Pragmatist Tie-Break

### Analyse
- Neutrales Urteil.

### Verdict: reject

### Begründung
- Mock-Test.
EOF
result3b="$(extract_vote "$T3B_FILE")"
if [ "$result3b" = "reject" ]; then
  pass "T3b: extract_vote parst '### Verdict:' als Fallback"
else
  fail "T3b: extract_vote gibt '$result3b' statt 'reject' bei Verdict-Fallback"
fi

# ---------------------------------------------------------------------------
# Test 4: call_agent mit Mock-claude → mock-stdout zurück
# ---------------------------------------------------------------------------
printf '\n--- Test 4: call_agent mit Mock-claude ---\n'
MOCK_BIN="$SANDBOX/mock-bin"
mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/mock-claude" <<'MOCK_EOF'
#!/usr/bin/env bash
printf '## Mock Agent Output\n\n### Vote: accept\n'
MOCK_EOF
chmod +x "$MOCK_BIN/mock-claude"

export CLAUDE_CMD="$MOCK_BIN/mock-claude"
export DISPUT_ID="test-disput-t4"
mkdir -p "$DISPUTES_DIR/$DISPUT_ID"

T4_OUTPUT="$SANDBOX/t4-output.md"
call_agent "test-agent" "$T4_OUTPUT" 2>/dev/null
if [ -f "$T4_OUTPUT" ]; then
  t4_content="$(cat "$T4_OUTPUT")"
  if printf '%s' "$t4_content" | grep -q '### Vote: accept'; then
    pass "T4: call_agent schreibt mock-stdout in output-file"
  else
    fail "T4: call_agent output enthält keinen '### Vote: accept' (content: $t4_content)"
  fi
else
  fail "T4: call_agent hat kein output-file erzeugt"
fi

# Vote extrahierbar
t4_vote="$(extract_vote "$T4_OUTPUT")"
if [ "$t4_vote" = "accept" ]; then
  pass "T4: extract_vote auf call_agent-Output → 'accept'"
else
  fail "T4: extract_vote → '$t4_vote' statt 'accept'"
fi

# ---------------------------------------------------------------------------
# Test 5: compute_consensus [accept, accept] → consensus_accept
# ---------------------------------------------------------------------------
printf '\n--- Test 5: compute_consensus accept+accept ---\n'
result5="$(compute_consensus "accept" "accept")"
if [ "$result5" = "consensus_accept" ]; then
  pass "T5: compute_consensus(accept,accept) = consensus_accept"
else
  fail "T5: compute_consensus = '$result5' erwartet 'consensus_accept'"
fi

# ---------------------------------------------------------------------------
# Test 6: compute_consensus [accept, reject] → needs_tiebreak
# ---------------------------------------------------------------------------
printf '\n--- Test 6: compute_consensus accept+reject ---\n'
result6="$(compute_consensus "accept" "reject")"
if [ "$result6" = "needs_tiebreak" ]; then
  pass "T6: compute_consensus(accept,reject) = needs_tiebreak"
else
  fail "T6: compute_consensus = '$result6' erwartet 'needs_tiebreak'"
fi

# ---------------------------------------------------------------------------
# Test 7: compute_consensus [reject, reject] → consensus_reject
# ---------------------------------------------------------------------------
printf '\n--- Test 7: compute_consensus reject+reject ---\n'
result7="$(compute_consensus "reject" "reject")"
if [ "$result7" = "consensus_reject" ]; then
  pass "T7: compute_consensus(reject,reject) = consensus_reject"
else
  fail "T7: compute_consensus = '$result7' erwartet 'consensus_reject'"
fi

# Bonus: 3-way all accept
result7b="$(compute_consensus "accept" "accept-with-changes" "accept")"
if [ "$result7b" = "consensus_accept" ]; then
  pass "T7b: compute_consensus(accept,accept-with-changes,accept) = consensus_accept"
else
  fail "T7b: compute_consensus = '$result7b' erwartet 'consensus_accept'"
fi

# ---------------------------------------------------------------------------
# Test 8: write_round_file schreibt korrekten Pfad
# ---------------------------------------------------------------------------
printf '\n--- Test 8: write_round_file ---\n'
T8_DISPUT_ID="test-disput-t8"
# Ensure INTAKE_COUNCIL_DIR is NOT set so write goes to DISPUTES_DIR
unset INTAKE_COUNCIL_DIR
write_round_file "$T8_DISPUT_ID" "1" "proponent" "## Proponent\n\n### Vote: accept" 2>/dev/null

expected_path="$DISPUTES_DIR/$T8_DISPUT_ID/round-1-proponent.md"
if [ -f "$expected_path" ]; then
  pass "T8: write_round_file schreibt nach disputes/<id>/round-1-proponent.md"
else
  fail "T8: Datei fehlt: $expected_path"
fi

# Mit INTAKE_COUNCIL_DIR
T8B_DISPUT_ID="intake-test-t8b"
INTAKE_COUNCIL_DIR="$SANDBOX/intake-council"
export INTAKE_COUNCIL_DIR
write_round_file "$T8B_DISPUT_ID" "2" "skeptic" "## Skeptic\n\n### Vote: reject" 2>/dev/null

expected_intake="$INTAKE_COUNCIL_DIR/$T8B_DISPUT_ID/round-2-skeptic.md"
if [ -f "$expected_intake" ]; then
  pass "T8b: write_round_file mit INTAKE_COUNCIL_DIR schreibt nach intake-council/<id>/..."
else
  fail "T8b: Datei fehlt: $expected_intake"
fi
# Reset INTAKE_COUNCIL_DIR
unset INTAKE_COUNCIL_DIR

# ---------------------------------------------------------------------------
# Test 9: disput_cost_record ruft cost_record auf (kein Fehler)
# ---------------------------------------------------------------------------
printf '\n--- Test 9: disput_cost_record ---\n'
T9_LOG="$SANDBOX/t9-cost-log.txt"
# Override cost_record um Aufruf zu tracken
cost_record() {
  printf '%s %s\n' "$1" "$2" >> "$T9_LOG"
  return 0
}

disput_cost_record "proponent" "0.75"
if [ -f "$T9_LOG" ] && grep -q "disput-proponent 0.75" "$T9_LOG"; then
  pass "T9: disput_cost_record ruft cost_record mit 'disput-<role>' + usd auf"
else
  fail "T9: disput_cost_record hat cost_record nicht korrekt aufgerufen (log: $(cat "$T9_LOG" 2>/dev/null || echo 'leer'))"
fi

# Restore cost_record stub
cost_record() { return 0; }

# ---------------------------------------------------------------------------
# Test 10: check_consensus 2-arg (Rückwärtskompatibilität für disput.sh)
# ---------------------------------------------------------------------------
printf '\n--- Test 10: check_consensus 2-arg (disput.sh Kompatibilität) ---\n'
r10a="$(check_consensus "accept" "accept")"
if [[ "$r10a" == "consensus accept" ]]; then
  pass "T10: check_consensus(accept,accept) = 'consensus accept'"
else
  fail "T10: check_consensus = '$r10a'"
fi

r10b="$(check_consensus "accept" "reject")"
if [[ "$r10b" == "no-consensus" ]]; then
  pass "T10: check_consensus(accept,reject) = 'no-consensus'"
else
  fail "T10: check_consensus = '$r10b'"
fi

r10c="$(check_consensus "accept" "accept-with-changes")"
if [[ "$r10c" == "consensus accept-with-changes" ]]; then
  pass "T10: check_consensus(accept,accept-with-changes) = 'consensus accept-with-changes'"
else
  fail "T10: check_consensus = '$r10c'"
fi

# ---------------------------------------------------------------------------
# Test 11: is_final_verdict
# ---------------------------------------------------------------------------
printf '\n--- Test 11: is_final_verdict ---\n'
if is_final_verdict "accept"; then
  pass "T11: is_final_verdict(accept) = true"
else
  fail "T11: is_final_verdict(accept) soll true sein"
fi
if ! is_final_verdict "abstain"; then
  pass "T11: is_final_verdict(abstain) = false"
else
  fail "T11: is_final_verdict(abstain) soll false sein"
fi

# ---------------------------------------------------------------------------
# Ergebnis
# ---------------------------------------------------------------------------
printf '\n========================================\n'
printf 'disput-common.sh: %d PASS, %d FAIL\n' "$PASS" "$FAIL"
printf '========================================\n'

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
