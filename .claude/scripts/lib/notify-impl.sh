#!/usr/bin/env bash
# notify-impl.sh — P0-7 Notification-Wrapper Implementation
# Aufgerufen via notify.sh-Shim. Nicht auf der Linter-Whitelist für notify.sh.
#
# Usage:
#   notify-impl.sh <severity> <topic> <title> <body> [actions_json]
#   notify-impl.sh <title> [<body> [<kind>]]                          # legacy back-compat

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

ENV_FILE="$REPO_ROOT/.env.headless"
if [ -z "${NTFY_TOPIC:-}" ] && [ -f "$ENV_FILE" ]; then
  set -a; . "$ENV_FILE"; set +a
fi

NOTIF_DIR="$REPO_ROOT/.claude/overseer/notifications"
SENT_LOG="$NOTIF_DIR/sent.jsonl"
QUEUED_LOG="$NOTIF_DIR/queued.jsonl"
DEDUP_LOG="$NOTIF_DIR/dedup.jsonl"
mkdir -p "$NOTIF_DIR"

DEDUP_TTL="${NOTIFY_DEDUP_TTL:-14400}"
QH_START="${QUIET_HOURS_START:-22}"
QH_END="${QUIET_HOURS_END:-8}"

_now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
_now_epoch() { date +%s; }
_current_hour() {
  if [ -n "${NOTIFY_MOCK_HOUR:-}" ]; then echo "$NOTIFY_MOCK_HOUR"
  else date +%H | sed 's/^0//'; fi
}
_in_quiet_hours() {
  local h; h=$(_current_hour)
  if [ "$QH_START" -le "$QH_END" ]; then
    [ "$h" -ge "$QH_START" ] && [ "$h" -lt "$QH_END" ]
  else
    [ "$h" -ge "$QH_START" ] || [ "$h" -lt "$QH_END" ]
  fi
}
_sha256() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  else sha256sum | awk '{print $1}'; fi
}
_truncate() {
  local s="$1" max="$2"
  if [ "${#s}" -gt "$max" ]; then printf '%s...' "${s:0:$((max-3))}"
  else printf '%s' "$s"; fi
}
_jq_str() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

make_action_buttons() {
  python3 - "$@" <<'PYEOF'
import json, sys
out = []
for arg in sys.argv[1:]:
    if ':' not in arg: continue
    label, url = arg.split(':', 1)
    out.append({"action": "http", "label": label.strip(), "url": url.strip()})
print(json.dumps(out))
PYEOF
}

if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  return 0 2>/dev/null || true
fi

_is_severity() { case "$1" in critical|info|noise) return 0 ;; *) return 1 ;; esac; }

if [ $# -ge 4 ] && _is_severity "${1:-}"; then
  SEVERITY="$1"; TOPIC="$2"; TITLE="$3"; BODY="$4"; ACTIONS_JSON="${5:-}"
else
  echo "[notify-impl] legacy invocation detected — please update caller to severity-routing" >&2
  TITLE="${1:-Claude}"; BODY="${2:-}"
  legacy_kind="${3:-info}"
  case "$legacy_kind" in
    failure) SEVERITY="critical" ;;
    *) SEVERITY="info" ;;
  esac
  TOPIC="${NTFY_TOPIC:-claude-code}"; ACTIONS_JSON=""
fi

TITLE="$(_truncate "$TITLE" 50)"
BODY="$(_truncate "$BODY" 200)"

case "$SEVERITY" in
  critical) PRIO=5 ;;
  info)     PRIO=3 ;;
  noise)
    echo "[notify-impl] noise: $TITLE — $BODY" >&2
    AUDIT_LIB="$REPO_ROOT/.claude/scripts/lib/audit.sh"
    if [ -r "$AUDIT_LIB" ]; then
      . "$AUDIT_LIB" 2>/dev/null || true
      command -v audit_record >/dev/null 2>&1 \
        && audit_record notify noise "$TOPIC" "$TITLE: $BODY" 2>/dev/null || true
    fi
    exit 0 ;;
  *) echo "[notify-impl] unknown severity: $SEVERITY" >&2; exit 2 ;;
esac

