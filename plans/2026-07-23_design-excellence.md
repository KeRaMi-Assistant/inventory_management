# Design-Exzellenz-Initiative — „State of the art, beste Experience"

**Stand:** 2026-07-23 · **Branch:** `feature/prototype-prep`
**Anspruch (Stakeholder):** Messlatte sind die besten Product-UIs (Linear,
Stripe, Klarna, Revolut) — nicht „funktioniert", sondern „fühlt sich
erstklassig an".

## Diagnose (eigene Analyse + Live-Design-Critic)

Fundament ist gut (Token-System, l10n, Responsive-Architektur, Dark-Mode),
aber die App wirkt wie ein **sauberes Admin-Template**, nicht wie ein
Produkt mit Charakter:

1. **Keine Hierarchie auf dem Dashboard:** 7 gleichgewichtete KPI-Kacheln;
   Gesamtprofit (die EINE Zahl, die Reseller interessiert) hat dasselbe
   Gewicht wie „Heute angekommen: 0". Verwaiste 7. Kachel im 2er-Grid.
   Kein Gruß, kein Kontext, keine Persönlichkeit.
2. **Flach:** `elevation: 0` + Border-only-Cards überall; kein
   Schatten-/Tiefen-System; Dark-Mode = flache Panels statt tonaler Tiefe.
3. **Kein Motion-System:** Tab-Wechsel = harter Schnitt; Listen erscheinen
   schlagartig; Zahlen springen; nichts „lebt". → **Slice 1 erledigt.**
4. **Zero-Value-Rauschen:** „0"-Kacheln gleichrangig mit Kernzahlen.
5. **Login/Empty-States:** korrekt, aber steril — keine Brand-Momente.
6. Feinschliff: Typo-Scale-Disziplin, Icon-Konsistenz, tabular figures für
   Zahlen, Badge-/Radius-Konsistenz. (Details: Design-Critic-Report,
   `.claude/test-runs/<ts>/design/`.)

## Slices (je klein, verifizierbar, einzeln committbar)

- [x] **S1 Motion-Fundament** — Fade-Through bei Sektions-Wechsel;
  `Entrance`-Widget (staggered Fade+Rise, Reduce-Motion-aware) auf
  KPI-Grid + Hub-Kacheln; Pressed-Scale (0.97/0.98) auf tappbaren Karten.
- [ ] **S2 Tiefe & Oberflächen** — Schatten-Tokens (`AppTheme.shadowSm/Md`)
  für Light (weich, tint-basiert, keine harten Material-Shadows); Dark
  bleibt tonal (hellere Surface statt Schatten). Cards: Border bleibt,
  bekommt aber Tiefe. Zentral über CardTheme + KpiCard/Panel.
- [ ] **S3 Dashboard-Hierarchie** — Gruß-Header (Tageszeit + Datum +
  1-Satz-Kontext), Hero-Metrik (Gesamtprofit groß, Trend), Sekundär-KPIs
  kompakt (kleinere Kacheln), Zero-Werte gedimmt.
- [ ] **S4 Lebende Zahlen** — KPI-Werte zählen beim Erscheinen hoch
  (Count-Up ~600 ms), Wertwechsel mit sanftem Tick statt Sprung.
- [ ] **S5 Critic-Feinschliff** — Top-Findings aus dem Live-Report
  (Typo/Icon/Spacing-Inkonsistenzen, Empty-State-Charakter, Login-Moment).

## Leitplanken

- Keine neuen Pakete, solange Framework-Primitives reichen.
- Jede Motion respektiert `MediaQuery.disableAnimations`.
- Desktop und Phone getrennt verifizieren (Browser-Smoke, Light+Dark).
- Theme-Tokens statt Ad-hoc-Werte (CLAUDE.md).
- Nach jedem Slice: `flutter analyze` + Test-Suite + visueller Vergleich.
