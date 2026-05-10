#!/usr/bin/env bash
# audit-record.sh — CLI wrapper for audit_record from lib/audit.sh.
#
# Usage: audit-record.sh <actor> <action> <subject> <reason>
#
# IMPORTANT: This file is in the Self-Mod-Blocklist — do NOT modify at runtime.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/audit.sh
source "${SCRIPT_DIR}/lib/audit.sh"

audit_record "$@"
