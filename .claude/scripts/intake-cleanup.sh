#!/usr/bin/env bash
# intake-cleanup.sh — Stale-Move-Cron-Hook for pending-approval files (T16).
#
# Usage:
#   bash intake-cleanup.sh [--dry-run]
#
# Behaviour:
#   1. Iterates .claude/stakeholder/pending-approval/*.md (top-level only).
#      - If created_at older than INTAKE_STALE_DAYS (default 7): move to stale/.
#        Audit: intake_pending_stalemove.
#   2. Iterates .claude/stakeholder/pending-approval/stale/*.md.
#      - If mtime > INTAKE_PURGE_DAYS (default 30): delete + audit.
#   3. Reminder: if ≥ INTAKE_REMINDER_MIN (default 3) top-level files older than
#      INTAKE_REMINDER_H (default 24h), send notify.sh info intake-stale-reminder.
#
# Integration with cleanup.sh (optional sub-call):
#   Add to cleanup.sh _run_pass: bash "$SCRIPT_DIR/intake-cleanup.sh" "$DRY_RUN_FLAG"
#
# IMPORTANT: This file is in the Self-Mod-Blocklist (P0-0).

set -uo pipefail

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
AUDIT_LIB="${AUDIT_LIB:-$SCRIPT_DIR/lib/audit.sh}"
NOTIFY_SH="${NOTIFY_SH:-$REPO_ROOT/.claude/scripts/notify.sh}"

PENDING_DIR="$REPO_ROOT/.claude/stakeholder/pending-approval"
STALE_DIR="$PENDING_DIR/stale"

# ---------------------------------------------------------------------------
# Config (override via env)
# ---------------------------------------------------------------------------
INTAKE_STALE_DAYS="${INTAKE_STALE_DAYS:-7}"
INTAKE_PURGE_DAYS="${INTAKE_PURGE_DAYS:-30}"
INTAKE_REMINDER_MIN="${INTAKE_REMINDER_MIN:-3}"
INTAKE_REMINDER_H="${INTAKE_REMINDER_H:-24}"

# ---------------------------------------------------------------------------
# Parse CLI
# ---------------------------------------------------------------------------
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      printf 'Usage: %s [--dry-run]\n' "$(basename "$0")" >&2
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

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_now_epoch() { date +%s; }
_dry()      { [[ "$DRY_RUN" -eq 1 ]]; }
_log()      { printf '[intake-cleanup] %s\n' "$*" >&2; }
_dry_log()  { _dry && printf '[DRY-RUN] %s\n' "$*" >&2; }

_notify() {
  local severity="$1" topic="$2" title="$3" body="$4"
  if [ -x "$NOTIFY_SH" ]; then
    bash "$NOTIFY_SH" "$severity" "$topic" "$title" "$body" 2>/dev/null || true
  fi
}

# Parse created_at from YAML frontmatter (--- ... ---).
# Returns epoch seconds, or 0 if not found / not parseable.
_parse_created_at() {
  local file="$1"
  local val
  val=$(grep -m1 '^created_at:' "$file" 2>/dev/null | sed 's/^created_at:[[:space:]]*//' | tr -d '"'"'" | xargs)
  if [ -z "$val" ]; then
    echo 0
    return
  fi
  # Try macOS date -j, then GNU date --date
  local epoch
  epoch=$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "$val" +%s 2>/dev/null) \
    || epoch=$(date --date="$val" +%s 2>/dev/null) \
    || epoch=0
  echo "${epoch:-0}"
}

