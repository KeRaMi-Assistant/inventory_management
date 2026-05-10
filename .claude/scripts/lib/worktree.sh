#!/usr/bin/env bash
# worktree.sh — Sourceable Bash-Library für Git-Worktree-Management
# Part of autonomous-council-swarm Phase 0 (P0-3).
#
# Note: Claude Code 2.1.138 has native --worktree/-w support.
# This wrapper is still needed for --max-budget-usd pass-through,
# symlink-strategy (Mitigation 7), disk-caps, pre-warm, and
# structured list/prune utilities used by the swarm orchestrator.
#
# Usage: source .claude/scripts/lib/worktree.sh
#
# Dependencies:
#   - git (required)
#   - gwq (optional; falls back to `git worktree` if not found)
#   - flutter (optional; only needed for WORKTREE_PREWARM=1)
#
# Environment variables (all optional):
#   WORKTREE_PREWARM=1        run `flutter pub get` after create
#   MOCK_DISK_FREE_GB=<n>     override disk-free check for testing
#   MOCK_DISK_FREE_PCT=<n>    override disk-free percent check for testing
#   WORKTREE_BASE_BRANCH=<b>  base branch for new worktrees (default: main)

set -euo pipefail

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_worktree_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || {
    echo "ERROR: not inside a git repo" >&2
    return 1
  }
}

_worktree_worker_dir() {
  local slug="$1"
  local repo_root
  repo_root="$(_worktree_repo_root)"
  local repo_parent
  repo_parent="$(dirname "$repo_root")"
  local repo_name
  repo_name="$(basename "$repo_root")"
  echo "${repo_parent}/${repo_name}_worker_${slug}"
}

_worktree_has_gwq() {
  command -v gwq &>/dev/null
}

_worktree_disk_check() {
  local repo_root="$1"
  # Allow test mocking via env vars
  local free_gb free_pct

  if [[ -n "${MOCK_DISK_FREE_GB:-}" ]]; then
    free_gb="$MOCK_DISK_FREE_GB"
  else
    # df -k: 1k-blocks; column 4 = available
    local avail_kb
    avail_kb=$(df -k "$repo_root" 2>/dev/null | awk 'NR==2{print $4}')
    free_gb=$(( avail_kb / 1024 / 1024 ))
  fi

  if [[ -n "${MOCK_DISK_FREE_PCT:-}" ]]; then
    free_pct="$MOCK_DISK_FREE_PCT"
  else
    # df output "Use%" column → invert to get free%
    local use_pct
    use_pct=$(df -k "$repo_root" 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}')
    free_pct=$(( 100 - use_pct ))
  fi

  if (( free_gb < 20 )); then
    echo "ERROR: disk too full — only ${free_gb} GB free (need ≥ 20 GB)" >&2
    return 4
  fi
  if (( free_pct < 30 )); then
    echo "ERROR: disk too full — only ${free_pct}% free (need ≥ 30%)" >&2
    return 4
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

# worktree_create <slug>
#   Creates a new git worktree at ../inventory_management_worker_<slug>
#   on branch feature/worker-<slug> from main (or WORKTREE_BASE_BRANCH).
#
# Exit codes:
#   0  success; prints worktree path
#   1  invalid slug
#   3  hard-cap (≥ 3 worker worktrees already exist)
#   4  insufficient disk space
#   5  pre-warm (flutter pub get) failed
#   6  acceptance validation failed (real .env* files found)
worktree_create() {
  local slug="${1:-}"
  if [[ -z "$slug" ]]; then
    echo "ERROR: worktree_create requires a slug argument" >&2
    return 1
  fi

  # Slug validation
  if ! [[ "$slug" =~ ^[a-z0-9][a-z0-9-]{0,30}$ ]]; then
    echo "ERROR: invalid slug '${slug}' — must match ^[a-z0-9][a-z0-9-]{0,30}$" >&2
    return 1
  fi

  local repo_root
  repo_root="$(_worktree_repo_root)"
  local worktree_path
  worktree_path="$(_worktree_worker_dir "$slug")"
  local branch_name="feature/worker-${slug}"
  local base_branch="${WORKTREE_BASE_BRANCH:-main}"

  # Hard-cap: count existing worker worktrees
  local count
  count=$(worktree_list 2>/dev/null | wc -l | tr -d ' ')
  if (( count >= 3 )); then
    echo "ERROR: hard-cap reached — ${count} worker worktrees already exist (max 3)" >&2
    return 3
  fi

  # Disk check
  _worktree_disk_check "$repo_root" || return 4

  # Already exists?
  if [[ -d "$worktree_path" ]]; then
    echo "WARNING: worktree path already exists: ${worktree_path}" >&2
    echo "$worktree_path"
    return 0
  fi

  # Resolve base branch: fall back to HEAD if given base_branch doesn't exist
  local resolved_base="$base_branch"
  if ! git -C "$repo_root" rev-parse --verify "$resolved_base" &>/dev/null; then
    resolved_base=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD)
    echo "WARNING: base branch '${base_branch}' not found, using '${resolved_base}'" >&2
  fi

  # Create worktree
  if _worktree_has_gwq; then
    gwq add "$branch_name" "$worktree_path" 2>/dev/null || \
      git -C "$repo_root" worktree add "$worktree_path" -b "$branch_name" "$resolved_base"
  else
    git -C "$repo_root" worktree add "$worktree_path" -b "$branch_name" "$resolved_base"
  fi

  # Symlink strategy for gitignored secrets (Mitigation 7)
  # Only files that actually exist in the main repo.
  # Use canonical (realpath) source so symlinks survive /var → /private/var on macOS.
  local secret_files=(".env" ".env.test" ".env.headless" ".env.local")
  local repo_root_real
  repo_root_real=$(cd "$repo_root" && pwd -P)
  for secret_file in "${secret_files[@]}"; do
    local src="${repo_root_real}/${secret_file}"
    local dst="${worktree_path}/${secret_file}"
    if [[ -f "$src" ]]; then
      ln -sf "$src" "$dst"
    fi
  done

  # Optional pre-warm
  if [[ "${WORKTREE_PREWARM:-0}" == "1" ]]; then
    if command -v flutter &>/dev/null; then
      echo "Pre-warming: flutter pub get in ${worktree_path}..." >&2
      if ! (cd "$worktree_path" && flutter pub get); then
        echo "ERROR: flutter pub get failed in ${worktree_path}" >&2
        # Clean up the worktree before returning error
        worktree_remove "$slug" 2>/dev/null || true
        return 5
      fi
    else
      echo "WARNING: flutter not in PATH — skipping pre-warm" >&2
    fi
  fi

  # Acceptance validation: no real .env* files (only symlinks allowed)
  local real_env_files
  real_env_files=$(find "$worktree_path" -maxdepth 1 -name '.env*' -type f 2>/dev/null || true)
  if [[ -n "$real_env_files" ]]; then
    echo "ERROR: real .env* files found in worktree (expected only symlinks):" >&2
    echo "$real_env_files" >&2
    return 6
  fi

  echo "$worktree_path"
}

