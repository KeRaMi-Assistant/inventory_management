---
description: Legt ein neues Backlog-Item für den Headless-Runner an
argument-hint: <freitext-was-zu-tun-ist>
---

Lege ein neues Backlog-Item für `headless-runner.sh` an. Argument:
`$ARGUMENTS`.

Schritte:

1. Bestimme nächste Priorität: zähle Files in `.claude/backlog/inbox/`,
   die mit `NN-` anfangen. Neue Nummer = höchste + 1, formatiert mit
   führender Null (z.B. `03`).
2. Generiere Slug aus dem Argument: kebab-case, max 40 Zeichen.
3. Schreibe `.claude/backlog/inbox/<NN>-<slug>.md` mit YAML-Frontmatter:
   ```
   ---
   slug: <slug>
   priority: <NN als Zahl>
   plan: false
   budget_usd: 5
   ---

   <Argument-Text>
   ```
   Falls das Argument auf eine grobe Architektur-Änderung hindeutet
   (mehrere Files, neue Tabelle, neue Edge-Function), setze `plan: true`.
4. Bestätige dem User mit dem File-Path und sag, wann der nächste
   Headless-Run plant ist (alle 30 Min, oder via `/auto-run`).