# ---------------------------------------------------------------------------
# Task 1: Move stale pending-approval files (>INTAKE_STALE_DAYS) to stale/
# ---------------------------------------------------------------------------
_sweep_stale() {
  _log "=== Stale-sweep (pending-approval > ${INTAKE_STALE_DAYS}d) ==="

  if [ ! -d "$PENDING_DIR" ]; then
    _log "pending-approval dir not found, skipping."
    return
  fi

  local now; now=$(_now_epoch)
  local stale_threshold=$(( INTAKE_STALE_DAYS * 86400 ))
  local moved=0

  while IFS= read -r f; do
    local fname; fname=$(basename "$f")
    local slug; slug="${fname%.md}"

    local created_epoch
    created_epoch=$(_parse_created_at "$f")

    local age_s=$(( now - created_epoch ))
    # Fallback to mtime if created_at missing or unparseable
    if [ "$created_epoch" -eq 0 ]; then
      created_epoch=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo "$now")
      age_s=$(( now - created_epoch ))
    fi

    local age_days=$(( age_s / 86400 ))

    if [ "$age_s" -ge "$stale_threshold" ]; then
      _log "Move to stale: $fname (${age_days}d old)"
      if ! _dry; then
        mkdir -p "$STALE_DIR"
        mv "$f" "$STALE_DIR/$fname"
        audit_record "intake-cleanup" "intake_pending_stalemove" "$slug" \
          "age_days=${age_days} threshold=${INTAKE_STALE_DAYS}"
        moved=$(( moved + 1 ))
      else
        _dry_log "Would move to stale: $fname (${age_days}d)"
      fi
    fi
  done < <(find "$PENDING_DIR" -maxdepth 1 -name '*.md' 2>/dev/null)

  _log "Moved $moved files to stale/"
}

# ---------------------------------------------------------------------------
# Task 2: Purge stale/ files older than INTAKE_PURGE_DAYS
# ---------------------------------------------------------------------------
_purge_stale() {
  _log "=== Purge stale (>  ${INTAKE_PURGE_DAYS}d) ==="

  if [ ! -d "$STALE_DIR" ]; then
    return
  fi

  local now; now=$(_now_epoch)
  local purge_threshold=$(( INTAKE_PURGE_DAYS * 86400 ))
  local deleted=0

  while IFS= read -r f; do
    local fname; fname=$(basename "$f")
    local slug; slug="${fname%.md}"
    local mtime
    mtime=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo "$now")
    local age_s=$(( now - mtime ))
    local age_days=$(( age_s / 86400 ))

    if [ "$age_s" -ge "$purge_threshold" ]; then
      _log "Purge stale file: $fname (${age_days}d old)"
      if ! _dry; then
        rm -f "$f"
        audit_record "intake-cleanup" "intake_stale_purged" "$slug" \
          "age_days=${age_days} threshold=${INTAKE_PURGE_DAYS}"
        deleted=$(( deleted + 1 ))
      else
        _dry_log "Would purge: $fname (${age_days}d)"
      fi
    fi
  done < <(find "$STALE_DIR" -maxdepth 1 -name '*.md' 2>/dev/null)

  _log "Purged $deleted stale files."
}

# ---------------------------------------------------------------------------
# Task 3: Reminder when ≥ INTAKE_REMINDER_MIN files older than INTAKE_REMINDER_H
# ---------------------------------------------------------------------------
_reminder_check() {
  _log "=== Reminder check (>= ${INTAKE_REMINDER_MIN} files older than ${INTAKE_REMINDER_H}h) ==="

  if [ ! -d "$PENDING_DIR" ]; then
    return
  fi

  local now; now=$(_now_epoch)
  local reminder_threshold=$(( INTAKE_REMINDER_H * 3600 ))
  local old_count=0

  while IFS= read -r f; do
    local created_epoch
    created_epoch=$(_parse_created_at "$f")
    if [ "$created_epoch" -eq 0 ]; then
      created_epoch=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo "$now")
    fi
    local age_s=$(( now - created_epoch ))
    if [ "$age_s" -ge "$reminder_threshold" ]; then
      old_count=$(( old_count + 1 ))
    fi
  done < <(find "$PENDING_DIR" -maxdepth 1 -name '*.md' 2>/dev/null)

  if [ "$old_count" -ge "$INTAKE_REMINDER_MIN" ]; then
    _log "Reminder: $old_count pending-approval files older than ${INTAKE_REMINDER_H}h"
    if ! _dry; then
      _notify "info" "intake-stale-reminder" \
        "Alte Vorschläge warten" \
        "Du hast ${old_count} alte Vorschläge — \`/yota pending\` zeigt alle."
    else
      _dry_log "Would send reminder: ${old_count} old files"
    fi
  else
    _log "No reminder needed ($old_count old files, threshold $INTAKE_REMINDER_MIN)."
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
_log "Starting intake-cleanup (dry-run=$DRY_RUN stale=${INTAKE_STALE_DAYS}d purge=${INTAKE_PURGE_DAYS}d)"
_sweep_stale
_purge_stale
_reminder_check
_log "intake-cleanup done."
