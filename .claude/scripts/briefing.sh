#!/usr/bin/env bash
# briefing.sh — P3-9 Heartbeat-Briefing-Daemon (Daily)
#
# Usage:
#   briefing.sh [--once]     — Generate one briefing and exit (default for LaunchAgent)
#   briefing.sh --daemon     — Loop: generate, then sleep 86400, repeat
#   briefing.sh --dry-run    — Print briefing to stdout, do NOT write file or notify
#
# Output: .claude/audit/briefings/<YYYY-MM-DD>.md
# Sends push notification via notify.sh with top-3 highlights.
# Includes HMAC-rotated token for Telegram-Bridge (P2-2b).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# Bibliotheken laden
# shellcheck source=lib/cost-cap.sh
source "$SCRIPT_DIR/lib/cost-cap.sh"

NOTIFY_SH="$SCRIPT_DIR/notify.sh"

# ---------------------------------------------------------------------------
# Pfade (überschreibbar für Tests)
# ---------------------------------------------------------------------------
BRIEFING_DIR="${BRIEFING_DIR:-$REPO_ROOT/.claude/audit/briefings}"
AUDIT_DIR="${AUDIT_DIR:-$REPO_ROOT/.claude/audit}"
OVERSEER_DIR="${OVERSEER_DIR:-$REPO_ROOT/.claude/overseer}"
DISPUTES_DIR="${DISPUTES_DIR:-$REPO_ROOT/.claude/disputes}"
STAKEHOLDER_PROCESSED_DIR="${STAKEHOLDER_PROCESSED_DIR:-$REPO_ROOT/.claude/stakeholder/processed}"
NOTIF_DIR="${NOTIF_DIR:-$REPO_ROOT/.claude/overseer/notifications}"

HMAC_SECRET_FILE="${HMAC_SECRET_FILE:-$HOME/.claude/inventory-telegram-hmac-secret}"

# ---------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------
log()  { printf '[briefing] %s\n' "$*" >&2; }
die()  { printf '[briefing] ERROR: %s\n' "$*" >&2; exit 1; }

_now_date() {
  if [ -n "${BRIEFING_MOCK_DATE:-}" ]; then
    printf '%s' "$BRIEFING_MOCK_DATE"
  else
    date -u +%Y-%m-%d
  fi
}

_truncate() {
  local s="$1" max="$2"
  if [ "${#s}" -gt "$max" ]; then printf '%s...' "${s:0:$((max-3))}"
  else printf '%s' "$s"; fi
}

