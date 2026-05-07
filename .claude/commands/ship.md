---
description: Final-Check + Commit + Push + PR öffnen
argument-hint: [optionaler PR-Titel]
---

Du shipst den aktuellen Feature-Branch.

1. Prüfe Branch: `git branch --show-current`. Wenn `main`: ABORT mit Hinweis, dass ein Feature-Branch nötig ist.
2. Führe aus: `flutter analyze` und `flutter test`. Bei Fehlern: ABORT, melde Fehler.
3. Rufe `security-reviewer` auf. Bei `verdict: block`: ABORT, liste Findings.
4. Wenn alles grün:
   - Whitelist-Add: `git add lib/ supabase/migrations/ supabase/functions/ test/ pubspec.yaml pubspec.lock plans/ .github/ CLAUDE.md .claude/agents/ .claude/commands/ .claude/scripts/ .claude/settings.json`
   - Commit-Message generieren aus dem letzten Plan-Titel oder $ARGUMENTS
   - `git commit` mit Co-Authored-By-Line
   - `git push -u origin <branch>`
5. PR erstellen mit `gh pr create --base main`:
   - Title: $ARGUMENTS oder erste Zeile der letzten Commit-Message
   - Body: Summary aus dem Plan + Test-Plan-Checkliste
6. Auto-Merge aktivieren: `gh pr merge --auto --squash --delete-branch`
   - Wenn das Repo Auto-Merge nicht erlaubt (Settings), failed der Befehl
     mit klarer Fehlermeldung — tolerier das, gib User Hinweis.
   - Wenn der Branch keine Required-Checks hat: kein Problem, merged
     wenn CI grün ist.

Gib am Ende die PR-URL zurück, plus Status: "auto-merge enabled" oder
"auto-merge nicht möglich (Repo-Setting)".
