#!/usr/bin/env bash
# cost-ledger-append.sh — Verify-Skript für P0-2a (cost_record / Ledger-Append)
#
# Führt alle Acceptance-Tests aus. Exit 0 = alle pass.
# Nutzung: bash .claude/scripts/verify/cost-ledger-append.sh

set -uo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

pass() { printf '[PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '[FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }

# Sandbox-Verzeichnis für alle Tests (wird am Ende entfernt)
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export COST_CAP_LEDGER_DIR="$SANDBOX/overseer"

# ---------------------------------------------------------------------------
# Test 1: Source klappt
# ---------------------------------------------------------------------------
set +e
( source "$LIB_DIR/cost-cap.sh" ) 2>/dev/null
_t1_rc=$?
set -e
if [ "$_t1_rc" -eq 0 ]; then
  pass "T1: source cost-cap.sh"
else
  fail "T1: source cost-cap.sh (exit $_t1_rc)"
fi

# Re-source für nachfolgende Tests
# shellcheck source=/dev/null
source "$LIB_DIR/cost-cap.sh"

# ---------------------------------------------------------------------------
# Test 2: Einzelner cost_record → 1 Zeile im Ledger
# ---------------------------------------------------------------------------
rm -rf "$SANDBOX/overseer"  # sauberer Zustand
cost_record "test-agent" "0.05"
LEDGER="$SANDBOX/overseer/cost-ledger.jsonl"

line_count=$(wc -l < "$LEDGER" | tr -d ' ')
if [ "$line_count" -eq 1 ]; then
  pass "T2: 1 Zeile im Ledger nach einzelnem cost_record"
else
  fail "T2: Erwartet 1 Zeile, erhalten $line_count"
fi

# JSON parsierbar?
if python3 -c "import json,sys; json.loads(open('$LEDGER').read())" 2>/dev/null; then
  pass "T2b: Zeile ist valides JSON"
else
  fail "T2b: Zeile ist kein valides JSON"
fi

# ---------------------------------------------------------------------------
# Test 3: Parallel-Append — 10 parallele Prozesse, genau 10 Zeilen, alle JSON
# ---------------------------------------------------------------------------
rm -rf "$SANDBOX/overseer"  # sauberer Zustand

PIDS=()
for i in $(seq 1 10); do
  (
    export COST_CAP_LEDGER_DIR="$SANDBOX/overseer"
    # shellcheck source=/dev/null
    source "$LIB_DIR/cost-cap.sh"
    cost_record "parallel-agent-$i" "0.0$i"
  ) &
  PIDS+=($!)
done

# Auf alle warten
ALL_OK=true
for pid in "${PIDS[@]}"; do
  wait "$pid" || ALL_OK=false
done

if $ALL_OK; then
  pass "T3a: Alle 10 parallelen cost_record-Calls beendet ohne Fehler"
else
  fail "T3a: Mindestens ein paralleler cost_record-Call ist fehlgeschlagen"
fi

LEDGER="$SANDBOX/overseer/cost-ledger.jsonl"
if [ -f "$LEDGER" ]; then
  parallel_lines=$(wc -l < "$LEDGER" | tr -d ' ')
else
  parallel_lines=0
fi

if [ "$parallel_lines" -eq 10 ]; then
  pass "T3b: Genau 10 Zeilen im Ledger nach 10 parallelen Calls"
else
  fail "T3b: Erwartet 10 Zeilen, erhalten $parallel_lines"
fi

# Alle Zeilen JSON-parsierbar?
bad_lines=0
while IFS= read -r line; do
  if ! python3 -c "import json,sys; json.loads(sys.argv[1])" "$line" 2>/dev/null; then
    ((bad_lines++))
  fi
done < "$LEDGER"

if [ "$bad_lines" -eq 0 ]; then
  pass "T3c: Alle 10 Zeilen sind valide JSON (keine Korruption)"
else
  fail "T3c: $bad_lines korrupte Zeile(n) nach Parallel-Append"
fi

# ---------------------------------------------------------------------------
# Test 4: Leerer agent → exit 1
# ---------------------------------------------------------------------------
rm -rf "$SANDBOX/overseer"
set +e
cost_record "" "0.05"
rc=$?
set -e
if [ "$rc" -eq 1 ]; then
  pass "T4: cost_record mit leerem agent → exit 1"
else
  fail "T4: Erwartet exit 1, erhalten exit $rc"
fi

# Kein Ledger-Eintrag?
if [ ! -f "$SANDBOX/overseer/cost-ledger.jsonl" ] || [ "$(wc -l < "$SANDBOX/overseer/cost-ledger.jsonl" | tr -d ' ')" -eq 0 ]; then
  pass "T4b: Kein Ledger-Eintrag bei ungültigem agent"
else
  fail "T4b: Unerwarteter Ledger-Eintrag bei ungültigem agent"
fi

# ---------------------------------------------------------------------------
# Test 5: Ungültiger usd-Wert → exit 1
# ---------------------------------------------------------------------------
set +e
cost_record "x" "abc"
rc=$?
set -e
if [ "$rc" -eq 1 ]; then
  pass "T5: cost_record mit usd='abc' → exit 1"
else
  fail "T5: Erwartet exit 1, erhalten exit $rc"
fi

# Negative Zahl auch ablehnen?
set +e
cost_record "x" "-1.5"
rc=$?
set -e
if [ "$rc" -eq 1 ]; then
  pass "T5b: cost_record mit usd='-1.5' → exit 1"
else
  fail "T5b: Erwartet exit 1 für negative Zahl, erhalten exit $rc"
fi

# ---------------------------------------------------------------------------
# Ergebnis
# ---------------------------------------------------------------------------
printf '\n--- Ergebnis: %d pass, %d fail ---\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf 'OK: Alle Tests bestanden.\n'
  exit 0
else
  printf 'FEHLER: %d Test(s) fehlgeschlagen.\n' "$FAIL" >&2
  exit 1
fi
