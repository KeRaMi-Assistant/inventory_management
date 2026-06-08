import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../screens/main_section.dart';
import 'brand_logo.dart';

/// Desktop-NavigationRail der App-Shell.
///
/// **Tier-2b-Umbau (T2.5):** Die Rail ist jetzt **Sektions-basiert**
/// (5 [MainSection]-Destinations) statt 11 [MainTab]-Destinations. Das
/// behebt E3/F2 aus dem Nav-Redesign-Plan:
/// - 11 → 5 Destinations passen komfortabel in jede Viewport-Höhe →
///   `scrollable` ist entfernt (war eine Notlösung).
/// - Inbox-Plan-Gating lebt nicht mehr in der Rail (kein
///   `visibility`-Filter mehr), sondern im Verkauf-`SegmentedButton`.
///   Alle 5 Sektionen sind immer sichtbar.
///
/// **API-Design:**
/// - Callback liefert [MainSection] (Enum), nicht den int-Index.
/// - Icon-/Label-/Badge-Resolver werden via Builder injiziert — die Logik
///   (welches Icon, welches Label, welcher Badge-Count) lebt im Caller
///   (`main_screen.dart`) und bleibt dort.
/// - [extended] berechnet der Caller via Viewport-Breite (≥1200) — das
///   Widget kennt keinen Breakpoint.
///
/// **Bug-Hunter-Fix (Flutter-Assertion, weiter gültig):**
/// `extended: true` UND `labelType != null/none` löst die Material-
/// Assertion aus. Daher:
/// - `extended: true`  → `labelType: null`
/// - `extended: false` → `labelType: NavigationRailLabelType.none`
///
/// **A11y-Keys:**
/// - `Key('mainNavRail')` auf dem Root.
/// - `Key('navRailDestination-<section.name>')` auf jeder Destination
///   (z.B. `navRailDestination-verkauf`).
class AppNavRail extends StatelessWidget {
  /// Die 5 Sektionen in Anzeigereihenfolge. Der Caller übergibt die volle
  /// Liste (`MainSection.values`).
  final List<MainSection> sections;

  /// Aktuell gewählte Sektion.
  final MainSection selectedSection;

  /// Callback bei Sektions-Auswahl. Liefert [MainSection], nicht int.
  final ValueChanged<MainSection> onSelect;

  /// Erweiterte Variante (Labels neben Icons sichtbar, breitere Rail).
  /// Caller berechnet das aus der Viewport-Breite (≥1200 dp).
  final bool extended;

  /// Icon-Resolver pro Sektion. Erhält [section] und [selected]-Flag; soll
  /// für `selected == true` das gefüllte/aktive Icon liefern, sonst das
  /// Outline-Icon.
  final Widget Function(MainSection section, bool selected) iconBuilder;

  /// Label-Resolver pro Sektion (l10n-strings aus dem Caller).
  final String Function(MainSection section) labelBuilder;

  /// Optional: Badge-Resolver (z.B. aggregierter Tracking-Count auf der
  /// Verkauf-Sektion). Liefert `null`, wenn die Sektion keinen Badge trägt.
  final Widget? Function(MainSection section)? badgeBuilder;

  const AppNavRail({
    super.key,
    required this.sections,
    required this.selectedSection,
    required this.onSelect,
    required this.extended,
    required this.iconBuilder,
    required this.labelBuilder,
    this.badgeBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // Defensiver Fallback: wenn [selectedSection] (warum auch immer) nicht
    // in [sections] ist, zeigen wir Index 0 — kein Crash.
    final selectedIndex = sections.contains(selectedSection)
        ? sections.indexOf(selectedSection)
        : 0;

    // Branding-Header — identisch zur bisherigen Rail:
    // - BrandMark immer sichtbar, mit Indigo-Gradient-Hintergrund.
    // - BrandWordmark NUR wenn extended (sonst zu breit für die Rail).
    // - Hintergrund-Token: AppTheme.navBg (fix dunkel in beiden Themes,
    //   weil die Rail Brand-dunkel bleiben soll).
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
    final labelType = extended ? null : NavigationRailLabelType.none;

    return NavigationRail(
      key: const Key('mainNavRail'),
      backgroundColor: AppTheme.navBg,
      selectedIndex: selectedIndex,
      extended: extended,
      labelType: labelType,
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
        if (railIndex < 0 || railIndex >= sections.length) return;
        onSelect(sections[railIndex]);
      },
      destinations: [
        for (final section in sections)
          _buildDestination(context, section, section == selectedSection),
      ],
    );
  }

  NavigationRailDestination _buildDestination(
    BuildContext context,
    MainSection section,
    bool selected,
  ) {
    final outlineIcon = iconBuilder(section, false);
    final selectedIcon = iconBuilder(section, true);
    final label = labelBuilder(section);

    // Optional: Badge um das Icon herum (z.B. aggregierter Tracking-Count).
    final badge = badgeBuilder?.call(section);

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
              key: Key('mobile-nav-${section.name}-badge'),
              child: badge,
            ),
          ),
        ],
      );
    }

    // `NavigationRailDestination` nimmt keinen `key`-Parameter — der Anker
    // landet auf dem Icon-Subtree. NavigationRail rendert je nach
    // Selection-State entweder `icon` ODER `selectedIcon`; daher tragen
    // BEIDE den Destination-Key, damit ein Test sicher genau einen Treffer
    // findet.
    final destKey = Key('navRailDestination-${section.name}');
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
