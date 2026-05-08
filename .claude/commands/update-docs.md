---
description: Aktualisiert das Handbook (`docs/handbook/`) inkrementell auf Basis des aktuellen Diffs via doc-updater-Agent
argument-hint: [--apply] [--from <ref>] [--paths "<glob ...>"] [--chapters "<03 06>"] [--strict]
---

Rufe den `doc-updater`-Subagenten mit folgender Aufgabe auf:

> Aktualisiere das Handbuch (`docs/handbook/`) auf Basis der aktuellen
> Code-Änderungen.
>
> 1. Lies CLAUDE.md.
> 2. Wenn `docs/handbook/` nicht existiert: gib genau
>    `[BLOCKER] docs/handbook/ existiert nicht — siehe Backlog-Task #03 (create-app-documentation-book).`
>    aus und stoppe.
> 3. Default-Diff-Quelle: `git diff main...HEAD --name-status`. Falls leer:
>    Fallback `git diff HEAD~1 --name-status`. `--from <ref>` aus
>    `$ARGUMENTS` überschreibt das.
> 4. Klassifiziere jede Pfad-Änderung anhand der Kapitel-Map aus deinem
>    System-Prompt. Pfade ohne Match in `## Unklassifiziert` aufnehmen.
> 5. Modus:
>    - **Default (kein `--apply`):** dry-run — Plan + geplante Diff-Snippets
>      nur. Schreibe **nichts**.
>    - **`--apply` in `$ARGUMENTS`:** Edits durchführen. Inkrementell, nicht
>      Komplett-Rewrite. Glossar-Eintrag bei neuem Begriff alphabetisch
>      einsortieren + verlinken.
> 6. `--strict` setzt exit 1 bei `unclassified_paths > 0`.
> 7. Antworte mit dem strukturierten Result-Block (`## doc-updater Result`)
>    und pro aktualisiertem Kapitel einem 3-Zeilen-Diff-Snippet.
>
> Hard-Constraints aus CLAUDE.md beachten: keine Edits in `lib/` oder
> `supabase/`, kein `git add`/`git commit`, keine Secrets im Output, keine
> Komplett-Rewrites. Wenn die Faktenlage aus dem Diff nicht reicht, setze
> `> TODO:` Marker im Doku-Text statt zu raten.
>
> Argumente vom Caller: `$ARGUMENTS` 1:1 durchreichen.
