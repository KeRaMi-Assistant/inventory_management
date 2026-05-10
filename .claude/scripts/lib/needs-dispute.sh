#!/usr/bin/env bash
# needs-dispute.sh — Sourceable library: heuristic to decide if an item needs a dispute.
#
# Usage: source this file, then call:
#   needs_dispute <item-path>
#     → exit 0 + stdout reason  : dispute required
#     → exit 1 + stdout reason  : no dispute required
#
# Heuristic order:
#   1. Frontmatter needs_dispute: true/false  (explicit override)
#   2. Mitigation 14: source: tier-3 + migration/RLS
#   3. Auto-heuristic (touches count, keywords, deps, paths)
#   4. Default: no dispute
#
# Audit: audit_record is called on each invocation.
#
# IMPORTANT: This file is in the Self-Mod-Blocklist — do NOT modify at runtime.

# Deliberately NO set -e here — this is a sourced library.
set -u

# ---------------------------------------------------------------------------
# _ndispute_source_audit_lib — load audit.sh if not already sourced
# ---------------------------------------------------------------------------
_ndispute_source_audit_lib() {
  # If audit_record is already defined, nothing to do.
  if declare -f audit_record >/dev/null 2>&1; then
    return 0
  fi
  local _lib_dir
  _lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local _audit_lib="${_lib_dir}/audit.sh"
  if [ -f "$_audit_lib" ]; then
    # shellcheck source=audit.sh
    source "$_audit_lib"
  fi
}

# ---------------------------------------------------------------------------
# _ndispute_frontmatter_field <file> <field>
# Returns scalar value of a YAML frontmatter field.
# Exits 1 if not found.
# ---------------------------------------------------------------------------
_ndispute_frontmatter_field() {
  local file="$1"
  local field="$2"
  python3 - "$file" "$field" <<'PYEOF'
import sys, re
path, field = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
fm_match = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
if not fm_match:
    sys.exit(1)
fm = fm_match.group(1)
for line in fm.split('\n'):
    m = re.match(r'^' + re.escape(field) + r'\s*:\s*(.+)$', line)
    if m:
        val = m.group(1).strip().strip('"').strip("'")
        print(val)
        sys.exit(0)
sys.exit(1)
PYEOF
}

# ---------------------------------------------------------------------------
# _ndispute_touches_list <file>
# Echoes touches items (one per line).
# Exits 1 if no touches field found.
# ---------------------------------------------------------------------------
_ndispute_touches_list() {
  local file="$1"
  python3 - "$file" <<'PYEOF'
import sys, re
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
fm_match = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
if not fm_match:
    sys.exit(1)
fm = fm_match.group(1)
items = []
in_touches = False
for line in fm.split('\n'):
    if re.match(r'^touches\s*:', line):
        in_touches = True
        inline = re.search(r'touches\s*:\s*\[(.+)\]', line)
        if inline:
            for item in inline.group(1).split(','):
                item = item.strip().strip('"').strip("'")
                if item:
                    items.append(item)
            in_touches = False
        else:
            scalar = re.match(r'^touches\s*:\s*(\S.*)$', line)
            if scalar:
                val = scalar.group(1).strip().strip('"').strip("'")
                if val:
                    items.append(val)
                in_touches = False
        continue
    if in_touches:
        item_match = re.match(r'^\s*-\s+(.+)$', line)
        if item_match:
            items.append(item_match.group(1).strip().strip('"').strip("'"))
        elif re.match(r'^\S', line):
            in_touches = False
if not items:
    sys.exit(1)
for item in items:
    print(item)
PYEOF
}

# ---------------------------------------------------------------------------
# _ndispute_body_text <file>
# Echoes the body (everything after the frontmatter) of the markdown file.
# If no frontmatter, echoes the full content.
# ---------------------------------------------------------------------------
_ndispute_body_text() {
  local file="$1"
  python3 - "$file" <<'PYEOF'
import sys, re
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
fm_match = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
if fm_match:
    print(content[fm_match.end():])
else:
    print(content)
PYEOF
}

# ---------------------------------------------------------------------------
# _ndispute_touches_count <touches-lines>
# Echoes integer count of non-empty touches lines.
# ---------------------------------------------------------------------------
_ndispute_touches_count() {
  local lines="$1"
  if [ -z "$lines" ]; then
    echo 0
    return
  fi
  echo "$lines" | grep -c '[^[:space:]]' || echo 0
}

