#!/usr/bin/env bash
# Drain-Loop: arbeitet das Backlog ab, indem es den headless-runner immer
# wieder aufruft, bis die inbox leer ist (oder ein Hard-Limit greift).
#
# Aufruf als Daemon:
#   nohup bash .claude/scripts/drain.sh > .claude/backlog/runs/drain.log 2>&1 &
#   echo $! > .claude/backlog/.drain.pid
#
# Stoppen:
#   kill "$(cat .claude/backlog/.drain.pid)" && rm .claude/backlog/.drain.pid

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INBOX="$ROOT/.claude/backlog/inbox"
RUNNER="$ROOT/.claude/scripts/headless-runner.sh"
NOTIFY="$ROOT/.claude/scripts/notify.sh"
MAX_ITERATIONS="${DRAIN_MAX_ITERATIONS:-30}"
SLEEP_BETWEEN="${DRAIN_SLEEP_SECONDS:-15}"

# .env.headless laden für NTFY_TOPIC
if [ -f "$ROOT/.env.headless" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.headless"
  set +a
fi

cd "$ROOT"

echo "[drain] starting, max_iterations=$MAX_ITERATIONS, sleep=${SLEEP_BETWEEN}s"
"$NOTIFY" "🚀 Drain gestartet" "Backlog wird abgearbeitet — alle 10 Min Heartbeat." info

ITER=0
while [ "$ITER" -lt "$MAX_ITERATIONS" ]; do
  COUNT="$(find "$INBOX" -maxdepth 1 -type f -name '*.md' ! -name '.gitkeep' 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$COUNT" -eq 0 ]; then
    echo "[drain] inbox empty after $ITER iterations — done"
    "$NOTIFY" "🏁 Drain fertig" "Backlog leer nach $ITER Iterations." success
    exit 0
  fi

  ITER=$((ITER + 1))
  echo "[drain $(date -u +%H:%M:%S)] iteration $ITER, $COUNT items remaining"
  bash "$RUNNER"
  RUNNER_EXIT=$?
  echo "[drain $(date -u +%H:%M:%S)] runner exit=$RUNNER_EXIT"

  sleep "$SLEEP_BETWEEN"
done

echo "[drain] max iterations ($MAX_ITERATIONS) reached — stopping"
"$NOTIFY" "⚠️ Drain gestoppt" "Max iterations $MAX_ITERATIONS erreicht. Inbox: $COUNT übrig." failure
exit 1
