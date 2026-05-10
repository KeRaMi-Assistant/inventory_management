#!/usr/bin/env bash
# recover.sh — Auto-Recovery-Watchdog (P3-5).
#
# Usage:
#   recover.sh           — equivalent to --once
#   recover.sh --once    — single iteration: dead PIDs, hanging workers, stale worktrees, stash-cleanup
#   recover.sh --status  — print recovery-counts.json
#   recover.sh --reset-counter <slug>  — reset counter for a slug to 0
#
# Runs every 5 min via LaunchAgent (see .claude/recovery-launchagent.plist.template).
#
# IMPORTANT: This file is in the Self-Mod-Blocklist.

set -uo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

LIB_WORKTREE="${SCRIPT_DIR}/lib/worktree.sh"
LIB_AUDIT="${SCRIPT_DIR}/lib/audit.sh"
NOTIFY_SH="${SCRIPT_DIR}/notify.sh"

OVERSEER_DIR="${REPO_ROOT}/.claude/overseer"
WORKERS_DIR="${OVERSEER_DIR}/state/workers"
INBOX_DIR="${OVERSEER_DIR}/inbox"
FAILED_DIR="${OVERSEER_DIR}/failed"
RECOVERY_COUNTS_JSON="${OVERSEER_DIR}/state/recovery-counts.json"

# ---------------------------------------------------------------------------
# Source libraries (best-effort)
# ---------------------------------------------------------------------------
if [ -f "$LIB_WORKTREE" ]; then
  # worktree.sh uses set -euo pipefail — source in subshell-safe manner
  set +u +e
  # shellcheck disable=SC1090
  source "$LIB_WORKTREE" 2>/dev/null || true
  set -u
fi

if [ -f "$LIB_AUDIT" ]; then
  set +u +e
  # shellcheck disable=SC1090
  source "$LIB_AUDIT" 2>/dev/null || true
  set -u
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_log() { printf '[recover] %s\n' "$*" >&2; }

_audit() {
  local action="$1" subject="$2" reason="$3"
  if command -v audit_record >/dev/null 2>&1; then
    audit_record "recover" "$action" "$subject" "$reason" 2>/dev/null || true
  fi
}

