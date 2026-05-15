#!/usr/bin/env bash
# check-smoke-passed.sh — Pre-Merge Gate für UI-Touching PRs.
#
# Bug 2026-05-15: 6× UI-Touches via PR gemerged ohne aktuellen Smoke-Test.
# Letzter Smoke-Test ist 13.05, also 2 Tage alt. Browser-Tester-Issues
# kommen unerkannt durch.
#
# Dieses Script blockt Merges wenn:
# 1. PR touched UI-Pfade (lib/screens/, lib/widgets/, lib/app_theme.dart,
#    lib/l10n/app_*.arb, lib/main.dart)
# 2. UND es gibt keinen aktuellen (< 24h alten) Smoke-Test-Report mit
#    `Result: passed` in .claude/test-runs/<ts>/report.md
#
# Override: SMOKE_CHECK_OVERRIDE=1 (z.B. für reine Doc-PRs oder Hot-Fixes)
#
# Usage:
#   bash .claude/scripts/check-smoke-passed.sh [<pr-number>]
#   (ohne PR-Nummer: prüft aktuelle Branch-HEAD-Diff gegen origin/main)
#
# Exit 0 = OK (no UI-touches OR fresh smoke pass)
# Exit 1 = BLOCK (UI-touched but smoke stale or fail)
# Exit 2 = setup error

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 2

PR_NUM="${1:-}"
MAX_AGE_HOURS="${SMOKE_MAX_AGE_HOURS:-24}"

# Determine what files changed
if [ -n "$PR_NUM" ]; then
  CHANGED_FILES=$(gh pr view "$PR_NUM" --json files -q '.files[].path' 2>/dev/null)
  CHECK_SOURCE="PR #$PR_NUM"
else
  # Local: compare to origin/main
  CHANGED_FILES=$(git diff --name-only origin/main HEAD 2>/dev/null)
  CHECK_SOURCE="HEAD vs origin/main"
fi

if [ -z "$CHANGED_FILES" ]; then
  echo "[smoke-check] No changes detected ($CHECK_SOURCE) — pass."
  exit 0
fi

# Check if any UI-path was touched
UI_TOUCHED=0
UI_PATTERN='^(lib/screens/|lib/widgets/|lib/app_theme\.dart|lib/main\.dart|lib/l10n/app_[a-z]+\.arb$)'
while IFS= read -r file; do
  if echo "$file" | grep -qE "$UI_PATTERN"; then
    UI_TOUCHED=1
    echo "[smoke-check] UI-touch: $file"
  fi
done <<< "$CHANGED_FILES"

if [ "$UI_TOUCHED" -eq 0 ]; then
  echo "[smoke-check] No UI paths touched ($CHECK_SOURCE) — smoke not required."
  exit 0
fi

# Override path
if [ "${SMOKE_CHECK_OVERRIDE:-0}" = "1" ]; then
  echo "[smoke-check] SMOKE_CHECK_OVERRIDE=1 set — bypassing check."
  echo "[smoke-check] WARNING: user explicitly overrode smoke-test gate."
  # Audit-log entry
  audit_file="$REPO_ROOT/.claude/audit/$(date -u +%Y-%m-%d).md"
  if [ -d "$(dirname "$audit_file")" ]; then
    {
      printf '\n---\naction: smoke_check_override\nts: %s\nsubject: %s\nreason: SMOKE_CHECK_OVERRIDE=1 explizit gesetzt\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$CHECK_SOURCE"
    } >> "$audit_file" 2>/dev/null || true
  fi
  exit 0
fi

# Find latest smoke-test report
TEST_RUNS_DIR="$REPO_ROOT/.claude/test-runs"
if [ ! -d "$TEST_RUNS_DIR" ]; then
  echo "[smoke-check] BLOCK: No .claude/test-runs/ directory. Run smoke-full-app-audit first." >&2
  exit 1
fi

# Find newest directory with report.md
LATEST_REPORT=""
LATEST_TS=0
for dir in "$TEST_RUNS_DIR"/*/; do
  [ -d "$dir" ] || continue
  report="${dir}report.md"
  if [ -f "$report" ]; then
    ts=$(stat -f %m "$report" 2>/dev/null || echo 0)
    if [ "$ts" -gt "$LATEST_TS" ]; then
      LATEST_TS=$ts
      LATEST_REPORT="$report"
    fi
  fi
done

if [ -z "$LATEST_REPORT" ]; then
  echo "[smoke-check] BLOCK: No smoke-test report.md found in .claude/test-runs/." >&2
  echo "[smoke-check] Run: /test-ui smoke-full-app-audit" >&2
  exit 1
fi

# Check age
NOW=$(date +%s)
AGE_SECONDS=$((NOW - LATEST_TS))
AGE_HOURS=$((AGE_SECONDS / 3600))

if [ "$AGE_HOURS" -ge "$MAX_AGE_HOURS" ]; then
  echo "[smoke-check] BLOCK: Latest smoke report is ${AGE_HOURS}h old (max ${MAX_AGE_HOURS}h)." >&2
  echo "[smoke-check]   Report: $LATEST_REPORT" >&2
  echo "[smoke-check]   Re-run: /test-ui smoke-full-app-audit" >&2
  exit 1
fi

# Check pass status
if grep -qE '^Result:[[:space:]]*passed' "$LATEST_REPORT" 2>/dev/null; then
  echo "[smoke-check] PASS: smoke report ${AGE_HOURS}h old, Result: passed"
  echo "[smoke-check]   Report: $LATEST_REPORT"
  exit 0
fi

echo "[smoke-check] BLOCK: smoke report ${AGE_HOURS}h old but Result is NOT 'passed'." >&2
echo "[smoke-check]   Report: $LATEST_REPORT" >&2
echo "[smoke-check]   Re-run: /test-ui smoke-full-app-audit" >&2
exit 1
