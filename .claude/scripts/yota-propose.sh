#!/usr/bin/env bash
# yota-propose.sh — Tier-1 Stakeholder Proposal CLI (Council-Gated Intake)
#
# Usage:
#   yota-propose.sh "<idee>"   — write idea as pending-proposal item
#   yota-propose.sh -          — read idea from stdin
#
# Writes: .claude/stakeholder/pending-proposal/<YYYYMMDD>-<HHMMSS>-<slug>.md
# Sentinel-Reject: exit 2 if text contains Sandwich-Markers (injection attempt)
# Max text length: 4096 chars (truncates + warns)
# Env override: YOTA_PROPOSE_TIER=tier-2 (for Telegram-Bot adapter in Wave 4)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

PROPOSAL_DIR="$REPO_ROOT/.claude/stakeholder/pending-proposal"
AUDIT_LIB="$REPO_ROOT/.claude/scripts/lib/audit.sh"
SLUG_LIB="$REPO_ROOT/.claude/scripts/lib/slug.sh"
TOKENS_LIB="$REPO_ROOT/.claude/scripts/lib/intake-tokens.sh"
NOTIFY_SH="$REPO_ROOT/.claude/scripts/notify.sh"
API_KEY_PREFLIGHT_LIB="$REPO_ROOT/.claude/scripts/lib/api-key-preflight.sh"

# Fall back to co-located scripts if REPO_ROOT override not present
[ -f "$AUDIT_LIB" ]               || AUDIT_LIB="$SCRIPT_DIR/lib/audit.sh"
[ -f "$SLUG_LIB" ]                || SLUG_LIB="$SCRIPT_DIR/lib/slug.sh"
[ -f "$TOKENS_LIB" ]              || TOKENS_LIB="$SCRIPT_DIR/lib/intake-tokens.sh"
[ -x "$NOTIFY_SH" ]               || NOTIFY_SH="$SCRIPT_DIR/notify.sh"
[ -f "$API_KEY_PREFLIGHT_LIB" ]   || API_KEY_PREFLIGHT_LIB="$SCRIPT_DIR/lib/api-key-preflight.sh"

# Source intake-tokens lib (provides generate_content_hash for proper dedup)
if [ -f "$TOKENS_LIB" ]; then
  # shellcheck source=lib/intake-tokens.sh
  source "$TOKENS_LIB"
fi

# Dedup window in seconds (default 1h); override via env
YOTA_DEDUP_WINDOW_SECS="${YOTA_DEDUP_WINDOW_SECS:-3600}"

# ---------------------------------------------------------------------------
# ANTHROPIC_API_KEY Pre-Flight — must happen before any claude --print call
# ---------------------------------------------------------------------------
if [ -f "$API_KEY_PREFLIGHT_LIB" ]; then
  # shellcheck source=lib/api-key-preflight.sh
  source "$API_KEY_PREFLIGHT_LIB"
  check_no_api_key
fi

MAX_CHARS=4096

# YOTA_PROPOSE_TIER: tier-1 (default) or tier-2 (Telegram adapter)
YOTA_PROPOSE_TIER="${YOTA_PROPOSE_TIER:-tier-1}"
# Extract numeric trust level from tier string (tier-1 → 1, tier-2 → 2)
TRUST_TIER="${YOTA_PROPOSE_TIER#tier-}"
# Ensure it's a positive integer; fallback to 1
if ! printf '%s' "$TRUST_TIER" | grep -qE '^[0-9]+$'; then
  TRUST_TIER=1
fi

