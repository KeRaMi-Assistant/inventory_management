#!/usr/bin/env bash
# verify/intake-validator-real-pass.sh
# Manual-only smoke: invokes the REAL intake-validator agent against
# the reconstructed Council-File from the quarantine rescue, expects PASS.
#
# NOT in default suite — costs ~$0.10 real LLM call.
# Skip with: SKIP_REAL_LLM=1 bash .claude/scripts/verify/intake-validator-real-pass.sh
#
# Usage: bash .claude/scripts/verify/intake-validator-real-pass.sh [--skip-real-llm]
#
# Exit 0 = PASS (or skipped), Exit 1 = validator returned non-pass verdict.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SCRIPT_NAME="intake-validator-real-pass.sh"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"

# Parse args
SKIP=0
for arg in "$@"; do
  [[ "$arg" == "--skip-real-llm" ]] && SKIP=1
done
[[ "${SKIP_REAL_LLM:-0}" == "1" ]] && SKIP=1

printf '\n=== %s ===\n\n' "$SCRIPT_NAME"

if [ "$SKIP" -eq 1 ]; then
  printf '[SKIP] SKIP_REAL_LLM=1 — real LLM call omitted.\n'
  exit 0
fi

# Find a valid Council-File in overseer/inbox or reconstruct from quarantine rescue.
# Priority order:
#   1. .claude/overseer/inbox/01-stakeholder-selectable-color-palettes.md (rescue target)
#   2. Any .claude/stakeholder/pending-approval/*.md with created_from: intake-council
CANDIDATE=""

RESCUE_FILE="$REPO_ROOT/.claude/overseer/inbox/01-stakeholder-selectable-color-palettes.md"
if [ -f "$RESCUE_FILE" ]; then
  CANDIDATE="$RESCUE_FILE"
  printf '[INFO] Using rescued inbox item: %s\n' "$RESCUE_FILE"
fi

if [ -z "$CANDIDATE" ]; then
  # Fall back to any pending-approval Council file
  for f in "$REPO_ROOT/.claude/stakeholder/pending-approval/"*.md; do
    [ -f "$f" ] || continue
    if grep -q 'created_from: intake-council' "$f" 2>/dev/null; then
      CANDIDATE="$f"
      printf '[INFO] Using pending-approval file: %s\n' "$f"
      break
    fi
  done
fi

if [ -z "$CANDIDATE" ]; then
  printf '[FAIL] No suitable Council-File found for real validator test.\n'
  printf '       Run the quarantine-rescue steps first, then retry.\n'
  exit 1
fi

printf '[INFO] Running intake-validator agent against: %s\n\n' "$CANDIDATE"

# Build a temp copy in the expected pending-approval location if needed
TMP_DIR="$(mktemp -d)"
TMP_FILE="$TMP_DIR/20260512-204909-make-different-app-themes-all-fonts-and.md"
cp "$CANDIDATE" "$TMP_FILE"

# Invoke validator via claude
PROMPT="Validate this intake-council output. Read the file at:

$TMP_FILE

Then check it against your schema rules (5 Kategorien, including 5a OUTER + 5b INNER YAML). Output EXACTLY one of the following on the FIRST line — nothing else before it, no markdown, no preamble:
  pass — <reason>
  needs-full-council — <reason>
  quarantine — <reason>

Do NOT write any other files."

OUTPUT="$("$CLAUDE_BIN" --print --agent intake-validator \
  --add-dir "$REPO_ROOT" \
  -p "$PROMPT" 2>/dev/null || true)"

rm -rf "$TMP_DIR"

printf 'Validator output:\n%s\n\n' "$OUTPUT"

FIRST_LINE="$(printf '%s' "$OUTPUT" | head -1 | tr '[:upper:]' '[:lower:]')"

if printf '%s' "$FIRST_LINE" | grep -q '^pass'; then
  printf '[PASS] Validator returned PASS — schema fix is effective.\n'
  exit 0
else
  printf '[FAIL] Validator did NOT return pass. First line: %s\n' "$FIRST_LINE"
  exit 1
fi
