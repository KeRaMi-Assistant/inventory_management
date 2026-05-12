#!/usr/bin/env bash
# eval-intake-council.sh — T19b: Driver für Pre-Merge-Eval N=25
#
# Läuft alle non-null Items aus .claude/intake-council/eval-set.json durch
# intake-council.sh, vergleicht Verdict mit expected_verdict, produziert
# Markdown-Report mit Match-Rate.
#
# Usage:
#   eval-intake-council.sh [--quick | --full]
#
#   --quick  Nur Items mit non-null text verarbeiten (default). Pass-Threshold: 4/5 (80%).
#   --full   Erfordert alle 25 Items non-null. Pass-Threshold: >=80%.
#
# Env-Overrides:
#   EVAL_DRY_RUN=1          Kein echter claude-Aufruf. Mock-Council-Outputs für Offline-Tests.
#   EVAL_COST_CAP_OVERRIDE=1 Überspringt cost_check_or_die (für Eval-Budget $50 einmalig).
#   EVAL_COST_CAP_TODAY=50  Override für Max-Tages-Budget (default: 50 USD für Eval).
#   EVAL_COST_CAP_WEEK=50   Override für Max-Wochen-Budget (default: 50 USD für Eval).
#
# Output-Verzeichnis: .claude/intake-council/eval-runs/<timestamp>/
# Report-File: .claude/intake-council/eval-runs/<timestamp>/report.md
#
# Exit-Codes:
#   0  — Match-Rate >= Threshold.
#   1  — Match-Rate < Threshold.
#   2  — Setup-Fehler (missing deps, API-Key, Cost-Cap).
#   3  — intake-council.sh nicht gefunden (soft-skip-Warnung).

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INTAKE_COUNCIL_DIR="$REPO_ROOT/.claude/intake-council"
LIB_DIR="$SCRIPT_DIR/lib"
EVAL_SET="$INTAKE_COUNCIL_DIR/eval-set.json"
INTAKE_COUNCIL_SCRIPT="$SCRIPT_DIR/intake-council.sh"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
MODE="quick"
for arg in "$@"; do
  case "$arg" in
    --quick) MODE="quick" ;;
    --full)  MODE="full"  ;;
    *)
      printf '[eval-intake-council] Unknown argument: %s\n' "$arg" >&2
      printf 'Usage: eval-intake-council.sh [--quick | --full]\n' >&2
      exit 2
      ;;
  esac
done

DRY_RUN="${EVAL_DRY_RUN:-0}"
COST_CAP_OVERRIDE="${EVAL_COST_CAP_OVERRIDE:-0}"
COST_CAP_TODAY="${EVAL_COST_CAP_TODAY:-50}"
COST_CAP_WEEK="${EVAL_COST_CAP_WEEK:-50}"

# ---------------------------------------------------------------------------
# Timestamp for this run
# ---------------------------------------------------------------------------
TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$INTAKE_COUNCIL_DIR/eval-runs/$TS"
mkdir -p "$RUN_DIR"

