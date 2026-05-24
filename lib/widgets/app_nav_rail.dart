import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../screens/main_tab.dart';
import 'brand_logo.dart';

/// Wiederverwendbares Desktop-NavigationRail-Widget, das das alte
/// `_Sidebar`-Custom-Widget aus [`main_screen.dart`] ersetzt
/// (D1b — Foundation in D1a, Wire-Up in D1b).
///
/// **Warum existiert dieses Widget?**
///
/// Die alte Custom-Sidebar hat eigene Hover-/Selected-/Badge-Logik
/// gebaut, ohne Material-3-Keyboard-Focus + M3-State-Layer. Wir wechseln
/// auf [NavigationRail] aus dem Material-Framework, behalten aber
/// Branding-Header (Logo + optional Wordmark) und das
/// `_navVisibility`-Filter-Verhalten (Free-Plan-Gating, Feature-Flags)
/// 1:1 bei.
///
/// **API-Design-Punkte:**
///
/// - Callback liefert `MainTab` (Enum), NICHT den int-Index der Rail.
///   Der dichte `selectedIndex` der Rail ≠ `MainTab.index`, sobald ein
///   Tab via [visibility] ausgeblendet ist. Index-Mapping (
///   `visibleTabAtRailIndex`) passiert intern.
/// - Icon-/Label-/Badge-Resolver werden via Builder injiziert — die
///   Logik (welches Outline-Icon, welches Selected-Icon, welcher
///   Badge-Count) lebt heute in `main_screen.dart` und soll dort
///   bleiben.
/// - [extended] berechnet der Caller via Container-Breite (≥1200) —
///   das Widget kennt keinen Breakpoint.
///
/// **Bug-Hunter-Fix (Flutter-Assertion):**
/// `extended: true` UND `labelType != null/none` löst `assert(!extended
/// || labelType == null || labelType == NavigationRailLabelType.none)`
/// im Material-Framework aus. Wir setzen daher:
/// - `extended: true`  → `labelType: null`
/// - `extended: false` → `labelType: NavigationRailLabelType.none`
///   (Labels sind nicht hilfreich, wenn die Rail collapsed ist;
///   `Tooltip` über das Icon zeigt sie. Hätten wir hier `.all` gesetzt,
///   würden Labels unterhalb der Icons immer mitgerendert — das passt
///   nicht zur heutigen Sidebar-Optik, in der collapsed = nur Icons.)
///
/// **Scrollable (Bug-Hunter Pre-Filter-Finding):**
/// 11 [MainTab.values] passen in 900px-Höhe knapp, sobald Branding-
/// Header + System-UI dazu kommen, wird's eng. Flutter SDK ≥ 3.27 hat
/// `NavigationRail.scrollable: true` — das wird gesetzt, damit
/// vertikales Scrollen automatisch greift.
///
/// **A11y-Keys** (Pflicht laut Plan §5.1.1):
/// - `Key('mainNavRail')` auf dem Root.
/// - `Key('navRailDestination-<tab.name>')` auf jeder Destination.
class AppNavRail extends StatelessWidget {
  /// Alle [MainTab]s in der Reihenfolge, in der sie potenziell angezeigt
  /// werden. Der Caller übergibt die volle Liste; der Filter passiert
  /// intern via [visibility].
  final List<MainTab> tabs;

  /// Per-Tab-Sichtbarkeit (Free-Plan-Gating, Feature-Flags etc.).
  /// `null` oder `true` ⇒ sichtbar, `false` ⇒ ausgeblendet.
  final Map<MainTab, bool> visibility;

  /// Aktuell gewählter Tab. Falls dieser Tab in [visibility] auf
  /// `false` steht, fällt das Widget defensiv auf
  /// `selectedIndex: 0` zurück (kein Crash, kein automatischer
  /// `onSelect`-Call — der Caller soll widersprüchliche States nicht
  /// produzieren).
  final MainTab selectedTab;

  /// Callback bei Tab-Auswahl. Liefert [MainTab], nicht int.
  final ValueChanged<MainTab> onSelect;

  /// Erweiterte Variante (Labels neben Icons sichtbar, breitere Rail).
  /// Caller berechnet das aus der Container-Breite (≥ 1200 dp).
  final bool extended;

  /// Icon-Resolver pro Tab. Erhält [tab] und [selected]-Flag; soll für
  /// `selected == true` das gefüllte/aktive Icon liefern, sonst das
  /// Outline-Icon.
  final Widget Function(MainTab tab, bool selected) iconBuilder;

  /// Label-Resolver pro Tab (l10n-strings aus dem Caller).
  final String Function(MainTab tab) labelBuilder;

  /// Optional: Badge-Resolver (z.B. Inbox-Unread-Count). Liefert
  /// `null`, wenn der Tab keinen Badge tragen soll.
  final Widget? Function(MainTab tab)? badgeBuilder;

