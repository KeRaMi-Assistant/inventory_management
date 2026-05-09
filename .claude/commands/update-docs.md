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
> 5. **Page-Registry-Pflege (PFLICHT):** Zusätzlich zum Handbuch
>    `_page-registry.md` synchron halten. Aus dem Diff alle
>    `lib/screens/**/*.dart`-Pfade filtern (`A`/`D`/`R<n>`) und
>    Sub-Routes unter `lib/widgets/(add_edit_*|*_dialog|*_sheet).dart`.
>    Adds → Eintrag am Ende der passenden Tabelle (Top-Level vs Auth
>    vs Sub-Routes) mit Default-Pflicht-Tests `smoke-theme,
>    mobile-overflow`. Removes → Tabellen-Zeile entfernen. Niemals
>    bestehende Reihenfolge umsortieren. Wenn `_page-registry.md`
>    fehlt: Blocker-Output und Stop.
> 6. Modus:
>    - **Default (kein `--apply`):** dry-run — Plan + geplante Diff-Snippets
>      + geplante Registry-Adds/-Removes nur. Schreibe **nichts**.
>    - **`--apply` in `$ARGUMENTS`:** Edits durchführen. Inkrementell, nicht
>      Komplett-Rewrite. Glossar-Eintrag bei neuem Begriff alphabetisch
>      einsortieren + verlinken. Registry-Edits durchschreiben.
> 7. `--strict` setzt exit 1 bei `unclassified_paths > 0`.
> 8. Antworte mit dem strukturierten Result-Block (`## doc-updater Result`)
>    inkl. `registry_added` / `registry_removed` und pro aktualisiertem
>    Kapitel einem 3-Zeilen-Diff-Snippet plus pro Registry-Edit einem
>    1-Zeilen-Hinweis (`Registry +/− /<route> (lib/screens/<file>.dart)`).
>
> Hard-Constraints aus CLAUDE.md beachten: keine Edits in `lib/` oder
> `supabase/`, kein `git add`/`git commit`, keine Secrets im Output, keine
> Komplett-Rewrites. Wenn die Faktenlage aus dem Diff nicht reicht, setze
> `> TODO:` Marker im Doku-Text statt zu raten.
>
> Argumente vom Caller: `$ARGUMENTS` 1:1 durchreichen.