REPORT="$RUN_DIR/report.md"

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
log()  { printf '[eval-intake-council] %s\n' "$*"; }
warn() { printf '[eval-intake-council] WARNING: %s\n' "$*" >&2; }
err()  { printf '[eval-intake-council] ERROR: %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Pre-flight 1: eval-set.json exists
# ---------------------------------------------------------------------------
if [ ! -f "$EVAL_SET" ]; then
  err "eval-set.json not found at $EVAL_SET"
  exit 2
fi

# ---------------------------------------------------------------------------
# Pre-flight 2: python3 / jq available for JSON parsing
# ---------------------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  err "python3 is required but not found."
  exit 2
fi

# ---------------------------------------------------------------------------
# Pre-flight 3: API-Key check (unless DRY_RUN)
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" = "0" ]; then
  if [ -f "$LIB_DIR/api-key-preflight.sh" ]; then
    # shellcheck disable=SC1090
    . "$LIB_DIR/api-key-preflight.sh"
    check_no_api_key
  else
    warn "api-key-preflight.sh not found at $LIB_DIR — skipping API-key check."
  fi
fi

# ---------------------------------------------------------------------------
# Pre-flight 4: Cost-Cap check (for --full mode, unless override or dry-run)
# ---------------------------------------------------------------------------
if [ "$MODE" = "full" ] && [ "$DRY_RUN" = "0" ] && [ "$COST_CAP_OVERRIDE" != "1" ]; then
  log "Cost-Cap pre-flight for --full mode (est. \$12-20 for N=25)..."
  if [ -f "$LIB_DIR/cost-cap.sh" ]; then
    # shellcheck disable=SC1090
    . "$LIB_DIR/cost-cap.sh"
    if ! cost_check_or_die "$COST_CAP_TODAY" "$COST_CAP_WEEK"; then
      err "Cost-Cap exceeded. Set EVAL_COST_CAP_OVERRIDE=1 to override for one-time eval budget."
      exit 2
    fi
    log "Cost-Cap OK (today <= \$$COST_CAP_TODAY / week <= \$$COST_CAP_WEEK)."
  else
    warn "cost-cap.sh not found — skipping cost check. Consider setting EVAL_COST_CAP_OVERRIDE=1 explicitly."
  fi
fi

# ---------------------------------------------------------------------------
# Pre-flight 5: intake-council.sh existence check
# ---------------------------------------------------------------------------
INTAKE_AVAILABLE=1
if [ ! -f "$INTAKE_COUNCIL_SCRIPT" ]; then
  warn "intake-council.sh not found at $INTAKE_COUNCIL_SCRIPT (T05 not yet implemented)."
  warn "Running in soft-skip mode — all items will be marked SKIP."
  INTAKE_AVAILABLE=0
fi

# ---------------------------------------------------------------------------
# Load eval-set.json → extract items
# ---------------------------------------------------------------------------
log "Loading eval-set from $EVAL_SET"

ITEMS_JSON="$(python3 - "$EVAL_SET" "$MODE" <<'PYEOF'
import sys, json

eval_set_path = sys.argv[1]
mode = sys.argv[2]

with open(eval_set_path) as f:
    items = json.load(f)

# Filter non-null text items
active = [it for it in items if it.get("text") is not None]
total_count = len(items)
active_count = len(active)

if mode == "full":
    null_count = total_count - active_count
    if null_count > 0:
        print(f"ERROR:full-mode-requires-all-non-null:{null_count}-null-items-found", flush=True)
        sys.exit(1)

# Output as JSON lines for bash to iterate
for it in active:
    print(json.dumps({"id": it["id"], "text": it["text"], "expected": it.get("expected_verdict")}))
PYEOF
)" || {
  err "Failed to parse eval-set.json or --full mode missing items."
  exit 2
}

# Check for error signal from python
if printf '%s' "$ITEMS_JSON" | grep -q "^ERROR:"; then
  ERR_MSG="$(printf '%s' "$ITEMS_JSON" | grep "^ERROR:" | head -1)"
  err "eval-set not ready for --full mode: $ERR_MSG"
  err "Populate all 25 items before running --full, or use --quick."
  exit 2
fi

# Count active items
ACTIVE_COUNT="$(printf '%s\n' "$ITEMS_JSON" | grep -c '.' || true)"
log "Active items: $ACTIVE_COUNT (mode: $MODE)"

if [ "$ACTIVE_COUNT" -eq 0 ]; then
  err "No active items found (all text fields are null)."
  exit 2
fi

# Thresholds
if [ "$MODE" = "quick" ]; then
  THRESHOLD_PASS=4
  THRESHOLD_TOTAL="$ACTIVE_COUNT"
  THRESHOLD_PCT=80
else
  THRESHOLD_PCT=80
  THRESHOLD_PASS="$(python3 -c "import math; print(math.ceil($ACTIVE_COUNT * 0.8))")"
  THRESHOLD_TOTAL="$ACTIVE_COUNT"
fi

