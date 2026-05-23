/// Zentrale Responsive-Infrastruktur — Zwei-Achsen-API.
///
/// **Warum zwei Achsen?**
///
/// (a) **Viewport-Achse** ([screenSizeOf] / [isPhoneViewport] /
///     [isDesktopViewport] via `MediaQuery.sizeOf`) — NUR für die
///     App-Shell-Entscheidung in `main_screen.dart` (Bottom-Nav vs.
///     NavigationRail). Die Viewport-Breite ist dort richtig, weil die Shell
///     selbst noch keine Sidebar hat, wenn sie entscheidet, welche Nav sie
///     anzeigt.
///
/// (b) **Container-Achse** ([widthClassOf] / [isCompact] / [isMedium] /
///     [isExpanded] / [isLarge]) — für ALLE Layout-Entscheidungen INNERHALB
///     eines Screens. IMMER aus einem `LayoutBuilder` mit
///     `constraints.maxWidth` aufrufen, NIE `MediaQuery`, da die
///     Desktop-Sidebar/Rail die nutzbare Breite reduziert. Wer
///     `MediaQuery.sizeOf` für ein Screen-internes Split-Layout nutzt,
///     erzeugt den Viewport-vs-Container-Bug (z. B. erscheint ein
///     Detail-Panel auf einem 1440-Viewport, obwohl der Container daneben
///     der 220-px-Sidebar nur noch 1220 px breit ist — ab einer
///     Schwelle von 1200 korrekt, aber nur zufällig; verschiebt sich beim
///     nächsten Sidebar-Breitenänderung still). Der Container-Helper nimmt
///     daher bewusst KEINEN `BuildContext`.
///
/// **Migration-Phasen (Epic 1):**
/// - Phase A: Magic Numbers → zentrale Konstanten, **Werte identisch**.
///   Verhaltensneutral; dient ausschließlich der Indirektion.
/// - Phase B: Werte konsolidieren (z. B. navRail 900, master 1200).
///   Verhaltensändernd; mit Vorher/Nachher-Screenshots auditiert.
///
/// Siehe Plan `plans/2026-05-22_ui-ux-responsive-overhaul.md` §5.1.
library;

import 'package:flutter/widgets.dart';

// ── Breakpoint-Konstanten ───────────────────────────────────────────────────

/// Zentrale Breakpoint-Schwellen. Orientierung an Material-3-Window-Size-
/// Classes (Compact <600 / Medium 600–840 / Expanded ≥840 / Large ≥1200),
/// bewusst an unsere Shell angepasst (navRail = 900, nicht 840; siehe §5.1).
///
/// Alle Werte sind `static const double` und dürfen in `switch`-Guards und
/// `if`-Bedingungen ohne Laufzeit-Overhead verwendet werden.
class Breakpoints {
  Breakpoints._();

  /// Phone vs. nicht-Phone. CLAUDE.md-konform: Bottom-Nav-Grenze.
  /// Material-3 Compact-Obergrenze.
  static const double phone = 600;

  /// Shell-Switch: ab hier zeigt `main_screen.dart` die NavigationRail statt
  /// der Bottom-Nav. Bewusst 900 statt M3-Standard 840, weil 840 px Viewport
  /// bei einer 220-px-Rail nur ~620 px Body lässt — zu eng für zwei Spalten.
  /// **Verhaltensändernd** ggü. heute (`<800`): Band 800–899 wechselt in
  /// Phase B von Sidebar auf Bottom-Nav. Nur für App-Shell gedacht.
  static const double navRail = 900;

  /// Master-Detail-Schwelle für Screen-interne Splits (Deals-Summary-Panel,
  /// Tickets-Detail-Panel, Inventory-Detail, Warehouse-Hub-Detail).
  /// Mindest-Body-Breite ~980 px (bei 220-px-Rail: 1200–220 = 980) erlaubt
  /// eine 360-px-Liste + 600-px-Detail komfortabel.
  static const double master = 1200;

  /// NavigationRail extended (Labels sichtbar) statt collapsed (Icons only).
  /// Identisch mit [master] — beide Eigenschaften treten bei 1200 px ein.
  static const double railExtended = 1200;

  // ── Legacy-Shell-Konstanten (Phase B — Cleanup abgeschlossen) ───────────
  //
  // Historie:
  // - `legacyShellNarrow` (800) hat in Phase A `main_screen.dart` Z. 321
  //   gespiegelt. Mit T1.3b ist die Shell-Schwelle auf [navRail] (900)
  //   migriert; `legacyShellNarrow` wurde entfernt.
  // - `legacyShellExtended` (1100) wurde in T1.3b in `main_screen.dart` durch
  //   [railExtended] (1200) und in T1.4b in `deals_screen.dart`/
  //   `tickets_screen.dart` durch [master] (1200) ersetzt. Die Konstante ist
  //   damit komplett tot und wurde entfernt.

