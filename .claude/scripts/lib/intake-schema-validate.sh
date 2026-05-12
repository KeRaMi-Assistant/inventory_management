#!/usr/bin/env bash
# intake-schema-validate.sh — stdlib-only YAML-frontmatter validator for intake files
# Usage: source this file, then call: validate_intake_file <type> <file>
# type ∈ {pending-proposal, pending-approval, rejected, superseded}
# Returns: 0 = valid, 1 = invalid

SCHEMAS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../schemas" && pwd)"

validate_intake_file() {
  local type="$1"
  local file="$2"

  if [[ -z "$type" || -z "$file" ]]; then
    echo "ERROR: usage: validate_intake_file <type> <file>" >&2
    return 1
  fi

  local valid_types=("pending-proposal" "pending-approval" "rejected" "superseded")
  local found=0
  for t in "${valid_types[@]}"; do
    [[ "$t" == "$type" ]] && found=1
  done
  if [[ $found -eq 0 ]]; then
    echo "ERROR: unknown type '$type'. Must be one of: ${valid_types[*]}" >&2
    return 1
  fi

  if [[ ! -f "$file" ]]; then
    echo "ERROR: file not found: $file" >&2
    return 1
  fi

  local schema="$SCHEMAS_DIR/intake-${type}.schema.json"
  if [[ ! -f "$schema" ]]; then
    echo "ERROR: schema not found: $schema" >&2
    return 1
  fi

  # Extract YAML frontmatter (between first two --- lines)
  local frontmatter
  frontmatter=$(python3 - "$file" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Extract content between first --- and second ---
m = re.match(r'^---\r?\n(.*?)\r?\n---\r?\n', content, re.DOTALL)
if not m:
    print("", end="")
    sys.exit(1)
print(m.group(1))
PYEOF
)

  if [[ $? -ne 0 || -z "$frontmatter" ]]; then
    echo "INVALID: no YAML frontmatter found in $file" >&2
    return 1
  fi

  # Convert YAML frontmatter to JSON and validate per-field
  python3 - "$frontmatter" "$schema" <<'PYEOF'
import sys, json, re

frontmatter = sys.argv[1]
schema_path = sys.argv[2]

with open(schema_path, "r") as f:
    schema = json.load(f)

# Parse simple YAML frontmatter (no nested objects beyond lists)
def parse_simple_yaml(text):
    data = {}
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip() or line.strip().startswith("#"):
            i += 1
            continue

        # Key-value
        m = re.match(r'^(\w+):\s*(.*)', line)
        if not m:
            i += 1
            continue

        key = m.group(1)
        val = m.group(2).strip()

        # List detection: value is empty and next lines start with '  -'
        if val == "" and i + 1 < len(lines) and re.match(r'^\s+-', lines[i+1]):
            items = []
            i += 1
            while i < len(lines) and re.match(r'^\s+-\s*(.*)', lines[i]):
                item_val = re.match(r'^\s+-\s*(.*)', lines[i]).group(1).strip()
                items.append(item_val)
                i += 1
            data[key] = items
            continue

        # Inline list: [a, b, c]
        if val.startswith("["):
            inner = val.strip("[]")
            if inner.strip() == "":
                data[key] = []
            else:
                data[key] = [x.strip().strip('"').strip("'") for x in inner.split(",")]
            i += 1
            continue

        # Boolean
        if val.lower() == "true":
            data[key] = True
        elif val.lower() == "false":
            data[key] = False
        elif val.lower() in ("null", "~", ""):
            data[key] = None
        else:
            # Try int
            try:
                data[key] = int(val)
            except ValueError:
                # Try float
                try:
                    data[key] = float(val)
                except ValueError:
                    # String: strip quotes
                    data[key] = val.strip('"').strip("'")

        i += 1

    return data

def validate_field(key, value, prop_schema, required_fields):
    errors = []

    # Type check
    expected_types = prop_schema.get("type")
    if expected_types:
        if isinstance(expected_types, str):
            expected_types = [expected_types]

        type_map = {
            "string": str,
            "integer": int,
            "number": (int, float),
            "boolean": bool,
            "array": list,
            "null": type(None),
        }

        matched = False
        for t in expected_types:
            if t == "number":
                if isinstance(value, (int, float)) and not isinstance(value, bool):
                    matched = True
            elif t == "null":
                if value is None:
                    matched = True
            elif t in type_map:
                if isinstance(value, type_map[t]) and not (t == "integer" and isinstance(value, bool)):
                    matched = True
        if not matched:
            errors.append(f"  field '{key}': expected type {expected_types}, got {type(value).__name__} ({repr(value)})")

    # Const
    if "const" in prop_schema and value != prop_schema["const"]:
        errors.append(f"  field '{key}': must be {repr(prop_schema['const'])}, got {repr(value)}")

    # Enum
    if "enum" in prop_schema and value not in prop_schema["enum"]:
        errors.append(f"  field '{key}': must be one of {prop_schema['enum']}, got {repr(value)}")

    # Pattern (only for strings)
    if "pattern" in prop_schema and isinstance(value, str):
        if not re.match(prop_schema["pattern"], value):
            errors.append(f"  field '{key}': value {repr(value)} does not match pattern {prop_schema['pattern']}")

    # MinLength
    if "minLength" in prop_schema and isinstance(value, str):
        if len(value) < prop_schema["minLength"]:
            errors.append(f"  field '{key}': minLength {prop_schema['minLength']}, got {len(value)}")

    # Minimum (numbers/integers)
    if "minimum" in prop_schema and isinstance(value, (int, float)):
        if value < prop_schema["minimum"]:
            errors.append(f"  field '{key}': minimum {prop_schema['minimum']}, got {value}")

    # Maximum
    if "maximum" in prop_schema and isinstance(value, (int, float)):
        if value > prop_schema["maximum"]:
            errors.append(f"  field '{key}': maximum {prop_schema['maximum']}, got {value}")

    # Array items
    if "items" in prop_schema and isinstance(value, list):
        item_schema = prop_schema["items"]
        for idx, item in enumerate(value):
            item_errors = validate_field(f"{key}[{idx}]", item, item_schema, [])
            errors.extend(item_errors)

    return errors

try:
    data = parse_simple_yaml(frontmatter)
except Exception as e:
    print(f"PARSE ERROR: {e}", file=sys.stderr)
    sys.exit(1)

properties = schema.get("properties", {})
required = schema.get("required", [])
additional = schema.get("additionalProperties", True)

errors = []

# Check required fields
for req in required:
    if req not in data:
        errors.append(f"  missing required field: '{req}'")

# Validate present fields
for key, value in data.items():
    if key in properties:
        field_errors = validate_field(key, value, properties[key], required)
        errors.extend(field_errors)
    elif additional is False:
        errors.append(f"  additional field not allowed: '{key}'")

if errors:
    print("INVALID:")
    for e in errors:
        print(e)
    sys.exit(1)
else:
    print("VALID")
    sys.exit(0)
PYEOF
}
