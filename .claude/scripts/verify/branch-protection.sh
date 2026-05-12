#!/usr/bin/env bash
# P4-2 Verify: Branch-Protection auf main mit Required Status Checks aktiv.
# Mitigation 10 (Plan Z. 742-751).
#
# Exit 0 = ok, exit 1 = fehlende Konfiguration.

set -uo pipefail

REPO="${GH_REPO:-KeRaMi-Assistant/inventory_management}"

if ! command -v gh >/dev/null 2>&1; then
  echo "[branch-protection] gh CLI fehlt — SKIP" >&2
  exit 0
fi

PROTECTION_JSON="$(gh api "repos/$REPO/branches/main/protection" 2>/dev/null)"
if [ -z "$PROTECTION_JSON" ] || ! printf '%s' "$PROTECTION_JSON" | python3 -c 'import json,sys; json.load(sys.stdin)' >/dev/null 2>&1; then
  echo "FAIL: Keine Branch-Protection auf main aktiv." >&2
  exit 1
fi

FAIL=0

# Required Status Checks
CHECKS="$(printf '%s' "$PROTECTION_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join(c["context"] for c in d.get("required_status_checks",{}).get("checks",[])))')"
if [ -z "$CHECKS" ]; then
  echo "FAIL: Keine required status checks konfiguriert." >&2
  FAIL=1
else
  echo "PASS: required status checks = $CHECKS"
fi

# Strict (= up-to-date branch required)
STRICT="$(printf '%s' "$PROTECTION_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("required_status_checks",{}).get("strict",False))')"
echo "INFO: strict = $STRICT"

# Linear history (verhindert merge-commits — auto-merge-pr.sh nutzt squash, kompatibel)
LINEAR="$(printf '%s' "$PROTECTION_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("required_linear_history",{}).get("enabled",False))')"
if [ "$LINEAR" = "True" ]; then
  echo "PASS: linear history enforced"
else
  echo "INFO: linear history NOT enforced (optional)"
fi

# Force-push blocked
NOFORCE="$(printf '%s' "$PROTECTION_JSON" | python3 -c 'import json,sys; print(not json.load(sys.stdin).get("allow_force_pushes",{}).get("enabled",True))')"
if [ "$NOFORCE" = "True" ]; then
  echo "PASS: force-push blocked"
else
  echo "FAIL: force-push allowed on main!" >&2
  FAIL=1
fi

# Deletions blocked
NODELETE="$(printf '%s' "$PROTECTION_JSON" | python3 -c 'import json,sys; print(not json.load(sys.stdin).get("allow_deletions",{}).get("enabled",True))')"
if [ "$NODELETE" = "True" ]; then
  echo "PASS: deletions blocked"
else
  echo "FAIL: branch-deletion allowed!" >&2
  FAIL=1
fi

# enforce_admins NICHT enabled (sonst MERGE_ADMIN_OVERRIDE-Pfad tot)
ENFORCE_ADMIN="$(printf '%s' "$PROTECTION_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("enforce_admins",{}).get("enabled",False))')"
if [ "$ENFORCE_ADMIN" = "False" ]; then
  echo "PASS: enforce_admins=false (Stakeholder-Override via --admin möglich, Mitigation 10)"
else
  echo "WARN: enforce_admins=true → MERGE_ADMIN_OVERRIDE-Pfad blockiert" >&2
fi

if [ "$FAIL" -eq 0 ]; then
  echo "--- branch-protection: OK ---"
  exit 0
else
  echo "--- branch-protection: FAIL ---" >&2
  exit 1
fi
