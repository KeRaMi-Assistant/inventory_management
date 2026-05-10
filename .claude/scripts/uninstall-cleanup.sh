#!/usr/bin/env bash
# uninstall-cleanup.sh — Removes the macOS LaunchAgent for cleanup.sh.
#
# Usage:
#   bash uninstall-cleanup.sh
#
# IMPORTANT: This file is in the Self-Mod-Blocklist (P0-0).

set -euo pipefail

LABEL="com.inventory.cleanup"
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
TARGET="$LAUNCH_AGENTS_DIR/$LABEL.plist"

if launchctl list "$LABEL" &>/dev/null 2>&1; then
  launchctl unload "$TARGET" 2>/dev/null || true
  printf 'Unloaded: %s\n' "$LABEL"
fi

if [ -f "$TARGET" ]; then
  rm -f "$TARGET"
  printf 'Removed: %s\n' "$TARGET"
else
  printf 'Not installed: %s\n' "$TARGET"
fi

printf 'cleanup LaunchAgent uninstalled.\n'
