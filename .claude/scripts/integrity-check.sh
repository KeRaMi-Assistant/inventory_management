#!/usr/bin/env bash
# Out-of-process Integrity-Checker für Self-Mod-Blocklist.
#
# Logik:
#   1. Manifest lesen (.claude/integrity/manifest.sha256).
#   2. Signatur-Zeile (`# signature: <hex>`) verifizieren — Mismatch → PANIC
#      (auch wenn Hashes "passen", weil ein Angreifer ohne Secret die
#      Signatur nicht regenerieren kann).
#   3. Aktuelle Hashes vergleichen.
#   4. Bei Diff:
#      - Gültiger signierter User-Session-Marker → akzeptieren, Manifest
#        regenerieren.
#      - sonst → PANIC: kritische Notification, .claude/overseer/PANIC
#        Marker schreiben, Audit-Eintrag.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/.claude/scripts/lib/self-mod-blocklist.sh"
MANIFEST="$ROOT/.claude/integrity/manifest.sha256"
SESSION_MARKER="$ROOT/.claude/.user-session-active"
PANIC_DIR="$ROOT/.claude/overseer"
PANIC_MARKER="$PANIC_DIR/PANIC"

if [ -r "$LIB" ]; then
  # shellcheck disable=SC1090
  SELF_MOD_REPO_ROOT="$ROOT" . "$LIB"
fi

cd "$ROOT"

if [ ! -f "$MANIFEST" ]; then
  echo "integrity-check: no manifest at $MANIFEST — run integrity-manifest-build.sh first" >&2
  exit 0  # not fatal — first-run case
fi

panic() {
  local reason="$1"
  local drift_msg="${2:-}"
  mkdir -p "$PANIC_DIR"
  {
    echo "PANIC at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Manifest: $MANIFEST"
    echo "Reason: $reason"
    if [ -n "$drift_msg" ]; then
      echo "Drift:"
      echo "$drift_msg"
    fi
  } > "$PANIC_MARKER"
  if [ -x "$ROOT/.claude/scripts/audit-record.sh" ]; then
    "$ROOT/.claude/scripts/audit-record.sh" \
      "integrity-check" "PANIC" "$MANIFEST" "$reason" \
      >/dev/null 2>&1 || true
  fi
  if [ -x "$ROOT/.claude/scripts/notify.sh" ]; then
    "$ROOT/.claude/scripts/notify.sh" \
      "PANIC: Self-Mod-Blocklist tampered" \
      "$reason — see $PANIC_MARKER" \
      "failure" >/dev/null 2>&1 || true
  fi
  echo "PANIC: $reason — $PANIC_MARKER" >&2
  exit 3
}

# --- 1) Verify signature ----------------------------------------------------
secret_file="${CLAUDE_SESSION_SECRET_FILE:-$HOME/.claude/inventory-session-secret}"
sig_check_result="$(/usr/bin/python3 - "$MANIFEST" "$secret_file" <<'PYEOF' 2>&1 || true
import sys, hashlib, os
manifest_path, secret_path = sys.argv[1], sys.argv[2]
try:
    with open(manifest_path, 'rb') as f:
        data = f.read()
except Exception as e:
    print(f"ERROR: cannot read manifest: {e}")
    sys.exit(2)

# Find last "# signature: " line
lines = data.split(b'\n')
sig_line = None
sig_idx = None
for i in range(len(lines) - 1, -1, -1):
    if lines[i].startswith(b'# signature: '):
        sig_line = lines[i].decode('utf-8', errors='replace')
        sig_idx = i
        break

if sig_line is None:
    print("MISSING_SIG")
    sys.exit(0)

provided_sig = sig_line.replace('# signature: ', '').strip()
# Reconstruct content without signature line
content_lines = lines[:sig_idx]
# Preserve trailing newlines structure: original had `... \n# signature: <h>\n`
# We hashed the tmp content (which ended in \n) + b'\n' + secret.
content = b'\n'.join(content_lines)
if content and not content.endswith(b'\n'):
    content += b''
# Add the trailing newline that was in tmp before signature was appended
if not content.endswith(b'\n'):
    content += b'\n'

if not os.path.isfile(secret_path) or not os.access(secret_path, os.R_OK):
    print("NO_SECRET")
    sys.exit(0)

with open(secret_path, 'r', encoding='utf-8') as f:
    secret = f.read().strip()

import hashlib
expected = hashlib.sha256(content + b'\n' + secret.encode('utf-8')).hexdigest()
if expected == provided_sig:
    print("OK")
else:
    print(f"MISMATCH:expected={expected[:16]}..,got={provided_sig[:16]}..")
PYEOF
)"

case "$sig_check_result" in
  OK)
    : # signature valid, continue
    ;;
  MISSING_SIG)
    # Old manifest pre-signing — accept but note it
    echo "integrity-check: warning — manifest has no signature line (legacy)" >&2
    ;;
  NO_SECRET)
    # Cannot verify without secret — skip signature check, proceed to hash check
    echo "integrity-check: warning — no secret-file, skipping signature verification" >&2
    ;;
  MISMATCH:*)
    panic "manifest signature mismatch ($sig_check_result)"
    ;;
  *)
    echo "integrity-check: signature verifier returned: $sig_check_result" >&2
    ;;
esac

# --- 2) Hash check via shasum -c -------------------------------------------
# Strip signature line for shasum -c (it doesn't understand `#` comments).
manifest_for_check="$(mktemp)"
trap 'rm -f "$manifest_for_check"' EXIT
grep -v '^# ' "$MANIFEST" > "$manifest_for_check" || true

shasum_out="$(shasum -a 256 -c -- "$manifest_for_check" 2>&1 || true)"
if ! printf '%s\n' "$shasum_out" | grep -qE ': FAILED|: No such file|: not found|did NOT match'; then
  exit 0
fi

# Mismatch — bestimme welche Dateien gedriftet sind
drift="$(printf '%s\n' "$shasum_out" | grep -E ': FAILED|: No such file|: not found|did NOT match' || true)"

# Accept drift only if a VALID signed session-marker exists.
if declare -f _is_session_marker_valid >/dev/null 2>&1 \
   && _is_session_marker_valid "$SESSION_MARKER"; then
  if [ -x "$ROOT/.claude/scripts/audit-record.sh" ]; then
    "$ROOT/.claude/scripts/audit-record.sh" \
      "${USER:-unknown}" "integrity-drift-accepted" "$MANIFEST" \
      "valid session-marker; regenerating manifest" >/dev/null 2>&1 || true
  fi
  bash "$ROOT/.claude/scripts/integrity-manifest-build.sh" >/dev/null
  exit 0
fi

panic "self-mod-blocklist hashes drifted without valid session-marker" "$drift"
