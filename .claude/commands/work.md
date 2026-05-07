---
description: Arbeitet einen existierenden Plan ab — orchestriert Coder-Subagenten
argument-hint: <plan-file-pfad>
---

Lies den Plan unter: $ARGUMENTS

Arbeite die Tasks der Reihe nach ab:
1. Identifiziere den passenden Subagenten pro Task (`flutter-coder`, `ui-builder`, `db-migrator`, `edge-fn-coder`).
2. Delegiere parallel, wo Tasks unabhängig sind. Sequenziell, wo Abhängigkeiten bestehen (Migration vor Provider, Provider vor Screen).
3. Nach jedem Task: Markiere ihn im Plan mit `[x]`.
4. Wenn alle Tasks `[x]` sind: rufe `tester` auf.
5. Wenn `tester` grün: rufe `security-reviewer` auf.
6. Bei `verdict: pass` oder `warn`: melde "ready to ship — `/ship` aufrufen".
7. Bei `verdict: block`: lass `flutter-coder` die Findings fixen und Loop ab Schritt 4.

Schreibe vor jedem Subagent-Call die Task-Beschreibung in `.claude/last-task.txt` (für den Auto-Commit).
