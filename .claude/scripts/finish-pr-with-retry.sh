#!/usr/bin/env bash
# finish-pr-with-retry.sh — CLI wrapper around merge-retry + release_item.
#
# Usage:
#   finish-pr-with-retry.sh <pr-number> <item-path> <worktree-path>
#
# Environment:
#   MERGE_ADMIN_OVERRIDE=1   — pass --admin to gh pr merge (Stakeholder-Override only)
#
# Exit codes (mirror auto_merge_with_retry):
#   0 — PR merged, item released as "done"
#   1 — Merge failed for non-conflict reasons, item released as "failed"
#   2 — Conflict not resolvable, item released as "merge-conflict" (back to inbox)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source dependencies
# shellcheck source=lib/merge-retry.sh
source "${LIB_DIR}/merge-retry.sh"
# shellcheck source=lib/picker.sh
source "${LIB_DIR}/picker.sh"
# shellcheck source=lib/audit.sh
source "${LIB_DIR}/audit.sh"

PR_NUMBER="${1:?Usage: finish-pr-with-retry.sh <pr-number> <item-path> <worktree-path>}"
ITEM_PATH="${2:?Usage: finish-pr-with-retry.sh <pr-number> <item-path> <worktree-path>}"
WORKTREE_PATH="${3:?Usage: finish-pr-with-retry.sh <pr-number> <item-path> <worktree-path>}"

if [ ! -f "$ITEM_PATH" ]; then
  printf 'finish-pr-with-retry: ERROR: item file not found: %s\n' "$ITEM_PATH" >&2
  exit 1
fi

# Run merge with retry
set +e
auto_merge_with_retry "$PR_NUMBER" "$ITEM_PATH" "$WORKTREE_PATH"
MERGE_EXIT=$?
set -e

case "$MERGE_EXIT" in
  0)
    printf '[finish-pr] Merge succeeded. Releasing item as "done".\n'
    release_item "$ITEM_PATH" "done"
    # Switch to main + pull if not already there
    CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || true)"
    if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "main" ]; then
      git checkout main 2>/dev/null || true
      git pull --ff-only 2>/dev/null || true
      printf '[finish-pr] Switched to main + pulled.\n'
    fi
    exit 0
    ;;
  2)
    printf '[finish-pr] Merge conflict not resolvable. Releasing item as "merge-conflict" (back to inbox).\n'
    release_item "$ITEM_PATH" "merge-conflict"
    # Audit the conflict for visibility
    audit_record "finish-pr-with-retry" "merge-conflict" \
      "PR #${PR_NUMBER}" \
      "Rebase-retry failed — item returned to inbox with [merge-conflict] marker: $(basename "$ITEM_PATH")"
    printf '[finish-pr] Item returned to inbox with [merge-conflict] prefix. Manual resolution required.\n' >&2
    exit 2
    ;;
  *)
    printf '[finish-pr] Merge failed (non-conflict). Releasing item as "failed".\n' >&2
    release_item "$ITEM_PATH" "failed"
    exit 1
    ;;
esac
