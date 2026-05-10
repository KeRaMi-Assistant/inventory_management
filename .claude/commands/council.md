---
description: Planning Committee — 5 parallele Experten-Reviewer (Architekt, Pessimist/Bug-Hunter, External-Solutions-Scout, Security, UX/Mobile) debattieren einen Plan, bevor irgendeine Zeile Code geschrieben wird.
argument-hint: <feature-beschreibung>
---

# Planning Committee

Du bist **Moderator** des Committees. Dein einziger Job: parallele Reviews orchestrieren, dann synthetisieren. Du selbst urteilst nicht über den Plan — du sammelst und konsolidierst.

**Design-Prinzip:** Mehr Token + mehr Modelle parallel ist besser als ein einzelner brillanter Reviewer. Wall-Clock-Zeit bleibt ähnlich, weil alles parallel läuft. Qualität > Token-Sparen.

---

## Phase 1 — Plan-Draft

Rufe `planner` (Opus) auf:

> Erstelle einen **Erstentwurf** (Draft) für folgenden Feature-Wunsch. Speichere unter `plans/YYYY-MM-DD_<slug>.md`. Header: `[DRAFT — Pending Committee Review]`. Pflicht-Sektionen: Ziel, Scope, Datenmodell + RLS, API/Edge Functions, UI + l10n-Keys, Tests, Risiken, Tasks (atomar, mit `agent:<name>`-Tag pro Task).
>
> Feature-Wunsch: $ARGUMENTS

Notiere den Plan-Pfad als `[PLAN_PATH]`.

---

## Phase 2 — Fünf parallele Reviews

**Spawne ALLE 5 Agents in EINEM Tool-Use-Block** (gleicher Message-Block, mehrere Agent-Calls). Reihenfolge unwichtig — sie laufen wirklich parallel.

Jeder Reviewer bekommt eine spezifische Rolle und ein bewusst gewähltes Modell. Jeder MUSS vor seinem Review relevanten Projekt-Kontext laden (sonst kommt nur generisches Geplapper).

### Reviewer 1 — Architekt (Opus)
`subagent_type: planner` (re-used als Architektur-Reviewer)

> Du bist Senior-Architekt. **Lies zuerst:** `[PLAN_PATH]`, dann CLAUDE.md (§Stack, §Code-Konventionen, §Subagent-Modell-Routing), dann grep `lib/providers/` und `lib/services/` für ähnliche bestehende Konstrukte.
>
> **Aufgabe:** Hinterfrage die Architektur des Plans:
> - Passt der Ansatz zum Provider-Pattern und zur bestehenden Service-Struktur?
> - Sind Tasks korrekt geschnitten (atomic, einzeln PR-fähig)?
> - Welche Abhängigkeiten fehlen im Task-Graph (`depends:`)?
> - Gibt es einen einfacheren Weg, der weniger neuen Code braucht (Wiederverwendung statt Neubau)?
>
> **Antwort-Format:**
> ```
> ## Architektur-Review
> Verdict: ✅ FREIGEGEBEN / ⚠️ ÜBERARBEITUNG / 🔴 ABLEHNUNG
>
> ### Findings
> - [PROBLEM] ...
> - [VERBESSERUNG] ...
>
> ### Konkrete Plan-Änderungen
> 1. ...
> ```

### Reviewer 2 — Pessimist / Bug-Hunter (Opus)
`subagent_type: general-purpose`

> **Du gehst davon aus, dass dieser Plan einen kritischen Fehler enthält. Finde ihn.** Reflexive Antworten wie "sieht gut aus" sind verboten.
>
> **Lies zuerst:** `[PLAN_PATH]`, CLAUDE.md (§Sicherheit, §Mobile-First), dann mindestens 2 ähnliche bestehende Files in `lib/` für Annahmen-Check.
>
> **Aufgabe:** Sei adversarial. Hinterfrage jede Annahme. Such nach:
> - Edge-Cases, die der Plan ignoriert (leere States, Fehler-States, Race-Conditions, Offline-Verhalten, gleichzeitige Multi-User-Edits, Migration auf existierenden Daten)
> - Falsche Annahmen über bestehenden Code (z.B. "der Provider X hat Methode Y" — stimmt das wirklich?)
> - Nicht-bedachte Failure-Modes (Network-Timeout, Supabase-RLS-Deny, Edge-Function-Cold-Start, Push-Token-Expiry)
> - Migrations-Risiken (Down-Migration vorhanden? Was passiert bei Rollback?)
> - UX-Fallen (User klickt zweimal, User schließt App während Operation, User hat keinen Workspace)
> - Performance-Cliffs (N+1 Queries, fehlende Indexes, große Listen ohne Pagination)
>
> Wenn du nach echtem harten Suchen wirklich keinen Fehler findest, sag das explizit — aber nicht früh aufgeben.
>
> **Antwort-Format:**
> ```
> ## Bug-Hunter-Review
> Gefundene Probleme: <N>
> Schwerste Severity: KRITISCH / HOCH / MITTEL / KEIN
>
> ### Was schiefgehen wird (priorisiert)
> 1. [KRITISCH] <Szenario> — <was kaputtgeht> — <wie wahrscheinlich>
> 2. [HOCH] ...
> 3. [MITTEL] ...
>
> ### Pflicht-Mitigationen für den Plan
> - ...
> ```

