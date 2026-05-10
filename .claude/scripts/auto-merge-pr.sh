#!/usr/bin/env bash
# Merget einen PR direkt (squash + delete-branch) — keine Branch-Protection nötig.
# Pre-Launch-tauglich, weil lokale Gates (analyze/test/security) vorher liefen.
#
# Usage:
#   auto-merge-pr.sh <pr-number>           # mergt diesen PR
#   auto-merge-pr.sh                       # mergt PR des aktuellen Branches

set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI missing" >&2
  exit 1
fi

PR_NUM="${1:-}"

if [ -z "$PR_NUM" ]; then
  BRANCH="$(git branch --show-current)"
  if [ "$BRANCH" = "main" ]; then
    echo "auto-merge: cannot run on main" >&2
    exit 1
  fi
  PR_NUM="$(gh pr list --head "$BRANCH" --json number --jq '.[0].number')"
  if [ -z "$PR_NUM" ]; then
    echo "auto-merge: no open PR for branch $BRANCH" >&2
    exit 1
  fi
fi

echo "→ merging PR #$PR_NUM (squash + delete branch)…"

# Mitigation 10: --admin wird NICHT standardmäßig verwendet.
# Headless/Overseer-Pfad wartet auf CI-Gates statt --admin zu erzwingen.
# Stakeholder-Override: MERGE_ADMIN_OVERRIDE=1 aktiviert --admin.
GH_MERGE_ARGS=( --squash --delete-branch )
if [ "${MERGE_ADMIN_OVERRIDE:-0}" = "1" ]; then
  GH_MERGE_ARGS+=( --admin )
  echo "  (MERGE_ADMIN_OVERRIDE=1: using --admin)"
fi

if gh pr merge "$PR_NUM" "${GH_MERGE_ARGS[@]}"; then
  echo "✓ PR #$PR_NUM merged."
  # Switch zu main + pull falls wir auf dem gemergten Branch waren
  CURRENT="$(git branch --show-current 2>/dev/null || echo)"
  PR_HEAD="$(gh pr view "$PR_NUM" --json headRefName --jq .headRefName 2>/dev/null || echo)"
  if [ "$CURRENT" = "$PR_HEAD" ] || [ -z "$CURRENT" ]; then
    git checkout main 2>/dev/null || true
    git pull --ff-only 2>/dev/null || true
    echo "✓ switched to main + pulled."
  fi
  exit 0
else
  echo "✗ merge failed for PR #$PR_NUM" >&2
  echo "  check: gh pr view $PR_NUM" >&2
  exit 1
fi
