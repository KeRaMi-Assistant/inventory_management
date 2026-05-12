#!/usr/bin/env bash
# intake-actions.sh — Sourceable library for intake approval actions.
#
# Extracted from telegram-bot.py T11-handler logic (T26 DRY-refactor).
# Used by yota-go.sh / yota-reject.sh / yota-change.sh (local CLI)
# and by telegram-bot.py (reuse via subprocess or import).
#
# Functions:
#   intake_go     <id_or_slug> <token_or_empty> <user_id>
#   intake_reject <id_or_slug> <reason>         <user_id>
#   intake_change <id_or_slug> <text>           <user_id>
#
# Exit codes (all functions):
#   0  — action applied
#   1  — error (see stderr)
#   2  — no pending approval found
#   3  — creator-binding mismatch (silent by design, but exit 3)
#   4  — token mismatch
#   5  — round-limit reached (change only)
#
# Requires (env or auto-detected):
#   REPO_ROOT         — repo root (auto from script location if absent)
#   PENDING_APPROVAL_DIR — override (default: $REPO_ROOT/.claude/stakeholder/pending-approval)
#   PENDING_PROPOSAL_DIR — override (default: $REPO_ROOT/.claude/stakeholder/pending-proposal)
#   REJECTED_DIR         — override (default: $REPO_ROOT/.claude/stakeholder/rejected)
#   OVERSEER_INBOX_DIR   — override (default: $REPO_ROOT/.claude/overseer/inbox)
#
# Deliberately NO set -e — this is a sourced library.
set -u

# ---------------------------------------------------------------------------
# Paths (resolved lazily on first call via _ia_init)
# ---------------------------------------------------------------------------
_IA_INITIALIZED=0

_ia_init() {
  if [ "$_IA_INITIALIZED" -eq 1 ]; then return 0; fi

  # Resolve SCRIPT_DIR relative to this file (works when sourced too)
  local _this_file="${BASH_SOURCE[0]}"
  local _this_dir
  _this_dir="$(cd "$(dirname "$_this_file")" && pwd)"

  # Repo root: parent of .claude/scripts/lib/
  REPO_ROOT="${REPO_ROOT:-$(cd "$_this_dir/../../.." && pwd)}"

  _IA_PENDING_APPROVAL_DIR="${PENDING_APPROVAL_DIR:-$REPO_ROOT/.claude/stakeholder/pending-approval}"
  _IA_PENDING_PROPOSAL_DIR="${PENDING_PROPOSAL_DIR:-$REPO_ROOT/.claude/stakeholder/pending-proposal}"
  _IA_REJECTED_DIR="${REJECTED_DIR:-$REPO_ROOT/.claude/stakeholder/rejected}"
  _IA_OVERSEER_INBOX_DIR="${OVERSEER_INBOX_DIR:-$REPO_ROOT/.claude/overseer/inbox}"
  _IA_INTAKE_TOKENS_LIB="${REPO_ROOT}/.claude/scripts/lib/intake-tokens.sh"
  _IA_AUDIT_LIB="${REPO_ROOT}/.claude/scripts/lib/audit.sh"
  _IA_NOTIFY_SH="${REPO_ROOT}/.claude/scripts/notify.sh"
  _IA_INTAKE_COUNCIL_SH="${REPO_ROOT}/.claude/scripts/intake-council.sh"

  # Source audit lib (best-effort)
  if [ -f "$_IA_AUDIT_LIB" ]; then
    # shellcheck source=audit.sh
    source "$_IA_AUDIT_LIB" 2>/dev/null || true
  fi
  # Source intake-tokens lib (best-effort)
  if [ -f "$_IA_INTAKE_TOKENS_LIB" ]; then
    # shellcheck source=intake-tokens.sh
    source "$_IA_INTAKE_TOKENS_LIB" 2>/dev/null || true
  fi

  _IA_INITIALIZED=1
}

