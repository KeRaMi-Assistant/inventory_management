#!/usr/bin/env bash
# verify/cost-tamper.sh — Sandbox tests for P3-10 Cost-Cap-Bypass-Schutz.
#
# Tests:
#   1. Normal-Append: 5× cost_record → cost-verify exit 0.
#   2. Tampering — entfernte Zeile: lösche line 3 → cost-verify exit 1.
#   3. Tampering — modifizierter usd: ändere line 2 usd-Wert → cost-verify exit 1.
#   4. Tampering — falscher entry_hash: ändere line 4 entry_hash → cost-verify exit 1.
#   5. Watchdog-Integration: Mock-Tampering → watchdog --once → PANIC-Marker.
#   6. flock-Race: 10 parallele cost_record → alle Hash-Chain-konsistent.
#
# Exit 0 bei allen pass, exit 1 bei erstem Fehler.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SCRIPTS_DIR}/../.." && pwd)"
COST_CAP_LIB="${SCRIPTS_DIR}/lib/cost-cap.sh"
COST_VERIFY="${SCRIPTS_DIR}/cost-verify.sh"
WATCHDOG="${SCRIPTS_DIR}/watchdog.sh"

PASS=0
FAIL=0
_pass() { printf '[PASS] %s\n' "$*"; (( PASS++ )) || true; }
_fail() { printf '[FAIL] %s\n' "$*" >&2; (( FAIL++ )) || true; }

# ---------------------------------------------------------------------------
# Helper: create fresh sandbox
# ---------------------------------------------------------------------------
_make_sandbox() {
  local dir
  dir="$(mktemp -d /tmp/cost-tamper-test.XXXXXX)"
  printf '%s' "$dir"
}

# ---------------------------------------------------------------------------
# Test 1 — Normal-Append: 5× cost_record → cost-verify exit 0
# ---------------------------------------------------------------------------
test_normal_append() {
  local sandbox
  sandbox="$(_make_sandbox)"
  export COST_CAP_LEDGER_DIR="$sandbox"

  source "$COST_CAP_LIB"

  cost_record "agent-a" "0.10"
  cost_record "agent-b" "0.20"
  cost_record "agent-c" "0.30"
  cost_record "agent-d" "0.40"
  cost_record "agent-e" "0.50"

  local rc=0
  COST_CAP_LEDGER_DIR="$sandbox" "$COST_VERIFY" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq 0 ]; then
    _pass "Test 1: Normal-Append (5 entries) → exit 0"
  else
    _fail "Test 1: Normal-Append → expected exit 0, got $rc"
  fi

  rm -rf "$sandbox"
}

# ---------------------------------------------------------------------------
# Test 2 — Tampering: entfernte Zeile (line 3) → cost-verify exit 1
# ---------------------------------------------------------------------------
test_removed_line() {
  local sandbox
  sandbox="$(_make_sandbox)"
  export COST_CAP_LEDGER_DIR="$sandbox"

  source "$COST_CAP_LIB"

  cost_record "agent-a" "0.10"
  cost_record "agent-b" "0.20"
  cost_record "agent-c" "0.30"
  cost_record "agent-d" "0.40"
  cost_record "agent-e" "0.50"

  local ledger="${sandbox}/cost-ledger.jsonl"
  # Remove line 3
  python3 -c "
lines = open('$ledger').readlines()
del lines[2]  # 0-based → line 3
open('$ledger', 'w').writelines(lines)
"

  local rc=0
  COST_CAP_LEDGER_DIR="$sandbox" "$COST_VERIFY" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq 1 ]; then
    _pass "Test 2: Removed line 3 → exit 1"
  else
    _fail "Test 2: Removed line 3 → expected exit 1, got $rc"
  fi

  rm -rf "$sandbox"
}

# ---------------------------------------------------------------------------
# Test 3 — Tampering: modifizierter usd in line 2 → cost-verify exit 1
# ---------------------------------------------------------------------------
test_modified_usd() {
  local sandbox
  sandbox="$(_make_sandbox)"
  export COST_CAP_LEDGER_DIR="$sandbox"

  source "$COST_CAP_LIB"

  cost_record "agent-a" "0.10"
  cost_record "agent-b" "0.20"
  cost_record "agent-c" "0.30"
  cost_record "agent-d" "0.40"
  cost_record "agent-e" "0.50"

  local ledger="${sandbox}/cost-ledger.jsonl"
  # Modify usd in line 2 (0-based index 1) from 0.2 to 9.99
  python3 -c "
import json
lines = open('$ledger').readlines()
entry = json.loads(lines[1])
entry['usd'] = 9.99
lines[1] = json.dumps(entry) + '\n'
open('$ledger', 'w').writelines(lines)
"

  local rc=0
  COST_CAP_LEDGER_DIR="$sandbox" "$COST_VERIFY" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq 1 ]; then
    _pass "Test 3: Modified usd in line 2 → exit 1"
  else
    _fail "Test 3: Modified usd in line 2 → expected exit 1, got $rc"
  fi

  rm -rf "$sandbox"
}

