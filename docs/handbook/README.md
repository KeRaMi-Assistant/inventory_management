# Handbuch — `inventory_management`

Dieses Handbuch ist die **vollständige Referenz** zur App. Es richtet sich an
zwei Zielgruppen:

- **Entwickler:innen**, die in den Code einsteigen, neue Features bauen oder
  bestehende erweitern.
- **Power-User**, die die App über die rein klickbaren Pfade hinaus verstehen
  wollen — etwa wieso eine Bestätigungsmail nicht erkannt wurde, was hinter
  einem Tracking-Status steckt oder wie das Mehrbenutzer-Modell funktioniert.

Es ist bewusst getrennt von [`docs/STRATEGY.md`](../STRATEGY.md): Strategie
beschreibt das *Warum* und die Roadmap. Dieses Handbuch beschreibt das *Wie*
und den *Ist-Zustand*.

> Sprache: Deutsch. Eine englische Variante folgt, sobald die App
> internationalisiert ausgerollt wird.

## Aufbau

Die Kapitel sind so geordnet, dass sich neue Mitspieler:innen vom Einsteiger
zum Architektur-Verständnis entwickeln. Wer schon im Code lebt, kann direkt
zu Architektur, Datenbank oder Edge-Functions springen.

| # | Kapitel | Worum es geht |
|---|---|---|
| 01 | [Getting Started](01-getting-started.md) | Repo klonen, Supabase aufsetzen, Flutter starten, Login + erstes Onboarding |
| 02 | [Konzepte](02-concepts.md) | Workspace, Deal, Inventory, Buyer, Shop, Supplier, Ticket, Inbox |
| 03 | [Screens-Walkthrough](03-screens-walkthrough.md) | Pro Top-Level-Screen ein Abschnitt — was er tut, wie er aufgebaut ist |
| 04 | [Inbox- & Mail-Pipeline](04-inbox-mail-pipeline.md) | IMAP-Polling, Adapter-Registry, HTML-Forensik, Klassifizierung, Tracking |
| 05 | [Architektur](05-architecture.md) | Stack, Layout, Provider-/Service-Schichten, Theme, Localization |
| 06 | [Datenbank](06-database.md) | Schema, RLS-Policies, Migrationsstrategie, kritische Indexe |
| 07 | [Edge Functions](07-edge-functions.md) | Liste aller Functions, Trigger, Secrets, Logs |
| 08 | [Deployment](08-deployment.md) | Migrations deployen, Functions deployen, Flutter-Builds (Web/iOS/Android) |
| 09 | [Troubleshooting](09-troubleshooting.md) | Häufige Probleme + sofort umsetzbare Lösungen |
| 10 | [Glossar](10-glossary.md) | Definitionen aller Fachbegriffe — wird aus jedem Kapitel verlinkt |

## Wie navigiere ich am schnellsten?

- Du bist **neu im Repo**? → [01](01-getting-started.md) → [02](02-concepts.md) → [05](05-architecture.md).
- Du **debuggst eine Mail**, die nicht ankam? → [04](04-inbox-mail-pipeline.md) → [09](09-troubleshooting.md).
- Du musst **eine Migration deployen**? → [06](06-database.md) → [08](08-deployment.md).
- Du fragst dich, **was "Deal" hier bedeutet**? → [10](10-glossary.md).

## Wie bleibt das Handbuch aktuell?

- Pro Kapitel steht im Footer eine **Quelle im Code** (`File-Pfade`). Wenn
  diese Dateien sich ändern, sollte das Kapitel mit-gepflegt werden.
- Migrations und Edge-Functions sind die "Wahrheit". Wenn das Handbuch von
  ihnen abweicht, gilt der Code — und das Handbuch wird im selben PR
  korrigiert.
- Glossar-Begriffe sind so geschrieben, dass sie nicht jede Sprint-Woche
  veralten. Wenn ein Begriff verschwindet, lieber einen "veraltet seit"-
  Hinweis hinterlassen, als den Eintrag zu löschen — Verlinkungen aus
  älteren Issues bleiben so klickbar.

## Hinweise zu Konventionen

- **Code-Snippets** zeigen wir nur, wenn sie Mehrwert haben. Reine
  Wiederholungen aus dem Code sind weggekürzt.
- **`Quelle im Code:`** am Ende eines Abschnitts referenziert relativ auf das
  Repo-Root, damit man die Datei direkt im Editor öffnen kann.
- **Mermaid-Diagramme** rendern direkt auf GitHub. Ein Pflicht-Diagramm pro
  Major-Kapitel (Architektur, Inbox-Pipeline) — mehr ist erlaubt, aber nicht
  nötig.
- **Tabelle vor Fließtext**, wenn der Inhalt aufzählend ist (Spalten,
  Status-Werte, Rollen). Spart Scroll-Distanz.

## Was du im Handbuch *nicht* findest

- **Roadmap & Marketing-Strategie** → [`docs/STRATEGY.md`](../STRATEGY.md).
- **Pricing-Analyse, Stripe-Setup** → [`docs/PRICING_ANALYSIS.txt`](../PRICING_ANALYSIS.txt).
- **Supabase-Erstkonfiguration für Solo-Devs** → [`SUPABASE_SETUP.md`](../../SUPABASE_SETUP.md).
- **Inbox-Forensik-Snapshots (Adapter-Output-Beispiele)** → [`docs/inbox-forensics/`](../inbox-forensics/).

Wenn du etwas Wichtiges hier nicht findest und es woanders auch nicht
dokumentiert ist, **das ist ein Bug** — bitte ein Backlog-Item via
`/queue "<beschreibe Lücke>"` öffnen oder direkt einen PR auf das fehlende
Kapitel.
