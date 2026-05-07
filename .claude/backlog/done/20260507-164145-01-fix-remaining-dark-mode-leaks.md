---
slug: fix-remaining-dark-mode-leaks
priority: 1
plan: true
test_scenario: smoke-theme-toggle
---

**Kontext:** Dark-Mode-Foundation steht (`AppTheme.bgAppOf(context)` etc.).
PR #5+#9 haben Dashboard, Tickets, Inventory weitgehend gefixt. ABER:
User-Screenshots zeigen, dass mehrere Screens immer noch Light-Mode-
Surfaces im Dark-Mode rendern.

## Konkrete Bug-Stellen (User-verifiziert per Screenshot)

| Screen | Region | Bug |
|---|---|---|
| `/deals` | Rechte Sidebar (Käufer + Statistiken-Panel) | weißer BG mit unleserlichem Text |
| `/deals` | Filter-Panel oben (Suche + Käufer + Status + Shop + Versandtyp + Beleg + Datum) | weißer BG |
| `/deals` | Status-Badges in den Stat-Listen (Bestellt/Unterwegs/Angekommen/Rechnung gestellt/Done) | hellblau/orange/violett-Bg verwenden Light-Mode-Tokens |
| `/inbox` | Header-Bar "1 Postfach verbunden" + Sub-Text "Polling alle 5 min..." | Sub-Text fast unsichtbar (Light-Token auf Dark-BG) |
| `/inbox` | Tab-Bar Vorschläge/Aktualisiert/Unklassifiziert | Bottom-Border-Bereich weiß |
| `/inbox` | Filter-Chips "Alle Shops" / "Alle Status" | weißer Chip-BG auf Dark-Page |
| `/inbox` | Vorschlags-Cards | Card-BG zu dunkel + Body-Text unleserlich (Produktname, Tracking, Preis) |
| `/inventory` | Stat-Cards oben (Gesamtartikel/Gesamtbestand/Kritische Artikel/Lagerwert) | weißer BG mit Light-Mode-Text |
| `/inventory` | Spalten-Header der Tabelle (SKU/Name/Lagerort/Bestand/Mindestbestand/Ø EK/Deal · Ticket) | textPrimary statt textPrimaryDark |
| `/inventory` | "Alarm-Banner" "1 Artikel hat Bestand unter Mindestbestand!" | hell-rosa BG (`dangerBg`) — braucht Dark-Pendant |
| `/statistics` | KPI-Cards (Umsatz, Profit, Marge, ROI, Offene Forderungen, Anzahl Deals) | komplett weißer BG |
| `/statistics` | Filter-Bar (Heute/7 Tage/30 Tage/Quartal/Jahr/Custom) | weißer Tab-Bar-Bereich |
| `/statistics` | Tab-Bar (Übersicht/Käufer/Produkte&Shops/Lager&Lieferanten/Finanzen) | weiße Bottom-Border |
| `/statistics` | Diagramm-Container "Profit & Umsatz" | weißer Container-BG |
| `/help` | Quickstart-Card-Liste, Discord-Card, "Konfigurierte Server-IDs"-Card | sehr dunkler Card-BG mit dunklem Text → unleserlich |
| `/settings` | Tab-Bar (Käufer/Shops/Team/Push/Postfach/Allgemein) | weiße Bottom-Border |
| `/settings` | Käufer-Liste: weißer Container unter der Liste + "Käufer hinzufügen" Button-BG-Bereich |

## Bug-Klassen (Kategorien zur systematischen Analyse)

1. **Container-Decorations** (`Container(decoration: BoxDecoration(color: ...))`)
   mit hardcodeden `Colors.white`, `Color(0xFF...)` oder `AppTheme.bgSurface`
   (statisch). Müssen `AppTheme.bgSurfaceOf(context)` o.ä. werden.
2. **Status-Badge-Hintergründe** (`accentLight`, `successBg`, `warningBg`,
   `dangerBg`, `infoBg`) — Light-Mode-only Tokens. Brauchen Dark-Pendants
   (`accentLightDark`, `successBgDark`, etc.) und Of(context)-Helper.
3. **Tab-Bar / Filter-Bar / Side-Panel** mit eigener `decoration.color` —
   muss context-aware werden.
4. **Stat-Cards / KPI-Cards / Banner-Boxes** mit fester BG-Color.

## Schritte

1. **Komplettes Audit** (alle 5 grep-Befehle aus `ui-builder.md`-Audit-Pflicht
   im Verzeichnis `lib/screens/` UND `lib/widgets/`) — schreibe alle
   Treffer in eine Liste.
2. **AppTheme erweitern:** für jede semantische Status-Farbe ein Dark-Pendant
   und einen `xxxBgOf(BuildContext)`-Helper. Mind.: `accentLightOf`,
   `successBgOf`, `warningBgOf`, `dangerBgOf`, `infoBgOf`.
3. **Refactor:** Alle Treffer aus dem Audit auf die context-aware Variante
   umstellen. Bei statischen Initialisern (z.B. const Maps) — entweder zur
   build-Methode verschieben oder als private builder-Methode lazyInit.
4. `flutter analyze` clean.
5. `flutter test` 69+ grün.
6. **`smoke-theme-toggle` MUSS auf ALLEN 10 Top-Level-Routen passed sein.**
   Per-Region-Audit (nicht Aggregat). Sub-Sub-Tabs (z.B. Settings-Tabs,
   Tickets Aktiv/Archiv) auch screenshotten.

## Akzeptanzkriterien

- Audit-Befehle liefern in `lib/screens/` und `lib/widgets/` keine
  Treffer mehr außer bewusste Akzent-Konstanten (`AppTheme.accent`,
  `AppTheme.success`, `AppTheme.warning`, `AppTheme.danger`, `AppTheme.info` —
  diese Foreground-Farben dürfen mode-agnostisch bleiben).
- Visual-Audit findet auf keiner Route eine Region > 5% Screen-Width mit
  RGB-Summe > 600 im Dark-Mode.
- Alle in der Bug-Liste oben aufgeführten Stellen sind im Dark-Mode visuell
  ununterscheidbar von "saubere App".

## Hinweis an den Implementer (Sub-Claude)

Du bist auf opus mit unbegrenztem Budget. Arbeit gründlich, nicht schnell.
Lieber 1 vollständig sauberes PR als 3 angefangene. Wenn nach dem ersten
Visual-Test Bugs übrig sind: fixen, retesten, fixen, retesten — bis
`smoke-theme-toggle` wirklich auf allen 10 Routen passed.