### Reviewer 3 — External-Solutions-Scout (Opus + WebSearch)
`subagent_type: general-purpose`

> **Bevor wir das selbst bauen — gibt es eine fertige Lösung?**
>
> **Lies zuerst:** `[PLAN_PATH]`, dann `pubspec.yaml` für aktuell genutzte Packages.
>
> **Aufgabe:** Suche aktiv nach existierenden Lösungen statt Eigenbau:
> 1. **pub.dev:** Gibt es ein etabliertes Flutter-Package, das die Funktionalität (oder einen Teil) abdeckt? Nutze WebSearch ("flutter <feature> package", "pub.dev <topic>"). Filter: aktiv gewartet (Update < 12 Monate), Pub-Score > 110, Likes > 100.
> 2. **OSS-Libraries / GitHub:** Gibt es Open-Source-Code (MIT/Apache), den wir adaptieren können statt von Null bauen?
> 3. **Supabase Templates / Edge-Function-Examples:** Hat Supabase einen offiziellen Template-Code für ähnliche Use-Cases? (`supabase.com/docs`, GitHub `supabase/supabase` examples)
> 4. **Externe APIs:** Lässt sich das Problem durch eine SaaS-API lösen (z.B. Tracking-Provider, Geocoding, OCR), die billiger ist als Eigenbau-Wartung?
>
> Für jeden Vorschlag: konkrete Trade-off-Analyse (Eigenbau vs. Import) — Lizenz, Wartung, Bundle-Size, Lock-in.
>
> Wenn keine fertige Lösung existiert, sag das explizit — aber zuerst hart suchen, nicht reflexartig "müssen wir selbst bauen".
>
> **Antwort-Format:**
> ```
> ## External-Solutions-Review
> Empfehlung: IMPORTIEREN / HYBRID / EIGENBAU
>
> ### Gefundene Lösungen
> 1. **<package/library>** v<version>
>    - Was es löst: ...
>    - Pro: ...
>    - Contra: ...
>    - Lizenz: ...
>    - Bundle-Impact: ...
> 2. ...
>
> ### Empfehlung an den Plan
> - [TEILEN] Plan-Task X durch Import von <package> ersetzen
> - [BEHALTEN] Plan-Task Y bleibt Eigenbau weil <Grund>
> ```

### Reviewer 4 — Security & RLS-Wächter (Opus)
`subagent_type: security-reviewer`

> Pre-Implementation-Review (NOT post-implementation). Lies `[PLAN_PATH]` + bestehende Migrations in `supabase/migrations/` (letzte 5 Files, um Policy-Stil zu verstehen).
>
> **Aufgabe:** Finde Sicherheitslücken bevor sie implementiert werden:
> - Fehlende RLS-Policies für neue Tabellen (default-deny + explicit allow?)
> - Cross-Workspace-Read-Lücken
> - Service-Role-Key-Verwendung wo Anon reichen würde
> - Input-Validation in geplanten Edge Functions (zod-artige Prüfung erwähnt?)
> - Secret-Leak-Risiken (Logs, Notification-Payloads, Error-Responses)
> - IDOR (geplante Endpoints ohne User-/Workspace-Check?)
> - PII in Push-Notifications
>
> **Antwort-Format:** dasselbe JSON-Schema wie der bestehende security-reviewer (`verdict`, `findings[]`, `summary`), aber bezogen auf den PLAN, nicht auf Code-Diff.

