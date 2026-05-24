import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/screens/main_tab.dart';
import 'package:inventory_management/widgets/app_nav_rail.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test-Helpers — minimal MaterialApp-Wrapper. AppNavRail braucht keinen
// l10n-Context, da Label-/Icon-Resolver vom Caller injiziert werden.
// ─────────────────────────────────────────────────────────────────────────────

const _allTabs = MainTab.values;

Map<MainTab, bool> _allVisible() =>
    {for (final t in _allTabs) t: true};

Widget _outlineIcon(MainTab tab, bool selected) =>
    Icon(selected ? Icons.star : Icons.star_border);

String _labelFor(MainTab tab) => tab.name;

Widget _wrap({
  required List<MainTab> tabs,
  required Map<MainTab, bool> visibility,
  required MainTab selectedTab,
  ValueChanged<MainTab>? onSelect,
  bool extended = false,
  Widget? Function(MainTab tab)? badgeBuilder,
  double width = 1440,
  double height = 900,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      child: Scaffold(
        body: Row(
          children: [
            AppNavRail(
              tabs: tabs,
              visibility: visibility,
              selectedTab: selectedTab,
              onSelect: onSelect ?? (_) {},
              extended: extended,
              iconBuilder: _outlineIcon,
              labelBuilder: _labelFor,
              badgeBuilder: badgeBuilder,
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    ),
  );
}

void main() {
  // ── Smoke: alle 11 Tabs gerendert ──────────────────────────────────────────

  testWidgets('AppNavRail — renders one destination per visible tab', (tester) async {
    await tester.pumpWidget(_wrap(
      tabs: _allTabs,
      visibility: _allVisible(),
      selectedTab: MainTab.dashboard,
      extended: true,
    ));
    await tester.pumpAndSettle();

    // Ein Destination-Key pro Tab — 11 erwartet.
    for (final tab in _allTabs) {
      expect(
        find.byKey(Key('navRailDestination-${tab.name}')),
        findsOneWidget,
        reason: 'Destination-Key fehlt für ${tab.name}',
      );
    }

    // Root-Key
    expect(find.byKey(const Key('mainNavRail')), findsOneWidget);

    // Kein Overflow / kein Crash
    expect(tester.takeException(), isNull);
  });

  // ── Visibility-Filter: 1 Tab versteckt ────────────────────────────────────

  testWidgets('AppNavRail — hides tabs flagged visibility=false', (tester) async {
    final vis = _allVisible();
    vis[MainTab.inbox] = false;

    await tester.pumpWidget(_wrap(
      tabs: _allTabs,
      visibility: vis,
      selectedTab: MainTab.dashboard,
      extended: true,
    ));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('navRailDestination-inbox')),
      findsNothing,
    );

    // Alle anderen 10 Tabs bleiben sichtbar.
    var visibleCount = 0;
    for (final tab in _allTabs) {
      if (tab == MainTab.inbox) continue;
      expect(
        find.byKey(Key('navRailDestination-${tab.name}')),
        findsOneWidget,
      );
      visibleCount += 1;
    }
    expect(visibleCount, 10);
  });

  // ── Defensiver Fallback: selectedTab nicht sichtbar ────────────────────────

  testWidgets('AppNavRail — does not crash when selectedTab is hidden', (tester) async {
    final vis = _allVisible();
    vis[MainTab.inbox] = false;

    await tester.pumpWidget(_wrap(
      tabs: _allTabs,
      visibility: vis,
      // selectedTab ist gerade NICHT sichtbar — Widget muss defensiv 0 wählen,
      // nicht crashen.
      selectedTab: MainTab.inbox,
      extended: true,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // NavigationRail rendert weiterhin (mit selectedIndex 0 intern).
    expect(find.byKey(const Key('mainNavRail')), findsOneWidget);
  });

  // ── onSelect liefert MainTab (Enum, nicht int) ─────────────────────────────

  testWidgets('AppNavRail — onSelect callback receives MainTab, not int', (tester) async {
    final selections = <MainTab>[];

    await tester.pumpWidget(_wrap(
      tabs: _allTabs,
      visibility: _allVisible(),
      selectedTab: MainTab.dashboard,
      extended: true,
      onSelect: selections.add,
    ));
    await tester.pumpAndSettle();

    // Tippe auf die "deals"-Destination — Flutter NavigationRail
    // löst onDestinationSelected aus.
    await tester.tap(find.byKey(const Key('navRailDestination-deals')));
    await tester.pumpAndSettle();

    expect(selections, hasLength(1));
    expect(selections.first, MainTab.deals);
  });

  // ── onSelect mit gefiltertem Index-Mapping ────────────────────────────────

  testWidgets('AppNavRail — onSelect maps dense rail index back to MainTab', (tester) async {
    // Versteckt den ersten Tab (dashboard). Dann ist die NavRail-Position 0
    // der zweite Enum-Wert (deals), Position 1 der dritte (tickets), …
    final vis = _allVisible();
    vis[MainTab.dashboard] = false;

    final selections = <MainTab>[];

    await tester.pumpWidget(_wrap(
      tabs: _allTabs,
      visibility: vis,
      selectedTab: MainTab.deals,
      extended: true,
      onSelect: selections.add,
    ));
    await tester.pumpAndSettle();

    // Position 1 (zweite sichtbare Destination nach `deals`) → `tickets`.
    await tester.tap(find.byKey(const Key('navRailDestination-tickets')));
    await tester.pumpAndSettle();

    expect(selections.first, MainTab.tickets);
  });

  // ── extended-Variante zeigt Wordmark ──────────────────────────────────────

  testWidgets('AppNavRail — extended=true shows wordmark', (tester) async {
    await tester.pumpWidget(_wrap(
      tabs: _allTabs,
      visibility: _allVisible(),
      selectedTab: MainTab.dashboard,
      extended: true,
    ));
    await tester.pumpAndSettle();

    // BrandWordmark rendert "Can" + "Logistics" via RichText.
    // Wir suchen nach dem RichText-Text-Fragment.
    final wordmarks = find.byWidgetPredicate((w) {
      if (w is! RichText) return false;
      final span = w.text.toPlainText();
      return span.contains('CanLogistics') || span.contains('Can');
    });
    expect(wordmarks, findsWidgets);
  });

  // ── !extended-Variante: kein Wordmark, nur Mark ───────────────────────────

  testWidgets('AppNavRail — extended=false hides wordmark', (tester) async {
    await tester.pumpWidget(_wrap(
      tabs: _allTabs,
      visibility: _allVisible(),
      selectedTab: MainTab.dashboard,
      extended: false,
    ));
    await tester.pumpAndSettle();

    // Keine RichText-Spans mit "Can"+"Logistics" im Header.
    final wordmarks = find.byWidgetPredicate((w) {
      if (w is! RichText) return false;
      final span = w.text.toPlainText();
      return span.contains('CanLogistics');
    });
    expect(wordmarks, findsNothing);
  });

  // ── A11y-Keys ──────────────────────────────────────────────────────────────

  testWidgets('AppNavRail — root and destination keys present', (tester) async {
    await tester.pumpWidget(_wrap(
      tabs: _allTabs,
      visibility: _allVisible(),
      selectedTab: MainTab.dashboard,
      extended: true,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mainNavRail')), findsOneWidget);
    expect(find.byKey(const Key('navRailDestination-dashboard')),
        findsOneWidget);
    expect(find.byKey(const Key('navRailDestination-warehouse')),
        findsOneWidget);
  });

  // ── Badge-Builder ─────────────────────────────────────────────────────────

  testWidgets('AppNavRail — badge appears on tab when badgeBuilder returns non-null',
      (tester) async {
    await tester.pumpWidget(_wrap(
      tabs: _allTabs,
      visibility: _allVisible(),
      selectedTab: MainTab.dashboard,
      extended: true,
      badgeBuilder: (tab) {
        if (tab == MainTab.inbox) {
          return const Text('3', key: Key('test-badge-text'));
        }
        return null;
      },
    ));
    await tester.pumpAndSettle();

    // Badge sitzt im KeyedSubtree mit konventionellem Key.
    expect(
      find.byKey(const Key('mobile-nav-inbox-badge')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('test-badge-text')), findsOneWidget);

    // Andere Tabs haben keinen Badge.
    expect(find.byKey(const Key('mobile-nav-dashboard-badge')), findsNothing);
  });
}
