#!/usr/bin/env bash
# Erstellt/aktualisiert .claude/integrity/manifest.sha256.
# Hashed jeden Pfad in der Self-Mod-Blocklist (sofern existent).
# LaunchAgent-Plist-Globs werden NICHT in dieses Manifest geschrieben
# (außerhalb Repo, separate Behandlung).
#
# Auth-Mode (P0-Sec-Fix #2):
#   - Refused den Run, wenn HEADLESS_MODE=1 oder OVERSEER_WORKER_PID gesetzt
#     UND kein gültiger signierter User-Session-Marker existiert. Damit kann
#     ein Worker das Manifest nicht heimlich neu generieren.
#
# Manifest-Signing:
#   - Letzte Zeile des Manifests ist `# signature: <hex>` mit
#     sha256(content_ohne_signatur || \n || secret).
#   - integrity-check.sh verifiziert die Signatur out-of-band.
#
# Usage:
#   bash .claude/scripts/integrity-manifest-build.sh           # build
#   bash .claude/scripts/integrity-manifest-build.sh --check   # exit 0 if matches
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/.claude/scripts/lib/self-mod-blocklist.sh"

if [ ! -r "$LIB" ]; then
  echo "missing lib: $LIB" >&2
  exit 1
fi
# shellcheck disable=SC1090
SELF_MOD_REPO_ROOT="$ROOT" . "$LIB"

# --- Auth-Gate --------------------------------------------------------------
# Build is allowed if:
#   (a) Not running under HEADLESS_MODE / OVERSEER_WORKER_PID, OR
#   (b) Valid signed session-marker exists.
if [ "${HEADLESS_MODE:-0}" = "1" ] || [ -n "${OVERSEER_WORKER_PID:-}" ]; then
  if ! _is_session_marker_valid "$ROOT/.claude/.user-session-active"; then
    actor="${OVERSEER_AGENT:-${USER:-unknown}}"
    if [ -x "$ROOT/.claude/scripts/audit-record.sh" ]; then
      "$ROOT/.claude/scripts/audit-record.sh" \
        "$actor" "integrity-manifest-build-blocked" "$ROOT/.claude/integrity/manifest.sha256" \
        "build refused under HEADLESS_MODE without valid session-marker" \
        >/dev/null 2>&1 || true
    fi
    if [ -x "$ROOT/.claude/scripts/notify.sh" ]; then
      "$ROOT/.claude/scripts/notify.sh" \
        "Integrity-Manifest-Build blocked" \
        "Worker tried to rebuild manifest without valid user session." \
        "failure" >/dev/null 2>&1 || true
    fi
    echo "integrity-manifest-build: refused (no valid user-session-marker under HEADLESS_MODE)" >&2
    exit 3
  fi
fi

DST_DIR="$ROOT/.claude/integrity"
DST="$DST_DIR/manifest.sha256"
mkdir -p "$DST_DIR"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

cd "$ROOT"
for entry in "${SELF_MOD_BLOCKLIST[@]}"; do
  if [ -f "$entry" ]; then
    # `shasum -a 256` (macOS) und `sha256sum` (Linux) sind kompatibel mit
    # `shasum -c`. Wir benutzen shasum, weil immer auf macOS verfügbar.
    if command -v shasum >/dev/null 2>&1; then
      shasum -a 256 -- "$entry" >> "$tmp"
    else
      sha256sum -- "$entry" >> "$tmp"
    fi
  fi
done

# --- Append signature ------------------------------------------------------
# Compute sha256(content || secret). Secret-File MUST exist (created by
# session-start.sh on first run).
secret_file="${CLAUDE_SESSION_SECRET_FILE:-$HOME/.claude/inventory-session-secret}"
if [ ! -r "$secret_file" ]; then
  echo "integrity-manifest-build: missing secret-file ($secret_file) — run session-start.sh first" >&2
  exit 4
fi
sig="$(/usr/bin/python3 - "$tmp" "$secret_file" <<'PYEOF'
import sys, hashlib
content_path, secret_path = sys.argv[1], sys.argv[2]
with open(content_path, 'rb') as f:
    content = f.read()
with open(secret_path, 'r', encoding='utf-8') as f:
    secret = f.read().strip()
h = hashlib.sha256(content + b'\n' + secret.encode('utf-8')).hexdigest()
print(h)
PYEOF
)"
printf '# signature: %s\n' "$sig" >> "$tmp"

if [ "${1:-}" = "--check" ]; then
  if [ ! -f "$DST" ]; then
    echo "no manifest at $DST" >&2
    exit 2
  fi
  if diff -u "$DST" "$tmp" >/dev/null; then
    exit 0
  fi
  diff -u "$DST" "$tmp" || true
  exit 1
fi

mv -f "$tmp" "$DST"
trap - EXIT
echo "manifest written: $DST ($(wc -l < "$DST") lines incl signature)"

# Audit
if [ -x "$ROOT/.claude/scripts/audit-record.sh" ]; then
  "$ROOT/.claude/scripts/audit-record.sh" \
    "${USER:-unknown}" "integrity-manifest-build" "$DST" \
    "rebuilt manifest with signature" >/dev/null 2>&1 || true
fi
