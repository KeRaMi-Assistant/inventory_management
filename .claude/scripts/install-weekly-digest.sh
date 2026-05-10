#!/usr/bin/env bash
# install-weekly-digest.sh — Installs the macOS LaunchAgent for weekly-digest.sh (Sundays 09:00).
#
# Usage:
#   bash install-weekly-digest.sh             # write plist only, do NOT load
#   bash install-weekly-digest.sh --load-now  # write plist AND load immediately

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LABEL="com.inventory.weekly-digest"
TEMPLATE="$ROOT/.claude/weekly-digest-launchagent.plist.template"

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
# Sanity checks
# ---------------------------------------------------------------------------
if [ ! -f "$TEMPLATE" ]; then
  printf 'ERROR: missing plist template: %s\n' "$TEMPLATE" >&2
  exit 1
fi

DIGEST_SH="$ROOT/.claude/scripts/weekly-digest.sh"
if [ ! -f "$DIGEST_SH" ]; then
  printf 'WARNING: weekly-digest.sh not found at %s\n' "$DIGEST_SH" >&2
  printf '  The LaunchAgent will be installed anyway, but it will not run.\n' >&2
fi

# ---------------------------------------------------------------------------
# Create target dirs
# ---------------------------------------------------------------------------
mkdir -p "$LAUNCH_AGENTS_DIR"
mkdir -p "$ROOT/.claude/stakeholder/digest"

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
  launchctl unload -w "$TARGET" 2>/dev/null || true
  launchctl load -w "$TARGET"
  printf 'LaunchAgent loaded — weekly digest will fire every Sunday at 09:00.\n'
else
  printf '\n'
  printf 'NOTE: LaunchAgent installed but NOT loaded (RunAtLoad=false).\n'
  printf 'To start the weekly-digest agent:\n'
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
  audit_record "install-weekly-digest" "info" "LaunchAgent installed" \
    "load_now=$LOAD_NOW target=$TARGET" 2>/dev/null || true
fi

NOTIFY_SH="$ROOT/.claude/scripts/notify.sh"
if [ -x "$NOTIFY_SH" ]; then
  REPO_ROOT="$ROOT" "$NOTIFY_SH" info "claude-code" \
    "Weekly-Digest LaunchAgent installed" \
    "load_now=$LOAD_NOW | target=$TARGET" >/dev/null 2>&1 || true
fi

printf '\n'
printf 'controls:\n'
printf '  bash %s/.claude/scripts/uninstall-weekly-digest.sh   # stop + remove\n' "$ROOT"
printf '  launchctl list | grep %s       # status\n' "$LABEL"
printf '  bash %s/.claude/scripts/weekly-digest.sh --dry-run   # test without file\n' "$ROOT"
printf '  tail -f %s/.claude/stakeholder/digest/weekly-digest.err.log\n' "$ROOT"
