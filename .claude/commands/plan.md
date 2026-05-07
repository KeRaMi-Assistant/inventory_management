---
description: Erstellt einen Implementation-Plan via planner-Agent
argument-hint: <feature-beschreibung>
---

Rufe den `planner`-Subagenten mit folgender Aufgabe auf:

> Plane das folgende Feature für die `inventory_management` App. Lies vorher CLAUDE.md und das aktuelle Projekt. Speichere den Plan in `plans/YYYY-MM-DD_<slug>.md` und gib mir Pfad + Kurz-Zusammenfassung zurück.
>
> Feature-Wunsch: $ARGUMENTS

Nach dem Plan: Frage den User, ob du implementieren sollst. Erst nach OK: orchestriere die passenden Coder-Subagenten gegen den Plan.
