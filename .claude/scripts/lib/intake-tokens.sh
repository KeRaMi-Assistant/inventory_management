#!/usr/bin/env bash
# intake-tokens.sh — Sourceable library for HMAC-Token generation, verification,
#                    and content-hash computation for yota-propose intake pipeline.
#
# Usage: source this file, then call:
#   generate_hmac_token  <approval-id>           → echoes 16-char token on stdout
#   verify_hmac_token    <approval-id> <token>   → exit 0 match, 1 mismatch
#   generate_content_hash <file>                 → echoes sha256 of body (no frontmatter)
#
# Secret file: ~/.claude/inventory-intake-hmac-secret (Mode 0400, auto-created)
# Falls back to ~/.claude/telegram-hmac-secret if present (T04 spec note).

# Deliberately NO set -e here — this is a sourced library.
set -u

# ---------------------------------------------------------------------------
# Internal: resolve HMAC secret file, create on first use
# ---------------------------------------------------------------------------
_intake_hmac_secret_file() {
  # Prefer telegram-hmac-secret if it already exists (T04 spec: fallback)
  local telegram_secret="${HOME}/.claude/telegram-hmac-secret"
  local intake_secret="${HOME}/.claude/inventory-intake-hmac-secret"

  if [ -f "$telegram_secret" ]; then
    printf '%s' "$telegram_secret"
    return 0
  fi

  if [ ! -f "$intake_secret" ]; then
    mkdir -p "${HOME}/.claude"
    openssl rand -hex 32 > "$intake_secret"
    chmod 0400 "$intake_secret"
  fi
  printf '%s' "$intake_secret"
}

# ---------------------------------------------------------------------------
# generate_hmac_token <approval-id>
#
# Token = first 16 chars of sha256(secret:approval-id:iso-date-today)
# Deterministic for same id + same UTC date.
# ---------------------------------------------------------------------------
generate_hmac_token() {
  local approval_id="${1:-}"
  if [ -z "$approval_id" ]; then
    printf 'generate_hmac_token: ERROR: approval-id required\n' >&2
    return 1
  fi

  local secret_file
  secret_file="$(_intake_hmac_secret_file)"
  local secret
  secret="$(cat "$secret_file" 2>/dev/null | tr -d '[:space:]')"
  if [ -z "$secret" ]; then
    printf 'generate_hmac_token: ERROR: cannot read secret from %s\n' "$secret_file" >&2
    return 1
  fi

  local iso_date
  # Allow test override via _INTAKE_TOKEN_DATE_OVERRIDE
  iso_date="${_INTAKE_TOKEN_DATE_OVERRIDE:-$(date -u +%Y-%m-%d)}"

  python3 - "$secret" "$approval_id" "$iso_date" <<'PYEOF'
import sys, hashlib

secret     = sys.argv[1]
appr_id    = sys.argv[2]
iso_date   = sys.argv[3]

data = f"{secret}:{appr_id}:{iso_date}"
full_hash = hashlib.sha256(data.encode('utf-8')).hexdigest()
# Truncate to 16 chars — UX-friendly for mobile confirmation
print(full_hash[:16])
PYEOF
}

# ---------------------------------------------------------------------------
# verify_hmac_token <approval-id> <token>
#
# Returns 0 on match, 1 on mismatch.
# Uses constant-time compare (Python hmac.compare_digest).
# Audit intake_token_mismatch on failure.
# ---------------------------------------------------------------------------
verify_hmac_token() {
  local approval_id="${1:-}"
  local token="${2:-}"

  if [ -z "$approval_id" ] || [ -z "$token" ]; then
    printf 'verify_hmac_token: ERROR: approval-id and token required\n' >&2
    return 1
  fi

  local expected
  expected="$(generate_hmac_token "$approval_id")"
  local gen_rc=$?
  if [ $gen_rc -ne 0 ]; then
    return 1
  fi

  local result
  result=$(python3 - "$expected" "$token" <<'PYEOF'
import sys, hmac

expected = sys.argv[1]
provided = sys.argv[2]

# constant-time compare
if hmac.compare_digest(expected, provided):
    print("match")
    sys.exit(0)
else:
    print("mismatch")
    sys.exit(1)
PYEOF
)
  local py_rc=$?

  if [ $py_rc -ne 0 ]; then
    # Audit mismatch
    local _audit_lib
    _audit_lib="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}/.claude/scripts/lib/audit.sh"
    if [ -f "$_audit_lib" ]; then
      # shellcheck source=audit.sh
      source "$_audit_lib"
      audit_record "intake-tokens" "intake_token_mismatch" "$approval_id" "provided=${token}" 2>/dev/null || true
    fi
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# generate_content_hash <file>
#
# Returns sha256 of the body text only (strips ---\nfrontmatter\n---\n prefix).
# Identical body with different frontmatter → identical hash (dedup-safe).
# ---------------------------------------------------------------------------
generate_content_hash() {
  local file="${1:-}"
  if [ -z "$file" ] || [ ! -f "$file" ]; then
    printf 'generate_content_hash: ERROR: file not found: %s\n' "${file:-<empty>}" >&2
    return 1
  fi

  python3 - "$file" <<'PYEOF'
import sys, hashlib, re

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Strip YAML frontmatter (between first two --- delimiters)
m = re.match(r'^---\r?\n.*?\r?\n---\r?\n', content, re.DOTALL)
if m:
    body = content[m.end():]
else:
    body = content

# Normalise: strip trailing whitespace per line, strip leading/trailing blank lines
lines = [l.rstrip() for l in body.splitlines()]
# Strip leading blank lines
while lines and not lines[0]:
    lines.pop(0)
# Strip trailing blank lines
while lines and not lines[-1]:
    lines.pop()

normalized = "\n".join(lines)
print(hashlib.sha256(normalized.encode("utf-8")).hexdigest())
PYEOF
}
