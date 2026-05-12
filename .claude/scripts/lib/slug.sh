#!/usr/bin/env bash
# slug.sh — Sourceable slug/ID helper library
# Usage: source .claude/scripts/lib/slug.sh
# IMPORTANT: No top-level exit calls — safe to source.

# ---------------------------------------------------------------------------
# make_slug <input-text>
# Converts arbitrary text to a kebab-case slug (max 40 chars).
# Returns "manual-input" for empty or invalid results.
# ---------------------------------------------------------------------------
make_slug() {
  local text="$1"
  local slug

  # Take first 40 chars (before transformation to keep meaningful prefix)
  slug="${text:0:60}"

  # Lowercase
  slug="$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]')"

  # Replace non-alphanumeric chars with hyphens
  slug="$(printf '%s' "$slug" | tr -cs 'a-z0-9' '-')"

  # Collapse repeated hyphens
  slug="$(printf '%s' "$slug" | sed 's/-\{2,\}/-/g')"

  # Strip leading/trailing hyphens
  slug="${slug#-}"
  slug="${slug%-}"

  # Truncate to 40 chars, then strip any trailing hyphen again
  slug="${slug:0:40}"
  slug="${slug%-}"

  # Validate result matches slug regex
  if [[ -z "$slug" ]] || ! [[ "$slug" =~ ^[a-z0-9][a-z0-9-]{0,39}$ ]]; then
    printf 'manual-input'
    return 0
  fi

  printf '%s' "$slug"
}

# ---------------------------------------------------------------------------
# validate_slug <slug>
# Returns 0 (valid) or 1 (invalid). Echoes cleaned slug on stdout if valid.
# ---------------------------------------------------------------------------
validate_slug() {
  local slug="$1"
  if [[ "$slug" =~ ^[a-z0-9][a-z0-9-]{0,39}$ ]]; then
    printf '%s' "$slug"
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# make_intake_id <slug> [base-dir]
# Produces a unique ID: <YYYYMMDD>-<HHMMSS>-<slug>
# Optional base-dir (default: .claude/stakeholder/pending-proposal) is used
# for collision detection.
# ---------------------------------------------------------------------------
make_intake_id() {
  local slug="$1"
  local base_dir="${2:-.claude/stakeholder/pending-proposal}"
  local timestamp
  timestamp="$(date -u +%Y%m%d-%H%M%S)"
  local candidate="${timestamp}-${slug}"
  local suffix=1

  # Collision guard: append -2, -3, ... until no matching file exists
  while [[ -f "${base_dir}/${candidate}.md" ]]; do
    (( suffix++ ))
    candidate="${timestamp}-${slug}-${suffix}"
  done

  printf '%s' "$candidate"
}

# ---------------------------------------------------------------------------
# validate_intake_id <id>
# Returns 0 (valid) or 1 (invalid). Echoes cleaned id on stdout if valid.
# ---------------------------------------------------------------------------
validate_intake_id() {
  local id="$1"
  if [[ "$id" =~ ^[0-9]{8}-[0-9]{6}-[a-z0-9-]{1,40}$ ]]; then
    printf '%s' "$id"
    return 0
  fi
  return 1
}