if [ "$SEVERITY" = "info" ] && _in_quiet_hours; then
  printf '{"ts":"%s","severity":"info","topic":"%s","title":%s,"body":%s,"actions":%s}\n' \
    "$(_now_iso)" "$TOPIC" \
    "$(printf '%s' "$TITLE" | _jq_str)" \
    "$(printf '%s' "$BODY"  | _jq_str)" \
    "${ACTIONS_JSON:-null}" >> "$QUEUED_LOG"
  AUDIT_LIB="$REPO_ROOT/.claude/scripts/lib/audit.sh"
  if [ -r "$AUDIT_LIB" ]; then
    . "$AUDIT_LIB" 2>/dev/null || true
    command -v audit_record >/dev/null 2>&1 \
      && audit_record notify queue_quiet_hours "$TOPIC" "$TITLE: $BODY" 2>/dev/null || true
  fi
  echo "[notify-impl] queued (quiet hours): $TITLE" >&2
  exit 0
fi

if [ "$SEVERITY" = "info" ]; then
  hash="$(printf '%s|%s|%s' "$TOPIC" "$TITLE" "$BODY" | _sha256)"
  now_epoch=$(_now_epoch)
  if [ -f "$DEDUP_LOG" ]; then
    last_ts=$(python3 - "$DEDUP_LOG" "$hash" <<'PYEOF'
import json, sys
path, h = sys.argv[1], sys.argv[2]
last = 0
try:
    with open(path) as f:
        for line in f:
            try:
                d = json.loads(line)
                if d.get("hash") == h:
                    last = max(last, int(d.get("last_sent_ts", 0)))
            except Exception: pass
except Exception: pass
print(last)
PYEOF
)
    if [ -n "$last_ts" ] && [ "$last_ts" -gt 0 ] \
       && [ $((now_epoch - last_ts)) -lt "$DEDUP_TTL" ]; then
      echo "[notify-impl] dedup skip: $TITLE" >&2
      exit 0
    fi
  fi
  printf '{"hash":"%s","last_sent_ts":%d}\n' "$hash" "$now_epoch" >> "$DEDUP_LOG"
fi

AUDIT_LIB="$REPO_ROOT/.claude/scripts/lib/audit.sh"
if [ -r "$AUDIT_LIB" ]; then
  . "$AUDIT_LIB" 2>/dev/null || true
  command -v audit_record >/dev/null 2>&1 \
    && audit_record notify "$SEVERITY" "$TOPIC" "$TITLE: $BODY" 2>/dev/null || true
fi

if [ "${NOTIFY_DRY_RUN:-0}" = "1" ]; then
  printf '{"ts":"%s","dry_run":true,"severity":"%s","topic":"%s","title":%s,"body":%s,"priority":%d,"actions":%s}\n' \
    "$(_now_iso)" "$SEVERITY" "$TOPIC" \
    "$(printf '%s' "$TITLE" | _jq_str)" \
    "$(printf '%s' "$BODY"  | _jq_str)" \
    "$PRIO" "${ACTIONS_JSON:-null}" >> "$SENT_LOG"
  exit 0
fi

if command -v osascript >/dev/null 2>&1; then
  SAFE_TITLE="$(printf '%s' "$TITLE" | sed 's/"/\\"/g')"
  SAFE_BODY="$(printf '%s' "$BODY"  | sed 's/"/\\"/g')"
  case "$SEVERITY" in
    critical) SOUND="Basso" ;;
    *)        SOUND="Pop" ;;
  esac
  osascript -e "display notification \"$SAFE_BODY\" with title \"$SAFE_TITLE\" sound name \"$SOUND\"" 2>/dev/null || true
fi

if [ -n "${TOPIC:-}" ]; then
  curl_args=( -fsSL --max-time 10 -H "Title: $TITLE" -H "Priority: $PRIO" -H "Tags: $SEVERITY" )
  if [ -n "$ACTIONS_JSON" ] && [ "$ACTIONS_JSON" != "null" ]; then
    curl_args+=( -H "Actions: $ACTIONS_JSON" )
  fi
  curl_args+=( -d "$BODY" "https://ntfy.sh/$TOPIC" )
  if ! curl "${curl_args[@]}" >/dev/null 2>&1; then
    echo "[notify-impl] curl failed (graceful)" >&2
  fi
fi

printf '{"ts":"%s","severity":"%s","topic":"%s","title":%s,"body":%s,"priority":%d,"actions":%s}\n' \
  "$(_now_iso)" "$SEVERITY" "$TOPIC" \
  "$(printf '%s' "$TITLE" | _jq_str)" \
  "$(printf '%s' "$BODY"  | _jq_str)" \
  "$PRIO" "${ACTIONS_JSON:-null}" >> "$SENT_LOG"

exit 0
