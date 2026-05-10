#!/usr/bin/env bash
# cleanup.sh — Daily cleanup daemon for the autonomous-council-swarm.
# Part of P3-6 (autonomous_council_swarm plan).
#
# Usage:
#   bash cleanup.sh [--once|--daemon] [--dry-run]
#
# Modes:
#   --once      Run one pass and exit (default; used by LaunchAgent).
#   --daemon    Run in a loop, sleeping 86400 s between passes.
#   --dry-run   Print what would be done, make no changes.
#
# IMPORTANT: This file is in the Self-Mod-Blocklist (P0-0).

set -uo pipefail

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
AUDIT_LIB="$SCRIPT_DIR/lib/audit.sh"
NOTIFY_SH="$SCRIPT_DIR/notify.sh"
STATE_DIR="$REPO_ROOT/.claude/overseer/state"
NOTIFIED_CACHE="$STATE_DIR/cleanup-notified-branches.json"

# ---------------------------------------------------------------------------
# Parse CLI
# ---------------------------------------------------------------------------
MODE="once"
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --once)    MODE="once" ;;
    --daemon)  MODE="daemon" ;;
    --dry-run) DRY_RUN=1 ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      printf 'Usage: %s [--once|--daemon] [--dry-run]\n' "$(basename "$0")" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------
if [ ! -f "$AUDIT_LIB" ]; then
  printf 'ERROR: audit library not found: %s\n' "$AUDIT_LIB" >&2
  exit 1
fi
# shellcheck source=lib/audit.sh
source "$AUDIT_LIB"

mkdir -p "$STATE_DIR"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_now_epoch() { date +%s; }
_dry() { [[ "$DRY_RUN" -eq 1 ]]; }

_log() { printf '[cleanup] %s\n' "$*" >&2; }
_dry_log() { _dry && printf '[DRY-RUN] %s\n' "$*" >&2; }

