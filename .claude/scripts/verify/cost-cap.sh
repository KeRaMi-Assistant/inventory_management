#!/usr/bin/env bash
# verify/cost-cap.sh — Tests für cost_today_usd, cost_week_usd, cost_check_or_die
#
# Alle Tests laufen in mktemp-Sandbox via COST_CAP_LEDGER_DIR.
# Exit 0 = alle Tests grün.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/../lib/cost-cap.sh"

if [ ! -f "$LIB" ]; then
  printf 'ERROR: cost-cap.sh nicht gefunden: %s\n' "$LIB" >&2
  exit 1
fi

# ---- Farben / Helpers -------------------------------------------------------
_pass() { printf '\033[32mPASS\033[0m %s\n' "$1"; }
_fail() { printf '\033[31mFAIL\033[0m %s — %s\n' "$1" "$2"; FAILURES=$((FAILURES+1)); }

FAILURES=0

# ---- Sandbox einrichten -----------------------------------------------------
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

_new_sandbox() {
  local d="$TMPDIR_BASE/sandbox_$1"
  mkdir -p "$d"
  printf '%s' "$d"
}

# Helper: Datum-Offset (macOS-kompatibel)
_date_offset() {
  local days="$1"   # negative = Vergangenheit
  if date -v "${days}d" +%Y-%m-%d >/dev/null 2>&1; then
    # macOS BSD date
    date -u -v "${days}d" +%Y-%m-%d
  else
    # GNU date
    date -u -d "${days} days" +%Y-%m-%d
  fi
}

# Helper: JSONL-Eintrag mit beliebigem Datum schreiben
_write_entry() {
  local ledger_file="$1"
  local date_str="$2"   # YYYY-MM-DD
  local usd="$3"
  local agent="${4:-test-agent}"
  printf '{"ts":"%sT12:00:00Z","agent":"%s","usd":%s,"pid":1}\n' \
    "$date_str" "$agent" "$usd" >> "$ledger_file"
}

# ============================================================
# Test 1 — Leeres Ledger
# ============================================================
sandbox1="$(_new_sandbox 1)"
export COST_CAP_LEDGER_DIR="$sandbox1"

# Sourcen nach jeder Sandbox-Änderung damit _cost_cap_ledger_dir neu evaluiert
source "$LIB"

result_today="$(cost_today_usd)"
if [ "$result_today" = "0.00" ]; then
  _pass "T1: leeres Ledger → cost_today_usd = 0.00"
else
  _fail "T1: leeres Ledger → cost_today_usd" "erwartet 0.00, erhalten $result_today"
fi

result_week="$(cost_week_usd)"
if [ "$result_week" = "0.00" ]; then
  _pass "T1: leeres Ledger → cost_week_usd = 0.00"
else
  _fail "T1: leeres Ledger → cost_week_usd" "erwartet 0.00, erhalten $result_week"
fi

cost_check_or_die 5 30
rc=$?
if [ "$rc" -eq 0 ]; then
  _pass "T1: cost_check_or_die 5 30 bei leerem Ledger → exit 0"
else
  _fail "T1: cost_check_or_die 5 30 bei leerem Ledger" "erwartet exit 0, erhalten $rc"
fi

# ============================================================
# Test 2 — Heute: 3 Einträge (2.0 + 1.5 + 1.0 = 4.50)
# ============================================================
sandbox2="$(_new_sandbox 2)"
export COST_CAP_LEDGER_DIR="$sandbox2"
source "$LIB"

TODAY="$(date -u +%Y-%m-%d)"
LEDGER2="$sandbox2/cost-ledger.jsonl"
_write_entry "$LEDGER2" "$TODAY" "2.0"
_write_entry "$LEDGER2" "$TODAY" "1.5"
_write_entry "$LEDGER2" "$TODAY" "1.0"

result_today2="$(cost_today_usd)"
if [ "$result_today2" = "4.50" ]; then
  _pass "T2: 3 heutige Einträge → cost_today_usd = 4.50"
else
  _fail "T2: 3 heutige Einträge → cost_today_usd" "erwartet 4.50, erhalten $result_today2"
fi

# check_or_die 5 → unter Limit → exit 0
cost_check_or_die 5 30
rc=$?
if [ "$rc" -eq 0 ]; then
  _pass "T2: cost_check_or_die 5 30 bei 4.50 today → exit 0"
else
  _fail "T2: cost_check_or_die 5 30 bei 4.50 today" "erwartet exit 0, erhalten $rc"
fi

# check_or_die 4 → über Limit → exit 2 + Marker
cost_check_or_die 4 30 || rc=$?
if [ "$rc" -eq 2 ]; then
  _pass "T2: cost_check_or_die 4 30 bei 4.50 today → exit 2"
else
  _fail "T2: cost_check_or_die 4 30 bei 4.50 today" "erwartet exit 2, erhalten $rc"
fi

MARKER2="$sandbox2/COST_CAP_REACHED"
if [ -f "$MARKER2" ]; then
  _pass "T2: COST_CAP_REACHED Marker existiert nach exit 2"