  // ── Legacy-Konstanten Cluster A (Phase A — T1.4a) ─────────────────────────
  //
  // Spiegeln Magic Numbers aus Listen-Screens exakt wider.
  // 700 gilt für `inventory_screen.dart` und `deal_table.dart` — daher eine
  // gemeinsame Konstante [legacyListNarrow].
  // 650 gilt für `tickets_screen.dart` (Mobile-Layout-Switch).
  //
  // Konsolidierung in Phase B / T1.4b: Entscheidung, ob diese Schwellen auf
  // [phone] (600) oder einen neuen Breakpoint-Wert angepasst werden, bleibt
  // dem Phase-B-PR überlassen. NICHT in neuen Screens verwenden.

  /// @deprecated Phase-A-Platzhalter für `inventory_screen.dart` Z. 52 und
  /// `deal_table.dart` Z. 130. Wird in Phase B durch eine endgültige Schwelle
  /// ersetzt und entfernt.
  static const double legacyListNarrow = 700;

  /// @deprecated Phase-A-Platzhalter für `tickets_screen.dart` Z. 167
  /// (Mobile-Layout-Switch). Wird in Phase B durch eine endgültige Schwelle
  /// ersetzt und entfernt.
  static const double legacyTicketsNarrow = 650;

  // ── Legacy-Konstanten Cluster B (Phase A — T1.5a) ─────────────────────────
  //
  // Spiegeln Magic Numbers aus Dashboard, Settings, Onboarding und
  // PublicProfile exakt wider. Phase A = Indirektion, Werte identisch.
  // Konsolidierung in Phase B / T1.5b (falls vorhanden).
  // NICHT in neuen Screens verwenden.

  // Dashboard ------------------------------------------------------------------

  /// @deprecated Magic Number aus `dashboard_screen.dart` —
  /// BuyerOverview/ActivityFeed nebeneinander ab dieser Container-Breite.
  /// Wird in Phase B konsolidiert.
  static const double legacyDashboardWide = 960;

  /// @deprecated Magic Number aus `dashboard_screen.dart` —
  /// LowStockAlertBlock und EmptyStateCard wechseln auf Phone-Layout
  /// unter dieser Container-Breite.
  /// Wird in Phase B gegen [phone] (600) geprüft.
  static const double legacyDashboardCompact = 520;

  /// @deprecated Magic Number aus `dashboard_screen.dart` KPI-Grid —
  /// unter dieser Breite 2 Spalten statt 3.
  /// Wird in Phase B gegen [phone] (600) geprüft.
  static const double legacyKpiCompact = 500;

  /// @deprecated Magic Number aus `dashboard_screen.dart` KPI-Grid —
  /// unter dieser Breite 3 Spalten statt 4. Semantisch anders als
  /// [navRail] (Shell-Switch) — nicht zusammenführen ohne Audit.
  /// Wird in Phase B geprüft.
  static const double legacyKpiMedium = 900;

  // Settings ------------------------------------------------------------------

  /// @deprecated Magic Number aus `settings_screen.dart` —
  /// Settings-Karten (Re-Parse, Demo-Wipe) stapeln vertikal unter dieser
  /// Container-Breite. Wird in Phase B gegen [phone] (600) geprüft.
  static const double legacySettingsCompact = 480;

  // Public Profile ------------------------------------------------------------

  /// @deprecated Magic Number aus `public_profile_screen.dart` —
  /// Produkt-Grid wechselt von 1 auf 2 Spalten ab dieser Viewport-Breite.
  /// Wird in Phase B gegen [phone] (600) geprüft.
  static const double legacyProfileMedium = 700;

  /// @deprecated Magic Number aus `public_profile_screen.dart` —
  /// Produkt-Grid wechselt von 2 auf 3 Spalten ab dieser Viewport-Breite.
  /// Semantisch verschieden von der alten Rail-Labels-Schwelle (1100) —
  /// daher nicht beim T1.4b-Cleanup mitentfernt.
  /// Wird in Phase B konsolidiert.
  static const double legacyProfileWide = 1100;

