---
description: Final-Check + Commit + Push + PR öffnen + sofort mergen
argument-hint: [optionaler PR-Titel]
---

Du shipst den aktuellen Feature-Branch — bis zum gemergten Stand auf
`main`. Pre-Launch, daher direktes Mergen erlaubt.

1. Prüfe Branch: `git branch --show-current`. Wenn `main`: ABORT.
2. Lokale Quality-Gates:
   - `flutter analyze` — bei Fehlern ABORT
   - `flutter test` — bei Fehlern ABORT
   - `security-reviewer` Subagent — bei `verdict: block` ABORT, Findings listen
3. Wenn alles grün:
   - Whitelist-Add: `git add lib/ supabase/migrations/ supabase/functions/ test/ pubspec.yaml pubspec.lock plans/ .github/ CLAUDE.md .claude/agents/ .claude/commands/ .claude/scripts/ .claude/settings.json .claude/backlog/templates/ .claude/launchagent.plist.template .mcp.json .gitignore .env.test.example .env.headless.example`
   - `git diff --cached --stat` — bevor Commit, sanity-check dass keine Secrets im Diff sind (`grep -nE "(supabase_config\\.dart|google-services\\.json|GoogleService-Info)" <(git diff --cached --name-only)` muss leer sein)
   - Commit-Message aus dem letzten Plan-Titel oder $ARGUMENTS, mit `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`
   - `git push -u origin <branch>`
4. PR erstellen via `gh pr create --base main`:
   - Title: $ARGUMENTS oder erste Zeile der Commit-Message
   - Body: Plan-Summary + Test-Plan-Checkliste (siehe `.github/pull_request_template.md`)
   - Notiere die PR-Nummer
5. **Direkt mergen** (Pre-Launch, lokale Gates haben bestanden):
   - `gh pr merge <pr-number> --squash --delete-branch`
   - Falls Merge fehlschlägt:
     - Konflikt mit main → ABORT, sag dem User welche Files konfliktieren — KEIN `git reset --hard`, KEIN auto-rebase
     - "Pull request is not mergeable" → versuche `git fetch origin main && git rebase origin/main`, dann re-push, dann nochmal mergen. Wenn das auch failed: ABORT mit klarer Fehlermeldung.
6. Lokal aufräumen: `git checkout main && git pull --ff-only`
7. Notification an User: `bash .claude/scripts/notify.sh "Claude ✅ shipped" "PR #<num> merged to main" success`

Gib zurück:
- PR-URL
- Status: `merged ✅` oder `open ❌ <reason>`
- Aktuell ausgecheckter Branch (sollte `main` sein nach Erfolg)