# ---------------------------------------------------------------------------
# Cost-Summary (today, yesterday, week)
# ---------------------------------------------------------------------------
_cost_summary() {
  python3 - "$(_cost_cap_ledger_dir)/cost-ledger.jsonl" "${BRIEFING_MOCK_DATE:-}" <<'PYEOF'
import sys, json, os
from datetime import datetime, timezone, timedelta

ledger_file = sys.argv[1]
mock_date = sys.argv[2] if len(sys.argv) > 2 else ''
if mock_date:
    try:
        now = datetime.strptime(mock_date, '%Y-%m-%d').replace(tzinfo=timezone.utc)
    except ValueError:
        now = datetime.now(timezone.utc)
else:
    now = datetime.now(timezone.utc)
today_str = now.strftime('%Y-%m-%d')
yesterday_str = (now - timedelta(days=1)).strftime('%Y-%m-%d')
cutoff_str = (now - timedelta(days=6)).strftime('%Y-%m-%d')

today_usd = 0.0
yesterday_usd = 0.0
week_usd = 0.0

if os.path.exists(ledger_file):
    try:
        with open(ledger_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    ts = entry.get('ts', '')
                    date_str = ts[:10]
                    usd = float(entry.get('usd', 0))
                    if date_str == today_str:
                        today_usd += usd
                    if date_str == yesterday_str:
                        yesterday_usd += usd
                    if date_str >= cutoff_str:
                        week_usd += usd
                except (json.JSONDecodeError, ValueError):
                    continue
    except FileNotFoundError:
        pass

print(f'today={today_usd:.2f} yesterday={yesterday_usd:.2f} week={week_usd:.2f}')
PYEOF
}

# ---------------------------------------------------------------------------
# Workers (24h)
# ---------------------------------------------------------------------------
_workers_section() {
  local since_24h
  since_24h="$(date -u -v-24H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u --date='24 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"

  # PRs merged
  local prs_merged=""
  if git -C "$REPO_ROOT" log --since="24 hours ago" --merges --first-parent main \
       --pretty=format:"%s" 2>/dev/null | head -20 > /tmp/briefing_prs_$$; then
    prs_merged="$(cat /tmp/briefing_prs_$$)"
  fi
  rm -f /tmp/briefing_prs_$$
  local pr_count=0
  [ -n "$prs_merged" ] && pr_count="$(printf '%s\n' "$prs_merged" | grep -c . || echo 0)"

  # Workers failed
  local failed_count=0
  local failed_dir="$OVERSEER_DIR/failed"
  if [ -d "$failed_dir" ]; then
    failed_count="$(find "$failed_dir" -maxdepth 1 -type f -newer "$(_mtime_cutoff_file 86400)" 2>/dev/null | wc -l | tr -d ' ')"
  fi

  # Items done
  local done_count=0
  local done_dir="$OVERSEER_DIR/done"
  if [ -d "$done_dir" ]; then
    done_count="$(find "$done_dir" -maxdepth 1 -type f -newer "$(_mtime_cutoff_file 86400)" 2>/dev/null | wc -l | tr -d ' ')"
  fi

  printf '%s\n\n' "## Workers (24h)"
  printf -- '- PRs merged: **%d**\n' "$pr_count"
  if [ -n "$prs_merged" ]; then
    printf '%s\n' "$prs_merged" | head -10 | while IFS= read -r pr_line; do
      printf '  - %s\n' "$pr_line"
    done
  fi
  printf -- '- Workers failed: **%d**\n' "$failed_count"
  printf -- '- Items done: **%d**\n' "$done_count"
  printf '\n'
}

# Helper: create a temp file with mtime = now - <seconds>
_mtime_cutoff_file() {
  local seconds="$1"
  local tmpf
  tmpf="$(mktemp)"
  # Set mtime to now - seconds (macOS: -v, GNU: --date)
  if touch -t "$(date -u -v-"${seconds}"S +%Y%m%d%H%M.%S 2>/dev/null || date -u --date="${seconds} seconds ago" +%Y%m%d%H%M.%S 2>/dev/null)" "$tmpf" 2>/dev/null; then
    :
  fi
  printf '%s' "$tmpf"
  # cleanup via caller
}

# ---------------------------------------------------------------------------
# Disputs (24h)
# ---------------------------------------------------------------------------
_disputs_section() {
  local decided=0
  local unresolved_count=0

  local cutoff_ts
  cutoff_ts="$(date -u -v-24H +%s 2>/dev/null || date -u --date='24 hours ago' +%s 2>/dev/null || date -u +%s)"

  if [ -d "$DISPUTES_DIR" ]; then
    # Decided: scan verdict.md files modified in last 24h
    while IFS= read -r verdict_file; do
      local mtime
      mtime="$(stat -f %m "$verdict_file" 2>/dev/null || stat -c %Y "$verdict_file" 2>/dev/null || echo 0)"
      if [ "$mtime" -ge "$cutoff_ts" ] 2>/dev/null; then
        decided=$((decided + 1))
      fi
    done < <(find "$DISPUTES_DIR" -name "verdict.md" 2>/dev/null)

    # Unresolved
    local unresolved_dir="$DISPUTES_DIR/unresolved"
    if [ -d "$unresolved_dir" ]; then
      unresolved_count="$(find "$unresolved_dir" -maxdepth 1 \( -type f -o -type d \) ! -path "$unresolved_dir" 2>/dev/null | wc -l | tr -d ' ')"
    fi
  fi

  printf '%s\n\n' "## Disputs (24h)"
  printf -- '- Decided: **%d**\n' "$decided"
  printf -- '- Unresolved: **%d**\n' "$unresolved_count"
  printf '\n'
}

# ---------------------------------------------------------------------------
# Stakeholder (24h)
# ---------------------------------------------------------------------------
_stakeholder_section() {
  local tier1=0 tier2=0 quarantined=0
  local cutoff_ts
  cutoff_ts="$(date -u -v-24H +%s 2>/dev/null || date -u --date='24 hours ago' +%s 2>/dev/null || date -u +%s)"

  if [ -d "$STAKEHOLDER_PROCESSED_DIR" ]; then
    while IFS= read -r f; do
      local mtime
      mtime="$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)"
      if [ "$mtime" -ge "$cutoff_ts" ] 2>/dev/null; then
        local fname
        fname="$(basename "$f")"
        case "$fname" in
          *tier-1*|*tier1*) tier1=$((tier1 + 1)) ;;
          *tier-2*|*tier2*) tier2=$((tier2 + 1)) ;;
          *quarantine*|*quarantined*) quarantined=$((quarantined + 1)) ;;
          *) tier2=$((tier2 + 1)) ;;
        esac
      fi
    done < <(find "$STAKEHOLDER_PROCESSED_DIR" -maxdepth 2 -type f 2>/dev/null)
  fi

  # Also check quarantine dir if exists
  local quarantine_dir
  quarantine_dir="$(dirname "$STAKEHOLDER_PROCESSED_DIR")/quarantine"
  if [ -d "$quarantine_dir" ]; then
    while IFS= read -r f; do
      local mtime
      mtime="$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)"
      if [ "$mtime" -ge "$cutoff_ts" ] 2>/dev/null; then
        quarantined=$((quarantined + 1))
      fi
    done < <(find "$quarantine_dir" -maxdepth 1 -type f 2>/dev/null)
  fi

  printf '%s\n\n' "## Stakeholder (24h)"
  printf -- '- Tier-1 items received: **%d**\n' "$tier1"
  printf -- '- Tier-2 items received: **%d**\n' "$tier2"
  printf -- '- Quarantined: **%d**\n' "$quarantined"
  printf '\n'
}

