#!/usr/bin/env bash
# Installiert den Integrity-Check-LaunchAgent (stündlich).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LABEL="com.inventory.integrity"
TEMPLATE="$ROOT/.claude/integrity-launchagent.plist.template"
TARGET="$HOME/Library/LaunchAgents/$LABEL.plist"

if [ ! -f "$TEMPLATE" ]; then
  echo "missing template: $TEMPLATE" >&2
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$ROOT/.claude/integrity"

sed \
  -e "s|__REPO_ROOT__|$ROOT|g" \
  -e "s|__HOME__|$HOME|g" \
  "$TEMPLATE" > "$TARGET"

launchctl unload "$TARGET" 2>/dev/null || true
launchctl load "$TARGET"

# Initial-Build des Manifests (best-effort)
if [ ! -f "$ROOT/.claude/integrity/manifest.sha256" ]; then
  bash "$ROOT/.claude/scripts/integrity-manifest-build.sh" || true
fi

echo "installed LaunchAgent → $TARGET"
echo "label=$LABEL  interval=3600s"
echo
echo "controls:"
echo "  bash $ROOT/.claude/scripts/uninstall-integrity-check.sh"
echo "  launchctl list | grep $LABEL"
echo "  bash $ROOT/.claude/scripts/integrity-check.sh   # one-shot manual"
