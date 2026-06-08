import 'main_tab.dart';

/// Sektions-Ebene (Tier-2b) ÜBER dem stabilen [MainTab]-Enum.
///
/// **Warum eine eigene Ebene statt Enum-Refactor?**
///
/// `MainTab` (11 Werte) bleibt der stabile State-Schlüssel in
/// `main_screen.dart` (`_selectedIndex`), `global_search_dialog.dart`
/// (`selectTab(MainTab)`), `inbox_screen.dart` etc. Ein Enum-Refactor
/// würde jeden Deep-Link-Pfad lautlos brechen. Stattdessen legen wir die
/// 5 **Sektionen** der neuen Informationsarchitektur (Plan §1) als dünne
/// Gruppierungs-Ebene darüber:
///
/// - **Bottom-Nav (Phone):** 5 Sektions-Slots statt 5+„Mehr".
/// - **Rail (Desktop):** 5 flache Destinations statt 11 (kein `scrollable`).
/// - **Sub-Tabs** innerhalb Verkauf/Auswertung über `SegmentedButton`.
///
/// `MainTab.inventory` / `MainTab.suppliers` / `MainTab.help` bleiben
/// gültige Deep-Link-Ziele (z.B. aus der Command-Palette oder dem
/// Dashboard) — sie mappen über [sectionOf] in die richtige Sektion,
/// sind aber selbst keine eigenen Bottom-/Rail-Slots mehr.
enum MainSection { dashboard, verkauf, lager, auswertung, konto }

/// Mappt jeden [MainTab] auf seine Sektion. Total über alle 11 Enum-Werte
/// — der Compiler erzwingt Vollständigkeit (kein `default`-Fallthrough).
MainSection sectionOf(MainTab t) => switch (t) {
      MainTab.dashboard => MainSection.dashboard,
      MainTab.deals || MainTab.tickets || MainTab.inbox => MainSection.verkauf,
      MainTab.inventory ||
      MainTab.suppliers ||
      MainTab.warehouse =>
        MainSection.lager,
      MainTab.stats || MainTab.activity => MainSection.auswertung,
      MainTab.settings || MainTab.help => MainSection.konto,
    };

/// Der Default-Tab, der beim Wechsel IN eine Sektion gewählt wird.
///
/// Lager-Sektion = der konsolidierte [MainTab.warehouse]-Hub (Tier-2a),
/// der Bestand/Lieferanten/Artikelstamm/… als Kacheln zeigt.
MainTab defaultTabOf(MainSection s) => switch (s) {
      MainSection.dashboard => MainTab.dashboard,
      MainSection.verkauf => MainTab.deals,
      MainSection.lager => MainTab.warehouse,
      MainSection.auswertung => MainTab.stats,
      MainSection.konto => MainTab.settings,
    };