# worktree_remove <slug>
#   Removes the git worktree for the given slug.
#   Idempotent: returns 0 if worktree does not exist.
worktree_remove() {
  local slug="${1:-}"
  if [[ -z "$slug" ]]; then
    echo "ERROR: worktree_remove requires a slug argument" >&2
    return 1
  fi

  local repo_root
  repo_root="$(_worktree_repo_root)"
  local worktree_path
  worktree_path="$(_worktree_worker_dir "$slug")"
  local branch_name="feature/worker-${slug}"

  # If worktree dir doesn't exist, nothing to do
  if [[ ! -d "$worktree_path" ]]; then
    return 0
  fi

  # Pre-cleanup: remove heavyweight build artifacts to free disk
  for cleanup_dir in ".dart_tool" "build"; do
    local target="${worktree_path}/${cleanup_dir}"
    if [[ -d "$target" ]]; then
      rm -rf "$target"
    fi
  done
  # Also .flutter-plugins-dependencies
  local flutter_plugins="${worktree_path}/.flutter-plugins-dependencies"
  if [[ -f "$flutter_plugins" ]]; then
    rm -f "$flutter_plugins"
  fi

  # Remove worktree
  if _worktree_has_gwq; then
    gwq remove "$worktree_path" 2>/dev/null || \
      git -C "$repo_root" worktree remove --force "$worktree_path"
  else
    git -C "$repo_root" worktree remove --force "$worktree_path"
  fi

  # Clean up git's worktree tracking
  git -C "$repo_root" worktree prune 2>/dev/null || true

  # Delete branch if it exists and is fully merged
  if git -C "$repo_root" rev-parse --verify "$branch_name" &>/dev/null; then
    local merge_base
    merge_base=$(git -C "$repo_root" merge-base main "$branch_name" 2>/dev/null || true)
    local branch_tip
    branch_tip=$(git -C "$repo_root" rev-parse "$branch_name" 2>/dev/null || true)
    if [[ -n "$merge_base" && "$merge_base" == "$branch_tip" ]]; then
      git -C "$repo_root" branch -D "$branch_name" 2>/dev/null || true
    fi
  fi

  return 0
}

# worktree_list
#   Prints one line per worker worktree: <slug>\t<path>
#   Only lists inventory_management_worker_* worktrees (not the main repo).
worktree_list() {
  local repo_root
  repo_root="$(_worktree_repo_root)"
  local repo_parent
  repo_parent="$(dirname "$repo_root")"
  local repo_name
  repo_name="$(basename "$repo_root")"
  local pattern="${repo_parent}/${repo_name}_worker_"

  git -C "$repo_root" worktree list --porcelain 2>/dev/null \
    | grep '^worktree ' \
    | awk '{print $2}' \
    | grep "^${pattern}" \
    | while IFS= read -r wt_path; do
        local slug="${wt_path#${pattern}}"
        printf '%s\t%s\n' "$slug" "$wt_path"
      done
}

# worktree_prune_stale <hours>
#   Removes worktrees whose last commit is older than <hours> hours.
worktree_prune_stale() {
  local hours="${1:-}"
  if [[ -z "$hours" ]] || ! [[ "$hours" =~ ^[0-9]+$ ]]; then
    echo "ERROR: worktree_prune_stale requires a positive integer <hours> argument" >&2
    return 1
  fi

  local cutoff_epoch
  cutoff_epoch=$(( $(date +%s) - hours * 3600 ))
  local pruned=()

  while IFS=$'\t' read -r slug wt_path; do
    if [[ ! -d "$wt_path/.git" ]] && [[ ! -f "$wt_path/.git" ]]; then
      # No git object — stale/broken, prune it
      worktree_remove "$slug" && pruned+=("$slug")
      continue
    fi
    local last_commit_epoch
    last_commit_epoch=$(git -C "$wt_path" log -1 --format="%ct" 2>/dev/null || echo "0")
    if (( last_commit_epoch < cutoff_epoch )); then
      echo "Pruning stale worktree: ${slug} (last commit: $(date -r "$last_commit_epoch" 2>/dev/null || echo "unknown"))" >&2
      worktree_remove "$slug" && pruned+=("$slug")
    fi
  done < <(worktree_list)

  if (( ${#pruned[@]} > 0 )); then
    printf '%s\n' "${pruned[@]}"
  fi
}