  const AppNavRail({
    super.key,
    required this.tabs,
    required this.visibility,
    required this.selectedTab,
    required this.onSelect,
    required this.extended,
    required this.iconBuilder,
    required this.labelBuilder,
    this.badgeBuilder,
  });

  /// Sicherheits-kritisch: Filter erzeugt die tatsächlich gerenderten
  /// Tabs aus der vollen [tabs]-Liste und [visibility]-Map. Reihenfolge
  /// bleibt erhalten — der dichte int-Index der NavigationRail
  /// referenziert diese Liste.
  List<MainTab> _visibleTabs() {
    return tabs.where((t) => visibility[t] != false).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleTabs();

    // Defensiver Fallback: wenn [selectedTab] gerade nicht sichtbar ist
    // (z.B. Plan-Downgrade hat einen Premium-Tab versteckt), zeigen wir
    // die Rail mit selectedIndex 0 — kein Crash. Der Caller behält die
    // Verantwortung, den State zu korrigieren (typischerweise via
    // initial-Tab-Logik in main_screen).
    final selectedIndex = visible.contains(selectedTab)
        ? visible.indexOf(selectedTab)
        : 0;

    // Branding-Header — identisch zur heutigen `_Sidebar`:
    // - BrandMark immer sichtbar, mit eingebettetem Indigo-Gradient-Hintergrund.
    // - BrandWordmark NUR wenn extended (sonst zu breit für die 64px-Rail).
    // - Hintergrund-Token: AppTheme.navBg (fix dunkel, keine Of(context)-Variante,
    //   weil die Sidebar in beiden Themes Brand-dunkel bleiben soll).
    final leading = SizedBox(
      height: 56,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 10),
        child: Row(
          mainAxisAlignment:
              extended ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            const BrandMark(size: 28, withBackground: true),
            if (extended) ...[
              const SizedBox(width: 10),
              const BrandWordmark(
                fontSize: 16,
                onDark: true,
                canColor: Colors.white,
                logisticsColor: Color(0xCCFFFFFF),
              ),
            ],
          ],
        ),
      ),
    );

    // API-Fix: bei extended NIE labelType setzen, bei !extended .none.
    final labelType =
        extended ? null : NavigationRailLabelType.none;

    return NavigationRail(
      key: const Key('mainNavRail'),
      backgroundColor: AppTheme.navBg,
      selectedIndex: selectedIndex,
      extended: extended,
      labelType: labelType,
      // 11 Tabs in einer 900-px-Höhe sind eng — Flutter ≥ 3.27 lässt die
      // Rail-Items scrollen, sobald sie nicht passen.
      scrollable: true,
      leading: leading,
      useIndicator: true,
      indicatorColor: Colors.white.withAlpha(20),
      selectedIconTheme: const IconThemeData(
        color: Colors.white,
        size: 22,
      ),
      unselectedIconTheme: const IconThemeData(
        color: AppTheme.navIcon,
        size: 22,
      ),
      selectedLabelTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: AppTheme.navLabel,
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      onDestinationSelected: (int railIndex) {
        // Index-Mapping: dichter NavRail-Index → MainTab.
        if (railIndex < 0 || railIndex >= visible.length) return;
        onSelect(visible[railIndex]);
      },
      destinations: [
        for (final tab in visible)
          _buildDestination(context, tab, tab == selectedTab),
      ],
    );
  }

  NavigationRailDestination _buildDestination(
    BuildContext context,
    MainTab tab,
    bool selected,
  ) {
    final outlineIcon = iconBuilder(tab, false);
    final selectedIcon = iconBuilder(tab, true);
    final label = labelBuilder(tab);

    // Optional: Badge um das Icon herum (z.B. Inbox-Unread-Count).
    // Konvention aus dem alten `_NavItem`: badgeKey = 'mobile-nav-<tab>-badge'.
    final badge = badgeBuilder?.call(tab);

    Widget wrapBadge(Widget icon) {
      if (badge == null) return icon;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            top: -4,
            right: -4,
            child: KeyedSubtree(
              key: Key('mobile-nav-${tab.name}-badge'),
              child: badge,
            ),
          ),
        ],
      );
    }

    // `NavigationRailDestination` selbst nimmt keinen `key`-Parameter
    // für die einzelne Destination — der Test/Selector-Anker landet
    // daher auf dem Icon-Subtree. NavigationRail rendert je nach
    // Selection-State entweder `icon` ODER `selectedIcon` (nicht beide),
    // daher tragen BEIDE den Destination-Key, damit ein Test sicher
    // einen einzigen Treffer findet — egal ob das Tab gerade selected
    // ist oder nicht.
    final destKey = Key('navRailDestination-${tab.name}');
    return NavigationRailDestination(
      icon: KeyedSubtree(
        key: destKey,
        child: wrapBadge(outlineIcon),
      ),
      selectedIcon: KeyedSubtree(
        key: destKey,
        child: wrapBadge(selectedIcon),
      ),
      label: Text(label),
    );
  }
}
