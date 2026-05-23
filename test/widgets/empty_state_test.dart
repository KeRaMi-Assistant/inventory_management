import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/widgets/empty_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper: minimal MaterialApp wrapper — EmptyState braucht keinen l10n-Context,
// da alle Strings vom Caller kommen.
// ─────────────────────────────────────────────────────────────────────────────

Widget _wrap(Widget child, {double phoneWidth = 360, double height = 640}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(phoneWidth, height)),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  // ── Smoke test ──────────────────────────────────────────────────────────────

  testWidgets('EmptyState — renders icon, title and subtitle', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const EmptyState(
          icon: Icons.category_outlined,
          title: 'Keine Kategorien',
          subtitle: 'Tippe auf +, um die erste Kategorie anzulegen.',
          keySlug: 'categories',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Key gesetzt
    expect(find.byKey(const Key('emptyState-categories')), findsOneWidget);

    // Texte vorhanden
    expect(find.text('Keine Kategorien'), findsOneWidget);
    expect(
      find.text('Tippe auf +, um die erste Kategorie anzulegen.'),
      findsOneWidget,
    );

    // Icon vorhanden
    expect(find.byIcon(Icons.category_outlined), findsOneWidget);

    // Kein Overflow auf 360 px
    expect(tester.takeException(), isNull);
  });

  // ── Action-Slot ─────────────────────────────────────────────────────────────

  testWidgets('EmptyState — renders action widget when provided', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Kein Eingang',
          subtitle: 'Noch keine E-Mails.',
          keySlug: 'inbox',
          action: ElevatedButton(
            key: const Key('emptyAction'),
            onPressed: () => tapped = true,
            child: const Text('Jetzt verbinden'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('emptyAction')), findsOneWidget);
    await tester.tap(find.byKey(const Key('emptyAction')));
    expect(tapped, isTrue);
  });

  // ── No action slot ──────────────────────────────────────────────────────────

  testWidgets('EmptyState — no action widget by default', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const EmptyState(
          icon: Icons.warehouse_outlined,
          title: 'Keine Lager',
          subtitle: 'Lege dein erstes Lager an.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Default keySlug
    expect(find.byKey(const Key('emptyState-default')), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  // ── No overflow on 360×640 ──────────────────────────────────────────────────

  testWidgets('EmptyState — no overflow on 360×640 Phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        const EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Kein Inventar vorhanden',
          subtitle:
              'Füge Artikel über den Button hinzu oder importiere eine Liste.',
          keySlug: 'inventory',
          action: Text('Artikel hinzufügen'),
        ),
        phoneWidth: 360,
        height: 640,
      ),
    );
    await tester.pumpAndSettle();

    // RenderOverflow triggers a FlutterError
    expect(tester.takeException(), isNull);
  });

  // ── Dark mode — no exception ────────────────────────────────────────────────

  testWidgets('EmptyState — renders in dark mode without crash', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: EmptyState(
            icon: Icons.sell_outlined,
            title: 'Keine Deals',
            subtitle: 'Lege deinen ersten Deal an.',
            keySlug: 'deals',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('emptyState-deals')), findsOneWidget);
  });
}
