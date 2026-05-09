#!/usr/bin/env bash
# audit.sh — Sourceable library for append-only audit trail with hash-chain.
#
# Usage: source this file, then call:
#   audit_record <actor> <action> <subject> <reason>
#
# IMPORTANT: This file is in the Self-Mod-Blocklist — do NOT modify at runtime.
#
# Output: .claude/audit/YYYY-MM-DD.md (Markdown, append-only, 0444 after each append)
# Hash-chain: prev_hash = SHA256 of the previous full entry block (incl trailing newline)
#             entry_hash = SHA256 of ts|sha|actor|action|subject|prev_hash|reason_json

# Deliberately NO set -e here — this is a sourced library.
set -u

# ---------------------------------------------------------------------------
# audit_record <actor> <action> <subject> <reason>
# Writes one entry to .claude/audit/YYYY-MM-DD.md.
# reason may be multiline; it is JSON-encoded automatically.
# ---------------------------------------------------------------------------
audit_record() {
  local actor="${1:-unknown}"
  local action="${2:-unknown}"
  local subject="${3:-unknown}"
  local reason="${4:-}"

  # Validate: no newlines in single-line fields
  local _f
  for _f in "$actor" "$action" "$subject"; do
    case "$_f" in
      *$'\n'*)
        printf 'audit_record: ERROR: newline in field value is not allowed\n' >&2
        return 1
        ;;
    esac
  done

  # Resolve AUDIT_DIR
  local _audit_dir
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    _audit_dir="${CLAUDE_PROJECT_DIR}/.claude/audit"
  else
    local _repo_root
    _repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    _audit_dir="${_repo_root}/.claude/audit"
  fi
  mkdir -p "$_audit_dir"

  # Rate-limit: max 100 entries / minute (per process group). DoS-protection
  # against runaway workers spamming audit-record. State file holds:
  #   <minute_epoch> <count>
  # Atomic via flock.
  local _ratelimit_file="${_audit_dir}/.audit.ratelimit"
  local _ratelimit_lock="${_audit_dir}/.audit.ratelimit.lock"
  local _max_per_minute="${CLAUDE_AUDIT_MAX_PER_MINUTE:-100}"
  if ! python3 - "$_ratelimit_file" "$_ratelimit_lock" "$_max_per_minute" <<'PYEOF'
import sys, os, fcntl, time
state_file, lock_file, max_per_min = sys.argv[1], sys.argv[2], int(sys.argv[3])
now_min = int(time.time() // 60)
lock_fd = open(lock_file, 'w')
try:
    fcntl.flock(lock_fd, fcntl.LOCK_EX)
    cur_min, count = now_min, 0
    if os.path.exists(state_file):
        try:
            with open(state_file, 'r') as f:
                parts = f.read().split()
                if len(parts) == 2:
                    cur_min, count = int(parts[0]), int(parts[1])
        except Exception:
            pass
    if cur_min != now_min:
        cur_min, count = now_min, 0
    if count >= max_per_min:
        sys.exit(2)
    count += 1
    with open(state_file, 'w') as f:
        f.write(f"{cur_min} {count}\n")
    sys.exit(0)
finally:
    fcntl.flock(lock_fd, fcntl.LOCK_UN)
    lock_fd.close()
PYEOF
  then
    printf 'audit_record: rate limit exceeded (>%s/min) — entry dropped\n' \
      "$_max_per_minute" >&2
    # Mirror the drop event itself to syslog (best-effort) so out-of-band
    # observers see the DoS-attempt.
    if command -v logger >/dev/null 2>&1; then
      logger -t claude-audit "RATE_LIMIT_DROP actor=$actor action=$action subject=$subject" 2>/dev/null || true
    fi
    return 2
  fi

  local _lock_file="${_audit_dir}/.audit.lock"
  local _today
  _today="$(date -u +%Y-%m-%d)"
  local _audit_file="${_audit_dir}/${_today}.md"

  # Delegate the actual append (with locking) to python3 for portability.
  # python3 fcntl.flock is available on macOS and Linux.
  local _git_sha
  _git_sha="$(git -C "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}" rev-parse --short HEAD 2>/dev/null || echo "0000000")"

  local _ts
  _ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Capture entry_hash via temp file so we can mirror it to syslog after.
  local _entry_hash_file
  _entry_hash_file="$(mktemp)"

  python3 - "$_audit_file" "$_lock_file" "$_ts" "$_git_sha" "$actor" "$action" "$subject" "$reason" "$_entry_hash_file" <<'PYEOF'
