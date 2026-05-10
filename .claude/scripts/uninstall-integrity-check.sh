#!/usr/bin/env bash
set -euo pipefail
LABEL="com.inventory.integrity"
TARGET="$HOME/Library/LaunchAgents/$LABEL.plist"
if [ -f "$TARGET" ]; then
  launchctl unload "$TARGET" 2>/dev/null || true
  rm -f "$TARGET"
  echo "removed $TARGET"
else
  echo "no LaunchAgent at $TARGET"
fi
