#!/usr/bin/env bash
# Installiert den macOS LaunchAgent, der headless-runner.sh periodisch ruft.
# Default-Intervall: 30 Min. Override via: HEADLESS_INTERVAL=600 bash install-headless.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LABEL="com.kerami.inventory.headless"
INTERVAL="${HEADLESS_INTERVAL:-1800}"
TEMPLATE="$ROOT/.claude/launchagent.plist.template"
TARGET="$HOME/Library/LaunchAgents/$LABEL.plist"

if [ ! -f "$TEMPLATE" ]; then
  echo "missing template: $TEMPLATE" >&2
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"

# substitute placeholders (sed-friendly: paths must not contain '|')
sed \
  -e "s|__LABEL__|$LABEL|g" \
  -e "s|__REPO_ROOT__|$ROOT|g" \
  -e "s|__HOME__|$HOME|g" \
  -e "s|__INTERVAL_SECONDS__|$INTERVAL|g" \
  "$TEMPLATE" > "$TARGET"

# unload any prior version, then load
launchctl unload "$TARGET" 2>/dev/null || true
launchctl load "$TARGET"

echo "installed LaunchAgent → $TARGET"
echo "label=$LABEL"
echo "interval=${INTERVAL}s ($((INTERVAL/60)) min)"
echo
echo "controls:"
echo "  bash $ROOT/.claude/scripts/uninstall-headless.sh    # stop + remove"
echo "  launchctl list | grep $LABEL                        # status"
echo "  bash $ROOT/.claude/scripts/headless-runner.sh       # one-shot manual run"
echo "  tail -f $ROOT/.claude/backlog/runs/launchagent.out.log"