  // ── Legacy-Konstanten Cluster C (Phase A — T1.6a) ─────────────────────────
  //
  // Spiegeln Magic Numbers aus Statistics-Widgets, Dialogen und Screens
  // exakt wider. Phase A = Indirektion, Werte identisch.
  // Konsolidierung in Phase B / T1.6b. NICHT in neuen Screens verwenden.

  /// @deprecated Phase-A-Platzhalter für `statistics/filter_bar.dart` und
  /// `tabs/overview_tab.dart` (zweimal). "Wide"-Layout ab hier (> 900 px).
  /// Wird in Phase B durch [navRail] (900) ersetzt und entfernt.
  static const double legacyStatsWide = 900;

  /// @deprecated Phase-A-Platzhalter für `tabs/finance_tab.dart` und
  /// `tabs/inventory_suppliers_tab.dart` (mehrfach). "Wide"-Layout ab 800 px.
  /// Wird in Phase B durch eine endgültige Schwelle ersetzt und entfernt.
  static const double legacyStatsFinanceWide = 800;

  /// @deprecated Phase-A-Platzhalter für `tabs/inventory_suppliers_tab.dart`
  /// (Spaltenanzahl-Switch und KPI-Reihe) und `add_edit_deal_dialog.dart`.
  /// "Narrow"-Layout unterhalb 480 px (einspaltig statt zweispaltig).
  /// Wird in Phase B durch eine endgültige Schwelle ersetzt und entfernt.
  static const double legacyStatsNarrow = 480;

  /// @deprecated Phase-A-Platzhalter für `screens/inbox_screen.dart` Z. 1249.
  /// Kompaktes Zeitstempel-Layout unterhalb 340 px (sehr schmaler Container).
  /// Wird in Phase B durch eine endgültige Schwelle ersetzt und entfernt.
  static const double legacyInboxNarrow = 340;

  /// @deprecated Phase-A-Platzhalter für `widgets/tracking_status_block.dart`
  /// Z. 601. Vertikal gestapelter Button-Layout unterhalb 320 px.
  /// Wird in Phase B durch eine endgültige Schwelle ersetzt und entfernt.
  static const double legacyTrackingNarrow = 320;

  /// @deprecated Phase-A-Platzhalter für
  /// `widgets/statistics/charts/donut_chart.dart`. Donut+Legende nebeneinander
  /// ab 360 px Container-Breite; darunter gestapelt.
  /// Wird in Phase B durch eine endgültige Schwelle ersetzt und entfernt.
  static const double legacyDonutNarrow = 360;
}

// ── ScreenSize-Enum (Viewport-Achse — App-Shell) ───────────────────────────

/// Viewport-Größenklasse des gesamten App-Fensters.
///
/// Diese Enum wird ausschließlich von den Viewport-Helpern ([screenSizeOf],
/// [isPhoneViewport], [isDesktopViewport]) zurückgegeben und ist für die
/// App-Shell-Entscheidung in `main_screen.dart` gedacht. Alle Screen-internen
/// Layout-Entscheidungen verwenden stattdessen [WidthClass] über
/// [widthClassOf].
///
/// Grenzen (entsprechen [Breakpoints]):
/// - [compact]  : Viewport-Breite < [Breakpoints.phone] (600)
/// - [medium]   : [Breakpoints.phone] ≤ Breite < [Breakpoints.navRail] (900)
/// - [expanded] : [Breakpoints.navRail] ≤ Breite < [Breakpoints.master] (1200)
/// - [large]    : Breite ≥ [Breakpoints.master] (1200)
enum ScreenSize {
  /// Viewport < 600 px — Phone.
  compact,

  /// 600 ≤ Viewport < 900 px — großes Phone / kleines Tablet.
  medium,

  /// 900 ≤ Viewport < 1200 px — Tablet / kleines Laptop.
  expanded,

  /// Viewport ≥ 1200 px — Desktop / großes Laptop.
  large,
}

// ── WidthClass-Enum (Container-Achse — Screen-intern) ─────────────────────

/// Container-Breitenklasse für Layout-Entscheidungen INNERHALB eines Screens.
///
/// Semantisch von [ScreenSize] getrennt: gleiche Schwellen ([Breakpoints]),
/// aber die Quelle ist immer `constraints.maxWidth` aus einem `LayoutBuilder`
/// — niemals `MediaQuery`. Damit ist der Viewport-vs-Container-Bug
/// strukturell ausgeschlossen.
///
/// Beispiel:
/// ```dart
/// LayoutBuilder(
///   builder: (context, constraints) {
///     final wc = widthClassOf(constraints.maxWidth);
///     return isLarge(constraints.maxWidth)
///         ? _MasterDetailLayout()
///         : _SingleColumnLayout();
///   },
/// );
/// ```
///
/// Grenzen (entsprechen [Breakpoints]):
/// - [compact]  : Breite < [Breakpoints.phone] (600)
/// - [medium]   : [Breakpoints.phone] ≤ Breite < [Breakpoints.navRail] (900)
/// - [expanded] : [Breakpoints.navRail] ≤ Breite < [Breakpoints.master] (1200)
/// - [large]    : Breite ≥ [Breakpoints.master] (1200)
enum WidthClass {
  /// Container-Breite < 600 px.
  compact,

