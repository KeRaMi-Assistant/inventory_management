#!/usr/bin/env bash
# Headless-Runner: pickt das erste Backlog-Item aus inbox/, ruft `claude --print`
# auf, verschiebt das Item nach done/ oder failed/, schickt Notification.
#
# Aufrufer: macOS LaunchAgent (alle 30 Min) oder `/auto-run` Slash-Command.
# Idempotent. Lock-File verhindert parallele Runs.
#
# Env-Vars (alle optional):
#   HEADLESS_MAX_BUDGET_USD   — default 5
#   HEADLESS_MODEL            — default sonnet
#   HEADLESS_PERMISSION_MODE  — default auto
#   NTFY_TOPIC                — falls Mobile-Push gewünscht
#
# Lädt zusätzlich .env.headless aus Repo-Root, falls vorhanden (gitignored).

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BACKLOG="$ROOT/.claude/backlog"
INBOX="$BACKLOG/inbox"
DONE="$BACKLOG/done"
FAILED="$BACKLOG/failed"
RUNS="$BACKLOG/runs"
LOCK="$BACKLOG/.lock"
NOTIFY="$ROOT/.claude/scripts/notify.sh"

mkdir -p "$INBOX" "$DONE" "$FAILED" "$RUNS"

# .env.headless laden (für NTFY_TOPIC etc.) — gitignored
if [ -f "$ROOT/.env.headless" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.headless"
  set +a
fi

# Default: opus, no budget cap. User decided: quality over cost.
# - HEADLESS_MAX_BUDGET_USD env or item frontmatter `budget_usd` can still cap.
# - Empty MAX_BUDGET = no --max-budget-usd flag passed = no cap.
MAX_BUDGET="${HEADLESS_MAX_BUDGET_USD:-}"
MODEL="${HEADLESS_MODEL:-opus}"
PERMISSION_MODE="${HEADLESS_PERMISSION_MODE:-auto}"

log() { printf '[headless %s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

# Lock-File-Handling
if [ -f "$LOCK" ]; then
  PID="$(cat "$LOCK" 2>/dev/null || echo)"
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    log "another run active (pid $PID), skipping"
    exit 0
  fi
  log "stale lock found, removing"
  rm -f "$LOCK"
fi
echo "$$" > "$LOCK"
trap 'rm -f "$LOCK"' EXIT INT TERM

# Find next item
NEXT_ITEM="$(find "$INBOX" -maxdepth 1 -type f -name '*.md' ! -name '.gitkeep' 2>/dev/null | sort | head -n 1)"
if [ -z "$NEXT_ITEM" ]; then
  log "inbox empty"
  exit 0
fi

ITEM_NAME="$(basename "$NEXT_ITEM")"
SLUG="${ITEM_NAME%.md}"
TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
RUN_LOG="$RUNS/${TIMESTAMP}-${SLUG}.log"

# Hard-Block: niemals headless auf main pushen — wenn aktuell main, switche zu fresh feature-branch.
CURRENT_BRANCH="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo)"
if [ "$CURRENT_BRANCH" = "main" ] || [ -z "$CURRENT_BRANCH" ]; then
  AUTO_BRANCH="feature/headless-${SLUG}-${TIMESTAMP}"
  log "switching from '$CURRENT_BRANCH' to fresh branch $AUTO_BRANCH"
  if ! git checkout -b "$AUTO_BRANCH" 2>>"$RUN_LOG"; then
    log "could not create branch — aborting"
    "$NOTIFY" "Claude headless" "Branch-Switch failed for $SLUG" failure
    mv "$NEXT_ITEM" "$FAILED/${TIMESTAMP}-${ITEM_NAME}"
    exit 1
  fi
fi

log "starting item: $SLUG (branch=$(git branch --show-current))"

# Build prompt: read content (frontmatter optional) and prepend repo-context note.
ITEM_CONTENT="$(cat "$NEXT_ITEM")"

# Extract fields from item frontmatter (optional).
# Format: YAML lines between --- delimiters.
parse_frontmatter() {
  awk -v key="$1" '
    /^---[[:space:]]*$/ { fm++; next }
    fm == 1 && $0 ~ "^"key":" {
      sub("^"key":[[:space:]]*", "")
      gsub(/^["'\'']|["'\'']$/, "")
      print; exit
    }
  ' "$NEXT_ITEM"
}

TEST_SCENARIO="$(parse_frontmatter test_scenario)"
ITEM_BUDGET="$(parse_frontmatter budget_usd)"

# Item budget overrides ENV default. ENV var still wins as a hard cap.
if [ -n "$ITEM_BUDGET" ] && [[ "$ITEM_BUDGET" =~ ^[0-9]+$ ]]; then
  if [ -z "${HEADLESS_MAX_BUDGET_USD:-}" ]; then
    MAX_BUDGET="$ITEM_BUDGET"
    log "item frontmatter budget_usd=$ITEM_BUDGET applied"
  else
    log "ENV HEADLESS_MAX_BUDGET_USD=$MAX_BUDGET overrides item budget_usd=$ITEM_BUDGET"
  fi
fi

read -r -d '' PROMPT <<EOF || true
Du arbeitest als autonome Coding-Session im Repo \`inventory_management\`
(Flutter + Supabase, Pre-Launch). Lies CLAUDE.md zuerst.

Aufgabe:
$ITEM_CONTENT

Workflow (PFLICHT in dieser Reihenfolge):
1. Wenn nötig, plane kurz (max 10 Zeilen).
2. Implementiere in feature-branch (du bist bereits drin).
3. \`flutter analyze\` + \`flutter test\` müssen am Ende grün sein.
4. **Visueller Test (PFLICHT bei UI-/Theme-/Color-Änderungen):**
   - Wenn das Item ein \`test_scenario\` im Frontmatter hat (hier:
     "${TEST_SCENARIO:-NICHT GESETZT}"), rufe den \`browser-tester\`-
     Subagenten mit diesem Szenario auf, BEVOR du /ship aufrufst.
   - Wenn der Tester \`Result: failed\` zurückgibt: KEIN /ship.
     Stattdessen: Diagnose ins Run-Log schreiben + exit 1 (Item landet
     in failed/, nicht done/).
   - Wenn kein test_scenario im Frontmatter: nur ausführen wenn das
     Item UI-relevant ist (Files in lib/screens/ oder lib/widgets/
     geändert). Dann \`smoke-login\` als Fallback nutzen.
5. Erst nach grünem Visual-Test: \`/ship\` (commit + push + PR + auto-merge).
6. Bei Blocker: dokumentiere klar, wo's hängt — kein Endlos-Try.

**EXIT-CODE-VERTRAG (KRITISCH):**
- \`/ship\` erfolgreich (PR merged) → exit 0 → Item landet in done/.
- Visueller Test failed → exit 1 → Item landet in failed/.
- Du brichst kontrolliert ab (kein /ship, Tool-Permission fehlt, MCP-Tool nicht da, fehlende Voraussetzungen) → **PFLICHT exit 1**.
  Sonst werden Items fälschlich als "done" verbucht obwohl nichts gemerged wurde.
  Vor exit: schreibe einen klaren Blocker-Report ins Run-Log
  (was fehlte, was zu tun ist, welcher Befehl).

Hard-Constraints:
- Niemals \`supabase db push\` gegen Prod.
- Niemals direkt auf main committen.
- Keine Secrets in Diff.
- KEIN /ship wenn Visual-Test failed.
- Du arbeitest gründlich, nicht schnell. Lieber 1 Item komplett fertig als 3 angefangen.
EOF

# Run claude --print non-interactively. Capture exit code and full log.
log "invoking claude (model=$MODEL, budget=\${MAX_BUDGET:-uncapped}, mode=$PERMISSION_MODE)"

set +e
echo "=== prompt ===" > "$RUN_LOG"
printf '%s\n' "$PROMPT" >> "$RUN_LOG"
echo "=== output ===" >> "$RUN_LOG"

# Build claude args. Skip --max-budget-usd if MAX_BUDGET is empty.
CLAUDE_ARGS=(
  --print
  --model "$MODEL"
  --permission-mode "$PERMISSION_MODE"
  --no-session-persistence
  --output-format text
)
if [ -n "$MAX_BUDGET" ]; then
  CLAUDE_ARGS+=(--max-budget-usd "$MAX_BUDGET")
fi

claude "${CLAUDE_ARGS[@]}" -p "$PROMPT" \
  >> "$RUN_LOG" 2>&1
EXIT_CODE=$?
set -e

# Sentinel-Mechanismus: Sub-Claude kann claude --print nicht von innen
# zu exit 1 zwingen. Wenn er einen Blocker-Marker im Output hinterlässt,
# überschreiben wir hier den Exit-Code auf 1 → Item landet in failed/.
# Marker-Patterns (case-sensitive, im Body, nicht im Prompt-Echo):
#   "## Blocker" / "## Abgebrochen" / "Blocker:" / "BLOCKER —"
#   "exit 1" / "kein /ship" / "kein PR"
if [ "$EXIT_CODE" -eq 0 ]; then
  OUTPUT_ONLY="$(awk '/^=== output ===/{found=1; next} found' "$RUN_LOG")"
  if printf '%s' "$OUTPUT_ONLY" | grep -qE '^(##\s+(Blocker|Abgebrochen)|BLOCKER\s+—|Blocker:)' \
     || printf '%s' "$OUTPUT_ONLY" | grep -qE '\bkein\s+/ship\b'; then
    log "blocker sentinel detected — forcing exit 1 (move to failed/)"
    EXIT_CODE=1
  fi
fi

# Capture last 8 lines as notification body
SUMMARY="$(tail -n 8 "$RUN_LOG" | tr '\n' ' ' | cut -c 1-300)"

if [ "$EXIT_CODE" -eq 0 ]; then
  log "item succeeded — moving to done/"
  mv "$NEXT_ITEM" "$DONE/${TIMESTAMP}-${ITEM_NAME}"
  "$NOTIFY" "Claude ✅ $SLUG" "Done. $SUMMARY" success
else
  log "item failed (exit=$EXIT_CODE) — moving to failed/"
  mv "$NEXT_ITEM" "$FAILED/${TIMESTAMP}-${ITEM_NAME}"
  cp "$RUN_LOG" "$FAILED/${TIMESTAMP}-${ITEM_NAME%.md}.log"
  "$NOTIFY" "Claude ❌ $SLUG" "Failed (exit $EXIT_CODE). $SUMMARY" failure
fi

log "done"
exit 0
