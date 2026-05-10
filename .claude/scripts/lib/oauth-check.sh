#!/usr/bin/env bash
# oauth-check.sh — Sourceable library for OAuth/CLI token health checks.
#
# Usage: source this file, then call:
#   check_gh_token           → echo JSON {"service":"gh","status":"ok|expiring|expired|not_authenticated"}
#   check_anthropic_token    → echo JSON {"service":"anthropic","status":"ok|expired|unreachable"}
#   check_supabase_cli       → echo JSON {"service":"supabase","status":"ok|missing|warning"}
#   oauth_check_all          → aggregates all, writes oauth-status.json, notifies on issues
#
# Exit codes from oauth_check_all:
#   0 = all ok
#   1 = one or more non-critical issues (gh/supabase expired/missing)
#   2 = anthropic expired (Overseer pause signal)
#
# Env overrides (for testing):
#   OAUTH_CHECK_GH_CMD       — override gh command path/name
#   OAUTH_CHECK_CLAUDE_CMD   — override claude command path/name
#   OAUTH_CHECK_SUPABASE_CMD — override supabase command path/name
#   OAUTH_CACHE_TTL          — seconds to cache anthropic probe result (default 3600 = 1h)
#   OAUTH_CLAUDE_TIMEOUT     — timeout for claude probe in seconds (default 30)
#   NOTIFY_DRY_RUN           — propagated to notify.sh

# Deliberately NO set -e — sourceable library.
set -uo pipefail

# ---------------------------------------------------------------------------
# Resolve REPO_ROOT (works whether sourced or executed directly)
# ---------------------------------------------------------------------------
_oauth_resolve_repo_root() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    printf '%s' "$CLAUDE_PROJECT_DIR"
    return
  fi
  # If sourced from a script, find repo root via git
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

_OAUTH_REPO_ROOT="$(_oauth_resolve_repo_root)"
_OAUTH_OVERSEER_DIR="$_OAUTH_REPO_ROOT/.claude/overseer"
_OAUTH_NOTIFY="$_OAUTH_REPO_ROOT/.claude/scripts/notify.sh"
_OAUTH_AUDIT_LIB="$_OAUTH_REPO_ROOT/.claude/scripts/lib/audit.sh"

# Load audit library if available
_oauth_audit_available=0
if [ -f "$_OAUTH_AUDIT_LIB" ]; then
  # shellcheck disable=SC1090
  . "$_OAUTH_AUDIT_LIB"
  _oauth_audit_available=1
fi

_oauth_audit() {
  local action="$1"
  local subject="${2:-oauth-check}"
  local reason="${3:-}"
  if [ "$_oauth_audit_available" -eq 1 ]; then
    audit_record "oauth-check" "$action" "$subject" "$reason" 2>/dev/null || true
  fi
}

_oauth_notify() {
  local severity="$1"
  local title="$2"
  local body="$3"
  if [ -f "$_OAUTH_NOTIFY" ]; then
    bash "$_OAUTH_NOTIFY" "$severity" "oauth-watch" "$title" "$body" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# check_gh_token
# ---------------------------------------------------------------------------
check_gh_token() {
  local _gh_cmd="${OAUTH_CHECK_GH_CMD:-gh}"

  # Step 1: check if gh is available
  if ! command -v "$_gh_cmd" >/dev/null 2>&1; then
    printf '{"service":"gh","status":"not_authenticated","detail":"gh not in PATH"}\n'
    return 0
  fi

  # Step 2: get auth status output
  local _status_out
  _status_out="$("$_gh_cmd" auth status --hostname github.com 2>&1)" || true

  # Step 3: check if not logged in at all
  if printf '%s' "$_status_out" | grep -qiE "(not logged|not authenticated|no credential|Token not found)"; then
    printf '{"service":"gh","status":"not_authenticated"}\n'
    return 0
  fi

  # Step 4: probe with gh api user to verify token is actually valid
  local _api_exit=0
  "$_gh_cmd" api user --silent 2>/dev/null || _api_exit=$?
  if [ "$_api_exit" -ne 0 ]; then
    printf '{"service":"gh","status":"expired"}\n'
    return 0
  fi

  # Step 5: check for explicit expiry info in status output
  # gh may show "Token expires: 2026-05-11 10:00:00 +0000 UTC" or similar
  # Detect "expires in Xh" or a date that's within 48h
  local _expiry_status="ok"

  # Check for "expires in" with hours <= 48
  if printf '%s' "$_status_out" | grep -qiE "expires? in [0-9]+ hour"; then
    local _hours
    _hours="$(printf '%s' "$_status_out" | grep -ioE "expires? in ([0-9]+) hour" | grep -oE "[0-9]+" | head -1)"
    if [ -n "$_hours" ] && [ "$_hours" -le 48 ]; then
      _expiry_status="expiring"
    fi
  fi

  # Check for "expires in X days" where X == 0 or 1
  if printf '%s' "$_status_out" | grep -qiE "expires? in [01] day"; then
    _expiry_status="expiring"
  fi

  # Check for "Token expires: <date>" — parse date if python3 available
  if [ "$_expiry_status" = "ok" ] && printf '%s' "$_status_out" | grep -qiE "Token expires:"; then
    _expiry_status="$(python3 - "$_status_out" <<'PYEOF'
import sys, re
from datetime import datetime, timezone, timedelta

text = sys.argv[1]
m = re.search(r'Token expires:\s+(.+)', text)
if not m:
    print("ok")
    sys.exit(0)
date_str = m.group(1).strip()

# Try common formats
for fmt in ('%Y-%m-%d %H:%M:%S %z', '%Y-%m-%dT%H:%M:%SZ', '%a %b %d %H:%M:%S %Y %z'):
    try:
        exp = datetime.strptime(date_str, fmt)
        now = datetime.now(timezone.utc)
        delta = exp - now
        if delta.total_seconds() < 0:
            print("expired")
        elif delta.total_seconds() < 48 * 3600:
            print("expiring")
        else:
            print("ok")
        sys.exit(0)
    except ValueError:
        pass
print("ok")
PYEOF
2>/dev/null || echo "ok")"
  fi

  printf '{"service":"gh","status":"%s"}\n' "$_expiry_status"
}

