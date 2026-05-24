import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // ── D1c: Keyboard-Navigation-Tests ────────────────────────────────────────

  // D1c-1: Tab-Key fokussiert NavigationRail-Destinations sequenziell.
  // Jede Destination ist via Material's InkResponse ein Focus-Knoten;
  // Tab-Traversal durchläuft sie in Renderreihenfolge (= Tab-Enum-Reihenfolge).
  testWidgets('AppNavRail — Tab-Key traverses destinations sequentially', (tester) async {
    tester.binding.focusManager.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    await tester.pumpWidget(_wrap(
      tabs: _allTabs,
      visibility: _allVisible(),
      selectedTab: MainTab.dashboard,
    ));
    await tester.pumpAndSettle();

    // Erstes Tab: Fokus landet auf dem ersten NavigationRail-Destination-Item.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    final firstFocused = tester.binding.focusManager.primaryFocus;
    expect(
      firstFocused,
      isNotNull,
      reason: 'Nach 1x Tab muss ein Focus-Knoten aktiv sein',
    );
    expect(
      firstFocused!.hasPrimaryFocus,
      isTrue,
      reason: 'primaryFocus.hasPrimaryFocus muss true sein',
    );

    // Zweites Tab: Fokus wechselt zu einem anderen Knoten (= nächste Destination).
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    final secondFocused = tester.binding.focusManager.primaryFocus;
    expect(
      secondFocused,
      isNotNull,
      reason: 'Nach 2x Tab muss weiterhin ein Focus-Knoten aktiv sein',
    );
    // Der Fokus muss sich von Schritt 1 auf Schritt 2 unterscheiden —
    // Tab hat eine neue Destination fokussiert.
    expect(
      secondFocused,
      isNot(same(firstFocused)),
      reason: 'Tab muss den Fokus von Destination 1 auf Destination 2 verschieben',
    );
  });

  // D1c-2: Enter löst onSelect mit dem richtigen MainTab aus.
  // Tab-Traversal: Tab 0 → dashboard (Index 0), Tab 1 → deals (Index 1).
  testWidgets('AppNavRail — Enter on focused destination fires onSelect', (tester) async {
    tester.binding.focusManager.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    final selections = <MainTab>[];

    await tester.pumpWidget(_wrap(
      tabs: _allTabs,
      visibility: _allVisible(),
      selectedTab: MainTab.dashboard,
      onSelect: selections.add,
    ));
    await tester.pumpAndSettle();

    // Tab zum ersten Item (dashboard, Index 0 in der Rail).
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(tester.binding.focusManager.primaryFocus?.hasPrimaryFocus, isTrue);

    // Enter aktiviert das fokussierte Item.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      selections,
      hasLength(1),
      reason: 'Enter auf fokussierter Destination muss onSelect genau einmal rufen',
    );
    expect(
      selections.first,
      MainTab.dashboard,
      reason: 'Fokussiertes Item war dashboard (erste Destination in Rail)',
    );
  });

  // D1c-3: Space löst ebenfalls onSelect aus (WCAG: Space und Enter sind
  // gleichwertige Aktivierungs-Tasten für fokussierbare Elemente).
  testWidgets('AppNavRail — Space on focused destination fires onSelect', (tester) async {
    tester.binding.focusManager.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    final selections = <MainTab>[];

    await tester.pumpWidget(_wrap(
      tabs: _allTabs,
      visibility: _allVisible(),
      selectedTab: MainTab.dashboard,
      onSelect: selections.add,
    ));
    await tester.pumpAndSettle();

    // Tab zum zweiten Item (deals, Tab 1 in der traversierten Rail).
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(tester.binding.focusManager.primaryFocus?.hasPrimaryFocus, isTrue);

    // Space aktiviert das fokussierte Item (deals).
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(
      selections,
      hasLength(1),
      reason: 'Space auf fokussierter Destination muss onSelect genau einmal rufen',
    );
    expect(
      selections.first,
      MainTab.deals,
      reason: 'Zweite Tab-Traversal-Position ist deals',
    );
  });

  // D1c-4: Mehrfache Tab-Traversal wechselt sukzessive Destinations.
  // Entspricht dem Verhalten "ArrowDown navigiert zur nächsten Destination"
  // (NavigationRail nutzt Column-Traversal über Tab, nicht Arrow-Keys intern).
  testWidgets(
      'AppNavRail — repeated Tab advances focus through destinations in order',
      (tester) async {
    tester.binding.focusManager.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    final selections = <MainTab>[];

    await tester.pumpWidget(_wrap(
      tabs: _allTabs,
      visibility: _allVisible(),
      selectedTab: MainTab.dashboard,
      onSelect: selections.add,
    ));
    await tester.pumpAndSettle();

    // Aktiviere 3 Destinations der Reihe nach über Tab + Enter.
    final expected = [MainTab.dashboard, MainTab.deals, MainTab.tickets];
    for (final expectedTab in expected) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        selections.last,
        expectedTab,
        reason: 'Tab+Enter muss Destination $expectedTab auswählen',
      );
    }
    expect(selections, hasLength(3));
  });

  // D1c-5: Selected-Indicator via Semantics — bei selectedTab=MainTab.deals
  // hat die deals-Destination `isSelected` im Semantics-Baum, alle anderen nicht.
  testWidgets('AppNavRail — selected destination has isSelected in semantics', (tester) async {
    await tester.pumpWidget(_wrap(
      tabs: _allTabs,
      visibility: _allVisible(),
      selectedTab: MainTab.deals,
    ));
    await tester.pumpAndSettle();

    // deals ist selected — Semantics-Flag muss gesetzt sein.
    final dealsSem =
        tester.getSemantics(find.byKey(const Key('navRailDestination-deals')));
    expect(
      dealsSem.flagsCollection.isSelected.name,
      'isTrue',
      reason:
          'navRailDestination-deals muss Semantics-Flag isSelected=true tragen',
    );

    // dashboard ist NICHT selected.
    final dashSem =
        tester.getSemantics(find.byKey(const Key('navRailDestination-dashboard')));
    expect(
      dashSem.flagsCollection.isSelected.name,
      isNot('isTrue'),
      reason: 'navRailDestination-dashboard darf isSelected=true NICHT tragen',
    );

    // Alle sichtbaren Tabs bis auf deals müssen isSelected=false haben.
    for (final tab in _allTabs) {
      if (tab == MainTab.deals) continue;
      final sem = tester.getSemantics(
        find.byKey(Key('navRailDestination-${tab.name}')),
      );
      expect(
        sem.flagsCollection.isSelected.name,
        isNot('isTrue'),
        reason: '${tab.name} darf isSelected=true nicht tragen wenn deals selected ist',
      );
    }
  });

  // D1c-6: Visibility-Filter + Keyboard-Traversal — versteckter Tab wird
  // bei Tab-Traversal übersprungen (er existiert nicht im Widget-Tree,
  // daher kein Focus-Knoten dafür). Nach N Tabs über alle sichtbaren
  // Destinations wurde deals nie als Focus-Ziel erreicht.
  testWidgets(
      'AppNavRail — Tab traversal skips hidden destination (visibility=false)',
      (tester) async {
    tester.binding.focusManager.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    // deals ist ausgeblendet.
    final vis = _allVisible();
    vis[MainTab.deals] = false;

    final selections = <MainTab>[];

    await tester.pumpWidget(_wrap(
      tabs: _allTabs,
      visibility: vis,
      selectedTab: MainTab.dashboard,
      onSelect: selections.add,
    ));
    await tester.pumpAndSettle();

    // Versuche, alle 10 sichtbaren Destinations via Tab+Enter zu aktivieren.
    // deals darf dabei NIE vorkommen.
    const visibleCount = 10; // 11 - 1 (deals hidden)
    for (int i = 0; i < visibleCount; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
    }

    expect(
      selections.contains(MainTab.deals),
      isFalse,
      reason: 'deals ist hidden — Tab-Traversal+Enter darf deals nie triggern',
    );
    expect(
      selections.length,
      visibleCount,
      reason: 'Genau $visibleCount Selections für $visibleCount sichtbare Destinations',
    );
  });
}
