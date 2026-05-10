#!/usr/bin/env bash
# install-audit-backup.sh — Installiert den audit-backup LaunchAgent (macOS)
#
# Voraussetzungen:
#   AUDIT_BACKUP_REMOTE muss gesetzt sein (oder via .env.headless).
#
# Usage:
#   AUDIT_BACKUP_REMOTE=git@github.com:... bash .claude/scripts/install-audit-backup.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load .env.headless for defaults
ENV_FILE="$REPO_ROOT/.env.headless"
if [ -f "$ENV_FILE" ]; then
  set -a; . "$ENV_FILE"; set +a
fi

AUDIT_BACKUP_REMOTE="${AUDIT_BACKUP_REMOTE:-}"
AUDIT_BACKUP_LOCAL="${AUDIT_BACKUP_LOCAL:-${HOME}/.claude/audit-backup-mirror}"
AUDIT_BACKUP_BRANCH="${AUDIT_BACKUP_BRANCH:-main}"

if [ -z "$AUDIT_BACKUP_REMOTE" ]; then
  echo "ERROR: AUDIT_BACKUP_REMOTE is not set."
  echo "  Set it via env: AUDIT_BACKUP_REMOTE=git@github.com:... bash $0"
  echo "  Or add it to .env.headless"
  exit 1
fi

PLIST_TEMPLATE="$REPO_ROOT/.claude/audit-backup-launchagent.plist.template"
PLIST_LABEL="com.inventory.audit-backup"
PLIST_DEST="${HOME}/Library/LaunchAgents/${PLIST_LABEL}.plist"

# Substitute placeholders
sed \
  -e "s|__REPO_ROOT__|${REPO_ROOT}|g" \
  -e "s|__HOME__|${HOME}|g" \
  -e "s|__AUDIT_BACKUP_REMOTE__|${AUDIT_BACKUP_REMOTE}|g" \
  "$PLIST_TEMPLATE" > "$PLIST_DEST"

# Unload first if already loaded (ignore errors)
launchctl unload "$PLIST_DEST" 2>/dev/null || true

# Load
if launchctl load "$PLIST_DEST"; then
  echo "audit-backup LaunchAgent installed and loaded."
  echo "  Schedule: every Sunday at 04:00"
  echo "  Remote:   $AUDIT_BACKUP_REMOTE"
  echo "  Plist:    $PLIST_DEST"
else
  echo "ERROR: launchctl load failed — check $PLIST_DEST for errors"
  exit 1
fi