# ---------------------------------------------------------------------------
# check_anthropic_token
# ---------------------------------------------------------------------------
check_anthropic_token() {
  local _claude_cmd="${OAUTH_CHECK_CLAUDE_CMD:-claude}"
  local _cache_ttl="${OAUTH_CACHE_TTL:-3600}"
  local _probe_timeout="${OAUTH_CLAUDE_TIMEOUT:-30}"

  mkdir -p "$_OAUTH_OVERSEER_DIR"
  local _cache_ts_file="$_OAUTH_OVERSEER_DIR/.claude-token-check-ts"
  local _now_ts
  _now_ts="$(date -u +%s)"

  # --- Cache check ---
  if [ -f "$_cache_ts_file" ]; then
    local _cached_ts _cached_status
    _cached_ts="$(cut -d'|' -f1 "$_cache_ts_file" 2>/dev/null || echo 0)"
    _cached_status="$(cut -d'|' -f2 "$_cache_ts_file" 2>/dev/null || echo "")"
    local _age=$(( _now_ts - _cached_ts ))
    if [ "$_age" -lt "$_cache_ttl" ] && [ -n "$_cached_status" ]; then
      printf '{"service":"anthropic","status":"%s","cached":true}\n' "$_cached_status"
      return 0
    fi
  fi

  # --- Live probe ---
  if ! command -v "$_claude_cmd" >/dev/null 2>&1; then
    printf '{"service":"anthropic","status":"unreachable","detail":"claude not in PATH"}\n'
    return 0
  fi

  local _probe_out _probe_exit=0
  _probe_out="$(timeout "$_probe_timeout" "$_claude_cmd" --print -p "ping" 2>/dev/null)" || _probe_exit=$?

  local _result_status
  if [ "$_probe_exit" -eq 124 ]; then
    # timeout hit
    _result_status="unreachable"
  elif [ "$_probe_exit" -ne 0 ]; then
    _result_status="expired"
  elif [ -z "${_probe_out:-}" ]; then
    # exit 0 but empty output → treat as unreachable
    _result_status="unreachable"
  else
    _result_status="ok"
  fi

  # Write cache
  printf '%s|%s\n' "$_now_ts" "$_result_status" > "$_cache_ts_file"

  # Handle expired: write marker + audit + critical notify
  local _marker="$_OAUTH_OVERSEER_DIR/AUTH_EXPIRED"
  if [ "$_result_status" = "expired" ]; then
    touch "$_marker"
    _oauth_audit "auth_expired" "anthropic" "claude --print probe returned non-zero exit"
    _oauth_notify "critical" "Anthropic Token Expired" \
      "claude --print probe failed (exit $_probe_exit). Overseer should pause. Renew token."
  elif [ "$_result_status" = "unreachable" ]; then
    _oauth_audit "auth_unreachable" "anthropic" "claude --print probe timed out or returned empty"
    _oauth_notify "info" "Anthropic Token Unreachable" \
      "claude probe timed out or returned empty (exit $_probe_exit)."
  else
    # Recovered — remove marker if it exists
    if [ -f "$_marker" ]; then
      rm -f "$_marker"
      _oauth_audit "auth_recovered" "anthropic" "claude --print probe succeeded; AUTH_EXPIRED marker removed"
    fi
  fi

  printf '{"service":"anthropic","status":"%s"}\n' "$_result_status"
}

