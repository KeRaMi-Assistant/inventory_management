---
id: 20260512-204909-make-different-app-themes-all-fonts-and
source: tier-2
trust_tier: 2
user_id: 8618680864
created_at: 2026-05-12T20:49:09Z
council_finished_at: 2026-05-12T20:50:30Z
state: pending-approval
verdict: propose
round: 1
council_cost_usd: 1.20
hmac_token: 9a74124632394c03
pushed_at: 2026-05-12T20:51:13Z
requires_human_dispute: false
touches: [lib/app_theme.dart, lib/providers/theme_provider.dart, lib/screens/settings_screen.dart, lib/l10n/app_de.arb, lib/l10n/app_en.arb]
created_from: intake-council
content_hash: b32712a393003598c90749428fed053d99224710f3ab9c1c147bac0257310830
---

## Verdict-Summary

Council-Konsens: Idee passt. Proponent + Skeptic stimmten zu.

## Vorgeschlagenes Backlog-Item

```yaml
---
slug: selectable-color-palettes
source: tier-3-intake
priority: 2
budget_usd: 3.00
model: sonnet
touches: [lib/app_theme.dart, lib/providers/theme_provider.dart, lib/screens/settings_screen.dart, lib/l10n/app_de.arb, lib/l10n/app_en.arb]
needs_gh: false
needs_dispute: false
requires_human_dispute: false
estimated_minutes: 90
created_from: intake-council
trust_tier: 2
---

## Council-Begründung (Long)

### Proponent
## Proponent (Intake)

### Vorteile
- **Fundament existiert schon zur Hälfte:** `lib/app_theme.dart` zentralisiert Farben + nutzt `google_fonts`. Der Schritt zu *mehreren* benannten Paletten (statt nur Light/Dark hardcodiert) ist eine natürliche Evolution, kein Neubau — der Refactor-Aufwand ist überschaubar.
- **Pre-Launch ist der richtige Zeitpunkt:** Solange es keine echten Nutzer-Sessions/gespeicherten Prefs gibt, ist ein Umbau der Theme-Schicht billig. Später (mit persistiertem User-Theme, mehr Screens) wird derselbe Refactor teurer.
- **Reduziert künftige Bug-Klasse:** Das CLAUDE.md verbietet ad-hoc `Colors.blue` — ein sauberes `ThemePalette`-Objekt mit `.of(context)` macht diese Regel erzwingbar und entfernt die manuelle `_dark(context)?:`-Verzweigung an ~20 Stellen.
- **Echter (kleiner) User-Value:** Ein dritter Akzent/„High-Contrast"-Modus ist ein günstiges Differenzierungs-Feature, das auf der bestehenden Help/Settings-Infra (Theme-Toggle existiert bereits) andockt.

### Empfohlene Implementation
- **Phase 1 (jetzt, klein):** `AppTheme` zu einem `ThemePalette`-Wert-Objekt refactoren — Felder statt `xxxOf(context)`-Paare. Eine `ThemeProvider` (existiert evtl. schon für Light/Dark) hält die aktive Palette. Fonts als `ThemePalette.textTheme` bündeln. Kein neues Theme hinzufügen, nur Struktur.
- **Phase 2 (separates Backlog-Item):** 1 zusätzliche Palette (z. B. „Midnight"/High-Contrast) + Auswahl in `settings_screen.dart` + Persist via vorhandenem Settings-Mechanismus. ARB-Keys DE/EN. `smoke-theme-toggle`/`smoke-full-app-audit` erweitern.
- **Nicht im Scope:** beliebig viele Themes, Custom-Color-Picker, Theme-Sync über Supabase — explizit verschieben.

### Vote: accept-with-changes

### Skeptic (intake-skeptic)
## Skeptic (Intake)

### Bedenken (proportional zur Evidenz)

- [MITTEL] **Teil 1 der Idee ist bereits vollständig implementiert.** `lib/app_theme.dart` ist exakt das beschriebene zentrale Token-System: alle Farben als `static const`, Google Fonts Inter als einzige Font-Quelle, `light` + `dark` als `ThemeData`-Getter, context-aware Helpers (`bgAppOf(context)` etc.). 28 Dateien nutzen es bereits. CLAUDE.md schreibt das sogar als Pflicht vor. Kein Handlungsbedarf für diesen Teil — reine Re-Implementierung bestehender Infrastruktur wäre Aufwand ohne Wert.

- [MITTEL] **Teil 2 (mehrere Themes jenseits Light/Dark) ist echter Scope — aber Pre-Launch-Priorisierungsfrage.** Wenn mit „different App Themes" zusätzliche Farbpaletten gemeint sind (z.B. Ocean Blue, Warm, High Contrast), ist das ca. 1–1,5 Tage Arbeit: `ThemeProvider` erweitern, Settings-UI-Entry, Persistenz via SharedPreferences, Smoke-Tests für alle Paletten × Phone + Desktop. Für Pre-Launch ist der ROI zu klären: Nutzt ein Beta-Tester das? Oder ist es Nice-to-Have?

### Empfohlene Mitigations

- Scope präzisieren vor Start: Bedeutet die Idee (a) „ich wusste nicht, dass es das schon gibt" → kein Work-Item nötig, oder (b) „ich will 2–3 zusätzliche Farbpaletten wählbar machen" → eigenes Backlog-Item mit konkreten Paletten-Namen.
- Falls (b): `ThemeProvider` in `lib/providers/` anlegen, der `ThemeMode` + `AppColorScheme`-Enum hält — analog bestehendem Provider-Pattern. Persistenz per `SharedPreferences`. Settings-Screen bekommt Theme-Picker-Tile.
- Kein RLS, keine Migration, kein Edge-Function-Impact.

### Vote: accept-with-changes

> Begründung: Die Zentralisierung ist bereits erledigt. Das Work-Item ist nur valide, wenn der User explizit *zusätzliche* Farbpaletten jenseits von Light/Dark meint. Proposal sollte vor Einreihung in den Backlog mit einer klaren Palette-Liste präzisiert werden.

### Pragmatist-Tie-Break (intake-pragmatist)
## Pragmatist (Intake)

### Analyse
- Proponent-Stärken: Theme-Fundament existiert (`lib/app_theme.dart` + `google_fonts`), Pre-Launch ist billigster Zeitpunkt für einen Palette-Refactor; ein zusätzlicher High-Contrast-Modus ist günstiges Differenzierungs-Feature.
- Skeptic-Bedenken: Teil 1 („zentrale Stelle für Fonts/Farben") ist bereits vollständig implementiert (28 Files nutzen `AppTheme`, CLAUDE.md erzwingt es). Nur „mehrere wählbare Paletten" ist echter Scope — und das ist eine Pre-Launch-Priorisierungsfrage ohne klaren Nutzer-Schmerz.

### Pre-Launch-ROI-Bewertung
- Teil 1: niedrig — bereits erledigt, Re-Implementierung wäre Aufwand ohne Wert.
- Teil 2 (2–3 zusätzliche Paletten + Picker + Persistenz + Smoke-Tests): niedrig–mittel, ~1–1,5 Tage. Nice-to-Have, kein Adoption-Blocker. Sinnvoll nur als Low-Prio-Item mit präziser Palette-Liste.

### Doppelung-Check
- `lib/app_theme.dart` deckt die Zentralisierung vollständig ab → **Doppelung für Teil 1**. Kein bekanntes Backlog-Item für „zusätzliche wählbare Paletten" → für Teil 2 keine Doppelung.

### Mobile-First-Fit
- Theme-/Palette-Wechsel ist viewport-unabhängig. Settings-Picker-Tile muss 48×48 dp Touch-Target erfüllen + `smoke-full-app-audit` über alle Paletten × Phone/Desktop. Kein Hover-Only. Fit gegeben, sofern der Audit erweitert wird.

### Verdict
**propose-with-changes**

### Begründung
- Teil 1 ist schon da — nur der reduzierte Scope „1–2 zusätzliche Farbpaletten wählbar machen" ist ein valides, aber niedrig-priores Item. Es wird nur eingereiht, wenn der User die konkreten Paletten benennt; sonst ist es ein No-Op.

### Falls propose-with-changes: konkrete Änderungen
- Scope auf Teil 2 begrenzen; Teil 1 (Zentralisierung) als bereits erledigt streichen.
- User muss die gewünschten Paletten-Namen liefern (z. B. „Midnight / High-Contrast / Ocean") — ohne Liste kein Start.
- Kein neues Theme-Konzept, sondern: `AppColorScheme`-Enum + `ThemeProvider`-Erweiterung, Persistenz via `SharedPreferences`, Settings-Picker-Tile, `smoke-full-app-audit` um neue Paletten erweitern. Kein RLS/Migration/Edge-Fn.

### Vorgeschlagenes Backlog-Item (nur wenn Verdict ≠ reject)
```yaml
---
slug: selectable-color-palettes
source: tier-3-intake
priority: 2
budget_usd: 3.00
model: sonnet
touches: [lib/app_theme.dart, lib/providers/theme_provider.dart, lib/screens/settings_screen.dart, lib/l10n/app_de.arb, lib/l10n/app_en.arb]
needs_gh: false
needs_dispute: false
requires_human_dispute: false
estimated_minutes: 90
created_from: intake-council
trust_tier: 2
---

