#!/usr/bin/env bash
# picker.sh — Sourceable library for atomic-move-picker with race-condition protection.
#
# Usage: source this file, then call:
#   pick_next_item <pid>          → echoes new in_progress path; exit 1 if nothing available
#   release_item <path> <result>  → result: done | failed | blocked-pre-ship | merge-conflict
#   recover_orphaned_items        → returns orphans to inbox; echoes recovery count
#   extract_touches <path>        → echoes touches array items (one per line)
#   paths_overlap <list-a> <list-b> → exit 0 if overlap, exit 1 if no overlap
#
# Directories operated on: .claude/overseer/{inbox,in_progress,done,failed,...}
# IMPORTANT: This file is in the Self-Mod-Blocklist — do NOT modify at runtime.

set -u

# ---------------------------------------------------------------------------
# _picker_overseer_root — resolve overseer base dir
# ---------------------------------------------------------------------------
_picker_overseer_root() {
  local base
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    base="${CLAUDE_PROJECT_DIR}/.claude/overseer"
  else
    local repo_root
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    base="${repo_root}/.claude/overseer"
  fi
  echo "$base"
}

# ---------------------------------------------------------------------------
# extract_touches <path>
# Reads YAML frontmatter from file, extracts touches: list.
# Outputs one path/glob per line. Returns exit 1 if no touches: field found.
# ---------------------------------------------------------------------------
extract_touches() {
  local file="$1"
  if [ ! -f "$file" ]; then
    printf 'extract_touches: ERROR: file not found: %s\n' "$file" >&2
    return 1
  fi

  # Use python3 for reliable YAML frontmatter parsing
  python3 - "$file" <<'PYEOF'
import sys
import re

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Extract YAML frontmatter between --- ... ---
fm_match = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
if not fm_match:
    sys.exit(1)

fm = fm_match.group(1)

# Find touches: field — supports block list or inline list
# Block list:
#   touches:
#     - foo
#     - bar
# Inline list:
#   touches: [foo, bar]
items = []
in_touches = False
for line in fm.split('\n'):
    if re.match(r'^touches\s*:', line):
        in_touches = True
        # Check for inline list: touches: [a, b]
        inline = re.search(r'touches\s*:\s*\[(.+)\]', line)
        if inline:
            for item in inline.group(1).split(','):
                item = item.strip().strip('"').strip("'")
                if item:
                    items.append(item)
            in_touches = False
        else:
            # Check for inline scalar: touches: somepath
            scalar = re.match(r'^touches\s*:\s*(\S.*)$', line)
            if scalar:
                val = scalar.group(1).strip().strip('"').strip("'")
                if val and val != '':
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
# _get_frontmatter_field <file> <field>
# Returns value of a scalar YAML frontmatter field.
# ---------------------------------------------------------------------------
_get_frontmatter_field() {
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
        print(m.group(1).strip().strip('"').strip("'"))
        sys.exit(0)
sys.exit(1)
PYEOF
}

# ---------------------------------------------------------------------------
# paths_overlap <list-a-lines> <list-b-lines>
# Both arguments are newline-separated lists of path globs/prefixes.
# Returns 0 if any entry in a is a prefix of any entry in b, or vice versa,
# or if any two entries are equal.
# ---------------------------------------------------------------------------
paths_overlap() {
  local list_a="$1"
  local list_b="$2"

  # Read into arrays
  local -a arr_a arr_b
  while IFS= read -r line; do
    [[ -n "$line" ]] && arr_a+=("$line")
  done <<< "$list_a"

  while IFS= read -r line; do
    [[ -n "$line" ]] && arr_b+=("$line")
  done <<< "$list_b"

  for a in "${arr_a[@]:-}"; do
    [[ -z "$a" ]] && continue
    for b in "${arr_b[@]:-}"; do
      [[ -z "$b" ]] && continue
      # Match if either is a prefix of the other or they are equal
      if [[ "$a" == "$b" ]] || [[ "$b" == "$a"* ]] || [[ "$a" == "$b"* ]]; then
        return 0
      fi
    done
  done
  return 1
}

# ---------------------------------------------------------------------------
# pick_next_item <pid>
# Picks next available item from overseer/inbox that does not conflict with
# any currently in-progress item's touches.
# Echoes the new in_progress path on success.
# Exits 1 if nothing available (all locked, all skipped, or inbox empty).
# ---------------------------------------------------------------------------
pick_next_item() {
  local pid="${1:?pick_next_item requires PID argument}"
  local overseer_root
  overseer_root="$(_picker_overseer_root)"
  local inbox_dir="${overseer_root}/inbox"
  local inprogress_dir="${overseer_root}/in_progress"

  mkdir -p "$inbox_dir" "$inprogress_dir"

  # Collect all in-progress touches for overlap check
  local inprogress_touches_all=""
  if compgen -G "${inprogress_dir}/*.md" > /dev/null 2>&1; then
    for ip_file in "${inprogress_dir}"/*.md; do
      local ip_touches
      ip_touches="$(extract_touches "$ip_file" 2>/dev/null || true)"
      if [ -n "$ip_touches" ]; then
        inprogress_touches_all="${inprogress_touches_all}${ip_touches}"$'\n'
      fi
    done
  fi

  # Collect inbox items sorted
  local -a inbox_items=()
  if compgen -G "${inbox_dir}/*.md" > /dev/null 2>&1; then
    while IFS= read -r f; do
      inbox_items+=("$f")
    done < <(find "$inbox_dir" -maxdepth 1 -name "*.md" | sort)
  fi

  if [ ${#inbox_items[@]} -eq 0 ]; then
    return 1
  fi

  for item_path in "${inbox_items[@]}"; do
    local basename
    basename="$(basename "$item_path")"
    local slug="${basename%.md}"

    # Check tier-1 / bypass_touches
    local source_val bypass_val
    source_val="$(_get_frontmatter_field "$item_path" "source" 2>/dev/null || true)"
    bypass_val="$(_get_frontmatter_field "$item_path" "bypass_touches" 2>/dev/null || true)"

    local is_tier1=0
    if [[ "$source_val" == "tier-1" ]] || [[ "$bypass_val" == "true" ]]; then
      is_tier1=1
    fi

    # Extract touches
    local item_touches
    item_touches="$(extract_touches "$item_path" 2>/dev/null || true)"

    if [ -z "$item_touches" ] && [ "$is_tier1" -eq 0 ]; then
      printf '[picker] WARNING: skipping item without touches: field (not tier-1): %s\n' "$basename" >&2
      continue
    fi

    # Check for overlap with in-progress items (skip tier-1 bypass for overlap check too)
    if [ -n "$item_touches" ] && [ -n "$inprogress_touches_all" ]; then
      if paths_overlap "$item_touches" "$inprogress_touches_all"; then
        # Soft lock: skip this item
        continue
      fi
    fi

    # Attempt atomic move
    local target_path="${inprogress_dir}/${slug}.${pid}.md"
    if mv "$item_path" "$target_path" 2>/dev/null; then
      echo "$target_path"
      return 0
    fi
    # mv failed (race: another picker was faster) → try next item
    continue
  done

  # Nothing available
  return 1
}

# ---------------------------------------------------------------------------
# release_item <path> <result>
# result: done | failed | blocked-pre-ship | merge-conflict
# ---------------------------------------------------------------------------
release_item() {
  local item_path="${1:?release_item requires path}"
  local result="${2:?release_item requires result (done|failed|blocked-pre-ship|merge-conflict)}"

  local overseer_root
  overseer_root="$(_picker_overseer_root)"

  local basename
  basename="$(basename "$item_path")"

  case "$result" in
    done|failed)
      local target_dir="${overseer_root}/${result}"
      mkdir -p "$target_dir"
      local target_path="${target_dir}/${basename}"
      mv "$item_path" "$target_path"
      _picker_audit_record "picker" "release_item" "$basename" "result=${result}"
      ;;
    blocked-pre-ship|merge-conflict)
      # Return to inbox with marker in filename (Mitigation 9, 15)
      local inbox_dir="${overseer_root}/inbox"
      mkdir -p "$inbox_dir"
      # Strip existing PID suffix and add marker
      local slug="${basename%.md}"
      # Remove trailing .<digits> PID suffix if present
      slug="$(printf '%s' "$slug" | sed 's/\.[0-9][0-9]*$//')"
      local marker_slug="[${result}]-${slug}"
      local target_path="${inbox_dir}/${marker_slug}.md"
      mv "$item_path" "$target_path"
      _picker_audit_record "picker" "release_item" "$basename" "result=${result} → returned to inbox as ${marker_slug}.md"
      ;;
    *)
      printf 'release_item: ERROR: unknown result "%s". Use: done|failed|blocked-pre-ship|merge-conflict\n' "$result" >&2
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# recover_orphaned_items
# Scans in_progress for items whose PID is no longer alive.
# Moves them back to inbox with [recovered] marker.
# Echoes count of recovered items.
# ---------------------------------------------------------------------------
recover_orphaned_items() {
  local overseer_root
  overseer_root="$(_picker_overseer_root)"
  local inprogress_dir="${overseer_root}/in_progress"
  local inbox_dir="${overseer_root}/inbox"

  mkdir -p "$inprogress_dir" "$inbox_dir"

  local count=0

  if ! compgen -G "${inprogress_dir}/*.md" > /dev/null 2>&1; then
    echo "$count"
    return 0
  fi

  for ip_file in "${inprogress_dir}"/*.md; do
    local basename
    basename="$(basename "$ip_file")"
    # Extract PID from filename: <slug>.<pid>.md
    local pid
    pid="$(printf '%s' "${basename%.md}" | grep -oE '\.[0-9]+$' | tr -d '.')"

    if [ -z "$pid" ]; then
      # No PID in filename — skip (not a normal in_progress item)
      continue
    fi

    # Check if PID is alive
    if kill -0 "$pid" 2>/dev/null; then
      # Process still alive — not orphaned
      continue
    fi

    # Process dead — recover
    local slug="${basename%.md}"
    # Remove trailing .<pid> suffix
    slug="$(printf '%s' "$slug" | sed 's/\.[0-9][0-9]*$//')"
    local recovered_name="[recovered]-${slug}.md"
    local target_path="${inbox_dir}/${recovered_name}"

    if mv "$ip_file" "$target_path" 2>/dev/null; then
      count=$((count + 1))
      _picker_audit_record "picker" "recover_orphaned" "$basename" "pid=${pid} dead; recovered to inbox as ${recovered_name}"
    fi
  done

  echo "$count"
}

# ---------------------------------------------------------------------------
# _picker_audit_record — call audit.sh if available, else no-op
# ---------------------------------------------------------------------------
_picker_audit_record() {
  local actor="$1" action="$2" subject="$3" reason="$4"
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local audit_lib="${lib_dir}/audit.sh"
  if [ -f "$audit_lib" ]; then
    # Source in subshell to avoid polluting caller
    (
      # shellcheck source=audit.sh
      source "$audit_lib"
      audit_record "$actor" "$action" "$subject" "$reason"
    ) 2>/dev/null || true
  fi
}
