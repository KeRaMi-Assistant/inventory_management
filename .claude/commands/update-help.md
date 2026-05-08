---
description: Aktualisiert die In-App-Hilfeseite (`lib/screens/help_screen.dart` + ARBs) inkrementell auf Basis des aktuellen Diffs via help-curator-Agent
argument-hint: [--apply] [--from <ref>] [--paths "<glob ...>"] [--sections "<inbox faq>"] [--strict]
---

Rufe den `help-curator`-Subagenten mit folgender Aufgabe auf:

> Aktualisiere die In-App-Hilfeseite (`lib/screens/help_screen.dart` +
> `lib/l10n/app_de.arb` + `lib/l10n/app_en.arb`) auf Basis der aktuellen
> Code-Änderungen.
>
> 1. Lies CLAUDE.md.
> 2. Wenn `lib/screens/help_screen.dart` nicht existiert: gib genau
>    `[BLOCKER] lib/screens/help_screen.dart existiert nicht — siehe Backlog-Task #01 (help-screen-curator-agent).`
>    aus und stoppe.
> 3. Default-Diff-Quelle: `git diff main...HEAD --name-status`. Falls leer:
>    Fallback `git diff HEAD~1 --name-status`. `--from <ref>` aus
>    `$ARGUMENTS` überschreibt das.
> 4. Klassifiziere jede Pfad-Änderung anhand der Trigger-Map aus deinem
>    System-Prompt. Pfade ohne Match in `## Unklassifiziert` aufnehmen.
>    Test/Build/Backlog-Pfade stillschweigend skippen.
> 5. Modus:
>    - **Default (kein `--apply`):** dry-run — Plan + geplante ARB-Keys +
>      geplante Screen-Edits nur. Schreibe **nichts**.
>    - **`--apply` in `$ARGUMENTS`:** Edits durchführen. Inkrementell, nicht
>      Komplett-Rewrite. ARB-Symmetrie (DE+EN) ist Pflicht.
> 6. `--strict` setzt exit 1 bei `unclassified_paths > 0`.
> 7. Antworte mit dem strukturierten Result-Block (`## help-curator Result`)
>    und pro aktualisierter Sektion einer 3-Zeilen-Zusammenfassung.
>
> Hard-Constraints aus CLAUDE.md beachten: keine Edits außerhalb von
> `lib/screens/help_screen.dart` und `lib/l10n/app_*.arb`, kein
> `git add`/`git commit`, keine Hardcoded-Strings im Screen, alle Texte
> über ARB. Wenn die Faktenlage aus dem Diff nicht reicht, setze
> `> TODO:` Marker im Plan statt zu raten.
>
> Argumente vom Caller: `$ARGUMENTS` 1:1 durchreichen.