### Reviewer 5 — UX & Mobile-First (Opus)
`subagent_type: general-purpose`

> **Lies zuerst:** `[PLAN_PATH]`, CLAUDE.md (§Mobile-First komplett), `.claude/agents/_page-registry.md`, sowie `lib/l10n/app_de.arb` (Key-Naming-Stil verstehen).
>
> **Aufgabe:** Mobile-First-Konformität & UX-Vollständigkeit:
> - Funktioniert jeder UI-Vorschlag auf 360×640 + 390×844?
> - Sind alle l10n-Keys (DE+EN) für jeden neuen UI-String genannt?
> - Touch-Targets ≥ 48dp eingeplant?
> - SafeArea + Keyboard-Handling bei Inputs bedacht?
> - Sind ALLE States gedacht: empty, loading, error, no-network, no-permission, success?
> - Accessibility-Anker (Keys/Labels) für Browser-Tester vorgesehen?
> - Bottom-Nav vs. Sidebar korrekt? Theme-Tokens (kein Colors.X) eingeplant?
> - Wird `_page-registry.md` ergänzt (neuer Screen → Pflicht-Tests definiert)?
>
> **Antwort-Format:**
> ```
> ## UX/Mobile-Review
> Verdict: ✅ / ⚠️ / 🔴
>
> ### Pflicht-Lücken
> - [PFLICHT] ...
>
> ### Optional-Lücken
> - [NICE] ...
>
> ### Konkrete Plan-Ergänzungen
> 1. ...
> ```

---

**Wichtig zur Ausführung:**

- ALLE 5 Agent-Calls in EINEM Message-Block. Nicht nacheinander.
- `[PLAN_PATH]` jeweils mit dem Pfad aus Phase 1 ersetzen.
- Warte auf alle 5 Antworten, bevor du Phase 3 startest.
- Token-Kosten dieser Phase sind hoch und beabsichtigt — Wall-Clock bleibt unter 5 Minuten weil parallel.

---

## Phase 3 — Synthese

Lies alle 5 Reviews. Schreibe folgenden Block für den User:

```
## 🏛 Planning Committee — Verdict

**Feature:** $ARGUMENTS
**Plan-Draft:** [PLAN_PATH]

| Reviewer | Verdict | Top-Befund |
|---|---|---|
| Architekt | ✅/⚠️/🔴 | <1-Zeile> |
| Bug-Hunter | <N gefunden, schwerstes <severity>> | <1-Zeile> |
| External-Scout | IMPORT/HYBRID/EIGENBAU | <Package o. "kein passendes"> |
| Security | pass/warn/block | <1-Zeile> |
| UX/Mobile | ✅/⚠️/🔴 | <1-Zeile> |

### 🔴 Pflicht-Änderungen am Plan (Blocker für Implementierung)
1. ...
2. ...

### ⚠️ Empfohlene Verbesserungen (nicht-blockierend)
- ...

### 🌍 External-Solutions-Empfehlungen
- <konkrete Package/Library-Vorschläge mit Plan-Impact>

### Gesamt-Verdict
- **FREIGEGEBEN** — Plan kann (mit ⚠️-Empfehlungen) implementiert werden
- **ÜBERARBEITUNG NÖTIG** — 🔴-Blocker vor Implementierung einarbeiten
- **ABLEHNUNG** — fundamentaler Re-Plan erforderlich (Architekt oder Bug-Hunter sagt "🔴")

### Kosten-Estimate für diesen Council-Run
- ~5× Opus-Reviews parallel (~$X gesamt, ~Y min Wall-Clock)
```

---

## Phase 4 — User-Entscheidung & Finalisierung

Frage den User explizit:
1. **Plan finalisieren + sofort implementieren** → integriere Pflicht-Änderungen (rufe `planner` nochmal auf, Header → `[Committee-Approved YYYY-MM-DD]`), dann `/work` mit dem finalen Plan
2. **Plan finalisieren ohne Implementation** → integriere Pflicht-Änderungen, kein `/work`
3. **Plan verwerfen** → Draft bleibt, neuer Anlauf mit anderem Ansatz
4. **Plan ohne Änderungen behalten** (User überstimmt das Committee) → Header → `[Committee-Reviewed YYYY-MM-DD, Findings overruled by user]`, dokumentiere die überstimmten Findings als Kommentar im Plan

Warte auf User-Entscheidung. Erst dann handeln.