_notify() {
  local severity="$1" topic="$2" title="$3" body="$4"
  if [ -x "$NOTIFY_SH" ]; then
    bash "$NOTIFY_SH" "$severity" "$topic" "$title" "$body" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Loaded-cache helpers for unmerged-old-branch notifications
# ---------------------------------------------------------------------------
_notified_cache_contains() {
  local branch="$1"
  if [ ! -f "$NOTIFIED_CACHE" ]; then return 1; fi
  python3 - "$NOTIFIED_CACHE" "$branch" <<'PYEOF'
import sys, json
try:
    data = json.load(open(sys.argv[1]))
    sys.exit(0 if sys.argv[2] in data.get("branches", []) else 1)
except Exception:
    sys.exit(1)
PYEOF
}

_notified_cache_add() {
  local branch="$1"
  python3 - "$NOTIFIED_CACHE" "$branch" <<'PYEOF'
import sys, json, os
path, branch = sys.argv[1], sys.argv[2]
data = {"branches": []}
if os.path.exists(path):
    try:
        data = json.load(open(path))
    except Exception:
        pass
if branch not in data.get("branches", []):
    data.setdefault("branches", []).append(branch)
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
PYEOF
}

_notified_cache_remove() {
  local branch="$1"
  python3 - "$NOTIFIED_CACHE" "$branch" <<'PYEOF'
import sys, json, os
path, branch = sys.argv[1], sys.argv[2]
if not os.path.exists(path): sys.exit(0)
try:
    data = json.load(open(path))
    data["branches"] = [b for b in data.get("branches", []) if b != branch]
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
except Exception:
    pass
PYEOF
}

# ---------------------------------------------------------------------------
# Task 1 + 2: Merged branches > 7d, Unmerged > 14d notify
# ---------------------------------------------------------------------------
_cleanup_branches() {
  _log "=== Branch cleanup ==="
  local now; now=$(_now_epoch)
  local deleted=0 notified=0

  # Build merged-into-main set
  local merged_set
  merged_set=$(git -C "$REPO_ROOT" branch --merged main 2>/dev/null | sed 's/^[* ]*//')

  while IFS= read -r line; do
    # line format: "refs/heads/feature/foo <unix-timestamp>"
    local refname ts branch
    refname=$(printf '%s' "$line" | awk '{print $1}')
    ts=$(printf '%s' "$line" | awk '{print $2}')
    branch="${refname#refs/heads/}"

    # Skip current branch
    local current
    current=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
    [ "$branch" = "$current" ] && continue
    # Skip main
    [ "$branch" = "main" ] && continue

    local age_days=$(( (now - ts) / 86400 ))
    local is_merged=0
    if printf '%s\n' "$merged_set" | grep -qxF "$branch" 2>/dev/null; then
      is_merged=1
    fi

    if [[ "$is_merged" -eq 1 && "$age_days" -gt 7 ]]; then
      _log "Delete merged branch '$branch' (${age_days}d old)"
      if ! _dry; then
        git -C "$REPO_ROOT" branch -D "$branch" 2>/dev/null || true
        audit_record "cleanup" "branch-delete" "$branch" "Merged branch older than 7 days (${age_days}d)"
        _notified_cache_remove "$branch"
        deleted=$(( deleted + 1 ))
      else
        _dry_log "Would delete merged branch: $branch"
      fi
    elif [[ "$is_merged" -eq 0 && "$age_days" -gt 14 ]]; then
      if ! _notified_cache_contains "$branch"; then
        _log "Notify: unmerged branch '$branch' is ${age_days}d old"
        if ! _dry; then
          _notify "warn" "cleanup" "Old unmerged branch" "Branch '$branch' is ${age_days} days old and not yet merged into main."
          audit_record "cleanup" "branch-warn" "$branch" "Unmerged branch older than 14 days (${age_days}d) — notification sent"
          _notified_cache_add "$branch"
          notified=$(( notified + 1 ))
        else
          _dry_log "Would notify about unmerged branch: $branch"
        fi
      fi
    fi
  done < <(git -C "$REPO_ROOT" for-each-ref \
    --format='%(refname:short) %(committerdate:unix)' \
    'refs/heads/feature/*' 'refs/heads/fix/*' 'refs/heads/chore/*' 2>/dev/null)

  printf '%d %d' "$deleted" "$notified"
}

# ---------------------------------------------------------------------------
# Task 3: Stashes > 7 days
# ---------------------------------------------------------------------------
_cleanup_stashes() {
  _log "=== Stash cleanup ==="
  local now; now=$(_now_epoch)
  local dropped=0

  # git stash list format with %gd = stash@{N}, %ci = committer date ISO
  local stash_list
  stash_list=$(git -C "$REPO_ROOT" stash list --format='%gd %ci' 2>/dev/null || true)

  if [ -z "$stash_list" ]; then
    printf '%d' "$dropped"
    return
  fi

  # Process in reverse order (highest index first) so indices stay stable
  local entries=()
  while IFS= read -r line; do
    entries+=("$line")
  done <<< "$stash_list"

  # Reverse iterate
  for (( i=${#entries[@]}-1; i>=0; i-- )); do
    local line="${entries[$i]}"
    local ref date_str
    ref=$(printf '%s' "$line" | awk '{print $1}')
    date_str=$(printf '%s' "$line" | awk '{$1=""; print $0}' | xargs)
    local ts
    ts=$(date -j -f '%Y-%m-%d %H:%M:%S %z' "$date_str" +%s 2>/dev/null \
      || date --date="$date_str" +%s 2>/dev/null \
      || echo "0")
    local age_days=$(( (now - ts) / 86400 ))

    if [[ "$age_days" -gt 7 ]]; then
      _log "Drop stash '$ref' (${age_days}d old)"
      if ! _dry; then
        git -C "$REPO_ROOT" stash drop "$ref" 2>/dev/null || true
        audit_record "cleanup" "stash-drop" "$ref" "Stash older than 7 days (${age_days}d)"
        dropped=$(( dropped + 1 ))
      else
        _dry_log "Would drop stash: $ref (${age_days}d)"
      fi
    fi
  done

  printf '%d' "$dropped"
}

# ---------------------------------------------------------------------------
# Task 4: Run-logs > 30 days
# ---------------------------------------------------------------------------
_cleanup_run_logs() {
  _log "=== Run-log cleanup (>30d) ==="
  local runs_dir="$REPO_ROOT/.claude/backlog/runs"
  local deleted=0

  if [ ! -d "$runs_dir" ]; then
    printf '%d' "$deleted"
    return
  fi

  while IFS= read -r f; do
    _log "Delete old log: $f"
    if ! _dry; then
      rm -f "$f"
      deleted=$(( deleted + 1 ))
    else
      _dry_log "Would delete log: $f"
    fi
  done < <(find "$runs_dir" -name '*.log' -mtime +30 2>/dev/null)

  printf '%d' "$deleted"
}

# ---------------------------------------------------------------------------
# Task 5: Disputes > 90 days → archive as tar.gz
# ---------------------------------------------------------------------------
_cleanup_disputes() {
  _log "=== Dispute archive (>90d) ==="
  local disputes_dir="$REPO_ROOT/.claude/disputes"
  local archive_base="$disputes_dir/archive"
  local archived=0

  if [ ! -d "$disputes_dir" ]; then
    printf '%d' "$archived"
    return
  fi

  local now; now=$(_now_epoch)

  while IFS= read -r dir; do
    local id; id=$(basename "$dir")
    # Get mtime of directory
    local mtime
    mtime=$(stat -f '%m' "$dir" 2>/dev/null || stat -c '%Y' "$dir" 2>/dev/null || echo "0")
    local age_days=$(( (now - mtime) / 86400 ))

    if [[ "$age_days" -gt 90 ]]; then
      local year; year=$(date -r "$mtime" +%Y 2>/dev/null || date +%Y)
      local target_dir="$archive_base/$year"
      local target="$target_dir/${id}.tar.gz"
      _log "Archive dispute '$id' (${age_days}d old) → $target"
      if ! _dry; then
        mkdir -p "$target_dir"
        tar -czf "$target" -C "$disputes_dir" "$id" 2>/dev/null || true
        rm -rf "$dir"
        audit_record "cleanup" "dispute-archive" "$id" "Dispute dir older than 90 days archived to ${target}"
        archived=$(( archived + 1 ))
      else
        _dry_log "Would archive dispute: $id → $target"
      fi
    fi
  done < <(find "$disputes_dir" -mindepth 1 -maxdepth 1 -type d \
    ! -name 'archive' 2>/dev/null)

  printf '%d' "$archived"
}

# ---------------------------------------------------------------------------
# Task 6: Audit files > 30 days → rotate into archive tar.gz per month
# ---------------------------------------------------------------------------
_cleanup_audit_files() {
  _log "=== Audit file rotation (>30d) ==="
  local audit_dir="$REPO_ROOT/.claude/audit"
  local archive_base="$audit_dir/archive"
  local rotated=0

  if [ ! -d "$audit_dir" ]; then
    printf '%d' "$rotated"
    return
  fi

  local now; now=$(_now_epoch)

  while IFS= read -r f; do
    local fname; fname=$(basename "$f")
    local mtime
    mtime=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo "0")
    local age_days=$(( (now - mtime) / 86400 ))

    if [[ "$age_days" -gt 30 ]]; then
      # Determine year/month from filename (YYYY-MM-DD.md) or fallback to mtime
      local year month
      if [[ "$fname" =~ ^([0-9]{4})-([0-9]{2})-[0-9]{2}\.md$ ]]; then
        year="${BASH_REMATCH[1]}"
        month="${BASH_REMATCH[2]}"
      else
        year=$(date -r "$mtime" +%Y 2>/dev/null || date +%Y)
        month=$(date -r "$mtime" +%m 2>/dev/null || date +%m)
      fi

      local target_dir="$archive_base/$year"
      local archive_name="${year}-${month}.tar.gz"
      local target="$target_dir/$archive_name"
      _log "Rotate audit '$fname' (${age_days}d) → $archive_name"

      if ! _dry; then
        mkdir -p "$target_dir"
        # Unlock file: remove immutable flag + make writable
        chflags nouchg "$f" 2>/dev/null || true
        chmod 0644 "$f" 2>/dev/null || true

        # Append to monthly archive (create or update)
        if [ -f "$target" ]; then
          # Extract existing, add new file, repack
          local tmp_dir; tmp_dir=$(mktemp -d)
          tar -xzf "$target" -C "$tmp_dir" 2>/dev/null || true
          cp "$f" "$tmp_dir/$fname"
          tar -czf "$target" -C "$tmp_dir" . 2>/dev/null || true
          rm -rf "$tmp_dir"
        else
          tar -czf "$target" -C "$audit_dir" "$fname" 2>/dev/null || true
        fi

        rm -f "$f"
        audit_record "cleanup" "audit-rotate" "$fname" "Audit file older than 30 days rotated to ${target}"
        rotated=$(( rotated + 1 ))
      else
        _dry_log "Would rotate audit file: $fname → $archive_name"
      fi
    fi
  done < <(find "$audit_dir" -maxdepth 1 -name '*.md' -mtime +30 2>/dev/null)

  printf '%d' "$rotated"
}

# ---------------------------------------------------------------------------
# Task 7: test-runs > 14 days
# ---------------------------------------------------------------------------
_cleanup_test_runs() {
  _log "=== Test-run cleanup (>14d) ==="
  local test_runs_dir="$REPO_ROOT/.claude/test-runs"
  local deleted=0

  if [ ! -d "$test_runs_dir" ]; then
    printf '%d' "$deleted"
    return
  fi

  while IFS= read -r dir; do
    _log "Delete old test-run: $(basename "$dir")"
    if ! _dry; then
      rm -rf "$dir"
      deleted=$(( deleted + 1 ))
    else
      _dry_log "Would delete test-run dir: $(basename "$dir")"
    fi
  done < <(find "$test_runs_dir" -maxdepth 1 -type d -mtime +14 \
    ! -path "$test_runs_dir" 2>/dev/null)

  printf '%d' "$deleted"
}

# ---------------------------------------------------------------------------
# Task 8: Orphaned worktrees
# ---------------------------------------------------------------------------
_cleanup_worktrees() {
  _log "=== Worktree prune ==="
  if ! _dry; then
    git -C "$REPO_ROOT" worktree prune 2>/dev/null || true
    audit_record "cleanup" "worktree-prune" "all" "git worktree prune — removed stale worktree refs"
  else
    _dry_log "Would run: git worktree prune"
  fi
}

# ---------------------------------------------------------------------------
# Main pass
# ---------------------------------------------------------------------------
_run_pass() {
  _log "Starting cleanup pass (dry-run=$DRY_RUN)"

  local branch_result; branch_result=$(_cleanup_branches)
  local branches_deleted; branches_deleted=$(printf '%s' "$branch_result" | awk '{print $1}')
  local branches_notified; branches_notified=$(printf '%s' "$branch_result" | awk '{print $2}')

  local stashes_dropped; stashes_dropped=$(_cleanup_stashes)
  local logs_deleted; logs_deleted=$(_cleanup_run_logs)
  local disputes_archived; disputes_archived=$(_cleanup_disputes)
  local audit_rotated; audit_rotated=$(_cleanup_audit_files)
  local test_runs_deleted; test_runs_deleted=$(_cleanup_test_runs)
  _cleanup_worktrees

  local summary="branches_deleted=${branches_deleted} branches_notified=${branches_notified} stashes_dropped=${stashes_dropped} logs_deleted=${logs_deleted} disputes_archived=${disputes_archived} audit_rotated=${audit_rotated} test_runs_deleted=${test_runs_deleted}"

  _log "Cleanup summary: $summary"

  if ! _dry; then
    audit_record "cleanup" "pass-complete" "daily-cleanup" "$summary"
    _notify "info" "cleanup" "Daily cleanup done" "$summary"
  else
    _log "[DRY-RUN] No changes were made."
  fi
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if [[ "$MODE" == "daemon" ]]; then
  while true; do
    _run_pass
    _log "Sleeping 86400s until next pass..."
    sleep 86400
  done
else
  _run_pass
fi
