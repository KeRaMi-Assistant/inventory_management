/// Enum-Migration für die Top-Level-Navigation. Vorher: Magic-Number-
/// Indizes (`_selectedIndex == 2` etc.) in `main_screen.dart`,
/// `global_search_dialog.dart`, `inbox_screen.dart`. Nachher:
/// Compile-Time-sichere Enum-Werte.
///
/// Plan-Ref: plans/2026-05-16_ux_quickwins_audit.md §Task #00.
/// Vorbedingung für Task #01 (Bottom-Nav-Refactor) — ohne das Enum
/// bricht jede Nav-Reorder lautlos zur Runtime.
enum MainTab {
  dashboard,
  deals,
  tickets,
  inbox,
  inventory,
  suppliers,
  stats,
  activity,
  settings,
  help,
  /// Warenwirtschaft-Hub (AF11). Sub-routes (Bestellungen, Lager,
  /// Warengruppen, Inventur, Reporting) werden als gepushte Routen
  /// INNERHALB des Hubs geöffnet — kein eigener MainTab pro Bereich.
  warehouse,
}