# ---------------------------------------------------------------------------
# Audit-Highlights (last 5 critical events)
# ---------------------------------------------------------------------------
_audit_highlights_section() {
  local highlights=()

  # Scan today + yesterday audit files for critical keywords
  local today_date="${1:-$(date -u +%Y-%m-%d)}"
  local yesterday_date
  yesterday_date="$(date -u -v-1d +%Y-%m-%d 2>/dev/null || date -u --date='1 day ago' +%Y-%m-%d 2>/dev/null || echo "$today_date")"

  local found=()
  for audit_file in "$AUDIT_DIR/$today_date.md" "$AUDIT_DIR/$yesterday_date.md"; do
    if [ -f "$audit_file" ]; then
      while IFS= read -r line; do
        case "$line" in
          *PANIC*|*SELF_MOD*|*COST_CAP_REACHED*|*critical*|*HARD-STOP*)
            found+=("$line")
            ;;
        esac
      done < "$audit_file"
    fi
  done

  printf '## Audit-Highlights (last 5 critical events)\n\n'
  if [ ${#found[@]} -eq 0 ]; then
    printf '_No critical audit events in last 24h._\n'
  else
    local count=0
    for evt in "${found[@]}"; do
      [ $count -ge 5 ] && break
      printf '- %s\n' "$(_truncate "$evt" 120)"
      count=$((count + 1))
    done
  fi
  printf '\n'
}

# ---------------------------------------------------------------------------
# Top-3-Highlights (intelligent ranking)
# ---------------------------------------------------------------------------
_top3_highlights() {
  # Parse git log: feat: first, then fix:, then routine
  local feat_prs=() fix_prs=() other_prs=()

  while IFS= read -r git_line; do
    [ -z "$git_line" ] && continue
    case "$git_line" in
      feat:*) feat_prs+=("$git_line") ;;
      fix:*)  fix_prs+=("$git_line") ;;
      *)      other_prs+=("$git_line") ;;
    esac
  done < <(git -C "$REPO_ROOT" log --since="24 hours ago" --merges --first-parent main \
              --pretty=format:"%s" 2>/dev/null | head -20)

  local highlights=()
  local _all_prs=()
  # Safely merge arrays (guard against empty)
  [ ${#feat_prs[@]} -gt 0 ]  && _all_prs+=("${feat_prs[@]}")
  [ ${#fix_prs[@]} -gt 0 ]   && _all_prs+=("${fix_prs[@]}")
  [ ${#other_prs[@]} -gt 0 ] && _all_prs+=("${other_prs[@]}")

  for p in "${_all_prs[@]+${_all_prs[@]}}"; do
    [ ${#highlights[@]} -ge 3 ] && break
    highlights+=("$p")
  done

  # If nothing from git, try done/ dir
  if [ ${#highlights[@]} -eq 0 ] && [ -d "$OVERSEER_DIR/done" ]; then
    local _cutoff_f
    _cutoff_f="$(_mtime_cutoff_file 86400)"
    while IFS= read -r f; do
      [ ${#highlights[@]} -ge 3 ] && break
      highlights+=("$(basename "$f")")
    done < <(find "$OVERSEER_DIR/done" -maxdepth 1 -type f -newer "$_cutoff_f" 2>/dev/null | sort -r | head -3)
    # shellcheck disable=SC2064
    trap "rm -f '$_cutoff_f'" RETURN 2>/dev/null || true
  fi

  printf '%s\n\n' "## Top-3-Highlights"
  if [ ${#highlights[@]} -eq 0 ]; then
    printf '%s\n' "_No notable activity in last 24h._"
  else
    local i=1
    for h in "${highlights[@]}"; do
      printf '%d. %s\n' "$i" "$(_truncate "$h" 120)"
      i=$((i + 1))
    done
  fi
  printf '\n'

  # Write compact summary for notification body
  local summary=""
  if [ ${#highlights[@]} -gt 0 ]; then
    for h in "${highlights[@]}"; do
      if [ -z "$summary" ]; then
        summary="$(_truncate "$h" 60)"
      else
        summary="$summary | $(_truncate "$h" 40)"
      fi
    done
  fi
  [ -z "$summary" ] && summary="No notable activity"
  # Write to a temp file keyed by shell PID ($$ == parent even in subshell in bash)
  printf '%s' "$summary" > "/tmp/briefing_top3_$$"
}

# ---------------------------------------------------------------------------
# HMAC-Token Generation
# ---------------------------------------------------------------------------
_ensure_hmac_secret() {
  local secret_dir
  secret_dir="$(dirname "$HMAC_SECRET_FILE")"
  mkdir -p "$secret_dir"

  if [ ! -f "$HMAC_SECRET_FILE" ]; then
    # Generate 32 random bytes as hex
    if command -v openssl >/dev/null 2>&1; then
      openssl rand -hex 32 > "$HMAC_SECRET_FILE"
    else
      python3 -c "import secrets; print(secrets.token_hex(32))" > "$HMAC_SECRET_FILE"
    fi
    chmod 0400 "$HMAC_SECRET_FILE"
    log "Created new HMAC secret at $HMAC_SECRET_FILE"
  fi
  cat "$HMAC_SECRET_FILE"
}

_compute_hmac_token() {
  local secret="$1"
  local briefing_id="$2"

  # Token = sha256(secret + briefing_id)
  printf '%s%s' "$secret" "$briefing_id" | \
    python3 -c "import sys, hashlib; data = sys.stdin.read(); print(hashlib.sha256(data.encode('utf-8')).hexdigest())"
}

# ---------------------------------------------------------------------------
# Generate Briefing
# ---------------------------------------------------------------------------
generate_briefing() {
  local today
  today="$(_now_date)"

  log "Generating briefing for $today ..."

  # Cost summary
  local cost_line
  cost_line="$(_cost_summary)"
  local cost_today cost_yesterday cost_week
  cost_today="$(printf '%s' "$cost_line" | grep -oE 'today=[0-9.]+' | cut -d= -f2)"
  cost_yesterday="$(printf '%s' "$cost_line" | grep -oE 'yesterday=[0-9.]+' | cut -d= -f2)"
  cost_week="$(printf '%s' "$cost_line" | grep -oE 'week=[0-9.]+' | cut -d= -f2)"
  cost_today="${cost_today:-0.00}"
  cost_yesterday="${cost_yesterday:-0.00}"
  cost_week="${cost_week:-0.00}"

  # Build briefing content
  local content=""

  # Header
  content+="# Daily Briefing — $today"$'\n\n'
  content+="## Cost Summary"$'\n\n'
  content+="| Period    | USD    |"$'\n'
  content+="|-----------|--------|"$'\n'
  content+="| Today     | \$$cost_today |"$'\n'
  content+="| Yesterday | \$$cost_yesterday |"$'\n'
  content+="| This week | \$$cost_week |"$'\n\n'

  # Workers
  local workers_section
  workers_section="$(_workers_section)"
  content+="$workers_section"

  # Disputs
  local disputs_section
  disputs_section="$(_disputs_section)"
  content+="$disputs_section"

  # Stakeholder
  local stakeholder_section
  stakeholder_section="$(_stakeholder_section)"
  content+="$stakeholder_section"

  # Audit Highlights
  local audit_section
  audit_section="$(_audit_highlights_section "$today")"
  content+="$audit_section"

  # Top-3
  local top3_section
  top3_section="$(_top3_highlights)"
  content+="$top3_section"

  # HMAC Token
  local hmac_secret hmac_token
  hmac_secret="$(_ensure_hmac_secret)"
  hmac_token="$(_compute_hmac_token "$hmac_secret" "$today")"

  content+="<!-- telegram-token: $hmac_token -->"$'\n\n'
  content+="## Telegram-Bot-Token (rotates daily)"$'\n\n'
  content+="<!-- briefing_id: $today | token: $hmac_token -->"$'\n'

  printf '%s' "$content"
}

# ---------------------------------------------------------------------------
# Run (once)
# ---------------------------------------------------------------------------
run_once() {
  local dry_run="${1:-0}"
  local today
  today="$(_now_date)"

  local briefing_content
  briefing_content="$(generate_briefing)"

  if [ "$dry_run" = "1" ]; then
    printf '%s\n' "$briefing_content"
    log "dry-run: no file written, no notification sent"
    return 0
  fi

  # Write file
  mkdir -p "$BRIEFING_DIR"
  local briefing_file="$BRIEFING_DIR/$today.md"
  printf '%s\n' "$briefing_content" > "$briefing_file"
  log "Briefing written → $briefing_file"

  # Read top-3 summary (written by _top3_highlights)
  local top3_body="Daily briefing ready"
  if [ -f "/tmp/briefing_top3_$$" ]; then
    top3_body="$(cat /tmp/briefing_top3_$$)"
    rm -f "/tmp/briefing_top3_$$"
  fi

  # Truncate body to 200 chars
  top3_body="$(_truncate "$top3_body" 200)"

  # Send notification
  if [ -x "$NOTIFY_SH" ]; then
    local actions
    actions="$(REPO_ROOT="$REPO_ROOT" "$SCRIPT_DIR/lib/notify-impl.sh" 2>/dev/null || true)"
    # Build action buttons inline
    local action_json
    action_json="$(python3 -c "
import json
print(json.dumps([{\"action\": \"http\", \"label\": \"Show\", \"url\": \"file://$briefing_file\"}]))
" 2>/dev/null || echo '[]')"

    REPO_ROOT="$REPO_ROOT" "$NOTIFY_SH" info briefing \
      "Daily briefing ready" \
      "$top3_body" \
      "$action_json" 2>/dev/null || true
    log "Notification sent"
  fi

  # Audit record
  local audit_lib="$SCRIPT_DIR/lib/audit.sh"
  if [ -r "$audit_lib" ]; then
    # shellcheck disable=SC1090
    source "$audit_lib" 2>/dev/null || true
    if command -v audit_record >/dev/null 2>&1; then
      audit_record "briefing" "info" "BRIEFING_GENERATED" \
        "date=$today file=$briefing_file" 2>/dev/null || true
    fi
  fi
}

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
MODE="once"
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --once)    MODE="once" ;;
    --daemon)  MODE="daemon" ;;
    --dry-run) DRY_RUN=1 ;;
    *)
      printf 'Usage: %s [--once|--daemon|--dry-run]\n' "$(basename "$0")" >&2
      exit 1
      ;;
  esac
done

case "$MODE" in
  once)
    run_once "$DRY_RUN"
    ;;
  daemon)
    log "Starting daemon mode (sleep 86400 between runs)"
    while true; do
      run_once "$DRY_RUN"
      log "Next run in 86400s"
      sleep 86400
    done
    ;;
esac
