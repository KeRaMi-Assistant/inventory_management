#!/usr/bin/env bash
# uninstall-yota-watch.sh — Entlädt den yota-watch LaunchAgent und entfernt das Plist.

set -euo pipefail

LABEL="com.inventory.yota-watch"
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
TARGET="$LAUNCH_AGENTS_DIR/$LABEL.plist"

if [ -f "$TARGET" ]; then
  launchctl unload -w "$TARGET" 2>/dev/null || true
  rm -f "$TARGET"
  printf 'uninstalled: %s\n' "$TARGET"
else
  printf 'not installed: %s\n' "$TARGET"
fi
