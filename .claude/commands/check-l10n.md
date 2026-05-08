---
description: Prüft l10n-Konsistenz (ARB-Symmetrie + Hardcoded-Strings) via l10n-checker-Agent
argument-hint: [--fix] [--json] [--no-hardcoded]
---

Rufe den `l10n-checker`-Subagenten mit folgender Aufgabe auf:

> Prüfe die l10n-Konsistenz für `inventory_management`.
>
> 1. Führe `python3 .claude/scripts/check-l10n.py $ARGUMENTS` aus.
> 2. Interpretiere Exit-Code + Output:
>    - `0` → alle Checks grün, melde kurz.
>    - `1` → es gibt Findings, gib den vollen Markdown-Report aus
>      (`# l10n-checker Report — <date>`).
>    - `2` → ARB-Datei kaputt oder fehlt — eskaliere mit klarer
>      Fehler-Beschreibung.
> 3. Wenn `$ARGUMENTS` ein `--fix` enthält:
>    - Das Skript hat fehlende EN-Keys mit `[TODO en] <DE>`-Markern
>      ergänzt. Lies `lib/l10n/app_en.arb`, ersetze die Marker durch
>      idiomatische englische Übersetzungen (nicht wörtlich), dann
>      Re-Run ohne `--fix` zur Verifikation.
>    - Hardcoded-Strings fixt das Skript NICHT — du listest sie auf,
>      schlägst pro Treffer einen ARB-Key vor und ÜBERLÄSST den Refactor
>      einem `flutter-coder`-Agenten oder dem User.
> 4. Antworte mit dem strukturierten Result-Block aus deinem
>    System-Prompt (`## l10n-checker Result`).
>
> Hard-Constraints aus CLAUDE.md beachten: keine direkten Änderungen an
> `lib/l10n/app_localizations*.dart` (generiert), keine Secrets, keine
> Branches/Commits.
