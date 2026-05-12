#!/usr/bin/env bash
# worker.sh — Wrapper around `claude --print` that processes a single backlog
# item inside an isolated worktree.
#
# Spec: plans/2026-05-09_autonomous_council_swarm.md (P1-2, lines 314-336).
#
# CLI:
#   worker.sh <item-path> <worktree-path>
#
# Exit codes (overseer maps these):
#   0  — success → release_item done
#   1  — failure → release_item failed (sentinel "## Result: failed", crash, etc.)
#   2  — PANIC → overseer writes PANIC marker, item back to inbox
#   3  — blocked-pre-ship → overseer release_item blocked-pre-ship
#
# IMPORTANT: This file is in the Self-Mod-Blocklist (P0-0).

set -uo pipefail

# ---------------------------------------------------------------------------
# 0. Argument parsing & path resolution
# ---------------------------------------------------------------------------
if [ "$#" -lt 2 ]; then
  printf 'worker.sh: usage: %s <item-path> <worktree-path>\n' "$0" >&2
  exit 1
fi

ITEM_PATH="$1"
WORKTREE_PATH="$2"

if [ ! -f "$ITEM_PATH" ]; then
  printf 'worker.sh: item not found: %s\n' "$ITEM_PATH" >&2
  exit 1
fi
if [ ! -d "$WORKTREE_PATH" ]; then
  printf 'worker.sh: worktree dir not found: %s\n' "$WORKTREE_PATH" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

LIB_COST="$SCRIPT_DIR/lib/cost-cap.sh"
LIB_AUDIT="$SCRIPT_DIR/lib/audit.sh"
NOTIFY_SH="$SCRIPT_DIR/notify.sh"

# Source libs (best-effort).
# shellcheck disable=SC1090
[ -f "$LIB_COST" ]  && source "$LIB_COST"  || true
# shellcheck disable=SC1090
[ -f "$LIB_AUDIT" ] && source "$LIB_AUDIT" || true

OVERSEER_DIR="$REPO_ROOT/.claude/overseer"
PANIC_MARKER="$OVERSEER_DIR/PANIC"
RUNS_DIR="$REPO_ROOT/.claude/backlog/runs"
mkdir -p "$RUNS_DIR" "$OVERSEER_DIR"

_log() { printf '[worker %s pid=%d] %s\n' "$(date -u +%H:%M:%S)" "$$" "$*" >&2; }

