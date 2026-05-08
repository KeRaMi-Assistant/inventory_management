#!/usr/bin/env python3
"""l10n consistency checker.

Checks:
  1. ARB-symmetry between lib/l10n/app_de.arb and lib/l10n/app_en.arb
  2. Placeholder symmetry (e.g. {name}, {count}) per key
  3. ARB JSON validity + @key metadata sanity
  4. Hardcoded German UI strings in lib/

Usage:
  python3 .claude/scripts/check-l10n.py            # report-only
  python3 .claude/scripts/check-l10n.py --fix      # auto-fill missing EN keys with [TODO en] DE-fallback
  python3 .claude/scripts/check-l10n.py --json     # JSON output instead of markdown
  python3 .claude/scripts/check-l10n.py --no-hardcoded  # skip hardcoded-string scan

Exit code:
  0 — no findings
  1 — at least one finding (missing key, placeholder mismatch, hardcoded string, JSON error)
  2 — invocation/IO error
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import date

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DE_ARB = os.path.join(ROOT, "lib", "l10n", "app_de.arb")
EN_ARB = os.path.join(ROOT, "lib", "l10n", "app_en.arb")
LIB_DIR = os.path.join(ROOT, "lib")

# Files we never scan for hardcoded strings (generated, l10n itself, examples).
SKIP_FILES = (
    "app_localizations.dart",
    "app_localizations_de.dart",
    "app_localizations_en.dart",
)
SKIP_DIRS = ("l10n",)

# Hardcoded-string detection: Dart UI constructors / param names that take user-visible text,
# followed by a German-looking literal (starts with capital incl. umlaut, has lowercase + space).
# Conservative pattern — false positives are noisy, false negatives we accept.
HARDCODED_RE = re.compile(
    r"""(?P<head>\b(?:Text|Tooltip|SnackBar|AlertDialog)\s*\(\s*|"""
    r"""(?:tooltip|hintText|labelText|helperText|errorText|message|title|content|semanticLabel|placeholder)\s*:\s*)"""
    r"""(?P<q>['"])(?P<text>[A-ZÄÖÜ][A-Za-zÄÖÜäöüß0-9][A-Za-zÄÖÜäöüß0-9 ,.!?\-:]{2,80})(?P=q)""",
)

# Heuristic: text containing typical German tokens or umlauts is German.
GERMAN_HINTS_RE = re.compile(r"[ÄÖÜäöüß]|\b(?:der|die|das|und|oder|nicht|ist|wird|werden|für|mit|von|zum|zur|kein|keine|Speichern|Abbrechen|Löschen|Bearbeiten|Hinzufügen|Schließen|Zurück|Ausgewählt|Bestätigen)\b")

PLACEHOLDER_RE = re.compile(r"\{(\w+)\}")


def load_arb(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def write_arb(path: str, data: dict) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def real_keys(arb: dict) -> set[str]:
    return {k for k in arb if not k.startswith("@")}


def placeholders_in(value) -> set[str]:
    if not isinstance(value, str):
        return set()
    return set(PLACEHOLDER_RE.findall(value))


def scan_hardcoded(root: str) -> list[dict]:
    findings: list[dict] = []
    for dirpath, dirnames, filenames in os.walk(root):
        # prune skip dirs in-place
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            if not fn.endswith(".dart"):
                continue
            if fn.endswith("_test.dart") or fn in SKIP_FILES:
                continue
            fp = os.path.join(dirpath, fn)
            rel = os.path.relpath(fp, ROOT)
            try:
                with open(fp, "r", encoding="utf-8") as f:
                    for i, line in enumerate(f, 1):
                        stripped = line.lstrip()
                        if stripped.startswith("//") or stripped.startswith("///"):
                            continue
                        for m in HARDCODED_RE.finditer(line):
                            text = m.group("text")
                            if not GERMAN_HINTS_RE.search(text):
                                continue
                            findings.append({
                                "file": rel,
                                "line": i,
                                "snippet": line.strip(),
                                "text": text,
                            })
            except (OSError, UnicodeDecodeError):
                continue
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description="Check l10n consistency for inventory_management.")
    parser.add_argument(
        "--fix",
        action="store_true",
        help="Auto-add missing EN keys with '[TODO en] <DE>' fallback marker.",
    )
    parser.add_argument(
        "--json",
        dest="json_out",
        action="store_true",
        help="Output JSON instead of markdown.",
    )
    parser.add_argument(
        "--no-hardcoded",
        action="store_true",
        help="Skip hardcoded-string scan (ARB-symmetry only).",
    )
    args = parser.parse_args()

    try:
        de = load_arb(DE_ARB)
        en = load_arb(EN_ARB)
    except FileNotFoundError as e:
        print(f"ERROR: ARB file not found: {e}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as e:
        print(f"ERROR: ARB JSON invalid: {e}", file=sys.stderr)
        return 2

    de_keys = real_keys(de)
    en_keys = real_keys(en)

    missing_in_en = sorted(de_keys - en_keys)
    missing_in_de = sorted(en_keys - de_keys)

    placeholder_mismatch: list[dict] = []
    for k in sorted(de_keys & en_keys):
        de_ph = placeholders_in(de.get(k))
        en_ph = placeholders_in(en.get(k))
        if de_ph != en_ph:
            placeholder_mismatch.append({
                "key": k,
                "de": sorted(de_ph),
                "en": sorted(en_ph),
            })

    # Optional: validate that @key metadata exists for keys that use placeholders
    metadata_warnings: list[str] = []
    for k in sorted(de_keys):
        if placeholders_in(de.get(k)) and f"@{k}" not in de:
            metadata_warnings.append(f"DE: @{k} metadata missing for key with placeholders")
    for k in sorted(en_keys):
        if placeholders_in(en.get(k)) and f"@{k}" not in en:
            metadata_warnings.append(f"EN: @{k} metadata missing for key with placeholders")

    fixed_keys: list[str] = []
    if args.fix and missing_in_en:
        # Append missing keys to EN file using DE value with [TODO en] marker.
        for k in missing_in_en:
            en[k] = f"[TODO en] {de[k]}" if isinstance(de[k], str) else de[k]
            fixed_keys.append(k)
            # carry over @key metadata if present
            meta_key = f"@{k}"
            if meta_key in de and meta_key not in en:
                en[meta_key] = de[meta_key]
        write_arb(EN_ARB, en)

    hardcoded: list[dict] = []
    if not args.no_hardcoded:
        hardcoded = scan_hardcoded(LIB_DIR)

    findings_count = (
        len(missing_in_en)
        + len(missing_in_de)
        + len(placeholder_mismatch)
        + len(hardcoded)
    )
    has_findings = findings_count > 0

    if args.json_out:
        out = {
            "date": date.today().isoformat(),
            "de_keys": len(de_keys),
            "en_keys": len(en_keys),
            "missing_in_en": missing_in_en,
            "missing_in_de": missing_in_de,
            "placeholder_mismatch": placeholder_mismatch,
            "metadata_warnings": metadata_warnings,
            "hardcoded_strings": hardcoded,
            "fixed_keys": fixed_keys,
            "has_findings": has_findings,
        }
        print(json.dumps(out, ensure_ascii=False, indent=2))
    else:
        print(f"# l10n-checker Report — {date.today().isoformat()}")
        print()
        print(f"## Symmetry: DE: {len(de_keys)} keys, EN: {len(en_keys)} keys")
        print()
        if missing_in_en:
            print(f"## Missing in EN ({len(missing_in_en)})")
            for k in missing_in_en:
                print(f"- `{k}`")
            print()
        if missing_in_de:
            print(f"## Missing in DE ({len(missing_in_de)})")
            for k in missing_in_de:
                print(f"- `{k}`")
            print()
        if placeholder_mismatch:
            print(f"## Placeholder Mismatch ({len(placeholder_mismatch)})")
            for m in placeholder_mismatch:
                print(f"- `{m['key']}`: DE={m['de']} EN={m['en']}")
            print()
        if hardcoded:
            print(f"## Hardcoded strings ({len(hardcoded)})")
            for h in hardcoded:
                print(f"- {h['file']}:{h['line']} — {h['snippet']}")
            print()
        if metadata_warnings:
            print(f"## @-Metadata warnings ({len(metadata_warnings)})")
            for w in metadata_warnings:
                print(f"- {w}")
            print()
        if fixed_keys:
            print(f"## Auto-fixed ({len(fixed_keys)} EN keys with `[TODO en]` marker)")
            for k in fixed_keys:
                print(f"- `{k}`")
            print()
            print("> **Next step:** replace `[TODO en] <DE>` placeholders in `lib/l10n/app_en.arb` with proper translations.")
            print()
        if not has_findings:
            print("All checks passed.")

    return 1 if has_findings else 0


if __name__ == "__main__":
    sys.exit(main())