  /// 600 ≤ Container-Breite < 900 px.
  medium,

  /// 900 ≤ Container-Breite < 1200 px.
  expanded,

  /// Container-Breite ≥ 1200 px.
  large,
}

// ── Viewport-Achse (NUR für main_screen.dart) ──────────────────────────────

/// Gibt die [ScreenSize] des aktuellen App-Fensters zurück.
///
/// Nutzt `MediaQuery.sizeOf(context)` (performant: kein vollständiges
/// `MediaQueryData`-Rebuild). Darf **ausschließlich in `main_screen.dart`**
/// für den Shell-Switch (Bottom-Nav vs. NavigationRail) verwendet werden.
/// Für alle anderen Layout-Entscheidungen: [widthClassOf] aus einem
/// `LayoutBuilder`.
ScreenSize screenSizeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < Breakpoints.phone) return ScreenSize.compact;
  if (width < Breakpoints.navRail) return ScreenSize.medium;
  if (width < Breakpoints.master) return ScreenSize.expanded;
  return ScreenSize.large;
}

/// Gibt `true` zurück, wenn der Viewport Phone-Breite hat
/// (< [Breakpoints.phone] = 600 px).
///
/// Darf **ausschließlich in `main_screen.dart`** verwendet werden.
/// Für Screen-interne Prüfungen: [isCompact].
bool isPhoneViewport(BuildContext context) =>
    MediaQuery.sizeOf(context).width < Breakpoints.phone;

/// Gibt `true` zurück, wenn der Viewport Desktop-Breite hat
/// (≥ [Breakpoints.navRail] = 900 px).
///
/// Darf **ausschließlich in `main_screen.dart`** verwendet werden.
/// Für Screen-interne Prüfungen: [isExpanded] oder [isLarge].
bool isDesktopViewport(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.navRail;

// ── Container-Achse (für alle LayoutBuilder-Stellen) ──────────────────────

/// Gibt die [WidthClass] für eine gegebene Container-Breite zurück.
///
/// Typischer Aufruf:
/// ```dart
/// LayoutBuilder(builder: (context, constraints) {
///   final wc = widthClassOf(constraints.maxWidth);
///   ...
/// });
/// ```
///
/// Nimmt KEINEN `BuildContext` — damit ist es strukturell unmöglich,
/// versehentlich `MediaQuery.sizeOf` statt `constraints.maxWidth` zu nutzen.
WidthClass widthClassOf(double width) {
  if (width < Breakpoints.phone) return WidthClass.compact;
  if (width < Breakpoints.navRail) return WidthClass.medium;
  if (width < Breakpoints.master) return WidthClass.expanded;
  return WidthClass.large;
}

/// `true` wenn Container-Breite < [Breakpoints.phone] (600 px).
///
/// Aus einem `LayoutBuilder` aufrufen: `isCompact(constraints.maxWidth)`.
bool isCompact(double width) => width < Breakpoints.phone;

/// `true` wenn [Breakpoints.phone] ≤ Container-Breite < [Breakpoints.navRail]
/// (600–899 px).
///
/// Aus einem `LayoutBuilder` aufrufen: `isMedium(constraints.maxWidth)`.
bool isMedium(double width) =>
    width >= Breakpoints.phone && width < Breakpoints.navRail;

/// `true` wenn [Breakpoints.navRail] ≤ Container-Breite < [Breakpoints.master]
/// (900–1199 px).
///
/// Aus einem `LayoutBuilder` aufrufen: `isExpanded(constraints.maxWidth)`.
bool isExpanded(double width) =>
    width >= Breakpoints.navRail && width < Breakpoints.master;

/// `true` wenn Container-Breite ≥ [Breakpoints.master] (1200 px).
///
/// Aus einem `LayoutBuilder` aufrufen: `isLarge(constraints.maxWidth)`.
/// Typisch für Master-Detail-Splits und Rail-Extended-Zustand.
bool isLarge(double width) => width >= Breakpoints.master;
