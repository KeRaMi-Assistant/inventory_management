#!/usr/bin/env bash
# audit-backup.sh — Wöchentlicher Off-Site-Backup-Push der Audit-Files (P3-13)
#
# Usage:
#   audit-backup.sh              — full backup (clone/pull, copy, push)
#   audit-backup.sh --dry-run    — zeigt was kopiert würde, kein push
#   audit-backup.sh --status     — zeigt last-run aus state
#
# Konfiguration via Env-Vars:
#   AUDIT_BACKUP_REMOTE   — Git-URL des separaten Backup-Repos (Pflicht)
#   AUDIT_BACKUP_LOCAL    — lokaler Working-Dir-Pfad (default ~/.claude/audit-backup-mirror)
#   AUDIT_BACKUP_BRANCH   — default main

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
NOTIFY="${SCRIPT_DIR}/notify.sh"

# Source audit library
source "${SCRIPT_DIR}/lib/audit.sh"

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
AUDIT_BACKUP_REMOTE="${AUDIT_BACKUP_REMOTE:-}"
AUDIT_BACKUP_LOCAL="${AUDIT_BACKUP_LOCAL:-${HOME}/.claude/audit-backup-mirror}"
AUDIT_BACKUP_BRANCH="${AUDIT_BACKUP_BRANCH:-main}"
STATE_FILE="${REPO_ROOT}/.claude/state/audit-backup-last-run.txt"

REPO_NAME="$(basename "$REPO_ROOT")"
AUDIT_SRC_DIR="${REPO_ROOT}/.claude/audit"
ISO_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_log() { printf '[audit-backup] %s\n' "$*"; }
_err() { printf '[audit-backup] ERROR: %s\n' "$*" >&2; }

_notify_critical() {
  local topic="$1" title="$2" body="$3"
  if [ -x "$NOTIFY" ]; then
    "$NOTIFY" critical "$topic" "$title" "$body" 2>/dev/null || true
  fi
  _err "$title — $body"
}

_write_state() {
  mkdir -p "$(dirname "$STATE_FILE")"
  printf 'last_run=%s\nstatus=%s\nfiles=%s\nremote=%s\n' \
    "$ISO_TS" "${1:-unknown}" "${2:-0}" "${AUDIT_BACKUP_REMOTE:-none}" \
    > "$STATE_FILE"
}

# ---------------------------------------------------------------------------
# --status
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--status" ]]; then
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
    _log "no state recorded yet"
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Guard: AUDIT_BACKUP_REMOTE must be set
# ---------------------------------------------------------------------------
if [ -z "$AUDIT_BACKUP_REMOTE" ]; then
  _log "WARNING: AUDIT_BACKUP_REMOTE not set — no backup target configured, skipping."
  exit 0
fi

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  _log "DRY-RUN mode — no push will be performed"
fi

# ---------------------------------------------------------------------------
# Collect audit files
# ---------------------------------------------------------------------------
if [ ! -d "$AUDIT_SRC_DIR" ]; then
  _log "No audit directory found at $AUDIT_SRC_DIR — nothing to backup."
  exit 0
fi

AUDIT_FILES_LIST="$(find "$AUDIT_SRC_DIR" -name "*.md" | sort)"
FILES_COUNT=0
if [ -n "$AUDIT_FILES_LIST" ]; then
  FILES_COUNT="$(echo "$AUDIT_FILES_LIST" | wc -l | tr -d ' ')"
fi

if [ "$FILES_COUNT" -eq 0 ]; then
  _log "No audit .md files found — nothing to backup."
  exit 0
fi

# ---------------------------------------------------------------------------
# Dry-run: just show what would be copied
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 1 ]; then
  _log "Would push $FILES_COUNT file(s) to $AUDIT_BACKUP_REMOTE"
  while IFS= read -r f; do
    rel="${f#"$AUDIT_SRC_DIR/"}"
    _log "  audit/${REPO_NAME}/${rel}"
  done <<< "$AUDIT_FILES_LIST"
  exit 0
fi

