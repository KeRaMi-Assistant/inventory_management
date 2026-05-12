---
description: Frag Yota nach dem aktuellen Swarm-Status (read-only Chat-Companion).
argument-hint: "[frage|watch]"
---

Frag **Yota** nach dem aktuellen Swarm-Status. Default-Aufruf zeigt 5-7-Zeilen-Übersicht.

Optionen:
- `/yota` — Status-Snapshot (default).
- `/yota <frage>` — beliebige Klartext-Frage (z.B. `/yota was hat worker 12345 zuletzt gemacht?`).
- `/yota watch` — startet 15-Minuten-Push-Daemon (`install-yota-watch.sh --load-now`).

Yota ist **read-only**. Für Coding-Tasks:
- `bash .claude/scripts/btw.sh "..."` (geht durch Triage).
- `/queue "..."` für ein direktes Backlog-Item.

---

$ARGUMENTS

Dispatche den **`yota`-Subagent** mit der obigen Eingabe. Wenn `$ARGUMENTS` leer ist, lass Yota einen Default-Status-Snapshot erzeugen.
Wenn `$ARGUMENTS` gleich `watch` ist, führe stattdessen `bash .claude/scripts/install-yota-watch.sh --load-now` aus.