_audit() {
  if command -v audit_record >/dev/null 2>&1; then
    audit_record "worker" "$1" "$2" "${3:-}" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# 1. Frontmatter parsing (Mitigation 3 — budget_usd PFLICHT)
# ---------------------------------------------------------------------------
_parse_fm() {
  # _parse_fm <file> <field>  → echoes value or empty.
  local file="$1" field="$2"
  python3 - "$file" "$field" <<'PYEOF' 2>/dev/null || true
import sys, re
try:
    path, field = sys.argv[1], sys.argv[2]
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    fm = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
    if not fm: sys.exit(0)
    for line in fm.group(1).split('\n'):
        m = re.match(r'^' + re.escape(field) + r'\s*:\s*(.+)$', line)
        if m:
            print(m.group(1).strip().strip('"').strip("'"))
            sys.exit(0)
except Exception:
    pass
PYEOF
}

_strip_fm_body() {
  # Echoes content of <file> with frontmatter stripped.
  local file="$1"
  python3 - "$file" <<'PYEOF' 2>/dev/null
import sys, re
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    content = f.read()
m = re.match(r'^---\s*\n.*?\n---\s*\n', content, re.DOTALL)
sys.stdout.write(content[m.end():] if m else content)
PYEOF
}

_acceptance_block() {
  # Echoes the acceptance line(s) from frontmatter (if any) — informational.
  local file="$1"
  python3 - "$file" <<'PYEOF' 2>/dev/null
import sys, re
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    content = f.read()
m = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
if not m: sys.exit(0)
fm = m.group(1)
out = []
in_acc = False
for line in fm.split('\n'):
    if re.match(r'^acceptance\s*:', line):
        in_acc = True
        inline = re.search(r'acceptance\s*:\s*(\S.*)$', line)
        if inline:
            out.append('- ' + inline.group(1).strip())
            in_acc = False
        continue
    if in_acc:
        if re.match(r'^\s*-\s+', line):
            out.append(line.strip())
        elif re.match(r'^\S', line):
            in_acc = False
print('\n'.join(out))
PYEOF
}

SLUG="$(_parse_fm "$ITEM_PATH" slug)"
if [ -z "$SLUG" ]; then
  # Fall back to filename stem (strip [marker]- prefix and .pid suffix)
  base="$(basename "$ITEM_PATH")"
  stem="${base%.md}"
  stem="$(printf '%s' "$stem" | sed 's/\.[0-9][0-9]*$//')"
  stem="$(printf '%s' "$stem" | sed 's/^\[[^]]*\]-//')"
  SLUG="$stem"
fi

BUDGET_USD="$(_parse_fm "$ITEM_PATH" budget_usd)"
if [ -z "$BUDGET_USD" ] || ! printf '%s' "$BUDGET_USD" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
  printf 'worker.sh: ERROR: required frontmatter field "budget_usd" missing or invalid in %s\n' "$ITEM_PATH" >&2
  _audit "missing_budget" "$SLUG" "item=$ITEM_PATH"
  exit 1
fi

# Default model is sonnet (Mitigation: opus only on explicit override).
ITEM_MODEL="$(_parse_fm "$ITEM_PATH" model)"
MODEL="${ITEM_MODEL:-sonnet}"

NEEDS_GH="$(_parse_fm "$ITEM_PATH" needs_gh)"
NEEDS_GH="${NEEDS_GH:-false}"

TIMEOUT_MIN="$(_parse_fm "$ITEM_PATH" timeout_minutes)"
if ! [[ "$TIMEOUT_MIN" =~ ^[0-9]+$ ]]; then
  TIMEOUT_MIN=240
fi

SOURCE_TIER="$(_parse_fm "$ITEM_PATH" source)"

# ---------------------------------------------------------------------------
# 2. Run-log path
# ---------------------------------------------------------------------------
TS="$(date -u +%Y%m%d-%H%M%S)"
RUN_LOG="$RUNS_DIR/${TS}-${SLUG}.log"
: > "$RUN_LOG"

_log "starting slug=$SLUG model=$MODEL budget=\$$BUDGET_USD source=${SOURCE_TIER:-unknown}"
_audit "start" "$SLUG" "model=$MODEL budget=$BUDGET_USD"

{
  echo "=== worker meta ==="
  echo "slug=$SLUG"
  echo "model=$MODEL"
  echo "budget_usd=$BUDGET_USD"
  echo "needs_gh=$NEEDS_GH"
  echo "timeout_minutes=$TIMEOUT_MIN"
  echo "worktree=$WORKTREE_PATH"
  echo "ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
} >> "$RUN_LOG"

# ---------------------------------------------------------------------------
# 3. Build prompt
# ---------------------------------------------------------------------------
ITEM_BODY="$(_strip_fm_body "$ITEM_PATH")"
ACCEPTANCE="$(_acceptance_block "$ITEM_PATH")"

PROMPT_HEADER="Du arbeitest als autonome Coding-Session im Worktree des Repos
\`inventory_management\` (Flutter + Supabase, Pre-Launch). Lies CLAUDE.md zuerst.

Du läufst innerhalb des **Autonomous Council Swarm Overseer** (P1-1).
Slug: \`${SLUG}\`. Budget-Cap (hart): \$${BUDGET_USD}.

## Aufgabe (aus Backlog-Item)

${ITEM_BODY}

## Self-Verify (PFLICHT vor /ship)

Acceptance-Kriterien aus dem Item-Frontmatter:
${ACCEPTANCE:-(keine acceptance-Liste im Frontmatter — Beschreibung nutzen)}

Vor jedem \`/ship\`:
- \`flutter analyze\` MUSS 0 issues sein.
- \`flutter test\` MUSS grün sein.
- Wenn UI-Pfade berührt (\`lib/screens/\`, \`lib/widgets/\`, \`lib/app_theme.dart\`,
  \`lib/l10n/app_*.arb\`):
  - \`smoke-full-app-audit\` muss grün laufen (siehe CLAUDE.md).
  - \`python3 .claude/scripts/check-l10n.py\` muss exit 0.
  Diese Pre-Ship-Gates werden vom Worker-Wrapper NACH deinem Run nochmal
  doublechecked — wenn sie fehlen, bekommt das Item den Marker
  \`[blocked-pre-ship]\` und kommt zurück in die Inbox.

## Sentinel-Verträge

- \`## Result: success\` schreiben wenn alles durch ist.
- \`## Result: failed\` wenn du nicht fertig wirst (Worker mappt → exit 1).
- \`## Self-Verify failed\` wenn Acceptance nicht erfüllt (→ exit 1).
- KEIN Sentinel = Worker entscheidet anhand von Output + Pre-Ship-Gates.

Hard-Constraints:
- Niemals \`supabase db push\` gegen Prod.
- Niemals direkt auf main committen.
- Keine Secrets ins Diff.
- Du arbeitest gründlich, nicht schnell."

# ---------------------------------------------------------------------------
# 4. PANIC watcher (Mitigation: every 30s check overseer/PANIC)
# ---------------------------------------------------------------------------
PANIC_WATCH_PID=""
_start_panic_watcher() {
  local target_pid="$1"
  (
    while kill -0 "$target_pid" 2>/dev/null; do
      if [ -f "$PANIC_MARKER" ]; then
        _log "PANIC marker detected — sending TERM to claude pid=$target_pid"
        kill -TERM "$target_pid" 2>/dev/null || true
        sleep 2
        kill -KILL "$target_pid" 2>/dev/null || true
        exit 0
      fi
      sleep 30
    done
  ) &
  PANIC_WATCH_PID=$!
}
_stop_panic_watcher() {
  if [ -n "$PANIC_WATCH_PID" ] && kill -0 "$PANIC_WATCH_PID" 2>/dev/null; then
    kill "$PANIC_WATCH_PID" 2>/dev/null || true
    wait "$PANIC_WATCH_PID" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# 5. Resolve `timeout` binary (macOS uses gtimeout from coreutils, optional)
# ---------------------------------------------------------------------------
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
fi

# ---------------------------------------------------------------------------
# 6. Run claude --print in a minimal-rights subshell (Empfehlung l)
# ---------------------------------------------------------------------------
_log "invoking claude (model=$MODEL, budget=\$$BUDGET_USD, timeout=${TIMEOUT_MIN}m)"

EXIT_CODE=0
PRINT_PID=""

# Stash GH_TOKEN before sub-env scrubbing if needs_gh=true
PARENT_GH_TOKEN="${GH_TOKEN:-}"

set +e
(
  # Working directory: the worktree
  cd "$WORKTREE_PATH" || exit 99

  # Hardened env (Empfehlung l):
  export HEADLESS_MODE=1
  export OVERSEER_WORKER_PID="${OVERSEER_WORKER_PID:-$$}"
  export CLAUDE_PROJECT_DIR="$WORKTREE_PATH"
  export COST_CAP_LEDGER_DIR="$REPO_ROOT/.claude/overseer"

  # GH_TOKEN: only if needs_gh=true
  if [ "$NEEDS_GH" = "true" ]; then
    if [ -n "$PARENT_GH_TOKEN" ]; then
      export GH_TOKEN="$PARENT_GH_TOKEN"
    fi
  else
    unset GH_TOKEN
    export GH_TOKEN=
  fi

  # Worker has NO supabase tokens regardless of parent env.
  unset SUPABASE_ACCESS_TOKEN
  unset SUPABASE_DB_PASSWORD
  export SUPABASE_ACCESS_TOKEN=
  export SUPABASE_DB_PASSWORD=

  echo "=== claude output ===" >> "$RUN_LOG"

  # Build cmd — --output-format json gives structured cost/result (Security #7)
  CLAUDE_ARGS=(
    --print
    --output-format json
    --permission-mode auto
    --max-budget-usd "$BUDGET_USD"
    --model "$MODEL"
  )

  # Capture raw JSON to a temp file; we'll extract result text + cost after.
  JSON_TMP="${RUN_LOG%.log}.json"

  if [ -n "$TIMEOUT_BIN" ]; then
    "$TIMEOUT_BIN" "${TIMEOUT_MIN}m" claude "${CLAUDE_ARGS[@]}" -p "$PROMPT_HEADER" \
      > "$JSON_TMP" 2>&1
  else
    claude "${CLAUDE_ARGS[@]}" -p "$PROMPT_HEADER" \
      > "$JSON_TMP" 2>&1
  fi
  _json_exit=$?

  # Extract result text from JSON and append to RUN_LOG (preserves sentinel grep).
  # Falls JSON-Parsing fails, append raw output so sentinels are still findable.
  python3 - "$JSON_TMP" "$RUN_LOG" <<'PYEOF' 2>/dev/null || cat "$JSON_TMP" >> "$RUN_LOG"
import sys, json
json_path, log_path = sys.argv[1], sys.argv[2]
try:
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    result_text = data.get('result', '')
    with open(log_path, 'a', encoding='utf-8') as f:
        f.write(result_text)
        if not result_text.endswith('\n'):
            f.write('\n')
except Exception:
    # Fallback: append raw
    with open(json_path, 'r', encoding='utf-8', errors='replace') as f:
        raw = f.read()
    with open(log_path, 'a', encoding='utf-8') as f:
        f.write(raw)
PYEOF

  exit $_json_exit
) &
PRINT_PID=$!

# Start PANIC watcher tied to claude PID
_start_panic_watcher "$PRINT_PID"

wait "$PRINT_PID"
EXIT_CODE=$?
set -e

_stop_panic_watcher

# Distinguish PANIC kill (TERM/KILL by watcher → exit 143/137) from other failures.
PANIC_HIT=0
if [ -f "$PANIC_MARKER" ] && { [ "$EXIT_CODE" -eq 143 ] || [ "$EXIT_CODE" -eq 137 ]; }; then
  PANIC_HIT=1
fi

# ---------------------------------------------------------------------------
# 7. Sentinel detection (failed / self-verify / cost-cap-tampering)
# ---------------------------------------------------------------------------
SENTINEL_FAIL=0
SENTINEL_PANIC=0
if [ -f "$RUN_LOG" ]; then
  if grep -qE '^## Result: failed' "$RUN_LOG" 2>/dev/null; then
    SENTINEL_FAIL=1
  fi
  if grep -qE '^## Self-Verify failed' "$RUN_LOG" 2>/dev/null; then
    SENTINEL_FAIL=1
  fi
  # Cost-cap tampering attempts → PANIC.
  if grep -qE '(rm[[:space:]]+.*cost-ledger|chmod[[:space:]]+.*cost-ledger|>[[:space:]]*.*cost-ledger\.jsonl)' "$RUN_LOG" 2>/dev/null; then
    SENTINEL_PANIC=1
  fi
fi

# ---------------------------------------------------------------------------
# 8. Pre-Ship-Gates (Mitigation 15) — only when UI paths touched.
# ---------------------------------------------------------------------------
PRE_SHIP_BLOCKED=0
PRE_SHIP_REASON=""

# Only meaningful if claude actually produced commits in the worktree.
if [ "$EXIT_CODE" -eq 0 ] && [ "$SENTINEL_FAIL" -eq 0 ] && [ "$SENTINEL_PANIC" -eq 0 ] && [ "$PANIC_HIT" -eq 0 ]; then
  # Determine diff base. Prefer HEAD~1 (any commits in this run); fall back to
  # comparing against origin/main if HEAD~1 is unavailable.
  DIFF_FILES=""
  if git -C "$WORKTREE_PATH" rev-parse HEAD~1 >/dev/null 2>&1; then
    DIFF_FILES="$(git -C "$WORKTREE_PATH" diff HEAD~1 --name-only 2>/dev/null || true)"
  fi
  if [ -z "$DIFF_FILES" ] && git -C "$WORKTREE_PATH" rev-parse origin/main >/dev/null 2>&1; then
    DIFF_FILES="$(git -C "$WORKTREE_PATH" diff origin/main --name-only 2>/dev/null || true)"
  fi
  # Also include uncommitted (any worker that didn't commit yet would still be caught)
  UNCOMMITTED="$(git -C "$WORKTREE_PATH" status --porcelain 2>/dev/null | awk '{print $2}' || true)"
  ALL_TOUCHED="$(printf '%s\n%s\n' "$DIFF_FILES" "$UNCOMMITTED" | sort -u)"

  UI_TOUCHED=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
      lib/screens/*|lib/widgets/*|lib/app_theme.dart|lib/l10n/app_*.arb)
        UI_TOUCHED=1
        break
        ;;
    esac
  done <<< "$ALL_TOUCHED"

  if [ "$UI_TOUCHED" -eq 1 ]; then
    _log "UI paths touched — running pre-ship gates"

    # Gate 1: smoke-full-app-audit must have a green report.
    AUDIT_GREEN=0
    TEST_RUNS_DIR="$REPO_ROOT/.claude/test-runs"
    if [ -d "$TEST_RUNS_DIR" ]; then
      LATEST_RUN="$(find "$TEST_RUNS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
                    | sort -r | head -n 1)"
      if [ -n "$LATEST_RUN" ] && [ -f "$LATEST_RUN/report.md" ]; then
        if grep -qE '^Result:[[:space:]]*passed' "$LATEST_RUN/report.md" 2>/dev/null; then
          AUDIT_GREEN=1
        fi
      fi
    fi
    if [ "$AUDIT_GREEN" -ne 1 ]; then
      PRE_SHIP_BLOCKED=1
      PRE_SHIP_REASON="smoke-full-app-audit not green (no recent passed report.md found)"
    fi

    # Gate 2: l10n-checker
    if [ "$PRE_SHIP_BLOCKED" -eq 0 ]; then
      L10N_SCRIPT="$REPO_ROOT/.claude/scripts/check-l10n.py"
      if [ -f "$L10N_SCRIPT" ]; then
        if ! python3 "$L10N_SCRIPT" >> "$RUN_LOG" 2>&1; then
          PRE_SHIP_BLOCKED=1
          PRE_SHIP_REASON="check-l10n.py exit != 0"
        fi
      fi
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 9. B4 Pre-Ship Code-Quality-Reviewer (warn-only — Mitigation 16)
# ---------------------------------------------------------------------------
CQ_AGENT_FILE="$REPO_ROOT/.claude/agents/code-quality-reviewer.md"
if [ -f "$CQ_AGENT_FILE" ] && command -v claude >/dev/null 2>&1; then
  echo "" >> "$RUN_LOG"
  echo "## Code-Quality-Findings" >> "$RUN_LOG"
  CQ_DIFF="$(git -C "$WORKTREE_PATH" diff HEAD~1 2>/dev/null || git -C "$WORKTREE_PATH" diff origin/main 2>/dev/null || true)"
  if [ -n "$CQ_DIFF" ]; then
    (
      cd "$WORKTREE_PATH"
      printf '%s' "$CQ_DIFF" | claude --print --permission-mode auto \
        --max-budget-usd 0.50 --model sonnet \
        --agent code-quality-reviewer 2>&1 \
        | head -c 8192 >> "$RUN_LOG" || true
    ) || true
  else
    echo "(no diff to review)" >> "$RUN_LOG"
  fi
else
  printf 'worker: code-quality-reviewer agent not present, skipping warn-only review\n' >&2
fi

# ---------------------------------------------------------------------------
# 10. Cost-Event ledger (Mitigation 3) — structured JSON extraction (Security #7)
# ---------------------------------------------------------------------------
ACTUAL_USD=""
ACTUAL_INPUT_TOKENS=""
ACTUAL_CACHED_TOKENS=""
ACTUAL_OUTPUT_TOKENS=""

JSON_TMP="${RUN_LOG%.log}.json"
if [ -f "$JSON_TMP" ]; then
  # Extract cost + token fields from structured JSON output.
  eval "$(python3 - "$JSON_TMP" <<'PYEOF' 2>/dev/null || true
import sys, json
try:
    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        data = json.load(f)
    usd = data.get('total_cost_usd')
    usage = data.get('usage', {})
    if usd is not None:
        print(f"ACTUAL_USD={float(usd):.6f}")
    inp = usage.get('input_tokens')
    if inp is not None:
        print(f"ACTUAL_INPUT_TOKENS={int(inp)}")
    cached = usage.get('cached_input_tokens')
    if cached is not None:
        print(f"ACTUAL_CACHED_TOKENS={int(cached)}")
    out = usage.get('output_tokens')
    if out is not None:
        print(f"ACTUAL_OUTPUT_TOKENS={int(out)}")
except Exception:
    pass
PYEOF
)"
fi

if [ -z "$ACTUAL_USD" ]; then
  # Pessimist fallback: charge full budget when JSON parsing fails.
  ACTUAL_USD="$BUDGET_USD"
fi

if command -v cost_record_full >/dev/null 2>&1 \
   && [ -n "$ACTUAL_INPUT_TOKENS" ] && [ -n "$ACTUAL_OUTPUT_TOKENS" ]; then
  cost_record_full "worker-${SLUG}" "$ACTUAL_USD" \
    "$ACTUAL_INPUT_TOKENS" "${ACTUAL_CACHED_TOKENS:-0}" "$ACTUAL_OUTPUT_TOKENS" \
    >/dev/null 2>&1 || true
elif command -v cost_record >/dev/null 2>&1; then
  cost_record "worker-${SLUG}" "$ACTUAL_USD" >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# 11. Determine final exit code.
# ---------------------------------------------------------------------------
FINAL_EXIT=0
FINAL_SENTINEL="## Result: success"

if [ "$SENTINEL_PANIC" -eq 1 ]; then
  FINAL_EXIT=2
  FINAL_SENTINEL="## Result: panic-abort"
elif [ "$PANIC_HIT" -eq 1 ]; then
  FINAL_EXIT=2
  FINAL_SENTINEL="## Result: panic-abort"
elif [ "$PRE_SHIP_BLOCKED" -eq 1 ]; then
  FINAL_EXIT=3
  FINAL_SENTINEL="## Result: blocked-pre-ship"
elif [ "$SENTINEL_FAIL" -eq 1 ] || [ "$EXIT_CODE" -ne 0 ]; then
  FINAL_EXIT=1
  FINAL_SENTINEL="## Result: failed"
fi

{
  echo ""
  echo "=== worker summary ==="
  echo "claude_exit=$EXIT_CODE"
  echo "sentinel_fail=$SENTINEL_FAIL"
  echo "sentinel_panic=$SENTINEL_PANIC"
  echo "panic_hit=$PANIC_HIT"
  echo "pre_ship_blocked=$PRE_SHIP_BLOCKED"
  echo "pre_ship_reason=${PRE_SHIP_REASON:-}"
  echo "actual_usd=$ACTUAL_USD"
  echo "$FINAL_SENTINEL"
} >> "$RUN_LOG"

_audit "finish" "$SLUG" "exit=$FINAL_EXIT actual_usd=$ACTUAL_USD claude_exit=$EXIT_CODE"
# Security #7 migration audit record (one-time; harmless on subsequent runs).
if command -v audit_record >/dev/null 2>&1; then
  audit_record system json-cost-migration "" \
    "worker.sh + disput.sh on --output-format json" 2>/dev/null || true
fi
_log "done slug=$SLUG final_exit=$FINAL_EXIT (claude=$EXIT_CODE pre_ship=$PRE_SHIP_BLOCKED)"

exit "$FINAL_EXIT"