# ---------------------------------------------------------------------------
# 1. Clone or pull backup repo
# ---------------------------------------------------------------------------
if [ ! -d "$AUDIT_BACKUP_LOCAL/.git" ]; then
  _log "Cloning $AUDIT_BACKUP_REMOTE → $AUDIT_BACKUP_LOCAL"
  mkdir -p "$(dirname "$AUDIT_BACKUP_LOCAL")"
  if ! git clone "$AUDIT_BACKUP_REMOTE" "$AUDIT_BACKUP_LOCAL" 2>&1; then
    _notify_critical "audit-backup-failed" \
      "audit-backup: clone failed" \
      "Could not clone $AUDIT_BACKUP_REMOTE — check AUDIT_BACKUP_REMOTE and credentials."
    _write_state "clone-failed" 0
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# 2. Pull latest
# ---------------------------------------------------------------------------
_log "Pulling latest from origin/${AUDIT_BACKUP_BRANCH}"
if ! git -C "$AUDIT_BACKUP_LOCAL" fetch origin "$AUDIT_BACKUP_BRANCH" 2>&1; then
  _log "WARNING: fetch failed — continuing with local state"
else
  git -C "$AUDIT_BACKUP_LOCAL" merge --ff-only "origin/${AUDIT_BACKUP_BRANCH}" 2>/dev/null || \
    _log "WARNING: merge failed — continuing with local state"
fi

# ---------------------------------------------------------------------------
# 3. Copy audit files into backup repo
# ---------------------------------------------------------------------------
DEST_DIR="${AUDIT_BACKUP_LOCAL}/audit/${REPO_NAME}"
mkdir -p "$DEST_DIR"

# Preserve archive/ subdir structure
while IFS= read -r f; do
  rel="${f#"$AUDIT_SRC_DIR/"}"
  dest="${DEST_DIR}/${rel}"
  mkdir -p "$(dirname "$dest")"
  cp -f "$f" "$dest"
done <<< "$AUDIT_FILES_LIST"

_log "Copied $FILES_COUNT file(s) to $DEST_DIR"

# ---------------------------------------------------------------------------
# 4. git add + commit (skip if nothing changed)
# ---------------------------------------------------------------------------
git -C "$AUDIT_BACKUP_LOCAL" add .

if git -C "$AUDIT_BACKUP_LOCAL" diff --cached --quiet; then
  _log "Nothing changed — skipping commit."
  _write_state "ok-no-change" "$FILES_COUNT"
  audit_record "audit-backup" "audit-backup" "no-change" \
    "remote=${AUDIT_BACKUP_REMOTE} files=${FILES_COUNT} ts=${ISO_TS}"
  exit 0
fi

_log "Committing: audit-backup: ${ISO_TS}"
git -C "$AUDIT_BACKUP_LOCAL" \
  -c user.name="${GIT_AUTHOR_NAME:-KeRaMi-Assistant}" \
  -c user.email="${GIT_AUTHOR_EMAIL:-noreply@local}" \
  commit -m "audit-backup: ${ISO_TS}"

# ---------------------------------------------------------------------------
# 5. Push (retry once on failure)
# ---------------------------------------------------------------------------
_log "Pushing to origin/${AUDIT_BACKUP_BRANCH}"
if ! git -C "$AUDIT_BACKUP_LOCAL" push origin "HEAD:refs/heads/${AUDIT_BACKUP_BRANCH}" 2>&1; then
  _log "Push failed — retrying with pull --rebase"
  if ! git -C "$AUDIT_BACKUP_LOCAL" pull --rebase origin "$AUDIT_BACKUP_BRANCH" 2>&1; then
    _notify_critical "audit-backup-failed" \
      "audit-backup: push failed (rebase error)" \
      "Cannot rebase onto $AUDIT_BACKUP_REMOTE — manual intervention required."
    _write_state "push-failed" "$FILES_COUNT"
    exit 1
  fi
  if ! git -C "$AUDIT_BACKUP_LOCAL" push origin "HEAD:refs/heads/${AUDIT_BACKUP_BRANCH}" 2>&1; then
    _notify_critical "audit-backup-failed" \
      "audit-backup: push failed after retry" \
      "Push to $AUDIT_BACKUP_REMOTE failed twice — check network/auth."
    _write_state "push-failed" "$FILES_COUNT"
    exit 1
  fi
fi

_log "Push successful."

# ---------------------------------------------------------------------------
# 6. Audit record in main repo
# ---------------------------------------------------------------------------
audit_record "audit-backup" "audit-backup" "pushed" \
  "remote=${AUDIT_BACKUP_REMOTE} files=${FILES_COUNT} ts=${ISO_TS}"

_write_state "ok" "$FILES_COUNT"
_log "Done: $FILES_COUNT audit file(s) backed up to $AUDIT_BACKUP_REMOTE"
