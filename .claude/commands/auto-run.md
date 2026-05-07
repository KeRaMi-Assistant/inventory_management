---
description: Startet sofort einen Headless-Run (verarbeitet das nächste Backlog-Item)
---

Manueller Trigger. Du machst NICHT die Arbeit selbst — du startest nur den
Background-Runner.

Schritte:

1. Prüfe `.claude/backlog/inbox/`: wenn leer, sag das dem User und
   stoppe.
2. Sonst: Liste das nächste Item, das verarbeitet wird (nach Filename
   sortiert), zeig dem User Filename + erste 5 Zeilen Inhalt.
3. Frage NICHT um Bestätigung — der User hat bewusst `/auto-run`
   gerufen.
4. Starte `bash .claude/scripts/headless-runner.sh` im Hintergrund
   (run_in_background=true). Berichte dem User die PID.
5. Sag dem User, wo er Live-Logs sieht:
   `tail -f .claude/backlog/runs/<timestamp>-<slug>.log`.

Wenn der Runner schon läuft (Lock-File existiert), sag das und stoppe.