# ---------------------------------------------------------------------------
# Pending-proposals temp dir
# ---------------------------------------------------------------------------
PENDING_DIR="$RUN_DIR/pending-proposal"
APPROVAL_DIR="$RUN_DIR/pending-approval"
mkdir -p "$PENDING_DIR" "$APPROVAL_DIR"

# ---------------------------------------------------------------------------
# Mock council function for DRY_RUN=1
# ---------------------------------------------------------------------------
mock_council_run() {
  local id="$1"
  local text="$2"
  local approval_file="$3"

  # Heuristic mock: produce verdict based on keywords in text
  local verdict="propose"
  local rationale="Mock: text looks like a routine proposal."

  lower_text="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')"

  if printf '%s' "$lower_text" | grep -qE 'guard-bash|self.mod|blocklist|security.bypass'; then
    verdict="needs-full-council"
    rationale="Mock: self-mod or security-bypass detected."
  elif printf '%s' "$lower_text" | grep -qE 'slack|e2e|encryption|complete.*integrat|custom.*backend'; then
    verdict="reject"
    rationale="Mock: out-of-scope or excessive complexity for pre-launch."
  elif printf '%s' "$lower_text" | grep -qE '^speed up|^improve performance|^make.*faster|vague|ambig'; then
    verdict="propose-with-changes"
    rationale="Mock: vague or missing acceptance criteria — needs scoping."
  elif printf '%s' "$lower_text" | grep -qE 'drag|swipe.*reorder|complex.*gesture|resize.*tablet'; then
    verdict="propose-with-changes"
    rationale="Mock: mobile-first concerns — skeptic would want touch-target check."
  fi

  # Write mock approval file
  cat > "$approval_file" <<MOCKEOF
# Mock Council Approval: $id

**verdict:** $verdict

**rationale:** $rationale

_Generated by EVAL_DRY_RUN mock council._
MOCKEOF
}

# ---------------------------------------------------------------------------
# Run loop
# ---------------------------------------------------------------------------
MATCH=0
MISMATCH=0
SKIP=0
ROWS=""

log "Starting eval run (DRY_RUN=$DRY_RUN, INTAKE_AVAILABLE=$INTAKE_AVAILABLE)..."
log "Output dir: $RUN_DIR"

while IFS= read -r item_json; do
  ITEM_ID="$(printf '%s' "$item_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['id'])")"
  ITEM_TEXT="$(printf '%s' "$item_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['text'])")"
  ITEM_EXPECTED="$(printf '%s' "$item_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['expected'] or '')")"

  PROPOSAL_FILE="$PENDING_DIR/$ITEM_ID.md"
  APPROVAL_FILE="$APPROVAL_DIR/$ITEM_ID.md"

  # Write mock pending proposal
  cat > "$PROPOSAL_FILE" <<PROPEOF
# Eval Proposal: $ITEM_ID

$ITEM_TEXT
PROPEOF

  ACTUAL_VERDICT="SKIP"
  STATUS="SKIP"

  if [ "$DRY_RUN" = "1" ]; then
    mock_council_run "$ITEM_ID" "$ITEM_TEXT" "$APPROVAL_FILE"
    ACTUAL_VERDICT="$(grep -i '^\*\*verdict:\*\*' "$APPROVAL_FILE" | sed 's/\*\*verdict:\*\* //' | tr -d '\r' | head -1)"
    if [ -z "$ACTUAL_VERDICT" ]; then
      ACTUAL_VERDICT="unknown"
    fi
    STATUS="evaluated"  # reset from initial SKIP so compare block runs
  elif [ "$INTAKE_AVAILABLE" = "0" ]; then
    ACTUAL_VERDICT="SKIP"
    STATUS="SKIP"
    SKIP=$((SKIP + 1))
  else
    # Real intake-council.sh call
    STATUS="evaluated"  # reset from initial SKIP so compare block runs
    if bash "$INTAKE_COUNCIL_SCRIPT" "$PROPOSAL_FILE" "$APPROVAL_FILE" 2>>"$RUN_DIR/council-stderr.log"; then
      ACTUAL_VERDICT="$(grep -i '^\*\*verdict:\*\*' "$APPROVAL_FILE" 2>/dev/null | sed 's/\*\*verdict:\*\* //' | tr -d '\r' | head -1 || true)"
      if [ -z "$ACTUAL_VERDICT" ]; then
        ACTUAL_VERDICT="unknown"
      fi
    else
      ACTUAL_VERDICT="error"
      warn "intake-council.sh failed for $ITEM_ID — marking as error."
    fi
  fi

  # Compare
  if [ "$STATUS" != "SKIP" ]; then
    if [ "$ACTUAL_VERDICT" = "$ITEM_EXPECTED" ]; then
      STATUS="PASS"
      MATCH=$((MATCH + 1))
    else
      STATUS="FAIL"
      MISMATCH=$((MISMATCH + 1))
    fi
  fi

  # Build row for report
  ROWS="$ROWS
