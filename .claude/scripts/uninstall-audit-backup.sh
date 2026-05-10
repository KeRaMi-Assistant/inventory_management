#!/usr/bin/env bash
# uninstall-audit-backup.sh — Entfernt den audit-backup LaunchAgent

set -uo pipefail

PLIST_LABEL="com.inventory.audit-backup"
PLIST_DEST="${HOME}/Library/LaunchAgents/${PLIST_LABEL}.plist"

if [ ! -f "$PLIST_DEST" ]; then
  echo "LaunchAgent not installed (plist not found): $PLIST_DEST"
  exit 0
fi

launchctl unload "$PLIST_DEST" 2>/dev/null || true
rm -f "$PLIST_DEST"
echo "audit-backup LaunchAgent unloaded and removed."