# ---------------------------------------------------------------------------
# Argument handling
# ---------------------------------------------------------------------------
if [ $# -eq 0 ]; then
  printf 'Usage: yota-propose.sh "<idee>"\n       yota-propose.sh -  (stdin)\n' >&2
  exit 1
fi

if [ "$1" = "-" ]; then
  RAW_TEXT="$(cat)"
else
  RAW_TEXT="$1"
fi

if [ -z "${RAW_TEXT:-}" ]; then
  printf 'yota-propose.sh: ERROR: empty input\n' >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Truncate if > MAX_CHARS
# ---------------------------------------------------------------------------
CHAR_COUNT="${#RAW_TEXT}"
if [ "$CHAR_COUNT" -gt "$MAX_CHARS" ]; then
  printf 'yota-propose.sh: WARNING: text truncated from %d to %d chars\n' "$CHAR_COUNT" "$MAX_CHARS" >&2
  RAW_TEXT="${RAW_TEXT:0:$MAX_CHARS}"
  CHAR_COUNT=$MAX_CHARS
fi

# ---------------------------------------------------------------------------
# Sentinel-Reject: detect injection attempt
# Covers:
#   <<<UNTRUSTED_PROPOSAL / <<<END_UNTRUSTED_PROPOSAL  (original T03 markers)
#   <<<UNTRUSTED_STAKEHOLDER_INPUT / <<<END_UNTRUSTED_STAKEHOLDER_INPUT
#   Any <<<UNTRUSTED_*  generic pattern (T04 extension)
# ---------------------------------------------------------------------------
_sentinel_check() {
  local text="$1"
  if printf '%s' "$text" | grep -qF '<<<UNTRUSTED_PROPOSAL'; then return 1; fi
  if printf '%s' "$text" | grep -qF '<<<END_UNTRUSTED_PROPOSAL'; then return 1; fi
  if printf '%s' "$text" | grep -qF '<<<UNTRUSTED_STAKEHOLDER_INPUT'; then return 1; fi
  if printf '%s' "$text" | grep -qF '<<<END_UNTRUSTED_STAKEHOLDER_INPUT'; then return 1; fi
  # Generic <<<UNTRUSTED_*>>> pattern (catches any future variants)
  if printf '%s' "$text" | grep -qE '<<<UNTRUSTED_[A-Z_]+'; then return 1; fi
  return 0
}

if ! _sentinel_check "$RAW_TEXT"; then
  printf 'yota-propose.sh: ERROR: prompt-injection-Versuch erkannt — Sentinel-Marker im Input\n' >&2
  # Audit the rejection attempt
  if [ -f "$AUDIT_LIB" ]; then
    # shellcheck source=lib/audit.sh
    source "$AUDIT_LIB"
    audit_record stakeholder intake_sentinel_rejected "sentinel-inject" \
      "tier=${TRUST_TIER} chars=${CHAR_COUNT}" 2>/dev/null || true
  fi
  exit 2
fi

# ---------------------------------------------------------------------------
# Slug + ID generation via lib/slug.sh
# ---------------------------------------------------------------------------
if [ -f "$SLUG_LIB" ]; then
  # shellcheck source=lib/slug.sh
  source "$SLUG_LIB"
else
  printf 'yota-propose.sh: ERROR: slug library not found: %s\n' "$SLUG_LIB" >&2
  exit 1
fi

SLUG="$(make_slug "$RAW_TEXT")"
if [ -z "$SLUG" ]; then
  SLUG="manual-input"
fi

# Security-defensive: validate slug before use
if ! validate_slug "$SLUG" >/dev/null; then
  SLUG="manual-input"
fi

mkdir -p "$PROPOSAL_DIR"

# make_intake_id uses PROPOSAL_DIR for collision detection
INTAKE_ID="$(make_intake_id "$SLUG" "$PROPOSAL_DIR")"

# Validate the generated ID
if ! validate_intake_id "$INTAKE_ID" >/dev/null; then
  printf 'yota-propose.sh: ERROR: generated invalid intake ID: %s\n' "$INTAKE_ID" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Timestamps + metadata
# ---------------------------------------------------------------------------
ISO_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
USER_ID="${TELEGRAM_USER_ID:-local-${USER:-unknown}}"

# Content hash via intake-tokens lib (strips frontmatter, normalises body)
# Write raw text to temp file; no frontmatter → body = full text
_TMPFILE="$(mktemp /tmp/yota-propose-XXXXXX.txt)"
printf '%s' "$RAW_TEXT" > "$_TMPFILE"

CONTENT_HASH=""
if declare -f generate_content_hash >/dev/null 2>&1; then
  CONTENT_HASH="$(generate_content_hash "$_TMPFILE" 2>/dev/null || true)"
fi

# Fallback: raw sha256
if [ -z "$CONTENT_HASH" ]; then
  CONTENT_HASH="$(python3 -c "import sys,hashlib; t=open('$_TMPFILE').read().strip(); print(hashlib.sha256(t.encode()).hexdigest())" 2>/dev/null || true)"
fi
if [ -z "$CONTENT_HASH" ]; then
  CONTENT_HASH="$(printf '%s' "$RAW_TEXT" | shasum -a 256 2>/dev/null | awk '{print $1}')"
fi
if [ -z "$CONTENT_HASH" ]; then
  CONTENT_HASH="unavailable"
fi
rm -f "$_TMPFILE"

# ---------------------------------------------------------------------------
# Dedup-Check: reject if identical content_hash exists in pending-proposal/
# within YOTA_DEDUP_WINDOW_SECS (default: 3600s)
# ---------------------------------------------------------------------------
_check_dedup() {
  local hash="$1"
  local window="$2"
  local now
  now="$(date -u +%s)"

  for f in "$PROPOSAL_DIR"/*.md; do
    [ -f "$f" ] || continue
    local fh
    fh="$(grep -m1 '^content_hash:' "$f" 2>/dev/null | awk '{print $2}')"
    [ "$fh" = "$hash" ] || continue
    local fmtime
    fmtime="$(python3 -c "import os,sys; print(int(os.path.getmtime(sys.argv[1])))" "$f" 2>/dev/null || echo 0)"
    local age=$(( now - fmtime ))
    if [ "$age" -le "$window" ]; then
      grep -m1 '^id:' "$f" 2>/dev/null | awk '{print $2}'
      return 0
    fi
  done
  return 1
}

mkdir -p "$PROPOSAL_DIR"
EXISTING_ID="$(_check_dedup "$CONTENT_HASH" "$YOTA_DEDUP_WINDOW_SECS" || true)"

if [ -n "$EXISTING_ID" ]; then
  printf 'yota-propose.sh: WARNING: identischer Content-Hash bereits vorhanden (id: %s) — kein Duplikat angelegt\n' "$EXISTING_ID" >&2
  if [ -f "$AUDIT_LIB" ]; then
    source "$AUDIT_LIB"
    audit_record stakeholder intake_content_duplicate "dedup-reject" \
      "existing_id=${EXISTING_ID} hash=${CONTENT_HASH}" 2>/dev/null || true
  fi
  exit 3
fi

# ---------------------------------------------------------------------------
# Write pending-proposal file
# ---------------------------------------------------------------------------
OUTFILE="$PROPOSAL_DIR/${INTAKE_ID}.md"

cat > "$OUTFILE" <<EOF
---
id: ${INTAKE_ID}
source: ${YOTA_PROPOSE_TIER}
trust_tier: ${TRUST_TIER}
user_id: ${USER_ID}
created_at: ${ISO_UTC}
state: pending-proposal
round: 1
content_hash: ${CONTENT_HASH}
---

<<<UNTRUSTED_PROPOSAL tier=${TRUST_TIER}>>>
${RAW_TEXT}
<<<END_UNTRUSTED_PROPOSAL>>>
EOF

# ---------------------------------------------------------------------------
# Audit
# ---------------------------------------------------------------------------
if [ -f "$AUDIT_LIB" ]; then
  # shellcheck source=lib/audit.sh
  # Guard: may already be sourced (idempotent if re-sourced)
  source "$AUDIT_LIB"
  audit_record stakeholder intake_proposed "$SLUG" \
    "tier=${TRUST_TIER} chars=${CHAR_COUNT}" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Notify
# ---------------------------------------------------------------------------
if [ -x "$NOTIFY_SH" ]; then
  "$NOTIFY_SH" info intake \
    "Proposal queued: ${SLUG}" \
    "Council deliberiert, du kriegst Verdict in ~90s. Cost: ~\$0.50-2." \
    2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Output: file path on stdout
# ---------------------------------------------------------------------------
printf '%s\n' "$OUTFILE"
