#!/usr/bin/env bash
# live-status.sh — Schreibt eine human-readable Live-Status-File jede Minute.
# Zeigt:
#   - Timestamp + Uhrzeit + "letztes Update"
#   - Aktive Worker (PID, ElaPSED, claude-PID, model, budget)
#   - Worktree-Diff (wieviele Files geändert, Zeilen)
#   - Items in Inbox/In-Progress/Failed/Done
#   - Letzte 3 Audit-Events
#   - Status: WORKING|IDLE|FAILED|DONE
#
# Modes:
#   live-status.sh           — one-shot, schreibt nach LIVE_STATUS.md
#   live-status.sh --daemon  — loop alle 60s
#
# File: .claude/overseer/LIVE_STATUS.md (gitignored)

set -o pipefail
# (no -u — empty arrays trip ${arr[@]} under set -u on bash 3.2)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
STATUS_FILE="$REPO_ROOT/.claude/overseer/LIVE_STATUS.md"

write_status() {
  local now ts_unix
  now="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  ts_unix="$(date +%s)"

  # State counts
  local inbox_n in_progress_n failed_n done_n quarantine_n
  inbox_n=$(ls "$REPO_ROOT/.claude/overseer/inbox/"*.md 2>/dev/null | wc -l | tr -d ' ')
  in_progress_n=$(ls "$REPO_ROOT/.claude/overseer/in_progress/"*.md 2>/dev/null | wc -l | tr -d ' ')
  failed_n=$(ls "$REPO_ROOT/.claude/overseer/failed/"*.md 2>/dev/null | wc -l | tr -d ' ')
  done_n=$(ls "$REPO_ROOT/.claude/overseer/done/"*.md 2>/dev/null | wc -l | tr -d ' ')
  quarantine_n=$(ls "$REPO_ROOT/.claude/stakeholder/quarantine/"*.md 2>/dev/null | wc -l | tr -d ' ')

  # Active worker procs (FILTER: only our scripts, not macOS mdworker etc.)
  local worker_pids=()
  while IFS= read -r line; do
    pid=$(echo "$line" | awk '{print $1}')
    [ -n "$pid" ] && worker_pids+=("$pid")
  done < <(pgrep -f "scripts/worker\.sh" 2>/dev/null | head -10)

  # claude --print invoked BY worker.sh (real workers, not stray yota/intake calls)
  local claude_pids=()
  while IFS= read -r line; do
    pid=$(echo "$line" | awk '{print $1}')
    [ -n "$pid" ] && claude_pids+=("$pid")
  done < <(pgrep -f "claude --print.*--max-budget-usd" 2>/dev/null | head -10)

  # Also track overseer daemon
  local overseer_pids=()
  while IFS= read -r line; do
    pid=$(echo "$line" | awk '{print $1}')
    [ -n "$pid" ] && overseer_pids+=("$pid")
  done < <(pgrep -f "scripts/overseer\.sh" 2>/dev/null | head -3)

  # Overall status
  local status="IDLE"
  local status_emoji="💤"
  if [ "${#claude_pids[@]}" -gt 0 ] || [ "${#worker_pids[@]}" -gt 0 ]; then
    status="WORKING"
    status_emoji="🔨"
  elif [ -f "$REPO_ROOT/.claude/overseer/PANIC" ]; then
    status="PANIC"
    status_emoji="⛔"
  elif [ "$failed_n" -gt 0 ] && [ "$done_n" -eq 0 ] && [ "$in_progress_n" -eq 0 ]; then
    status="FAILED"
    status_emoji="❌"
  fi

  # Worktree-diff for active worker
  local diff_summary=""
  for wt in "$REPO_ROOT"/../inventory_management_worker_*; do
    [ -d "$wt" ] || continue
    local wt_name=$(basename "$wt" | sed 's/inventory_management_worker_//')
    local changed=$(cd "$wt" 2>/dev/null && git status --short 2>/dev/null | wc -l | tr -d ' ')
    local stat_out=$(cd "$wt" 2>/dev/null && git diff --shortstat 2>/dev/null)
    diff_summary="${diff_summary}
- \`${wt_name}\`: ${changed} files changed | ${stat_out:-no diff yet}"
  done
  [ -z "$diff_summary" ] && diff_summary="
- (no active worktrees)"

  # Latest run-log (smallest mtime in runs/)
  local latest_log
  latest_log=$(ls -t "$REPO_ROOT/.claude/backlog/runs/"*.log 2>/dev/null | grep -v 'heartbeat\|launchagent\|drain' | head -1)
  local log_info=""
  if [ -n "$latest_log" ]; then
    local size_bytes mtime
    size_bytes=$(stat -f '%z' "$latest_log" 2>/dev/null || echo "?")
    mtime=$(stat -f '%Sm' -t '%H:%M:%S' "$latest_log" 2>/dev/null || echo "?")
    log_info="- file: \`$(basename "$latest_log")\`
- size: ${size_bytes} bytes  ·  mtime: ${mtime}"
  fi

  # Active worker details
  local worker_details=""
  for pid in "${worker_pids[@]}"; do
    local etime cmd
    etime=$(ps -p "$pid" -o etime= 2>/dev/null | tr -d ' ')
    cmd=$(ps -p "$pid" -o command= 2>/dev/null | head -c 80)
    [ -n "$etime" ] && worker_details="${worker_details}
- worker pid=${pid}  ·  elapsed: ${etime}  ·  cmd: ${cmd}…"
  done

  local claude_details=""
  for pid in "${claude_pids[@]}"; do
    local etime model
    etime=$(ps -p "$pid" -o etime= 2>/dev/null | tr -d ' ')
    # Extract --model from cmdline
    model=$(ps -p "$pid" -o command= 2>/dev/null | grep -oE '\-\-model [a-z]+' | head -1 | awk '{print $2}')
    [ -n "$etime" ] && claude_details="${claude_details}
- claude pid=${pid}  ·  elapsed: ${etime}  ·  model: ${model:-?}"
  done

  # Latest audit events (last 5)
  local audit_file="$REPO_ROOT/.claude/audit/$(date +%Y-%m-%d).md"
  local audit_recent=""
  if [ -f "$audit_file" ]; then
    audit_recent=$(grep -A1 "^action:" "$audit_file" 2>/dev/null | grep -E "action:|subject:" | tail -10 | sed 's/^/  /')
  fi

  # Inbox-list (slugs)
  local inbox_list=""
  for f in "$REPO_ROOT/.claude/overseer/inbox/"*.md; do
    [ -f "$f" ] || continue
    inbox_list="${inbox_list}
- $(basename "$f" .md)"
  done

  # Compose the status file
  cat > "$STATUS_FILE" <<EOF
# 🤖 Autonomous Swarm — Live Status

> **Letztes Update:** \`${now}\` (Unix ${ts_unix})
> Diese Datei wird **jede Minute** vom live-status-Daemon aktualisiert.
> Wenn dieser Timestamp älter als 2 min ist → Daemon hängt/ist tot.

## ${status_emoji} Status: **${status}**

- **Overseer-Daemons:** ${#overseer_pids[@]} (PID${overseer_pids[*]:+ ${overseer_pids[*]}})
- **Worker.sh:** ${#worker_pids[@]}
- **claude --print (Worker):** ${#claude_pids[@]}

## 🧵 Aktive Worker
${worker_details:-
- (keine aktiven Worker)}
${claude_details}

## 🌳 Worktree-Diff
${diff_summary}

## 📂 Item-State
- 📥 Inbox:        **${inbox_n}** wartend${inbox_list:-
  (leer)}
- 🔄 In-Progress:  **${in_progress_n}**
- ✅ Done:         **${done_n}**
- ❌ Failed:       **${failed_n}**
- 🚧 Quarantine:   **${quarantine_n}**

## 📋 Letztes Run-Log
${log_info:-
- (kein Run-Log)}

## 📜 Letzte Audit-Events (heute)
${audit_recent:-
- (keine heute)}

---
*Tail-live: \`tail -f .claude/backlog/runs/<latest>.log\` · Yota-Snapshot: \`bash .claude/scripts/yota-snapshot.sh --human\`*
EOF
}

case "${1:-}" in
  --daemon)
    while true; do
      write_status
      sleep 60
    done
    ;;
  --once|"")
    write_status
    echo "Written: $STATUS_FILE"
    ;;
  *)
    echo "Usage: $0 [--once|--daemon]" >&2
    exit 1
    ;;
esac