| $ITEM_ID | $(printf '%s' "$ITEM_TEXT" | head -c 60)... | $ITEM_EXPECTED | $ACTUAL_VERDICT | $STATUS |"

  log "  $ITEM_ID → expected=$ITEM_EXPECTED actual=$ACTUAL_VERDICT status=$STATUS"

done <<< "$ITEMS_JSON"

# ---------------------------------------------------------------------------
# Aggregate
# ---------------------------------------------------------------------------
TOTAL_EVAL=$((MATCH + MISMATCH))
if [ "$TOTAL_EVAL" -eq 0 ]; then
  MATCH_RATE_PCT=0
else
  MATCH_RATE_PCT="$(python3 -c "print(round($MATCH / $TOTAL_EVAL * 100, 1))")"
fi

if [ "$TOTAL_EVAL" -ge 1 ]; then
  PASS_OVERALL="$(python3 -c "print('PASS' if $MATCH >= $THRESHOLD_PASS else 'FAIL')")"
else
  PASS_OVERALL="SKIP"
fi

# ---------------------------------------------------------------------------
# Write report
# ---------------------------------------------------------------------------
cat > "$REPORT" <<REPORTEOF
# Eval-Intake-Council Report

**Run:** $TS
**Mode:** $MODE
**DRY_RUN:** $DRY_RUN

## Summary

| Metric | Value |
|---|---|
| Active items evaluated | $TOTAL_EVAL |
| Skipped (intake-council.sh absent) | $SKIP |
| Matches (PASS) | $MATCH |
| Mismatches (FAIL) | $MISMATCH |
| Match-Rate | ${MATCH_RATE_PCT}% |
| Threshold | ${THRESHOLD_PCT}% (>= $THRESHOLD_PASS / $TOTAL_EVAL) |
| **Result** | **$PASS_OVERALL** |

## Item-Level Results

| ID | Text (first 60 chars) | Expected | Actual | Status |
|---|---|---|---|---|$ROWS

## Files

- Proposals: \`$PENDING_DIR/\`
- Approvals: \`$APPROVAL_DIR/\`
- Council stderr: \`$RUN_DIR/council-stderr.log\`

---
_Generated by \`eval-intake-council.sh\`_
REPORTEOF

log "Report written to $REPORT"
log "Result: $PASS_OVERALL (match-rate: ${MATCH_RATE_PCT}% threshold: ${THRESHOLD_PCT}%)"

# ---------------------------------------------------------------------------
# Cleanup mock files
# ---------------------------------------------------------------------------
rm -rf "$PENDING_DIR" "$APPROVAL_DIR"
log "Cleaned up mock proposal/approval files."

# ---------------------------------------------------------------------------
# Exit code
# ---------------------------------------------------------------------------
if [ "$PASS_OVERALL" = "PASS" ]; then
  exit 0
elif [ "$PASS_OVERALL" = "SKIP" ]; then
  warn "All items skipped — intake-council.sh not available."
  exit 3
else
  err "Match-Rate below threshold. See report: $REPORT"
  exit 1
fi
