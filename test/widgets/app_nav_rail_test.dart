import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/screens/main_section.dart';
import 'package:inventory_management/widgets/app_nav_rail.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test-Helpers — minimal MaterialApp-Wrapper. Tier-2b: AppNavRail ist jetzt
// Sektions-basiert (5 MainSection-Destinations statt 11 MainTab). Es gibt kein
// visibility-Gating mehr — alle 5 Sektionen sind immer sichtbar (Inbox-Gating
// lebt im Verkauf-SegmentedButton, nicht in der Rail).
// ─────────────────────────────────────────────────────────────────────────────

const _allSections = MainSection.values;

Widget _outlineIcon(MainSection section, bool selected) =>
    Icon(selected ? Icons.star : Icons.star_border);

String _labelFor(MainSection section) => section.name;

Widget _wrap({
  List<MainSection> sections = _allSections,
  required MainSection selectedSection,
  ValueChanged<MainSection>? onSelect,
  bool extended = false,
  Widget? Function(MainSection section)? badgeBuilder,
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
              sections: sections,
              selectedSection: selectedSection,
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
  // ── Smoke: alle 5 Sektionen gerendert ──────────────────────────────────────

  testWidgets('AppNavRail — renders one destination per section', (tester) async {
    await tester.pumpWidget(_wrap(
      selectedSection: MainSection.dashboard,
      extended: true,
    ));
    await tester.pumpAndSettle();

    // Ein Destination-Key pro Sektion — 5 erwartet.
    for (final section in _allSections) {
      expect(
        find.byKey(Key('navRailDestination-${section.name}')),
        findsOneWidget,
        reason: 'Destination-Key fehlt für ${section.name}',
      );
    }

    // Root-Key
    expect(find.byKey(const Key('mainNavRail')), findsOneWidget);

    // Kein Overflow / kein Crash
    expect(tester.takeException(), isNull);
  });

  // ── onSelect liefert MainSection (Enum, nicht int) ─────────────────────────

  testWidgets('AppNavRail — onSelect callback receives MainSection, not int',
      (tester) async {
    final selections = <MainSection>[];

    await tester.pumpWidget(_wrap(
      selectedSection: MainSection.dashboard,
      extended: true,
      onSelect: selections.add,
    ));
    await tester.pumpAndSettle();

    // Tippe auf die "verkauf"-Destination — NavigationRail löst
    // onDestinationSelected aus.
    await tester.tap(find.byKey(const Key('navRailDestination-verkauf')));
    await tester.pumpAndSettle();

    expect(selections, hasLength(1));
    expect(selections.first, MainSection.verkauf);
  });

  // ── onSelect mapt dichten Rail-Index zurück auf die Sektion ────────────────

  testWidgets('AppNavRail — onSelect maps dense rail index back to MainSection',
      (tester) async {
    final selections = <MainSection>[];

    await tester.pumpWidget(_wrap(
      selectedSection: MainSection.dashboard,
      extended: true,
      onSelect: selections.add,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('navRailDestination-auswertung')));
    await tester.pumpAndSettle();

    expect(selections.first, MainSection.auswertung);
  });

  // ── Defensiver Fallback: selectedSection nicht in Liste ────────────────────

  testWidgets('AppNavRail — does not crash with subset of sections',
      (tester) async {
    await tester.pumpWidget(_wrap(
      sections: const [MainSection.dashboard, MainSection.verkauf],
      // Eine Sektion, die nicht in der (subset-)Liste ist — defensiver 0.
      selectedSection: MainSection.konto,
      extended: true,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('mainNavRail')), findsOneWidget);
  });

  // ── extended-Variante zeigt Wordmark ──────────────────────────────────────

  testWidgets('AppNavRail — extended=true shows wordmark', (tester) async {
    await tester.pumpWidget(_wrap(
      selectedSection: MainSection.dashboard,
      extended: true,
    ));
    await tester.pumpAndSettle();

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
      selectedSection: MainSection.dashboard,
      extended: false,
    ));
    await tester.pumpAndSettle();

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
      selectedSection: MainSection.dashboard,
      extended: true,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mainNavRail')), findsOneWidget);
    expect(find.byKey(const Key('navRailDestination-dashboard')),
        findsOneWidget);
    expect(find.byKey(const Key('navRailDestination-lager')), findsOneWidget);
    expect(find.byKey(const Key('navRailDestination-konto')), findsOneWidget);
  });

  // ── Badge-Builder ─────────────────────────────────────────────────────────

  testWidgets(
      'AppNavRail — badge appears on section when badgeBuilder returns non-null',
      (tester) async {
    await tester.pumpWidget(_wrap(
      selectedSection: MainSection.dashboard,
      extended: true,
      badgeBuilder: (section) {
        if (section == MainSection.verkauf) {
          return const Text('3', key: Key('test-badge-text'));
        }
        return null;
      },
    ));
    await tester.pumpAndSettle();

    // Badge sitzt im KeyedSubtree mit konventionellem Key.
    expect(
      find.byKey(const Key('mobile-nav-verkauf-badge')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('test-badge-text')), findsOneWidget);

    // Andere Sektionen haben keinen Badge.
    expect(find.byKey(const Key('mobile-nav-dashboard-badge')), findsNothing);
  });

  // ── Keyboard-Navigation: Tab-Traversal ─────────────────────────────────────

  testWidgets('AppNavRail — Tab-Key traverses destinations sequentially',
      (tester) async {
    tester.binding.focusManager.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    await tester.pumpWidget(_wrap(
      selectedSection: MainSection.dashboard,
    ));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    final firstFocused = tester.binding.focusManager.primaryFocus;
    expect(firstFocused, isNotNull);
    expect(firstFocused!.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    final secondFocused = tester.binding.focusManager.primaryFocus;
    expect(secondFocused, isNotNull);
    expect(
      secondFocused,
      isNot(same(firstFocused)),
      reason: 'Tab muss den Fokus von Destination 1 auf Destination 2 verschieben',
    );
  });

  // ── Enter aktiviert die fokussierte Destination ────────────────────────────

  testWidgets('AppNavRail — Enter on focused destination fires onSelect',
      (tester) async {
    tester.binding.focusManager.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    final selections = <MainSection>[];

    await tester.pumpWidget(_wrap(
      selectedSection: MainSection.dashboard,
      onSelect: selections.add,
    ));
    await tester.pumpAndSettle();

    // Tab zum ersten Item (dashboard, Index 0 in der Rail).
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(tester.binding.focusManager.primaryFocus?.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(selections, hasLength(1));
    expect(selections.first, MainSection.dashboard);
  });

  // ── Space aktiviert die fokussierte Destination ────────────────────────────

  testWidgets('AppNavRail — Space on focused destination fires onSelect',
      (tester) async {
    tester.binding.focusManager.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    final selections = <MainSection>[];

    await tester.pumpWidget(_wrap(
      selectedSection: MainSection.dashboard,
      onSelect: selections.add,
    ));
    await tester.pumpAndSettle();

    // Tab zum zweiten Item (verkauf).
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(tester.binding.focusManager.primaryFocus?.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(selections, hasLength(1));
    expect(selections.first, MainSection.verkauf);
  });

  // ── Wiederholtes Tab durchläuft Sektionen in Reihenfolge ───────────────────

  testWidgets(
      'AppNavRail — repeated Tab advances focus through sections in order',
      (tester) async {
    tester.binding.focusManager.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    final selections = <MainSection>[];

    await tester.pumpWidget(_wrap(
      selectedSection: MainSection.dashboard,
      onSelect: selections.add,
    ));
    await tester.pumpAndSettle();

    final expected = [
      MainSection.dashboard,
      MainSection.verkauf,
      MainSection.lager,
    ];
    for (final expectedSection in expected) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        selections.last,
        expectedSection,
        reason: 'Tab+Enter muss Sektion $expectedSection auswählen',
      );
    }
    expect(selections, hasLength(3));
  });

  // ── Selected-Indicator via Semantics ───────────────────────────────────────

  testWidgets('AppNavRail — selected destination has isSelected in semantics',
      (tester) async {
    await tester.pumpWidget(_wrap(
      selectedSection: MainSection.verkauf,
    ));
    await tester.pumpAndSettle();

    final verkaufSem = tester
        .getSemantics(find.byKey(const Key('navRailDestination-verkauf')));
    expect(
      verkaufSem.flagsCollection.isSelected.name,
      'isTrue',
      reason:
          'navRailDestination-verkauf muss Semantics-Flag isSelected=true tragen',
    );

    final dashSem = tester
        .getSemantics(find.byKey(const Key('navRailDestination-dashboard')));
    expect(
      dashSem.flagsCollection.isSelected.name,
      isNot('isTrue'),
      reason: 'navRailDestination-dashboard darf isSelected=true NICHT tragen',
    );

    for (final section in _allSections) {
      if (section == MainSection.verkauf) continue;
      final sem = tester.getSemantics(
        find.byKey(Key('navRailDestination-${section.name}')),
      );
      expect(
        sem.flagsCollection.isSelected.name,
        isNot('isTrue'),
        reason:
            '${section.name} darf isSelected=true nicht tragen wenn verkauf selected ist',
      );
    }
  });
}