# ---------------------------------------------------------------------------
# Test 4 — Tampering: falscher entry_hash in line 4 → cost-verify exit 1
# ---------------------------------------------------------------------------
test_wrong_entry_hash() {
  local sandbox
  sandbox="$(_make_sandbox)"
  export COST_CAP_LEDGER_DIR="$sandbox"

  source "$COST_CAP_LIB"

  cost_record "agent-a" "0.10"
  cost_record "agent-b" "0.20"
  cost_record "agent-c" "0.30"
  cost_record "agent-d" "0.40"
  cost_record "agent-e" "0.50"

  local ledger="${sandbox}/cost-ledger.jsonl"
  # Corrupt entry_hash in line 4 (0-based index 3)
  python3 -c "
import json
lines = open('$ledger').readlines()
entry = json.loads(lines[3])
entry['entry_hash'] = 'deadbeef' * 8  # 64 hex chars, but wrong
lines[3] = json.dumps(entry) + '\n'
open('$ledger', 'w').writelines(lines)
"

  local rc=0
  COST_CAP_LEDGER_DIR="$sandbox" "$COST_VERIFY" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq 1 ]; then
    _pass "Test 4: Wrong entry_hash in line 4 → exit 1"
  else
    _fail "Test 4: Wrong entry_hash in line 4 → expected exit 1, got $rc"
  fi

  rm -rf "$sandbox"
}

# ---------------------------------------------------------------------------
# Test 5 — Watchdog-Integration: Mock-Tampering → watchdog --once → PANIC-Marker
# ---------------------------------------------------------------------------
test_watchdog_tamper_panic() {
  local sandbox
  sandbox="$(_make_sandbox)"
  export COST_CAP_LEDGER_DIR="$sandbox"

  source "$COST_CAP_LIB"

  cost_record "agent-a" "0.10"
  cost_record "agent-b" "0.20"
  cost_record "agent-c" "0.30"

  # Tamper: remove line 2
  local ledger="${sandbox}/cost-ledger.jsonl"
  python3 -c "
lines = open('$ledger').readlines()
del lines[1]
open('$ledger', 'w').writelines(lines)
"

  # Build minimal overseer dir structure
  local overseer_dir="${sandbox}/overseer"
  mkdir -p "$overseer_dir"

  # Run watchdog --once with sandbox paths
  # Suppress notify (NOTIFY_DRY_RUN=1), override all resource checks to safe defaults
  local watchdog_rc=0
  REPO_ROOT="$sandbox" \
  COST_CAP_LEDGER_DIR="$sandbox" \
  NOTIFY_DRY_RUN=1 \
  MOCK_DISK_FREE_GB=100 \
  MOCK_DISK_FREE_PCT=80 \
  MOCK_WORKTREE_COUNT=1 \
  MOCK_INBOX_COUNT=0 \
  MOCK_STASH_COUNT=0 \
  OVERSEER_CAP_TODAY=1000 \
  OVERSEER_CAP_WEEK=5000 \
    "$WATCHDOG" --once 2>/dev/null || watchdog_rc=$?

  local panic_marker="${sandbox}/.claude/overseer/PANIC"
  if [ -f "$panic_marker" ]; then
    local content
    content="$(cat "$panic_marker")"
    if printf '%s' "$content" | grep -q "cost-ledger-tampering-detected"; then
      _pass "Test 5: Watchdog --once with tampered ledger → PANIC marker written"
    else
      _fail "Test 5: PANIC marker exists but wrong content: $content"
    fi
  else
    _fail "Test 5: Watchdog --once with tampered ledger → PANIC marker NOT found at $panic_marker"
  fi

  rm -rf "$sandbox"
}

# ---------------------------------------------------------------------------
# Test 6 — flock-Race: 10 parallele cost_record → alle Hash-Chain-konsistent
# ---------------------------------------------------------------------------
test_flock_race() {
  local sandbox
  sandbox="$(_make_sandbox)"
  export COST_CAP_LEDGER_DIR="$sandbox"

  # Run 10 parallel cost_record calls
  local pids=()
  for i in $(seq 1 10); do
    (
      source "$COST_CAP_LIB"
      COST_CAP_LEDGER_DIR="$sandbox" cost_record "agent-race-${i}" "0.0${i}"
    ) &
    pids+=($!)
  done

  # Wait for all
  local all_ok=true
  for p in "${pids[@]}"; do
    wait "$p" || { all_ok=false; }
  done

  if [ "$all_ok" = "false" ]; then
    _fail "Test 6: Some parallel cost_record processes failed"
    rm -rf "$sandbox"
    return
  fi

  # Verify hash-chain
  local rc=0
  COST_CAP_LEDGER_DIR="$sandbox" "$COST_VERIFY" >/dev/null 2>&1 || rc=$?

  # Count entries
  local ledger="${sandbox}/cost-ledger.jsonl"
  local count=0
  if [ -f "$ledger" ]; then
    count=$(wc -l < "$ledger" | tr -d ' ')
  fi

  if [ "$rc" -eq 0 ] && [ "$count" -eq 10 ]; then
    _pass "Test 6: flock-Race — 10 parallel cost_record, all chain-consistent (count=$count)"
  elif [ "$rc" -ne 0 ]; then
    _fail "Test 6: flock-Race → chain invalid (cost-verify exit $rc), count=$count"
  else
    _fail "Test 6: flock-Race → count mismatch: expected 10, got $count"
  fi

  rm -rf "$sandbox"
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
printf '=== cost-tamper verify suite ===\n'

test_normal_append
test_removed_line
test_modified_usd
test_wrong_entry_hash
test_watchdog_tamper_panic
test_flock_race

printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