# ---------------------------------------------------------------------------
# _ia_audit <actor> <action> <subject> <reason>
# ---------------------------------------------------------------------------
_ia_audit() {
  if command -v audit_record >/dev/null 2>&1; then
    audit_record "$1" "$2" "$3" "$4" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# _ia_notify <severity> <title> <body>
# ---------------------------------------------------------------------------
_ia_notify() {
  local sev="$1" title="$2" body="$3"
  if [ -x "${_IA_NOTIFY_SH:-}" ]; then
    REPO_ROOT="$REPO_ROOT" "$_IA_NOTIFY_SH" "$sev" "intake-actions" "$title" "$body" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# _ia_read_frontmatter <file>
# Emits key=value lines for the YAML frontmatter of a markdown file.
# Only simple scalar keys (no nested YAML).
# ---------------------------------------------------------------------------
_ia_read_frontmatter() {
  python3 - "$1" <<'PY' 2>/dev/null
import sys, re

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        content = f.read()
except OSError as e:
    print(f"error=1", flush=True)
    sys.exit(0)

m = re.match(r'^---\r?\n(.*?)\r?\n---\r?\n', content, re.DOTALL)
if not m:
    sys.exit(0)

for line in m.group(1).splitlines():
    kv = line.split(":", 1)
    if len(kv) == 2:
        key = kv[0].strip()
        val = kv[1].strip()
        # Emit as shell-safe key=value (escape val)
        safe_val = val.replace("'", "'\\''")
        print(f"{key}='{safe_val}'")
PY
}

# ---------------------------------------------------------------------------
# _ia_get_fm_field <file> <key> → echoes value
# ---------------------------------------------------------------------------
_ia_get_fm_field() {
  local file="$1" key="$2"
  python3 - "$file" "$key" <<'PY' 2>/dev/null
import sys, re

path, key = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding="utf-8") as f:
        content = f.read()
except OSError:
    sys.exit(0)

m = re.match(r'^---\r?\n(.*?)\r?\n---\r?\n', content, re.DOTALL)
if not m:
    sys.exit(0)

for line in m.group(1).splitlines():
    kv = line.split(":", 1)
    if len(kv) == 2 and kv[0].strip() == key:
        print(kv[1].strip())
        break
PY
}

# ---------------------------------------------------------------------------
# _ia_resolve <id_or_slug> → echoes matching file path (empty = not found)
# Searches _IA_PENDING_APPROVAL_DIR for .md files matching id or slug prefix.
# ---------------------------------------------------------------------------
_ia_resolve() {
  local id_or_slug="$1"
  local dir="$_IA_PENDING_APPROVAL_DIR"

  if [ ! -d "$dir" ]; then
    return 0
  fi

  # Exact filename prefix (e.g. 20260512-101010-<slug>.md)
  local exact_match=""
  local fuzzy_matches=()

  while IFS= read -r -d '' candidate; do
    local base
    base="$(basename "$candidate" .md)"
    local fm_id
    fm_id="$(_ia_get_fm_field "$candidate" "id" 2>/dev/null)"

    # Exact full ID match
    if [ "$fm_id" = "$id_or_slug" ]; then
      printf '%s' "$candidate"
      return 0
    fi
    # Slug portion after YYYYMMDD-HHMMSS-
    local parts_slug
    parts_slug="$(printf '%s' "$base" | python3 -c 'import sys; p=sys.stdin.read().split("-",2); print(p[2] if len(p)>=3 else p[-1])' 2>/dev/null)"
    if [[ "$parts_slug" == "$id_or_slug"* ]]; then
      fuzzy_matches+=("$candidate")
    fi
  done < <(find "$dir" -maxdepth 1 -name "*.md" -not -name "*.superseded.md" -print0 2>/dev/null)

  if [ "${#fuzzy_matches[@]}" -eq 1 ]; then
    printf '%s' "${fuzzy_matches[0]}"
    return 0
  fi
  # Not found or ambiguous — return empty
  return 0
}

# ---------------------------------------------------------------------------
# _ia_verify_token <approval_id> <token>
# Returns 0 on match, 1 on mismatch or empty token (token optional = skip).
# ---------------------------------------------------------------------------
_ia_verify_token() {
  local id="$1" token="${2:-}"
  if [ -z "$token" ]; then return 0; fi

  if command -v verify_hmac_token >/dev/null 2>&1; then
    if verify_hmac_token "$id" "$token" 2>/dev/null; then
      return 0
    fi
  fi
  # Fallback: check frontmatter hmac_token field directly
  local path
  path="$(_ia_resolve "$id")"
  if [ -n "$path" ]; then
    local fm_token
    fm_token="$(_ia_get_fm_field "$path" "hmac_token" 2>/dev/null)"
    if python3 -c "
import sys, hmac
a, b = sys.argv[1], sys.argv[2]
sys.exit(0 if hmac.compare_digest(a,b) else 1)
" "$fm_token" "$token" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

# ---------------------------------------------------------------------------
# _ia_run_validator <approval_path> → echoes "pass|needs-full-council|quarantine|error" <reason>
# Calls intake-validator via intake-council.sh --validate or validator agent.
# ---------------------------------------------------------------------------
_ia_run_validator() {
  local path="$1"
  # Use the validator agent if available
  local validator_sh="${REPO_ROOT}/.claude/scripts/lib/intake-validator-agent.sh"
  if [ -f "$validator_sh" ]; then
    local out
    out="$(REPO_ROOT="$REPO_ROOT" bash "$validator_sh" "$path" 2>/dev/null)" || true
    local verdict
    verdict="$(printf '%s' "$out" | grep -m1 '^verdict:' | cut -d: -f2- | xargs 2>/dev/null)"
    local reason
    reason="$(printf '%s' "$out" | grep -m1 '^reason:' | cut -d: -f2- | xargs 2>/dev/null)"
    if [ -n "$verdict" ]; then
      printf '%s\n%s' "$verdict" "$reason"
      return 0
    fi
  fi
  # Fallback: pass (local CLI doesn't run full council)
  printf 'pass\nlocal-bypass'
}

# ---------------------------------------------------------------------------
# intake_go <id_or_slug> <token_or_empty> <user_id>
#
# Approves a pending-approval item:
#   1. Creator-binding check (user_id must match fm.user_id or be local-)
#   2. HMAC token verify (optional — skip if empty)
#   3. Run intake-validator
#   4. Move approval → pending-approval/approved/, item lands in overseer/inbox/
# ---------------------------------------------------------------------------
intake_go() {
  _ia_init
  local id_or_slug="${1:-}"
  local token="${2:-}"
  local user_id="${3:-}"

  if [ -z "$id_or_slug" ]; then
    printf 'intake_go: ERROR: id_or_slug required\n' >&2
    return 1
  fi

  local path
  path="$(_ia_resolve "$id_or_slug")"
  if [ -z "$path" ] || [ ! -f "$path" ]; then
    printf 'intake_go: no pending approval found for: %s\n' "$id_or_slug" >&2
    return 2
  fi

  local fm_user_id fm_id
  fm_user_id="$(_ia_get_fm_field "$path" "user_id" 2>/dev/null)"
  fm_id="$(_ia_get_fm_field "$path" "id" 2>/dev/null)"
  fm_id="${fm_id:-$(basename "$path" .md)}"

  # Creator-binding: exact match required; local- prefix does NOT grant cross-user access
  if [ -n "$user_id" ] && [ -n "$fm_user_id" ]; then
    if [ "$fm_user_id" != "$user_id" ]; then
      _ia_audit "intake-actions" "intake_go_wrong_user" "$fm_id" "actual=${user_id} expected=${fm_user_id}"
      printf 'intake_go: creator-binding mismatch — silent ignore\n' >&2
      return 3
    fi
  fi

  # HMAC token verification
  if [ -n "$token" ]; then
    if ! _ia_verify_token "$fm_id" "$token"; then
      _ia_audit "intake-actions" "intake_token_mismatch" "$fm_id" "user=${user_id}"
      printf 'intake_go: token mismatch\n' >&2
      return 4
    fi
  fi

  # Run validator
  local val_out val_verdict val_reason
  val_out="$(_ia_run_validator "$path")"
  val_verdict="$(printf '%s' "$val_out" | head -1)"
  val_reason="$(printf '%s' "$val_out" | tail -1)"

  _ia_audit "intake-actions" "intake_user_go" "$fm_id" \
    "user=${user_id} validator=${val_verdict}"

  if [ "$val_verdict" = "pass" ]; then
    # Move approval to approved/
    local done_dir="${_IA_PENDING_APPROVAL_DIR}/approved"
    mkdir -p "$done_dir"
    local dest="${done_dir}/$(basename "$path")"
    mv "$path" "$dest" 2>/dev/null || {
      printf 'intake_go: ERROR: could not move %s → %s\n' "$path" "$dest" >&2
      return 1
    }
    printf 'approved: %s\n' "$fm_id"
    return 0
  fi

  if [ "$val_verdict" = "needs-full-council" ]; then
    printf 'intake_go: needs-full-council — run /council %s manually\n' "$fm_id" >&2
    return 1
  fi

  printf 'intake_go: validator returned %s: %s\n' "$val_verdict" "$val_reason" >&2
  return 1
}

# ---------------------------------------------------------------------------
# intake_reject <id_or_slug> <reason> <user_id>
# ---------------------------------------------------------------------------
intake_reject() {
  _ia_init
  local id_or_slug="${1:-}"
  local reason="${2:-}"
  local user_id="${3:-}"

  if [ -z "$id_or_slug" ]; then
    printf 'intake_reject: ERROR: id_or_slug required\n' >&2
    return 1
  fi

  local path
  path="$(_ia_resolve "$id_or_slug")"
  if [ -z "$path" ] || [ ! -f "$path" ]; then
    printf 'intake_reject: no pending approval found for: %s\n' "$id_or_slug" >&2
    return 2
  fi

  local fm_user_id fm_id
  fm_user_id="$(_ia_get_fm_field "$path" "user_id" 2>/dev/null)"
  fm_id="$(_ia_get_fm_field "$path" "id" 2>/dev/null)"
  fm_id="${fm_id:-$(basename "$path" .md)}"

  # Creator-binding: exact match required
  if [ -n "$user_id" ] && [ -n "$fm_user_id" ]; then
    if [ "$fm_user_id" != "$user_id" ]; then
      _ia_audit "intake-actions" "intake_go_wrong_user" "$fm_id" "actual=${user_id}"
      printf 'intake_reject: creator-binding mismatch — silent ignore\n' >&2
      return 3
    fi
  fi

  # Move to rejected/
  mkdir -p "$_IA_REJECTED_DIR"
  local iso
  iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local dest="${_IA_REJECTED_DIR}/$(basename "$path")"

  # Prepend reject metadata to content
  local orig_content
  orig_content="$(cat "$path" 2>/dev/null || true)"
  {
    printf -- '---\nstate: rejected\nrejected_by: %s\nrejected_at: %s\nreject_reason: %s\n---\n\n' \
      "$user_id" "$iso" "$reason"
    printf '%s\n' "$orig_content"
  } > "$dest"
  rm -f "$path" 2>/dev/null || true

  _ia_audit "intake-actions" "intake_user_reject" "$fm_id" \
    "user=${user_id} reason=${reason:0:80}"

  printf 'rejected: %s\n' "$fm_id"
  return 0
}

# ---------------------------------------------------------------------------
# intake_change <id_or_slug> <text> <user_id>
# ---------------------------------------------------------------------------
intake_change() {
  _ia_init
  local id_or_slug="${1:-}"
  local new_text="${2:-}"
  local user_id="${3:-}"

  if [ -z "$id_or_slug" ] || [ -z "$new_text" ]; then
    printf 'intake_change: ERROR: id_or_slug and text required\n' >&2
    return 1
  fi

  local path
  path="$(_ia_resolve "$id_or_slug")"
  if [ -z "$path" ] || [ ! -f "$path" ]; then
    printf 'intake_change: no pending approval found for: %s\n' "$id_or_slug" >&2
    return 2
  fi

  local fm_user_id fm_id fm_round fm_source fm_tier fm_hash
  fm_user_id="$(_ia_get_fm_field "$path" "user_id" 2>/dev/null)"
  fm_id="$(_ia_get_fm_field "$path" "id" 2>/dev/null)"
  fm_id="${fm_id:-$(basename "$path" .md)}"
  fm_round="$(_ia_get_fm_field "$path" "round" 2>/dev/null)"
  fm_round="${fm_round:-1}"
  fm_source="$(_ia_get_fm_field "$path" "source" 2>/dev/null)"
  fm_source="${fm_source:-tier-1}"
  fm_tier="$(_ia_get_fm_field "$path" "trust_tier" 2>/dev/null)"
  fm_tier="${fm_tier:-1}"
  fm_hash="$(_ia_get_fm_field "$path" "content_hash" 2>/dev/null)"

  # Creator-binding: exact match required
  if [ -n "$user_id" ] && [ -n "$fm_user_id" ]; then
    if [ "$fm_user_id" != "$user_id" ]; then
      printf 'intake_change: creator-binding mismatch — silent ignore\n' >&2
      return 3
    fi
  fi

  # Max-rounds guard (T11 logic: MAX_INTAKE_ROUNDS = 3)
  local max_rounds=3
  if [ "$fm_round" -ge "$max_rounds" ] 2>/dev/null; then
    printf 'intake_change: max %d rounds reached — use go or reject\n' "$max_rounds" >&2
    return 5
  fi

  # Atomic-mv to superseded
  local superseded="${path%.md}.superseded.md"
  mv "$path" "$superseded" 2>/dev/null || {
    printf 'intake_change: ERROR: could not move %s\n' "$path" >&2
    return 1
  }

  # Write new pending-proposal with round+1
  mkdir -p "$_IA_PENDING_PROPOSAL_DIR"
  local new_round=$(( fm_round + 1 ))
  local new_proposal="${_IA_PENDING_PROPOSAL_DIR}/${fm_id}.md"
  local iso
  iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local orig_content
  orig_content="$(cat "$superseded" 2>/dev/null || true)"

  {
    printf -- '---\nid: %s\nsource: %s\ntrust_tier: %s\nuser_id: %s\ncreated_at: %s\nstate: pending-proposal\nround: %d\ncontent_hash: %s\n---\n\n' \
      "$fm_id" "$fm_source" "$fm_tier" "$user_id" "$iso" "$new_round" "$fm_hash"
    printf '<<<UNTRUSTED_PROPOSAL tier=%s>>>\n' "$fm_tier"
    printf '%s\n\n' "$orig_content"
    printf '## User-Change (Round %d)\n%s\n' "$new_round" "$new_text"
    printf '<<<END_UNTRUSTED_PROPOSAL>>>\n'
  } > "$new_proposal"

  # Spawn intake-council (detached) if script available
  if [ -f "$_IA_INTAKE_COUNCIL_SH" ]; then
    nohup bash "$_IA_INTAKE_COUNCIL_SH" "$new_proposal" \
      >/dev/null 2>&1 &
  fi

  _ia_audit "intake-actions" "intake_user_change" "$fm_id" \
    "user=${user_id} round=${new_round}"
  _ia_audit "intake-actions" "intake_round_advanced" "$fm_id" \
    "round=${new_round}"

  printf 'changed: %s (round %d)\n' "$fm_id" "$new_round"
  return 0
}
