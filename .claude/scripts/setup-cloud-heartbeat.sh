#!/usr/bin/env bash
# setup-cloud-heartbeat.sh — One-time setup for Cloud-Heartbeat (P3-12).
#
# Generates a shared-secret token, writes it to:
#   ~/.claude/inventory-overseer-heartbeat-token  (mode 0400)
#
# Then prints the manual steps needed to complete the setup:
#   1. Add to .env.headless
#   2. gh secret set OVERSEER_HEARTBEAT_TOKEN
#   3. gh secret set NTFY_HEARTBEAT_TOPIC
#   4. gh secret set NTFY_TOPIC (if not already set)
#
# Safe to re-run: if a token file already exists it asks before overwriting.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

TOKEN_FILE="${HOME}/.claude/inventory-overseer-heartbeat-token"
TOKEN_DIR="$(dirname "$TOKEN_FILE")"

# ---------------------------------------------------------------------------
# Check existing token
# ---------------------------------------------------------------------------
if [ -f "$TOKEN_FILE" ]; then
  printf 'A token file already exists at %s\n' "$TOKEN_FILE"
  printf 'Overwrite? [y/N] '
  read -r CONFIRM </dev/tty || CONFIRM="N"
  case "$CONFIRM" in
    y|Y) ;;
    *) printf 'Aborted.\n'; exit 0 ;;
  esac
fi

# ---------------------------------------------------------------------------
# Generate token (48 hex chars = 192 bits)
# ---------------------------------------------------------------------------
mkdir -p "$TOKEN_DIR"

TOKEN=""
if command -v openssl >/dev/null 2>&1; then
  TOKEN="$(openssl rand -hex 48)"
elif [ -r /dev/urandom ]; then
  TOKEN="$(head -c 48 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 96)"
else
  printf 'ERROR: cannot generate secure random token (no openssl, no /dev/urandom)\n' >&2
  exit 1
fi

printf '%s' "$TOKEN" > "$TOKEN_FILE"
chmod 0400 "$TOKEN_FILE"

# ---------------------------------------------------------------------------
# Read optional topics from env
# ---------------------------------------------------------------------------
NTFY_TOPIC="${NTFY_TOPIC:-claude-code}"
NTFY_HEARTBEAT_TOPIC="${NTFY_HEARTBEAT_TOPIC:-${NTFY_TOPIC}-heartbeat}"

# ---------------------------------------------------------------------------
# Print setup instructions
# ---------------------------------------------------------------------------
printf '\n'
printf '=== Cloud Heartbeat Setup ===\n'
printf '\n'
printf 'Token written to: %s (mode 0400)\n' "$TOKEN_FILE"
printf 'Token: %s\n' "$TOKEN"
printf '\n'
printf 'Manual steps to complete setup:\n'
printf '\n'
printf '1. Add to .env.headless:\n'
printf '   OVERSEER_HEARTBEAT_TOKEN=%s\n' "$TOKEN"
printf '   NTFY_HEARTBEAT_TOPIC=%s\n' "$NTFY_HEARTBEAT_TOPIC"
printf '\n'
printf '2. Set GitHub Secrets (run from repo root):\n'
printf '   gh secret set OVERSEER_HEARTBEAT_TOKEN --body "%s"\n' "$TOKEN"
printf '   gh secret set NTFY_HEARTBEAT_TOPIC     --body "%s"\n' "$NTFY_HEARTBEAT_TOPIC"
printf '   gh secret set NTFY_TOPIC               --body "%s"  # skip if already set\n' "$NTFY_TOPIC"
printf '\n'
printf '3. Subscribe to ntfy topics on your phone:\n'
printf '   https://ntfy.sh/%s  (heartbeat pings)\n' "$NTFY_HEARTBEAT_TOPIC"
printf '   https://ntfy.sh/%s  (overseer alerts — already set up)\n' "$NTFY_TOPIC"
printf '\n'
printf '4. Verify once the overseer is running:\n'
printf '   bash %s/scripts/cloud-heartbeat-ping.sh\n' "$(realpath "$REPO_ROOT/.claude")"
printf '   cat %s/overseer/last-heartbeat.json\n' "$(realpath "$REPO_ROOT/.claude")"
printf '\n'
printf 'The GitHub-Actions workflow will alert you if no heartbeat arrives in 4h:\n'
printf '  .github/workflows/cloud-heartbeat-watch.yml\n'
printf '\n'
exit 0
