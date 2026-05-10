#!/usr/bin/env bash
# cloud-heartbeat-ping.sh — Sends a heartbeat ping from the Overseer to ntfy.sh.
#
# Called by overseer.sh every 60 minutes (HEARTBEAT_INTERVAL=3600).
# If no token is configured → silent skip (exit 0).
# If ntfy push fails     → silent skip (network-down is not fatal).
#
# Required env / secret file:
#   OVERSEER_HEARTBEAT_TOKEN  — shared secret (min 32 chars)
#   or ~/.claude/inventory-overseer-heartbeat-token
#
# Env:
#   NTFY_HEARTBEAT_TOPIC  — topic for heartbeat pings (default: ${NTFY_TOPIC:-claude-code}-heartbeat)
#   NTFY_TOPIC            — base topic (fallback)
#   REPO_ROOT             — repo root (auto-detected from script location)
#
# IMPORTANT: This file is NOT in the Self-Mod-Blocklist — the overseer calls it
# as a subprocess, so self-modification is not a concern here.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# ---------------------------------------------------------------------------
# Resolve token
# ---------------------------------------------------------------------------
TOKEN="${OVERSEER_HEARTBEAT_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  TOKEN_FILE="${HOME}/.claude/inventory-overseer-heartbeat-token"
  if [ -f "$TOKEN_FILE" ]; then
    TOKEN="$(cat "$TOKEN_FILE" 2>/dev/null || true)"
  fi
fi

if [ -z "$TOKEN" ]; then
  printf '[heartbeat-ping] no token configured — skipping\n' >&2
  exit 0
fi

# Minimum token length sanity check (32 chars)
if [ "${#TOKEN}" -lt 32 ]; then
  printf '[heartbeat-ping] WARN: token too short (%d chars < 32) — skipping\n' "${#TOKEN}" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Build heartbeat payload
# ---------------------------------------------------------------------------
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HOST="$(hostname 2>/dev/null || echo unknown)"

PAYLOAD="{\"ts\":\"${TS}\",\"host\":\"${HOST}\",\"token\":\"${TOKEN}\"}"

# ---------------------------------------------------------------------------
# Write local state (used by verify tests + future local watchdog)
# ---------------------------------------------------------------------------
OVERSEER_DIR="${REPO_ROOT}/.claude/overseer"
mkdir -p "$OVERSEER_DIR"
printf '%s\n' "$PAYLOAD" > "${OVERSEER_DIR}/last-heartbeat.json"

# ---------------------------------------------------------------------------
# Push to ntfy.sh (best-effort — network failures must not break overseer)
# ---------------------------------------------------------------------------
HEARTBEAT_TOPIC="${NTFY_HEARTBEAT_TOPIC:-${NTFY_TOPIC:-claude-code}-heartbeat}"

curl -fsSL --max-time 10 \
  -H "Title: heartbeat" \
  -H "Tags: heartbeat,ok" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "https://ntfy.sh/${HEARTBEAT_TOPIC}" >/dev/null 2>&1 || {
    printf '[heartbeat-ping] WARN: ntfy push failed (network?) — continuing\n' >&2
  }

printf '[heartbeat-ping] ok ts=%s host=%s topic=%s\n' "$TS" "$HOST" "$HEARTBEAT_TOPIC" >&2
exit 0
