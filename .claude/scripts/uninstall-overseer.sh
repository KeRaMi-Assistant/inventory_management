#!/usr/bin/env bash
# uninstall-overseer.sh — Stops + removes the Overseer LaunchAgent.
#
# Idempotent: safe to run even if the agent is not currently loaded.
#
# IMPORTANT: This file is in the Self-Mod-Blocklist (P0-0).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LABEL="com.inventory.overseer"

# Allow env-override of target dir for testing/sandboxing.
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
TARGET="$LAUNCH_AGENTS_DIR/$LABEL.plist"

# ---------------------------------------------------------------------------
# Unload (idempotent — if not loaded, launchctl exits non-zero which we swallow)
# ---------------------------------------------------------------------------
if [ -f "$TARGET" ]; then
  launchctl unload -w "$TARGET" 2>/dev/null || true
  rm -f "$TARGET"
  printf 'removed %s\n' "$TARGET"
else
  printf 'no LaunchAgent plist found at %s (already uninstalled?)\n' "$TARGET"
fi

# ---------------------------------------------------------------------------
# Best-effort: kill any lingering overseer.sh processes
# ---------------------------------------------------------------------------
pkill -f "overseer.sh" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Audit + notification
# ---------------------------------------------------------------------------
AUDIT_SH="$ROOT/.claude/scripts/lib/audit.sh"
if [ -f "$AUDIT_SH" ]; then
  # shellcheck disable=SC1090
  source "$AUDIT_SH" 2>/dev/null || true
fi
if command -v audit_record >/dev/null 2>&1; then
  audit_record "uninstall-overseer" "info" "LaunchAgent uninstalled" "target=$TARGET" 2>/dev/null || true
fi

NOTIFY_SH="$ROOT/.claude/scripts/notify.sh"
if [ -x "$NOTIFY_SH" ]; then
  REPO_ROOT="$ROOT" "$NOTIFY_SH" info "claude-code" \
    "Overseer LaunchAgent uninstalled" \
    "target=$TARGET" >/dev/null 2>&1 || true
fi

printf 'done\n'