import sys, os, json, hashlib, fcntl, stat

audit_file       = sys.argv[1]
lock_file        = sys.argv[2]
ts               = sys.argv[3]
git_sha          = sys.argv[4]
actor            = sys.argv[5]
action           = sys.argv[6]
subject          = sys.argv[7]
reason           = sys.argv[8]
entry_hash_out   = sys.argv[9]

def sha256(s: str) -> str:
    return hashlib.sha256(s.encode('utf-8')).hexdigest()

reason_json = json.dumps(reason)

# Acquire exclusive lock via fcntl (works on macOS + Linux)
lock_fd = open(lock_file, 'w')
try:
    fcntl.flock(lock_fd, fcntl.LOCK_EX)  # blocking, no timeout needed (fast op)

    # Compute prev_hash: SHA256 of current file content (empty → all-zeros)
    zero_hash = "0" * 64
    if os.path.exists(audit_file) and os.path.getsize(audit_file) > 0:
        # Temporarily make readable if needed (should already be readable)
        with open(audit_file, 'r', encoding='utf-8') as f:
            content = f.read()
        prev_hash = sha256(content)
    else:
        prev_hash = zero_hash

    # Compute entry_hash over deterministic concat
    entry_data = f"{ts}|{git_sha}|{actor}|{action}|{subject}|{prev_hash}|{reason_json}"
    entry_hash = sha256(entry_data)

    # Build entry block
    block = (
        f"---\n"
        f"ts: {ts}\n"
        f"sha: {git_sha}\n"
        f"actor: {actor}\n"
        f"action: {action}\n"
        f"subject: {subject}\n"
        f"prev_hash: {prev_hash}\n"
        f"entry_hash: {entry_hash}\n"
        f"reason: {reason_json}\n"
        f"---\n"
        f"\n"
    )

    # Make writable if currently 0444
    was_readonly = False
    was_uchg = False
    if os.path.exists(audit_file):
        current_mode = stat.S_IMODE(os.stat(audit_file).st_mode)
        if current_mode == 0o444:
            was_readonly = True
            # macOS: remove uchg flag if set
            os.system(f'chflags nouchg "{audit_file}" 2>/dev/null')
            os.chmod(audit_file, 0o644)

    # Append
    with open(audit_file, 'a', encoding='utf-8') as f:
        f.write(block)

    # Set 0444 (append-only protection)
    os.chmod(audit_file, 0o444)

    # macOS: attempt chflags uchg (optional, best-effort)
    os.system(f'chflags uchg "{audit_file}" 2>/dev/null')

    # Export entry_hash for caller (syslog mirror)
    try:
        with open(entry_hash_out, 'w') as f:
            f.write(entry_hash + '\n')
    except Exception:
        pass

finally:
    fcntl.flock(lock_fd, fcntl.LOCK_UN)
    lock_fd.close()

PYEOF

  # --- Syslog mirror (out-of-band audit) ---------------------------------
  # Each entry is mirrored to macOS/Linux syslog via `logger`. Workers
  # cannot rewrite/delete syslog without root, so this is an out-of-band
  # tamper-detector. audit-verify.sh cross-checks both stores.
  local _entry_hash=""
  if [ -s "$_entry_hash_file" ]; then
    _entry_hash="$(head -n 1 "$_entry_hash_file" | tr -d '[:space:]')"
  fi
  rm -f "$_entry_hash_file"

  if command -v logger >/dev/null 2>&1; then
    # Single-line, parseable: ts=... sha=... actor=... action=... subject=... entry_hash=...
    # No raw `reason` (may contain PII / multiline) — only its sha256.
    local _reason_sha
    _reason_sha="$(printf '%s' "$reason" | shasum -a 256 2>/dev/null | awk '{print $1}')"
    [ -z "$_reason_sha" ] && _reason_sha="-"
    logger -t claude-audit \
      "ts=$_ts sha=$_git_sha actor=$actor action=$action subject=$subject entry_hash=$_entry_hash reason_sha=$_reason_sha" \
      2>/dev/null || true
  fi
}