## Aufgabe
Zusätzliche wählbare Farbpaletten (über Light/Dark hinaus) einführen. `AppColorScheme`-Enum + `ThemeProvider` (Provider-Pattern, kein Riverpod) hält aktive Palette; Persistenz via SharedPreferences. Auswahl als Tile im Settings-Screen. Voraussetzung: User benennt konkrete Paletten-Namen — sonst Item zurückstellen. Bestehende Zentralisierung in `lib/app_theme.dart` NICHT neu bauen, nur erweitern.

## Acceptance
- Mind. eine zusätzliche Palette (Name vom User) ist in Settings wählbar und persistiert über App-Restart.
- Keine hardcoded Colors; alle neuen Werte als Token in `app_theme.dart`. ARB DE+EN symmetrisch.
- Picker-Tile ≥ 48×48 dp; funktioniert auf 360×640 und 390×844 ohne Overflow.

## Verify
`/test-ui smoke-full-app-audit` grün über alle Paletten × Light/Dark × Phone+Desktop; Theme-Auswahl in Settings ändern, App neu starten, Auswahl bleibt erhalten.
```

## Stakeholder-Original


<<<UNTRUSTED_PROPOSAL tier=2>>>
Make different App Themes, all Fonts and colors are in some central place so Theme switches are easy
<<<END_UNTRUSTED_PROPOSAL>>>
