import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/utils/responsive.dart';
import 'package:inventory_management/widgets/app_screen_scaffold.dart';
import 'package:inventory_management/widgets/empty_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper: rendert AppScreenScaffold in einem MaterialApp mit gegebener Breite
// ─────────────────────────────────────────────────────────────────────────────

Widget _buildScaffold({
  required double width,
  double height = 800,
  bool isEmpty = false,
  Widget? emptyState,
  Widget? header,
  Widget? fab,
  PreferredSizeWidget? appBar,
  double maxContentWidth = 1200,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      child: SizedBox(
        width: width,
        height: height,
        child: AppScreenScaffold(
          appBar: appBar,
          floatingActionButton: fab,
          header: header,
          isEmpty: isEmpty,
          emptyState: emptyState,
          maxContentWidth: maxContentWidth,
          body: const _BodySentinel(),
        ),
      ),
    ),
  );
}

/// Sentinel-Widget, das wir im Body suchen, um zu prüfen ob der Body gerendert
/// wird (vs. emptyState).
class _BodySentinel extends StatelessWidget {
  const _BodySentinel();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: Key('bodySentinel'),
      color: Colors.transparent,
      child: SizedBox.expand(),
    );
  }
}

void main() {
  // ── A11y-Key ──────────────────────────────────────────────────────────────

  testWidgets('AppScreenScaffold — appScreenContent Key vorhanden', (tester) async {
    await tester.pumpWidget(_buildScaffold(width: 360));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('appScreenContent')), findsOneWidget);
  });

  // ── Phone (360 px) — kein maxWidth-Constraint ─────────────────────────────

  testWidgets(
      'AppScreenScaffold — auf 360 px Phone rendert Body volle Breite '
      '(kein ConstrainedBox)', (tester) async {
    await tester.pumpWidget(_buildScaffold(width: 360));
    await tester.pumpAndSettle();

    // Auf Phone (compact) gibt es keinen ConstrainedBox → Body füllt alles.
    expect(find.byKey(const Key('bodySentinel')), findsOneWidget);

    // Kein Overflow
    expect(tester.takeException(), isNull);
  });

  // ── Desktop (1600 px) — maxWidth-Constraint greift ───────────────────────

  testWidgets(
      'AppScreenScaffold — auf 1600 px Desktop ist Content-Breite ≤ maxContentWidth',
      (tester) async {
    // Viewport 1600 px
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildScaffold(width: 1600, maxContentWidth: 1200));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('appScreenContent')), findsOneWidget);

    // ConstrainedBox mit maxWidth = 1200 muss im Tree existieren.
    final constrainedBoxes = tester.widgetList<ConstrainedBox>(
      find.byType(ConstrainedBox),
    );
    final hasMaxWidth = constrainedBoxes
        .any((cb) => cb.constraints.maxWidth <= 1200);
    expect(hasMaxWidth, isTrue,
        reason: 'Auf Desktop muss ein ConstrainedBox mit maxWidth ≤ 1200 '
            'existieren');
  });

  // ── isEmpty: true → emptyState sichtbar, body nicht ─────────────────────

  testWidgets('AppScreenScaffold — zeigt emptyState wenn isEmpty == true',
      (tester) async {
    await tester.pumpWidget(
      _buildScaffold(
        width: 360,
        isEmpty: true,
        emptyState: const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Leer',
          subtitle: 'Keine Einträge',
          keySlug: 'test',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // EmptyState sichtbar
    expect(find.byKey(const Key('emptyState-test')), findsOneWidget);
    // Body NICHT sichtbar
    expect(find.byKey(const Key('bodySentinel')), findsNothing);
  });

  // ── isEmpty: false → body sichtbar ───────────────────────────────────────

  testWidgets('AppScreenScaffold — zeigt body wenn isEmpty == false', (tester) async {
    await tester.pumpWidget(
      _buildScaffold(
        width: 360,
        isEmpty: false,
        emptyState: const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Leer',
          subtitle: 'Keine Einträge',
          keySlug: 'test',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bodySentinel')), findsOneWidget);
    expect(find.byKey(const Key('emptyState-test')), findsNothing);
  });

  // ── AppBar-Slot ──────────────────────────────────────────────────────────

  testWidgets('AppScreenScaffold — AppBar wird korrekt gerendert', (tester) async {
    await tester.pumpWidget(
      _buildScaffold(
        width: 360,
        appBar: AppBar(
          key: const Key('testAppBar'),
          title: const Text('Test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('testAppBar')), findsOneWidget);
  });

  // ── FAB-Slot ─────────────────────────────────────────────────────────────

  testWidgets('AppScreenScaffold — FAB wird korrekt gerendert', (tester) async {
    await tester.pumpWidget(
      _buildScaffold(
        width: 390,
        fab: FloatingActionButton(
          key: const Key('testFab'),
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('testFab')), findsOneWidget);
  });

  // ── Header-Slot ──────────────────────────────────────────────────────────

  testWidgets('AppScreenScaffold — Header-Slot wird gerendert', (tester) async {
    await tester.pumpWidget(
      _buildScaffold(
        width: 360,
        header: const SizedBox(
          key: Key('testHeader'),
          height: 48,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('testHeader')), findsOneWidget);
  });

  // ── Breakpoint boundary: exakt bei Breakpoints.phone ────────────────────

  testWidgets(
      'AppScreenScaffold — bei exakt phone-Breakpoint (600 px) kein Overflow',
      (tester) async {
    await tester.pumpWidget(_buildScaffold(width: Breakpoints.phone));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('appScreenContent')), findsOneWidget);
  });

  // ── Kein Overflow auf 360×640 ────────────────────────────────────────────

  testWidgets('AppScreenScaffold — kein Overflow auf 360×640 Phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildScaffold(width: 360, height: 640));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // ── Dark mode ────────────────────────────────────────────────────────────

  testWidgets('AppScreenScaffold — kein Crash im Dark-Mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: SizedBox(
          width: 390,
          height: 844,
          child: AppScreenScaffold(
            appBar: AppBar(title: const Text('Dark')),
            body: const _BodySentinel(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
