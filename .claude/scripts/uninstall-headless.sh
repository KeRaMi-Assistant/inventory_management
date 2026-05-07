#!/usr/bin/env bash
# Stoppt + entfernt den headless LaunchAgent.

set -euo pipefail

LABEL="com.kerami.inventory.headless"
TARGET="$HOME/Library/LaunchAgents/$LABEL.plist"

if [ -f "$TARGET" ]; then
  launchctl unload "$TARGET" 2>/dev/null || true
  rm -f "$TARGET"
  echo "removed $TARGET"
else
  echo "no LaunchAgent installed at $TARGET"
fi

# Belt & suspenders: kill any lingering claude-print started by the runner
pkill -f "claude.*--print" 2>/dev/null || true

echo "done"
