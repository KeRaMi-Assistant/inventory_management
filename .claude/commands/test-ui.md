---
description: Startet einen Browser-Test-Lauf via Playwright-MCP gegen die Flutter-Web-App
argument-hint: <scenario-name oder freitext>
---

Rufe den `browser-tester`-Subagenten mit folgender Aufgabe:

> Führe das Szenario `$ARGUMENTS` durch.
>
> 1. Lies `.env.test` — falls fehlend, brich ab und sag mir, dass ich
>    `cp .env.test.example .env.test` ausführen soll.
> 2. Stelle sicher, dass der Web-Dev-Server läuft. Falls nicht:
>    `bash .claude/scripts/dev-web.sh`. Warte bis HTTP 200.
> 3. Öffne `http://localhost:8123` via Playwright-MCP.
> 4. Falls `$ARGUMENTS` ein Standard-Szenario ist (`smoke-login`,
>    `smoke-inbox`, `smoke-theme-toggle`, `smoke-help`,
>    `smoke-full-app-audit`), nutze die Schritte aus deinem
>    System-Prompt. `smoke-full-app-audit` läuft pro Eintrag in
>    `.claude/agents/_page-registry.md` einen Audit-Block durch und
>    schreibt bei Befunden Auto-Requeue-Tasks ins Inbox.
>    Sonst: interpretiere `$ARGUMENTS` als Klartext-Anweisung und übersetze
>    sie in Snapshot/Action/Wait-Schritte.
> 5. Schreibe Report nach `.claude/test-runs/<timestamp>/report.md` mit
>    Screenshots.
> 6. Lasse den Dev-Server laufen — ich stoppe ihn manuell via
>    `bash .claude/scripts/stop-web.sh`, falls nötig.
>
> Gib mir am Ende den Pfad zum Report-File und eine 5-Zeilen-Zusammenfassung
> zurück.
