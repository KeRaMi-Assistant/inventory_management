#!/usr/bin/env bash
# btw.sh — Stakeholder-Inbox-CLI (Tier-1)
#
# Usage:
#   btw.sh "<text>"          — write text as stakeholder inbox item
#   btw.sh -                 — read text from stdin
#
# Writes: .claude/stakeholder/inbox/<YYYYMMDD-HHMMSS>-<slug>.md
# Sentinel-Reject: exit 2 if text contains Sandwich-Markers (injection attempt)
# Max text length: 4096 chars (truncates + warns)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

INBOX_DIR="$REPO_ROOT/.claude/stakeholder/inbox"
# Prefer REPO_ROOT-based paths so sandbox/test overrides work
AUDIT_LIB="$REPO_ROOT/.claude/scripts/lib/audit.sh"
NOTIFY_SH="$REPO_ROOT/.claude/scripts/notify.sh"
# Fall back to co-located scripts if REPO_ROOT override not present
[ -f "$AUDIT_LIB" ] || AUDIT_LIB="$SCRIPT_DIR/lib/audit.sh"
[ -x "$NOTIFY_SH" ] || NOTIFY_SH="$SCRIPT_DIR/notify.sh"

MAX_CHARS=4096

# BTW_SOURCE_TIER: tier-1 (default) or tier-2 (Telegram adapter)
BTW_SOURCE_TIER="${BTW_SOURCE_TIER:-tier-1}"
# Extract numeric trust level from tier string (tier-1 → 1, tier-2 → 2)
TRUST_TIER="${BTW_SOURCE_TIER#tier-}"
# Ensure it's a positive integer; fallback to 1
if ! printf '%s' "$TRUST_TIER" | grep -qE '^[0-9]+$'; then
  TRUST_TIER=1
fi

# ---------------------------------------------------------------------------
# Argument handling
# ---------------------------------------------------------------------------
if [ $# -eq 0 ]; then
  printf 'Usage: btw.sh "<text>"\n' >&2
  exit 1
fi

if [ "$1" = "-" ]; then
  # stdin mode
  RAW_TEXT="$(cat)"
else
  RAW_TEXT="$1"
fi

if [ -z "${RAW_TEXT:-}" ]; then
  printf 'Usage: btw.sh "<text>"\n' >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Truncate if > MAX_CHARS
# ---------------------------------------------------------------------------
CHAR_COUNT="${#RAW_TEXT}"
if [ "$CHAR_COUNT" -gt "$MAX_CHARS" ]; then
  printf 'btw.sh: WARNING: text truncated from %d to %d chars\n' "$CHAR_COUNT" "$MAX_CHARS" >&2
  RAW_TEXT="${RAW_TEXT:0:$MAX_CHARS}"
  CHAR_COUNT=$MAX_CHARS
fi

# ---------------------------------------------------------------------------
# Sentinel-Reject: detect injection attempt
# ---------------------------------------------------------------------------
SENTINEL_OPEN='<<<UNTRUSTED_STAKEHOLDER_INPUT'
SENTINEL_CLOSE='<<<END_UNTRUSTED_STAKEHOLDER_INPUT'

if printf '%s' "$RAW_TEXT" | grep -qF "$SENTINEL_OPEN" || \
   printf '%s' "$RAW_TEXT" | grep -qF "$SENTINEL_CLOSE"; then
  printf 'btw.sh: ERROR: potential injection — text contains Sandwich-Marker sentinel\n' >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Slug generation: first 40 chars, lowercase, kebab-case, collapse hyphens
# ---------------------------------------------------------------------------
_make_slug() {
  local text="$1"
  local slug
  # Take first 40 chars
  slug="${text:0:40}"
  # Lowercase
  slug="$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]')"
  # Replace non-alphanumeric with hyphens
  slug="$(printf '%s' "$slug" | tr -cs 'a-z0-9' '-')"
  # Collapse repeated hyphens
  slug="$(printf '%s' "$slug" | sed 's/-\{2,\}/-/g')"
  # Trim leading/trailing hyphens
  slug="${slug#-}"
  slug="${slug%-}"
  printf '%s' "$slug"
}

SLUG="$(_make_slug "$RAW_TEXT")"
if [ -z "$SLUG" ]; then
  SLUG="manual-input"
fi

# ---------------------------------------------------------------------------
# Timestamp and filename
# ---------------------------------------------------------------------------
TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
ISO_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FILENAME="${TIMESTAMP}-${SLUG}.md"

mkdir -p "$INBOX_DIR"
OUTFILE="$INBOX_DIR/$FILENAME"

# ---------------------------------------------------------------------------
# Write inbox item
# ---------------------------------------------------------------------------
cat > "$OUTFILE" <<EOF
---
source: ${BTW_SOURCE_TIER}
created_at: ${ISO_UTC}
trust_tier: ${TRUST_TIER}
---

<<<UNTRUSTED_STAKEHOLDER_INPUT tier=${TRUST_TIER}>>>
${RAW_TEXT}
<<<END_UNTRUSTED_STAKEHOLDER_INPUT>>>
EOF

# ---------------------------------------------------------------------------
# Notify
# ---------------------------------------------------------------------------
if [ -x "$NOTIFY_SH" ]; then
  "$NOTIFY_SH" info stakeholder \
    "btw queued: ${SLUG}" \
    "received ${CHAR_COUNT} chars — triage in next overseer-tick" \
    2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Audit
# ---------------------------------------------------------------------------
if [ -f "$AUDIT_LIB" ]; then
  # shellcheck source=lib/audit.sh
  source "$AUDIT_LIB"
  audit_record stakeholder btw_received "$SLUG" "tier=${TRUST_TIER} chars=${CHAR_COUNT}" 2>/dev/null || true
fi

printf 'btw.sh: queued %s\n' "$FILENAME"