_notify() {
  local severity="$1" title="$2" body="$3"
  local topic="${NTFY_TOPIC:-claude-code}"
  if [ -x "$NOTIFY_SH" ]; then
    REPO_ROOT="$REPO_ROOT" "$NOTIFY_SH" "$severity" "$topic" "$title" "$body" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# _read_counts  → reads RECOVERY_COUNTS_JSON into global assoc array
# _write_counts → writes assoc array back
# ---------------------------------------------------------------------------
_read_counts() {
  mkdir -p "$(dirname "$RECOVERY_COUNTS_JSON")"
  if [ ! -f "$RECOVERY_COUNTS_JSON" ]; then
    printf '{}' > "$RECOVERY_COUNTS_JSON"
  fi
}

_get_count() {
  local slug="$1"
  python3 - "$RECOVERY_COUNTS_JSON" "$slug" <<'PY'
import sys, json
data = json.load(open(sys.argv[1])) if __import__('os').path.getsize(sys.argv[1]) > 0 else {}
print(data.get(sys.argv[2], {}).get("count", 0))
PY
}

_increment_count() {
  local slug="$1"
  local iso_now
  iso_now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  python3 - "$RECOVERY_COUNTS_JSON" "$slug" "$iso_now" <<'PY'
import sys, json, os

path, slug, iso = sys.argv[1], sys.argv[2], sys.argv[3]
data = json.load(open(path)) if os.path.getsize(path) > 0 else {}
entry = data.get(slug, {"count": 0, "last_recovered": "", "history": []})
entry["count"] += 1
entry["last_recovered"] = iso
entry.setdefault("history", []).append(iso)
# Keep last 10 history entries
entry["history"] = entry["history"][-10:]
data[slug] = entry
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(entry["count"])
PY
}

_reset_count() {
  local slug="$1"
  python3 - "$RECOVERY_COUNTS_JSON" "$slug" <<'PY'
import sys, json, os
path, slug = sys.argv[1], sys.argv[2]
data = json.load(open(path)) if os.path.getsize(path) > 0 else {}
if slug in data:
    data[slug] = {"count": 0, "last_recovered": "", "history": []}
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print(f"reset: {slug}")
else:
    print(f"not found: {slug}")
PY
}

# ---------------------------------------------------------------------------
# release_item_to_inbox_with_marker <item_slug> <count>
# Writes (or moves) item to inbox with [recovered Nx] prefix.
# If count >= 3 → sends to failed/ instead.
# ---------------------------------------------------------------------------
release_item_to_inbox_with_marker() {
  local item_slug="$1"
  local count="$2"
  local item_src_path="${3:-}"  # optional: original file path to move

  mkdir -p "$INBOX_DIR" "$FAILED_DIR"

  if [ "$count" -ge 3 ]; then
    # Send to failed/
    local dest_name="[recovered-${count}x]-${item_slug}.md"
    local dest_path="${FAILED_DIR}/${dest_name}"
    if [ -n "$item_src_path" ] && [ -f "$item_src_path" ]; then
      mv "$item_src_path" "$dest_path" 2>/dev/null || true
    else
      # Create a stub with marker
      printf '# Recovered (3x limit) — %s\n\nRecovery count: %s\n' \
        "$item_slug" "$count" > "$dest_path"
    fi
    _log "CRITICAL: slug=${item_slug} recovered ${count}x — moved to failed/ as ${dest_name}"
    _audit "recover_to_failed" "$item_slug" "count=${count} >= 3 → failed/"
    _notify critical "Recovery: 3-cycle limit hit" \
      "Item ${item_slug} failed 3x recovery — moved to failed/. Manual intervention required."
  else
    # Return to inbox with marker
    local marker="[recovered ${count}x]"
    local dest_name="${marker}-${item_slug}.md"
    local dest_path="${INBOX_DIR}/${dest_name}"
    if [ -n "$item_src_path" ] && [ -f "$item_src_path" ]; then
      mv "$item_src_path" "$dest_path" 2>/dev/null || true
    else
      printf '# Recovered — %s\n\nRecovery count: %s\n' \
        "$item_slug" "$count" > "$dest_path"
    fi
    _log "INFO: slug=${item_slug} returned to inbox as ${dest_name} (count=${count})"
    _audit "recover_to_inbox" "$item_slug" "count=${count} → inbox as ${dest_name}"
    _notify info "Recovery: worker requeued" \
      "Item ${item_slug} recovered (attempt ${count}) — back in inbox."
  fi
}

# ---------------------------------------------------------------------------
# _slug_from_pid_file <pid_file_path>
# Extracts worker slug from pid file JSON content or filename.
# ---------------------------------------------------------------------------
_slug_from_pid_file() {
  local pid_file="$1"
  python3 - "$pid_file" <<'PY' 2>/dev/null || basename "$pid_file" .pid
import sys, json, os
path = sys.argv[1]
try:
    data = json.load(open(path))
    # Try common keys
    for key in ("slug", "item_slug", "task_slug"):
        if key in data:
            print(data[key])
            sys.exit(0)
    # Fallback: derive from item_path
    item = data.get("item_path", "")
    if item:
        base = os.path.basename(item)
        # Strip .md and PID suffix (<slug>.<pid>.md)
        slug = base.replace(".md", "")
        slug = __import__("re").sub(r'\.[0-9]+$', '', slug)
        print(slug)
        sys.exit(0)
except Exception:
    pass
# Fallback: filename without extension
print(os.path.basename(path).replace(".pid", ""))
PY
}

_pid_from_pid_file() {
  local pid_file="$1"
  python3 - "$pid_file" <<'PY' 2>/dev/null || basename "$pid_file" .pid | grep -oE '[0-9]+' | head -1
import sys, json
try:
    data = json.load(open(sys.argv[1]))
    print(data.get("pid", data.get("worker_pid", "")))
except Exception:
    pass
PY
}

_started_iso_from_pid_file() {
  local pid_file="$1"
  python3 - "$pid_file" <<'PY' 2>/dev/null || echo ""
import sys, json
try:
    data = json.load(open(sys.argv[1]))
    print(data.get("started_iso", data.get("started", "")))
except Exception:
    pass
PY
}

_worktree_slug_from_pid_file() {
  local pid_file="$1"
  python3 - "$pid_file" <<'PY' 2>/dev/null || echo ""
import sys, json
try:
    data = json.load(open(sys.argv[1]))
    print(data.get("worktree_slug", data.get("slug", "")))
except Exception:
    pass
PY
}

_item_path_from_pid_file() {
  local pid_file="$1"
  python3 - "$pid_file" <<'PY' 2>/dev/null || echo ""
import sys, json
try:
    data = json.load(open(sys.argv[1]))
    print(data.get("item_path", ""))
except Exception:
    pass
PY
}

# ---------------------------------------------------------------------------
# _collect_active_pids → prints all PIDs from active (alive) pid-files
# ---------------------------------------------------------------------------
_collect_active_pids() {
  if [ ! -d "$WORKERS_DIR" ] || ! compgen -G "${WORKERS_DIR}/*.pid" >/dev/null 2>&1; then
    return 0
  fi
  for pf in "${WORKERS_DIR}/"*.pid; do
    [ -f "$pf" ] || continue
    local pid
    pid="$(_pid_from_pid_file "$pf")"
    [[ -z "$pid" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      printf '%s\n' "$pid"
    fi
  done
}

# ---------------------------------------------------------------------------
# _collect_active_worktree_slugs → prints slugs from all active pid-files
# ---------------------------------------------------------------------------
_collect_active_worktree_slugs() {
  if [ ! -d "$WORKERS_DIR" ] || ! compgen -G "${WORKERS_DIR}/*.pid" >/dev/null 2>&1; then
    return 0
  fi
  for pf in "${WORKERS_DIR}/"*.pid; do
    [ -f "$pf" ] || continue
    local pid
    pid="$(_pid_from_pid_file "$pf")"
    [[ -z "$pid" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      local wslug
      wslug="$(_worktree_slug_from_pid_file "$pf")"
      [[ -n "$wslug" ]] && printf '%s\n' "$wslug"
    fi
  done
}

# ---------------------------------------------------------------------------
# _do_recover_pid_file <pid_file> <reason>
# Common recovery path: clean up pid-file + worktree + requeue item.
# ---------------------------------------------------------------------------
_do_recover_pid_file() {
  local pid_file="$1"
  local reason="$2"
  local kill_first="${3:-0}"  # if 1, kill -9 the PID first

  local pid wslug item_path item_slug
  pid="$(_pid_from_pid_file "$pid_file")"
  wslug="$(_worktree_slug_from_pid_file "$pid_file")"
  item_path="$(_item_path_from_pid_file "$pid_file")"
  item_slug="$(_slug_from_pid_file "$pid_file")"

  if [ "$kill_first" -eq 1 ] && [ -n "$pid" ]; then
    _log "WARN: killing hanging worker PID=${pid} (${reason})"
    kill -9 "$pid" 2>/dev/null || true
  fi

  # Increment recovery counter
  _read_counts
  local count
  count="$(_increment_count "$item_slug")"

  # Remove worktree
  if [ -n "$wslug" ] && command -v worktree_remove >/dev/null 2>&1; then
    worktree_remove "$wslug" 2>/dev/null || true
    _log "INFO: removed worktree slug=${wslug}"
  fi

  # Remove pid-file
  rm -f "$pid_file" 2>/dev/null || true

  # Remove any associated .exit file
  local exit_file="${pid_file%.pid}.exit"
  rm -f "$exit_file" 2>/dev/null || true

  # Requeue item (or move to failed)
  release_item_to_inbox_with_marker "$item_slug" "$count" "$item_path"

  _audit "$reason" "$item_slug" "pid=${pid} wslug=${wslug} recovery_count=${count}"
  _log "INFO: recovery done — slug=${item_slug} pid=${pid} count=${count}"
}

# ---------------------------------------------------------------------------
# Check 1: Dead worker PIDs
# ---------------------------------------------------------------------------
_check_dead_pids() {
  _log "Check 1: dead worker PIDs"
  if [ ! -d "$WORKERS_DIR" ] || ! compgen -G "${WORKERS_DIR}/*.pid" >/dev/null 2>&1; then
    _log "  no pid-files found — skip"
    return 0
  fi

  for pid_file in "${WORKERS_DIR}/"*.pid; do
    [ -f "$pid_file" ] || continue

    local pid
    pid="$(_pid_from_pid_file "$pid_file")"
    if [ -z "$pid" ]; then
      _log "  WARN: could not extract PID from ${pid_file} — skipping"
      continue
    fi

    # Skip alive workers
    if kill -0 "$pid" 2>/dev/null; then
      continue
    fi

    # Dead — check for .exit file (clean exit)
    local exit_file="${pid_file%.pid}.exit"
    if [ -f "$exit_file" ]; then
      # Clean exit: pid-file will be cleaned up by the worker itself or overseer
      _log "  PID=${pid} dead + .exit file present — not orphan, skip"
      continue
    fi

    # Orphan: dead without .exit
    _log "  ORPHAN: pid-file=${pid_file} PID=${pid} — recovering"
    _do_recover_pid_file "$pid_file" "recover_dead_pid" 0
  done
}

# ---------------------------------------------------------------------------
# Check 2: Hanging workers (timeout > RECOVER_HANG_TIMEOUT_MIN, default 60)
# ---------------------------------------------------------------------------
_check_hanging_workers() {
  local timeout_min="${RECOVER_HANG_TIMEOUT_MIN:-60}"
  _log "Check 2: hanging workers (timeout=${timeout_min}min)"

  if [ ! -d "$WORKERS_DIR" ] || ! compgen -G "${WORKERS_DIR}/*.pid" >/dev/null 2>&1; then
    _log "  no pid-files — skip"
    return 0
  fi

  local now_epoch
  now_epoch="$(date +%s)"
  local timeout_secs=$(( timeout_min * 60 ))

  for pid_file in "${WORKERS_DIR}/"*.pid; do
    [ -f "$pid_file" ] || continue

    local pid
    pid="$(_pid_from_pid_file "$pid_file")"
    if [ -z "$pid" ]; then continue; fi

    # Only check alive workers
    if ! kill -0 "$pid" 2>/dev/null; then continue; fi

    local started_iso
    started_iso="$(_started_iso_from_pid_file "$pid_file")"
    if [ -z "$started_iso" ]; then
      _log "  WARN: no started_iso in ${pid_file} — skip"
      continue
    fi

    # Parse ISO to epoch via python3
    local started_epoch
    started_epoch="$(python3 -c "
import sys, datetime
iso = sys.argv[1].rstrip('Z')
try:
    dt = datetime.datetime.fromisoformat(iso)
    print(int(dt.timestamp()))
except Exception:
    print(0)
" "$started_iso" 2>/dev/null || echo "0")"

    local elapsed=$(( now_epoch - started_epoch ))
    if [ "$elapsed" -gt "$timeout_secs" ]; then
      _log "  HANG: pid=${pid} started=${started_iso} elapsed=${elapsed}s > ${timeout_secs}s — killing"
      _do_recover_pid_file "$pid_file" "recover_hang_timeout" 1
    fi
  done
}

# ---------------------------------------------------------------------------
# Check 3: Dead worktrees (no active PID + stale last commit > 24h)
# ---------------------------------------------------------------------------
_check_dead_worktrees() {
  _log "Check 3: dead worktrees"
  if ! command -v worktree_list >/dev/null 2>&1; then
    _log "  worktree_list not available — skip"
    return 0
  fi

  local active_slugs
  active_slugs="$(_collect_active_worktree_slugs)"

  while IFS=$'\t' read -r wslug wt_path; do
    # Check if slug is in active workers
    if printf '%s\n' "$active_slugs" | grep -qxF "$wslug"; then
      continue  # active worker — leave it
    fi

    # Check stale: last commit > 24h ago
    local last_commit_epoch
    last_commit_epoch="$(git -C "$wt_path" log -1 --format="%ct" 2>/dev/null || echo "0")"
    local now_epoch
    now_epoch="$(date +%s)"
    local cutoff=$(( now_epoch - 24 * 3600 ))

    if [ "$last_commit_epoch" -lt "$cutoff" ]; then
      _log "  STALE WORKTREE: slug=${wslug} path=${wt_path} — removing"
      worktree_remove "$wslug" 2>/dev/null || true
      _audit "remove_stale_worktree" "$wslug" "no active pid + last commit > 24h"
      _notify info "Recovery: stale worktree removed" \
        "Worktree ${wslug} removed (no active worker, last commit > 24h)."
    fi
  done < <(worktree_list 2>/dev/null || true)
}

# ---------------------------------------------------------------------------
# Check 4: Stash cleanup (overseer-related stashes > 5)
# ---------------------------------------------------------------------------
_check_stash_cleanup() {
  _log "Check 4: stash cleanup"
  local stash_list
  stash_list="$(git -C "$REPO_ROOT" stash list 2>/dev/null | grep -i 'overseer\|worker\|recover' || true)"
  local count
  count="$(printf '%s' "$stash_list" | grep -c . || echo "0")"

  if [ "$count" -gt 5 ]; then
    _log "  INFO: ${count} overseer-related stashes > 5 — dropping oldest"
    # Drop oldest (highest index). stash@{N} where N = count-1.
    local oldest_idx=$(( count - 1 ))
    # Find the actual stash index in the full list
    local full_list
    full_list="$(git -C "$REPO_ROOT" stash list 2>/dev/null)"
    local full_count
    full_count="$(printf '%s\n' "$full_list" | grep -c . || echo "0")"
    if [ "$full_count" -gt 0 ]; then
      git -C "$REPO_ROOT" stash drop "stash@{$(( full_count - 1 ))}" 2>/dev/null || true
      _audit "stash_drop" "stash@{$(( full_count - 1 ))}" "overseer stash count ${count} > 5"
    fi
  fi
}

# ---------------------------------------------------------------------------
# run_once — single recovery iteration
# ---------------------------------------------------------------------------
run_once() {
  _log "=== recover.sh --once (RECOVER_HANG_TIMEOUT_MIN=${RECOVER_HANG_TIMEOUT_MIN:-60}) ==="
  mkdir -p "$WORKERS_DIR" "$INBOX_DIR" "$FAILED_DIR"

  _read_counts

  _check_dead_pids
  _check_hanging_workers
  _check_dead_worktrees
  _check_stash_cleanup

  _log "=== recovery iteration done ==="
}

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
MODE="once"
RESET_SLUG=""

for arg in "$@"; do
  case "$arg" in
    --once)   MODE="once" ;;
    --status) MODE="status" ;;
    --reset-counter)
      MODE="reset"
      ;;
    *)
      if [ "$MODE" = "reset" ] && [ -z "$RESET_SLUG" ]; then
        RESET_SLUG="$arg"
      else
        printf 'Usage: %s [--once|--status|--reset-counter <slug>]\n' "$(basename "$0")" >&2
        exit 1
      fi
      ;;
  esac
done

case "$MODE" in
  once)
    run_once
    ;;
  status)
    _read_counts
    if [ -f "$RECOVERY_COUNTS_JSON" ]; then
      cat "$RECOVERY_COUNTS_JSON"
    else
      printf '{}\n'
    fi
    ;;
  reset)
    if [ -z "$RESET_SLUG" ]; then
      printf 'ERROR: --reset-counter requires a slug argument\n' >&2
      exit 1
    fi
    _read_counts
    _reset_count "$RESET_SLUG"
    _log "Counter reset for slug: ${RESET_SLUG}"
    ;;
esac