# ---------------------------------------------------------------------------
# _ndispute_touches_has_wildcard <touches-lines>
# Returns 0 (true) if any touches entry is a wildcard like "lib/" or similar.
# ---------------------------------------------------------------------------
_ndispute_touches_has_wildcard() {
  local lines="$1"
  # Wildcard patterns: ends with / or contains *
  if echo "$lines" | grep -qE '(^|\n)(lib/|supabase/)$|^lib/$|^supabase/$|\*'; then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# needs_dispute <item-path>
# Main entry point.
# ---------------------------------------------------------------------------
needs_dispute() {
  local item_path="${1:?needs_dispute requires item-path argument}"

  _ndispute_source_audit_lib

  local slug
  slug="$(basename "$item_path" .md)"

  if [ ! -f "$item_path" ]; then
    printf 'needs_dispute: ERROR: file not found: %s\n' "$item_path" >&2
    return 2
  fi

  # -------------------------------------------------------------------------
  # 1. Frontmatter explicit override: needs_dispute: true/false
  # -------------------------------------------------------------------------
  local nd_override
  nd_override="$(_ndispute_frontmatter_field "$item_path" "needs_dispute" 2>/dev/null || true)"

  if [ "$nd_override" = "true" ]; then
    local reason="explicit override: needs_dispute: true"
    printf '%s\n' "$reason"
    audit_record "needs-dispute" "triggered" "$slug" "$reason" 2>/dev/null || true
    return 0
  fi

  if [ "$nd_override" = "false" ]; then
    local reason="explicit override: needs_dispute: false"
    printf '%s\n' "$reason"
    audit_record "needs-dispute" "skipped" "$slug" "$reason" 2>/dev/null || true
    return 1
  fi

  # -------------------------------------------------------------------------
  # 2. Mitigation 14: tier-3 + migration/RLS
  # -------------------------------------------------------------------------
  local source_val
  source_val="$(_ndispute_frontmatter_field "$item_path" "source" 2>/dev/null || true)"

  local touches_lines
  touches_lines="$(_ndispute_touches_list "$item_path" 2>/dev/null || true)"

  local body_text
  body_text="$(_ndispute_body_text "$item_path" 2>/dev/null || true)"

  # Also include frontmatter for keyword search in body (full content)
  local full_text
  full_text="$(cat "$item_path" 2>/dev/null || true)"

  if [ "$source_val" = "tier-3" ]; then
    local is_migration_rls=0
    # touches contains supabase/migrations/
    if echo "$touches_lines" | grep -q 'supabase/migrations/'; then
      is_migration_rls=1
    fi
    # body contains RLS, migration, or policy keywords (case-insensitive)
    if echo "$full_text" | grep -qiE '\bRLS\b|migration|policy'; then
      is_migration_rls=1
    fi
    if [ "$is_migration_rls" -eq 1 ]; then
      local reason="triggered: tier-3 + migration"
      printf '%s\n' "$reason"
      audit_record "needs-dispute" "triggered" "$slug" "$reason" 2>/dev/null || true
      return 0
    fi
  fi

  # -------------------------------------------------------------------------
  # 3. Auto-heuristic
  # -------------------------------------------------------------------------

  # 3a. >5 Files OR touches: lib/ wildcard
  local touch_count
  touch_count="$(_ndispute_touches_count "$touches_lines")"

  if [ "$touch_count" -gt 5 ]; then
    local reason="touches > 5 files (count=$touch_count)"
    printf '%s\n' "$reason"
    audit_record "needs-dispute" "triggered" "$slug" "$reason" 2>/dev/null || true
    return 0
  fi

  # Check for wildcard "lib/" as single touches entry
  if echo "$touches_lines" | grep -qE '^lib/$'; then
    local reason="touches: lib/ wildcard"
    printf '%s\n' "$reason"
    audit_record "needs-dispute" "triggered" "$slug" "$reason" 2>/dev/null || true
    return 0
  fi

  # 3b. Architecture keywords in body
  if echo "$body_text" | grep -qiE 'refactor|architektur|architecture|migration|breaking[[:space:]]+change|deprecat|provider-pattern'; then
    local reason="body contains architecture/refactor keyword"
    printf '%s\n' "$reason"
    audit_record "needs-dispute" "triggered" "$slug" "$reason" 2>/dev/null || true
    return 0
  fi

  # 3c. New dependency: pubspec.yaml or package.json in touches
  if echo "$touches_lines" | grep -qE 'pubspec\.yaml|package\.json'; then
    local reason="touches: dependency file (pubspec.yaml or package.json)"
    printf '%s\n' "$reason"
    audit_record "needs-dispute" "triggered" "$slug" "$reason" 2>/dev/null || true
    return 0
  fi

  # 3d. Migration: supabase/migrations/ in touches
  if echo "$touches_lines" | grep -q 'supabase/migrations/'; then
    local reason="touches: supabase/migrations/"
    printf '%s\n' "$reason"
    audit_record "needs-dispute" "triggered" "$slug" "$reason" 2>/dev/null || true
    return 0
  fi

  # 3e. Edge Function: supabase/functions/ in touches
  if echo "$touches_lines" | grep -q 'supabase/functions/'; then
    local reason="touches: supabase/functions/"
    printf '%s\n' "$reason"
    audit_record "needs-dispute" "triggered" "$slug" "$reason" 2>/dev/null || true
    return 0
  fi

  # 3f. Theme/Design-System: lib/app_theme.dart in touches
  if echo "$touches_lines" | grep -q 'lib/app_theme.dart'; then
    local reason="touches: lib/app_theme.dart (theme/design-system)"
    printf '%s\n' "$reason"
    audit_record "needs-dispute" "triggered" "$slug" "$reason" 2>/dev/null || true
    return 0
  fi

  # -------------------------------------------------------------------------
  # 4. Default: no dispute
  # -------------------------------------------------------------------------
  local reason="no trigger condition matched"
  printf '%s\n' "$reason"
  audit_record "needs-dispute" "skipped" "$slug" "$reason" 2>/dev/null || true
  return 1
}