else
  _fail "T2: COST_CAP_REACHED Marker" "Datei nicht gefunden: $MARKER2"
fi

# ============================================================
# Test 3 — Gestern + Heute gemischt: cost_today_usd zeigt nur heute
# ============================================================
sandbox3="$(_new_sandbox 3)"
export COST_CAP_LEDGER_DIR="$sandbox3"
source "$LIB"

TODAY3="$(date -u +%Y-%m-%d)"
YESTERDAY3="$(_date_offset -1)"
LEDGER3="$sandbox3/cost-ledger.jsonl"
_write_entry "$LEDGER3" "$YESTERDAY3" "10.0"  # gestern — darf nicht gezählt werden
_write_entry "$LEDGER3" "$TODAY3"    "2.0"    # heute
_write_entry "$LEDGER3" "$TODAY3"    "1.0"    # heute

result_today3="$(cost_today_usd)"
if [ "$result_today3" = "3.00" ]; then
  _pass "T3: Gestern+Heute gemischt → cost_today_usd = 3.00 (nur heute)"
else
  _fail "T3: Gestern+Heute gemischt → cost_today_usd" "erwartet 3.00, erhalten $result_today3"
fi

# ============================================================
# Test 4 — Woche: Tag -1, -3, -5 werden gezählt; Tag -8 nicht
# ============================================================
sandbox4="$(_new_sandbox 4)"
export COST_CAP_LEDGER_DIR="$sandbox4"
source "$LIB"

LEDGER4="$sandbox4/cost-ledger.jsonl"
D1="$(_date_offset -1)"
D3="$(_date_offset -3)"
D5="$(_date_offset -5)"
D8="$(_date_offset -8)"

_write_entry "$LEDGER4" "$D1" "3.0"   # in der Woche
_write_entry "$LEDGER4" "$D3" "2.0"   # in der Woche
_write_entry "$LEDGER4" "$D5" "1.0"   # in der Woche (genau Tag 6 → grenzwertig, aber -5 = vor 5 Tagen → drin)
_write_entry "$LEDGER4" "$D8" "99.0"  # außerhalb → muss ignoriert werden

result_week4="$(cost_week_usd)"
if [ "$result_week4" = "6.00" ]; then
  _pass "T4: Woche-Test → cost_week_usd = 6.00 (Tag-8 ausgefiltert)"
else
  _fail "T4: Woche-Test → cost_week_usd" "erwartet 6.00, erhalten $result_week4"
fi

# ============================================================
# Test 5 — Ungültige Argumente → exit 1
# ============================================================
sandbox5="$(_new_sandbox 5)"
export COST_CAP_LEDGER_DIR="$sandbox5"
source "$LIB"

cost_check_or_die abc 5 2>/dev/null || rc=$?
if [ "$rc" -eq 1 ]; then
  _pass "T5: cost_check_or_die abc 5 → exit 1"
else
  _fail "T5: cost_check_or_die abc 5 → exit 1" "erhalten $rc"
fi

cost_check_or_die 5 xyz 2>/dev/null || rc=$?
if [ "$rc" -eq 1 ]; then
  _pass "T5: cost_check_or_die 5 xyz → exit 1"
else
  _fail "T5: cost_check_or_die 5 xyz → exit 1" "erhalten $rc"
fi

# ============================================================
# Test 6 — Marker-File: nach exit 2 da, nach exit 0 NICHT da
# ============================================================
sandbox6="$(_new_sandbox 6)"
export COST_CAP_LEDGER_DIR="$sandbox6"
source "$LIB"

MARKER6="$sandbox6/COST_CAP_REACHED"
TODAY6="$(date -u +%Y-%m-%d)"
LEDGER6="$sandbox6/cost-ledger.jsonl"

# Kein Eintrag → exit 0 → kein Marker
cost_check_or_die 5 30
rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$MARKER6" ]; then
  _pass "T6: exit 0 → kein COST_CAP_REACHED Marker"
else
  _fail "T6: exit 0 → kein COST_CAP_REACHED Marker" "rc=$rc, marker_exists=$([ -f "$MARKER6" ] && echo yes || echo no)"
fi

# Eintrag über Limit schreiben → exit 2 → Marker da
_write_entry "$LEDGER6" "$TODAY6" "6.0"
cost_check_or_die 5 30 2>/dev/null || rc=$?
if [ "$rc" -eq 2 ] && [ -f "$MARKER6" ]; then
  _pass "T6: exit 2 → COST_CAP_REACHED Marker vorhanden"
else
  _fail "T6: exit 2 → COST_CAP_REACHED Marker vorhanden" "rc=$rc, marker_exists=$([ -f "$MARKER6" ] && echo yes || echo no)"
fi

# ============================================================
# Ergebnis
# ============================================================
printf '\n'
if [ "$FAILURES" -eq 0 ]; then
  printf '\033[32mAlle Tests grün.\033[0m\n'
  exit 0
else
  printf '\033[31m%d Test(s) fehlgeschlagen.\033[0m\n' "$FAILURES"
  exit 1
fi
