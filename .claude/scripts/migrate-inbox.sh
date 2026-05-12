#!/usr/bin/env bash
# migrate-inbox.sh — P4-0 Inbox-Pfad-Migration
#
# Vereint .claude/overseer/inbox/ und .claude/backlog/inbox/ auf einen
# einzigen Pfad: .claude/backlog/inbox/ (Single-Inbox-Modus).
#
# Nach Migration: Overseer INBOX_DIR = .claude/backlog/inbox/ statt
# .claude/overseer/inbox/ — konfiguriert via INBOX_DIR-Env-Override in
# overseer.sh und picker.sh CLAUDE_PROJECT_DIR-Logic.
#
# CLI:
#   migrate-inbox.sh             — full migration (mit Sicherheits-Checks)
#   migrate-inbox.sh --dry-run   — zeigt was passieren würde, kein Edit

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
OVERSEER_DIR="${REPO_ROOT}/.claude/overseer"
OVERSEER_INBOX="${OVERSEER_DIR}/inbox"
OVERSEER_DONE="${OVERSEER_DIR}/done"
OVERSEER_FAILED="${OVERSEER_DIR}/failed"
OVERSEER_INPROGRESS="${OVERSEER_DIR}/in_progress"

BACKLOG_DIR="${REPO_ROOT}/.claude/backlog"
BACKLOG_INBOX="${BACKLOG_DIR}/inbox"
BACKLOG_DONE="${BACKLOG_DIR}/done"
BACKLOG_FAILED="${BACKLOG_DIR}/failed"
BACKLOG_INPROGRESS="${BACKLOG_DIR}/in_progress"

OVERSEER_SH="${SCRIPT_DIR}/overseer.sh"
PICKER_SH="${SCRIPT_DIR}/lib/picker.sh"
USER_SESSION_FILE="${REPO_ROOT}/.claude/.user-session-active"
MIGRATION_MARKER="${OVERSEER_DIR}/.inbox-migration-done"
AUDIT_LOG="${REPO_ROOT}/.claude/audit/migrate-inbox.log"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_log()  { printf '[migrate-inbox %s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
_err()  { printf '[migrate-inbox ERROR] %s\n' "$*" >&2; }
_warn() { printf '[migrate-inbox WARN] %s\n' "$*" >&2; }

_audit() {
  local action="$1" detail="${2:-}"
  mkdir -p "$(dirname "$AUDIT_LOG")"
  printf '%s migrate-inbox %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$action" "$detail" >> "$AUDIT_LOG" 2>/dev/null || true
}

_count_md() {
  local dir="$1"
  if [ ! -d "$dir" ]; then echo 0; return; fi
  find "$dir" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' '
}

# ---------------------------------------------------------------------------
# Idempotency check
# ---------------------------------------------------------------------------
if [ -f "$MIGRATION_MARKER" ]; then
  _log "Already migrated (marker: $MIGRATION_MARKER). Nothing to do."
  exit 0
fi

# ---------------------------------------------------------------------------
# Pre-Flight Checks
# ---------------------------------------------------------------------------
_log "Running pre-flight checks..."

# 1. User session guard (migration is user-gated)
if [ "$DRY_RUN" -eq 0 ]; then
  if [ ! -f "$USER_SESSION_FILE" ]; then
    _err "User-session not active. Create ${USER_SESSION_FILE} before running migration."
    _err "Hint: touch ${USER_SESSION_FILE}"
    exit 1
  fi
fi

# 2. Both inboxen must be empty
OVERSEER_INBOX_COUNT=0
BACKLOG_INBOX_COUNT=0

if [ -d "$OVERSEER_INBOX" ]; then
  OVERSEER_INBOX_COUNT="$(_count_md "$OVERSEER_INBOX")"
fi
if [ -d "$BACKLOG_INBOX" ]; then
  BACKLOG_INBOX_COUNT="$(_count_md "$BACKLOG_INBOX")"
fi

if [ "$OVERSEER_INBOX_COUNT" -gt 0 ] || [ "$BACKLOG_INBOX_COUNT" -gt 0 ]; then
  _err "Pre-flight FAILED: Inboxen nicht leer."
  _err "  overseer/inbox: ${OVERSEER_INBOX_COUNT} item(s)"
  _err "  backlog/inbox:  ${BACKLOG_INBOX_COUNT} item(s)"
  _err "Bitte alle Items abarbeiten oder manuell verschieben, dann erneut ausführen."
  exit 1
fi

# 3. LaunchAgents: warn + exit 1 if both headless AND overseer active
LAUNCHCTL_OUT="$(launchctl list 2>/dev/null || true)"
HEADLESS_ACTIVE=0
OVERSEER_ACTIVE=0
if echo "$LAUNCHCTL_OUT" | grep -qE "headless"; then HEADLESS_ACTIVE=1; fi
if echo "$LAUNCHCTL_OUT" | grep -qE "overseer"; then OVERSEER_ACTIVE=1; fi

if [ "$HEADLESS_ACTIVE" -eq 1 ] && [ "$OVERSEER_ACTIVE" -eq 1 ]; then
  _err "WARN: Beide LaunchAgents (headless + overseer) sind aktiv."
  _err "Bitte zuerst P4-1 ausführen (bash .claude/scripts/uninstall-headless.sh),"
  _err "dann erneut migrate-inbox.sh aufrufen."
  exit 1
fi

_log "Pre-flight checks passed."

# ---------------------------------------------------------------------------
# Dry-Run: show plan and exit
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 1 ]; then
  printf '\n=== DRY-RUN: Inbox-Migration Plan ===\n\n'
  printf 'Source (overseer):\n'
  printf '  inbox:      %s  (%d .md files)\n' "$OVERSEER_INBOX" "$OVERSEER_INBOX_COUNT"
  printf '  done:       %s\n' "$OVERSEER_DONE"
  printf '  failed:     %s\n' "$OVERSEER_FAILED"
  printf '  in_progress:%s\n' "$OVERSEER_INPROGRESS"
  printf '\nTarget (backlog):\n'
  printf '  inbox:      %s\n' "$BACKLOG_INBOX"
  printf '  done:       %s\n' "$BACKLOG_DONE"
  printf '  failed:     %s\n' "$BACKLOG_FAILED"
  printf '\nActions:\n'
  printf '  1. Backup  overseer/inbox → overseer/inbox.pre-migration.bak\n'
  printf '  2. Move    overseer/inbox/*.md → backlog/inbox/ (inbox is empty — nothing to move)\n'
  printf '  3. Move    overseer/done/ files → backlog/done/\n'
  printf '  4. Move    overseer/failed/ files → backlog/failed/\n'
  printf '  5. Move    overseer/in_progress/ files → backlog/in_progress/\n'
  printf '  6. Write   migration marker: %s\n' "$MIGRATION_MARKER"
  printf '\nNo edits performed (--dry-run).\n'
  exit 0
