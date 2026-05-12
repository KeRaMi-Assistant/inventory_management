#!/usr/bin/env bash
# reset-intake-onboarding.sh — Delete T23b state-marker(s) for re-onboarding
#
# Usage:
#   reset-intake-onboarding.sh <user_id>   — reset for one user
#   reset-intake-onboarding.sh --all       — reset all users
#
# The state dir can be overridden by INTAKE_ONBOARDING_STATE_DIR (same env var
# as in telegram-bot.py, used by tests).

set -uo pipefail

STATE_DIR="${INTAKE_ONBOARDING_STATE_DIR:-$HOME/.claude/state}"

if [ $# -eq 0 ]; then
  printf 'Usage: reset-intake-onboarding.sh <user_id> | --all\n' >&2
  exit 1
fi

if [ "$1" = "--all" ]; then
  markers=("$STATE_DIR"/yota-intake-introduced-*)
  if [ ${#markers[@]} -eq 0 ] || [ ! -e "${markers[0]}" ]; then
    printf 'reset-intake-onboarding: no markers found in %s\n' "$STATE_DIR"
    exit 0
  fi
  count=0
  for m in "${markers[@]}"; do
    rm -f "$m"
    printf 'removed: %s\n' "$m"
    count=$((count + 1))
  done
  printf 'reset-intake-onboarding: removed %d marker(s)\n' "$count"
else
  USER_ID="$1"
  if ! printf '%s' "$USER_ID" | grep -qE '^[0-9]+$'; then
    printf 'reset-intake-onboarding: user_id must be numeric, got: %s\n' "$USER_ID" >&2
    exit 1
  fi
  MARKER="$STATE_DIR/yota-intake-introduced-$USER_ID"
  if [ -f "$MARKER" ]; then
    rm -f "$MARKER"
    printf 'reset-intake-onboarding: removed %s\n' "$MARKER"
  else
    printf 'reset-intake-onboarding: marker not found (already reset?): %s\n' "$MARKER"
  fi
fi
