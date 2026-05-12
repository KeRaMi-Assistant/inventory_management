#!/usr/bin/env bash
# repair-pending-approval.sh — One-shot helper to repair a pending-approval
# file whose `## Vorgeschlagenes Backlog-Item` section is empty (Bug 1
# legacy fallout). Synthesizes a default backlog-item-YAML from the slug +
# Proponent's "Empfohlene Implementation" + Skeptic's "Empfohlene
# Mitigations" sections.
#
# Usage:
#   bash .claude/scripts/repair-pending-approval.sh <id>
#
# Idempotent: if the section is already populated, prints a notice and
# exits 0 without changes. Heavy lifting is in Python to keep multiline
# text handling safe.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PENDING_APPROVAL_DIR="${PENDING_APPROVAL_DIR:-$REPO_ROOT/.claude/stakeholder/pending-approval}"

die() { printf '[repair-pending-approval] ERROR: %s\n' "$*" >&2; exit 1; }

[ $# -ge 1 ] || die "Usage: $0 <id>"
ID="$1"
FILE="$PENDING_APPROVAL_DIR/${ID}.md"
[ -f "$FILE" ] || die "Pending-Approval-File nicht gefunden: $FILE"

python3 - "$FILE" "$ID" <<'PY'
import sys, re, datetime, pathlib

path = pathlib.Path(sys.argv[1])
full_id = sys.argv[2]
slug = re.sub(r'^[0-9]{8}-[0-9]{6}-', '', full_id) or full_id

content = path.read_text(encoding='utf-8')
lines = content.splitlines()

def extract_section(lines, heading_prefix, stop_prefixes):
    """Return body lines of a section starting at a line beginning with
    heading_prefix, ending at the next line starting with any stop_prefix."""
    out = []
    in_section = False
    for ln in lines:
        if not in_section and ln.startswith(heading_prefix):
            in_section = True
            continue
        if in_section:
            if any(ln.startswith(p) for p in stop_prefixes):
                break
            out.append(ln)
    return out

# Existing backlog-item section
backlog = [l for l in extract_section(lines, '## Vorgeschlagenes Backlog-Item', ['## '])
           if l.strip()]
if backlog:
    print(f'[repair-pending-approval] Backlog-Item bereits befüllt — keine Änderung.',
          file=sys.stderr)
    sys.exit(0)

proponent_impl = extract_section(lines, '### Empfohlene Implementation',
                                 ['### ', '## '])
skeptic_mit = extract_section(lines, '### Empfohlene Mitigations',
                              ['### ', '## '])

# Heuristic touches: gather lib/, supabase/, test/ paths from the
# proponent-implementation block.
joined = '\n'.join(proponent_impl)
candidates = sorted(set(re.findall(r'\b(?:lib|supabase|test)/[A-Za-z0-9_./-]+',
                                    joined)))
# Trim trailing punctuation
candidates = [c.rstrip('.,;:`') for c in candidates]
if not candidates:
    candidates = ['lib/']
touches_yaml = '[' + ', '.join(f'"{c}"' for c in candidates) + ']'

iso_now = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')

prop_block = '\n'.join(proponent_impl).strip() or '(kein Proponent-Block gefunden)'
skep_block = '\n'.join(skeptic_mit).strip() or '(kein Skeptic-Mitigations-Block gefunden)'

backlog_block = f"""```yaml
---
slug: {slug}
source: tier-3-intake
priority: 2
budget_usd: 5.0
model: sonnet
touches: {touches_yaml}
needs_gh: false
created_from: intake-council
verdict: propose
requires_human_dispute: false
repaired_at: {iso_now}
repaired_by: repair-pending-approval.sh
---

## Aufgabe

{slug} — synthetisiert aus Council-Round-1 (Proponent + Skeptic).
Der ursprüngliche Pragmatist-Lauf hat das Backlog-Item nicht generiert
(Bug 1: pre-fix Council-Konsens-Pfad sprang Pragmatist).

### Empfohlene Implementation (aus Proponent)

{prop_block}

### Mitigations (aus Skeptic)

{skep_block}

## Acceptance

- [ ] dart analyze lib/ ohne neue Fehler
- [ ] flutter test grün
- [ ] smoke-full-app-audit grün (UI-Änderung)
- [ ] DE+EN ARB-Keys symmetrisch
```"""

# Replace the empty section body. The section ends at the next `## ` heading.
new_lines = []
i = 0
replaced = False
while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    if not replaced and line.startswith('## Vorgeschlagenes Backlog-Item'):
        # Skip any blank lines that were the empty body, find next `## ` heading
        new_lines.append('')
        new_lines.append(backlog_block)
        new_lines.append('')
        # Advance past existing (empty/whitespace) body up to next `## `
        j = i + 1
        while j < len(lines) and not lines[j].startswith('## '):
            j += 1
        i = j
        replaced = True
        continue
    i += 1

path.write_text('\n'.join(new_lines) + '\n', encoding='utf-8')
print(f'[repair-pending-approval] Repaired: {path}', file=sys.stderr)
print(f'[repair-pending-approval]   slug={slug}', file=sys.stderr)
print(f'[repair-pending-approval]   touches={touches_yaml}', file=sys.stderr)
PY