fi

# ---------------------------------------------------------------------------
# Migration
# ---------------------------------------------------------------------------
_log "Starting migration..."

# 1. Backup
BACKUP_DIR="${OVERSEER_INBOX}.pre-migration.bak"
if [ -d "$OVERSEER_INBOX" ]; then
  _log "Backup: $OVERSEER_INBOX → $BACKUP_DIR"
  cp -r "$OVERSEER_INBOX" "$BACKUP_DIR"
  _audit "backup_created" "$BACKUP_DIR"
else
  _log "overseer/inbox does not exist — creating empty backup marker"
  mkdir -p "$BACKUP_DIR"
  _audit "backup_created_empty" "$BACKUP_DIR"
fi

# 2. Move inbox items (should be empty per pre-flight, but be thorough)
mkdir -p "$BACKLOG_INBOX"
if [ -d "$OVERSEER_INBOX" ] && [ "$OVERSEER_INBOX_COUNT" -gt 0 ]; then
  _log "Moving $OVERSEER_INBOX_COUNT item(s) from overseer/inbox → backlog/inbox"
  find "$OVERSEER_INBOX" -maxdepth 1 -name '*.md' -exec mv {} "$BACKLOG_INBOX/" \;
  _audit "inbox_moved" "count=$OVERSEER_INBOX_COUNT"
else
  _log "overseer/inbox is empty — nothing to move (expected)"
  _audit "inbox_empty_skip" ""
fi

# 3. Move done/ files
if [ -d "$OVERSEER_DONE" ] && [ "$(find "$OVERSEER_DONE" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]; then
  mkdir -p "$BACKLOG_DONE"
  _log "Moving overseer/done → backlog/done"
  find "$OVERSEER_DONE" -maxdepth 1 -name '*.md' -exec mv {} "$BACKLOG_DONE/" \;
  _audit "done_moved" ""
else
  _log "overseer/done has no .md files — skip"
fi

# 4. Move failed/ files
if [ -d "$OVERSEER_FAILED" ] && [ "$(find "$OVERSEER_FAILED" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]; then
  mkdir -p "$BACKLOG_FAILED"
  _log "Moving overseer/failed → backlog/failed"
  find "$OVERSEER_FAILED" -maxdepth 1 -name '*.md' -exec mv {} "$BACKLOG_FAILED/" \;
  _audit "failed_moved" ""
else
  _log "overseer/failed has no .md files — skip"
fi

# 5. Move in_progress/ files (should be empty, but be safe)
OVERSEER_INPROGRESS_COUNT=0
if [ -d "$OVERSEER_INPROGRESS" ]; then
  OVERSEER_INPROGRESS_COUNT="$(find "$OVERSEER_INPROGRESS" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
fi
if [ "$OVERSEER_INPROGRESS_COUNT" -gt 0 ]; then
  mkdir -p "$BACKLOG_INPROGRESS"
  _log "Moving $OVERSEER_INPROGRESS_COUNT in_progress item(s) to backlog/in_progress"
  find "$OVERSEER_INPROGRESS" -maxdepth 1 -name '*.md' -exec mv {} "$BACKLOG_INPROGRESS/" \;
  _audit "inprogress_moved" "count=$OVERSEER_INPROGRESS_COUNT"
fi

# 6. Write migration marker
printf 'migrated at %s\nbacklog_inbox=%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  "$BACKLOG_INBOX" \
  > "$MIGRATION_MARKER"
_audit "migration_marker_written" "$MIGRATION_MARKER"

# 7. Notify
_log "Migration complete."
_log "Single-Inbox path: $BACKLOG_INBOX"
_log "Overseer should now be configured with INBOX_DIR override to: $BACKLOG_INBOX"
_log "  (set OVERSEER_INBOX_DIR env-var or pass REPO_ROOT env accordingly)"
_audit "migration_complete" "single_inbox=$BACKLOG_INBOX"

printf '\n=== MIGRATION COMPLETE ===\n'
printf 'Single-Inbox path: %s\n' "$BACKLOG_INBOX"
printf 'Marker written:    %s\n' "$MIGRATION_MARKER"
printf 'Audit log:         %s\n' "$AUDIT_LOG"
printf '\nNext step: P4-1 — uninstall-headless.sh, dann overseer neu starten.\n'
