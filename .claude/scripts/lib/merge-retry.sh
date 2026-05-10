#!/usr/bin/env bash
# merge-retry.sh — Sourceable library for PR merge with rebase-retry on conflict.
#
# Usage: source this file, then call:
#   auto_merge_with_retry <pr_number> <item_path> <worktree_path>
#
# Exit codes:
#   0 — PR merged successfully
#   1 — Merge failed for non-conflict reasons (CI checks, etc.)
#   2 — Merge conflict that could not be auto-resolved via rebase
#
# Caller is responsible for calling release_item with the appropriate result.
# Mitigation 9: on exit 2, caller should release with "merge-conflict" result
#               (not "failed") so item returns to inbox with [merge-conflict] marker.
# Mitigation 10: --admin is NOT used by default. Set MERGE_ADMIN_OVERRIDE=1 to enable.

# Deliberately NO set -e here — this is a sourced library used in varied contexts.
set -u

auto_merge_with_retry() {
  local pr_number="${1:?auto_merge_with_retry: pr_number required}"
  local item_path="${2:?auto_merge_with_retry: item_path required}"
  local worktree_path="${3:?auto_merge_with_retry: worktree_path required}"

  # Build merge args — Mitigation 10: no --admin by default
  local -a gh_merge_args=( --squash --delete-branch )
  if [ "${MERGE_ADMIN_OVERRIDE:-0}" = "1" ]; then
    gh_merge_args+=( --admin )
    printf '[merge-retry] MERGE_ADMIN_OVERRIDE=1: adding --admin flag\n' >&2
  fi

  # --- Attempt 1: direct merge ---
  printf '[merge-retry] Attempting merge of PR #%s (args: %s)\n' \
    "$pr_number" "${gh_merge_args[*]}" >&2

  if gh pr merge "$pr_number" "${gh_merge_args[@]}" 2>/tmp/merge-retry-stderr.$$; then
    printf '[merge-retry] PR #%s merged successfully on first attempt.\n' "$pr_number" >&2
    rm -f /tmp/merge-retry-stderr.$$
    return 0
  fi

  local merge_stderr
  merge_stderr="$(cat /tmp/merge-retry-stderr.$$ 2>/dev/null || true)"
  rm -f /tmp/merge-retry-stderr.$$

  printf '[merge-retry] First merge attempt failed. stderr: %s\n' "$merge_stderr" >&2

  # Detect conflict vs. other failure (CI checks, auth, etc.)
  # GitHub CLI typically says "merge conflict" or "conflicts" in error output
  local is_conflict=0
  if printf '%s' "$merge_stderr" | grep -qiE 'conflict|cannot rebase|diverged|behind'; then
    is_conflict=1
  fi

  if [ "$is_conflict" -eq 0 ]; then
    printf '[merge-retry] Merge failed for non-conflict reason — no rebase attempted.\n' >&2
    printf 'merge-retry: PR #%s merge failed (non-conflict). Check: gh pr view %s\n' \
      "$pr_number" "$pr_number" >&2
    return 1
  fi

  # --- Rebase-retry path ---
  printf '[merge-retry] Conflict detected. Attempting rebase in worktree: %s\n' "$worktree_path" >&2

  if [ ! -d "$worktree_path" ]; then
    printf 'merge-retry: ERROR: worktree_path does not exist: %s\n' "$worktree_path" >&2
    return 2
  fi

  # Fetch latest main
  if ! git -C "$worktree_path" fetch origin main 2>&1; then
    printf 'merge-retry: ERROR: git fetch origin main failed in %s\n' "$worktree_path" >&2
    return 2
  fi

  # Attempt rebase
  if ! git -C "$worktree_path" rebase origin/main 2>/tmp/merge-retry-rebase-stderr.$$ ; then
    local rebase_stderr
    rebase_stderr="$(cat /tmp/merge-retry-rebase-stderr.$$ 2>/dev/null || true)"
    rm -f /tmp/merge-retry-rebase-stderr.$$
    printf '[merge-retry] Rebase failed (conflict not auto-resolvable): %s\n' "$rebase_stderr" >&2
    # Abort rebase to leave worktree in clean state
    git -C "$worktree_path" rebase --abort 2>/dev/null || true
    printf 'merge-retry: PR #%s — rebase failed, conflict not auto-resolvable. Item will be returned to inbox with [merge-conflict] marker.\n' \
      "$pr_number" >&2
    return 2
  fi
  rm -f /tmp/merge-retry-rebase-stderr.$$

  printf '[merge-retry] Rebase successful. Force-pushing with lease...\n' >&2

  # Force-push (--force-with-lease is safe: fails if remote has diverged unexpectedly)
  if ! git -C "$worktree_path" push --force-with-lease 2>&1; then
    printf 'merge-retry: ERROR: force-push after rebase failed.\n' >&2
    return 2
  fi

  printf '[merge-retry] Force-push done. Retrying merge of PR #%s...\n' "$pr_number" >&2

  # --- Attempt 2: merge after rebase ---
  if gh pr merge "$pr_number" "${gh_merge_args[@]}" 2>/tmp/merge-retry-stderr2.$$; then
    printf '[merge-retry] PR #%s merged successfully after rebase.\n' "$pr_number" >&2
    rm -f /tmp/merge-retry-stderr2.$$
    return 0
  fi

  local merge2_stderr
  merge2_stderr="$(cat /tmp/merge-retry-stderr2.$$ 2>/dev/null || true)"
  rm -f /tmp/merge-retry-stderr2.$$

  printf 'merge-retry: PR #%s — second merge attempt failed after rebase: %s\n' \
    "$pr_number" "$merge2_stderr" >&2
  printf 'merge-retry: Item will be returned to inbox with [merge-conflict] marker.\n' >&2
  return 2
}
