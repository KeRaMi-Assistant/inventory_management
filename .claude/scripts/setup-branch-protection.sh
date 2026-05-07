#!/usr/bin/env bash
# Einmaliges Setup: aktiviert Branch-Protection für `main` via gh API.
# Erfordert: `gh` CLI authenticated, `gh auth status` zeigt Login.
#
# Was es tut:
#   1. Aktiviert Auto-Merge im Repo (Setting)
#   2. Setzt Branch-Protection-Rule auf main:
#      - required status checks: flutter-ci, claude-review (PR Review)
#      - required PR reviews: 0 (du bist Solo-Maintainer)
#      - linear history forced
#      - admin enforcement off (du kannst notfalls direkt mergen)
#
# Idempotent: kann mehrfach laufen.

set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI missing — install via 'brew install gh'" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "gh not authenticated — run 'gh auth login' first" >&2
  exit 1
fi

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
echo "repo: $REPO"

echo "→ enabling auto-merge in repo settings…"
gh api -X PATCH "repos/$REPO" -f allow_auto_merge=true -f delete_branch_on_merge=true >/dev/null

echo "→ setting branch protection on main…"
gh api -X PUT "repos/$REPO/branches/main/protection" \
  -H "Accept: application/vnd.github+json" \
  --input - <<'JSON' >/dev/null
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["flutter-ci", "code-review"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false
  },
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "restrictions": null
}
JSON

echo "✓ branch-protection on main set."
echo
echo "next steps:"
echo "  - PRs müssen ab jetzt grünen 'flutter-ci' und 'code-review' Check haben."
echo "  - Auto-Merge aktivierst du pro PR via 'gh pr merge --auto --squash'."
echo "  - Im Browser: github.com/$REPO/settings/branches"
