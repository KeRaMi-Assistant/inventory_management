#!/usr/bin/env bash
# install-overseer.sh — Installs the macOS LaunchAgent for overseer.sh (KeepAlive daemon).
#
# Usage:
#   bash install-overseer.sh           # write plist only, do NOT load
#   bash install-overseer.sh --load-now  # write plist AND load immediately
#
# The LaunchAgent is installed with RunAtLoad=false to prevent Boot-Storm
# (Empfehlung i from the committee plan). To start the overseer after install:
#   launchctl load -w ~/Library/LaunchAgents/com.inventory.overseer.plist
# Or re-run this script with --load-now.
#
# IMPORTANT: This file is in the Self-Mod-Blocklist (P0-0).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LABEL="com.inventory.overseer"
TEMPLATE="$ROOT/.claude/overseer-launchagent.plist.template"

# Allow env-override of target dir for testing/sandboxing.
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
TARGET="$LAUNCH_AGENTS_DIR/$LABEL.plist"

LOAD_NOW=0
for arg in "$@"; do
  case "$arg" in
    --load-now) LOAD_NOW=1 ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      printf 'Usage: %s [--load-now]\n' "$(basename "$0")" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Sanity: template must exist
# ---------------------------------------------------------------------------
if [ ! -f "$TEMPLATE" ]; then
  printf 'ERROR: missing plist template: %s\n' "$TEMPLATE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Sanity: overseer.sh must exist
# ---------------------------------------------------------------------------
OVERSEER_SH="$ROOT/.claude/scripts/overseer.sh"
if [ ! -f "$OVERSEER_SH" ]; then
  printf 'WARNING: overseer.sh not found at %s\n' "$OVERSEER_SH" >&2
  printf '  The LaunchAgent will be installed anyway, but the daemon will not run.\n' >&2
fi

# ---------------------------------------------------------------------------
# Create target dir
# ---------------------------------------------------------------------------
mkdir -p "$LAUNCH_AGENTS_DIR"

# ---------------------------------------------------------------------------
# Conflict-check: warn if headless LaunchAgent is already loaded
# (they use separate inbox paths so can coexist — Mitigation 8)
# ---------------------------------------------------------------------------
HEADLESS_LABEL="com.kerami.inventory.headless"
if launchctl list 2>/dev/null | grep -q "$HEADLESS_LABEL"; then
  printf 'INFO: headless LaunchAgent (%s) is currently loaded.\n' "$HEADLESS_LABEL" >&2
  printf '  Both agents can run in parallel — they use separate inbox paths\n' >&2
  printf '  (.claude/backlog/ for headless vs .claude/overseer/ for overseer).\n' >&2
  printf '  This is intentional (Plan Mitigation 8). No action required.\n' >&2
fi

# ---------------------------------------------------------------------------
# Create overseer log dir (logs live here per plist StandardOut/ErrPath)
# ---------------------------------------------------------------------------
mkdir -p "$ROOT/.claude/overseer"

# ---------------------------------------------------------------------------
# Write plist from template
# ---------------------------------------------------------------------------
sed \
  -e "s|__REPO_ROOT__|$ROOT|g" \
  -e "s|__HOME__|$HOME|g" \
  "$TEMPLATE" > "$TARGET"

printf 'installed plist → %s\n' "$TARGET"

# ---------------------------------------------------------------------------
# Optionally load now
# ---------------------------------------------------------------------------
if [ "$LOAD_NOW" -eq 1 ]; then
  # Unload any prior version first (idempotent).
  launchctl unload -w "$TARGET" 2>/dev/null || true
  launchctl load -w "$TARGET"
  printf 'LaunchAgent loaded — overseer daemon is now running (KeepAlive=true).\n'
else
  printf '\n'
  printf 'NOTE: LaunchAgent installed but NOT loaded (RunAtLoad=false).\n'
  printf 'To start the overseer now:\n'
  printf '  launchctl load -w %s\n' "$TARGET"
  printf 'Or re-run: bash %s --load-now\n' "$(basename "$0")"
fi

# ---------------------------------------------------------------------------
# Audit + notification
# ---------------------------------------------------------------------------
AUDIT_SH="$ROOT/.claude/scripts/lib/audit.sh"
if [ -f "$AUDIT_SH" ]; then
  # shellcheck disable=SC1090
  source "$AUDIT_SH" 2>/dev/null || true
fi
if command -v audit_record >/dev/null 2>&1; then
  audit_record "install-overseer" "info" "LaunchAgent installed" "load_now=$LOAD_NOW target=$TARGET" 2>/dev/null || true
fi

NOTIFY_SH="$ROOT/.claude/scripts/notify.sh"
if [ -x "$NOTIFY_SH" ]; then
  REPO_ROOT="$ROOT" "$NOTIFY_SH" info "claude-code" \
    "Overseer LaunchAgent installed" \
    "load_now=$LOAD_NOW | target=$TARGET" >/dev/null 2>&1 || true
fi

printf '\n'
printf 'controls:\n'
printf '  bash %s/.claude/scripts/uninstall-overseer.sh    # stop + remove\n' "$ROOT"
printf '  launchctl list | grep %s            # status\n' "$LABEL"
printf '  bash %s/.claude/scripts/overseer.sh --status     # overseer status\n' "$ROOT"
printf '  tail -f %s/.claude/overseer/overseer.err.log\n' "$ROOT"