# ---------------------------------------------------------------------------
# check_supabase_cli
# ---------------------------------------------------------------------------
check_supabase_cli() {
  local _supabase_cmd="${OAUTH_CHECK_SUPABASE_CMD:-supabase}"

  # Step 1: existence check
  if ! command -v "$_supabase_cmd" >/dev/null 2>&1; then
    printf '{"service":"supabase","status":"missing","detail":"supabase not in PATH"}\n'
    return 0
  fi

  # Step 2: version check (basic sanity)
  local _ver_exit=0
  "$_supabase_cmd" --version >/dev/null 2>&1 || _ver_exit=$?
  if [ "$_ver_exit" -ne 0 ]; then
    printf '{"service":"supabase","status":"missing","detail":"supabase --version failed"}\n'
    return 0
  fi

  # Step 3: access-token mtime check
  local _token_file="$HOME/.supabase/access-token"
  if [ -f "$_token_file" ]; then
    local _mtime_age
    _mtime_age="$(python3 -c "
import os, time
mtime = os.path.getmtime('$_token_file')
age_days = (time.time() - mtime) / 86400
print(int(age_days))
" 2>/dev/null || echo 0)"
    if [ "$_mtime_age" -ge 30 ]; then
      printf '{"service":"supabase","status":"warning","detail":"access-token mtime %d days old"}\n' "$_mtime_age"
      return 0
    fi
  fi

  printf '{"service":"supabase","status":"ok"}\n'
}

# ---------------------------------------------------------------------------
# oauth_check_all
# ---------------------------------------------------------------------------
oauth_check_all() {
  mkdir -p "$_OAUTH_OVERSEER_DIR"

  local _ts
  _ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Run all checks
  local _gh_json _anthropic_json _supabase_json
  _gh_json="$(check_gh_token)"
  _anthropic_json="$(check_anthropic_token)"
  _supabase_json="$(check_supabase_cli)"

  # Parse statuses
  local _gh_status _anthropic_status _supabase_status
  _gh_status="$(printf '%s' "$_gh_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])" 2>/dev/null || echo "unknown")"
  _anthropic_status="$(printf '%s' "$_anthropic_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])" 2>/dev/null || echo "unknown")"
  _supabase_status="$(printf '%s' "$_supabase_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])" 2>/dev/null || echo "unknown")"

  # Write aggregate status file
  local _status_file="$_OAUTH_OVERSEER_DIR/oauth-status.json"
  python3 - "$_status_file" "$_ts" "$_gh_status" "$_anthropic_status" "$_supabase_status" <<'PYEOF'
import sys, json
f, ts, gh, anthropic, supabase = sys.argv[1:]
data = {
    "ts": ts,
    "gh": {"status": gh},
    "anthropic": {"status": anthropic},
    "supabase": {"status": supabase}
}
with open(f, 'w') as fh:
    json.dump(data, fh, indent=2)
    fh.write('\n')
PYEOF

  # Notifications and exit code determination
  local _exit_code=0
  local _has_warning=0

  # gh status handling
  case "$_gh_status" in
    expiring)
      _oauth_notify "info" "GitHub Token Expiring" \
        "gh token expires within 48h. Run: gh auth login"
      _oauth_audit "token_expiring" "gh" "gh token expiry < 48h"
      _has_warning=1
      ;;
    expired)
      _oauth_notify "info" "GitHub Token Expired" \
        "gh auth status shows token is expired/revoked. Run: gh auth login"
      _oauth_audit "token_expired" "gh" "gh api user probe failed"
      _has_warning=1
      ;;
    not_authenticated)
      _oauth_notify "info" "GitHub Not Authenticated" \
        "gh is not logged in. Run: gh auth login"
      _oauth_audit "not_authenticated" "gh" "gh auth status shows not logged in"
      _has_warning=1
      ;;
  esac

  # anthropic status — check_anthropic_token already handles marker + notify for expired/unreachable
  case "$_anthropic_status" in
    expired)
      _exit_code=2  # Pause signal for Overseer
      ;;
    unreachable)
      _has_warning=1
      ;;
  esac

  # supabase status handling
  case "$_supabase_status" in
    warning)
      _oauth_notify "info" "Supabase Token Stale" \
        "~/.supabase/access-token is >30 days old. Consider: supabase login"
      _oauth_audit "token_stale" "supabase" "access-token mtime > 30 days"
      _has_warning=1
      ;;
    missing)
      # Just a warning — workers may not need supabase CLI
      _oauth_audit "cli_missing" "supabase" "supabase binary not found in PATH"
      _has_warning=1
      ;;
  esac

  if [ "$_exit_code" -eq 0 ] && [ "$_has_warning" -eq 1 ]; then
    _exit_code=1
  fi

  return "$_exit_code"
}
