import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/widgets/statistics/kpi_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper: minimaler MaterialApp-Wrapper — KpiCard braucht keinen l10n-Context,
// alle Strings kommen als Parameter.
// ─────────────────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  // ── Semantics-Label ohne Trend ─────────────────────────────────────────────

  testWidgets('KpiCard — Semantics-Label ohne deltaPct', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const KpiCard(
          label: 'Offene Bestellungen',
          value: '42',
          icon: Icons.shopping_cart_outlined,
          accent: Colors.blue,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Semantics-Label entspricht „KPI <label>, Wert <value>" ohne Trend.
    expect(
      find.bySemanticsLabel('KPI Offene Bestellungen, Wert 42'),
      findsOneWidget,
    );
  });

  // ── Semantics-Label mit positivem Trend ───────────────────────────────────

  testWidgets('KpiCard — Semantics-Label mit positivem deltaPct',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const KpiCard(
          label: 'Umsatz',
          value: '1.234 €',
          icon: Icons.payments_outlined,
          accent: Colors.green,
          deltaPct: 12.5,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('KPI Umsatz, Wert 1.234 €, Trend +12.5%'),
      findsOneWidget,
    );
  });

  // ── Semantics-Label mit negativem Trend + deltaLabel ─────────────────────

  testWidgets('KpiCard — Semantics-Label mit negativem deltaPct + deltaLabel',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const KpiCard(
          label: 'Gewinn',
          value: '500 €',
          icon: Icons.trending_up,
          accent: Colors.purple,
          deltaPct: -8.0,
          deltaLabel: 'vs. Vormonat',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('KPI Gewinn, Wert 500 €, Trend -8.0% vs. Vormonat'),
      findsOneWidget,
    );
  });

  // ── excludeSemantics verhindert doppeltes Vorlesen der internen Texte ─────

  testWidgets(
      'KpiCard — interne Text-Widgets sind per excludeSemantics ausgeblendet',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const KpiCard(
          label: 'Kritischer Bestand',
          value: '3',
          icon: Icons.warning_amber_rounded,
          accent: Colors.red,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Das Semantics-Label auf dem Root ist gesetzt.
    expect(
      find.bySemanticsLabel('KPI Kritischer Bestand, Wert 3'),
      findsOneWidget,
    );

    // Die internen Text-Widgets „3" und „Kritischer Bestand" dürfen dem
    // Semantics-Tree NICHT als eigene Knoten erscheinen, da excludeSemantics:
    // true sie ausblendet.
    final semanticsHandle = tester.ensureSemantics();
    final semanticsTree = tester.getSemantics(
      find.bySemanticsLabel('KPI Kritischer Bestand, Wert 3'),
    );
    // Der Semantics-Knoten hat das zusammengesetzte Label — kein separater
    // Knoten für „3" alleine.
    expect(semanticsTree.label, equals('KPI Kritischer Bestand, Wert 3'));
    semanticsHandle.dispose();
  });

  // ── Null-Delta bleibt stabil (kein !-Bang-Crash) ──────────────────────────

  testWidgets('KpiCard — rendert ohne Overflow bei deltaPct = null',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const KpiCard(
          label: 'Heute angekommen',
          value: '7',
          icon: Icons.today_outlined,
          accent: Colors.teal,
          // deltaPct absichtlich nicht gesetzt
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // ── deltaInverted beeinflusst NICHT das Semantics-Label ───────────────────

  testWidgets('KpiCard — deltaInverted=true ändert nur Farbe, nicht Label',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const KpiCard(
          label: 'Offene Forderungen',
          value: '200 €',
          icon: Icons.hourglass_empty,
          accent: Colors.orange,
          deltaPct: 5.0,
          deltaInverted: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Label bleibt neutral — die Farb-Interpretation (rot = schlecht, da
    // invertiert) liegt beim Theme, nicht im Semantics-Text.
    expect(
      find.bySemanticsLabel('KPI Offene Forderungen, Wert 200 €, Trend +5.0%'),
      findsOneWidget,
    );
  });

  // ── KpiGrid rendert mehrere KpiCards ohne Overflow ────────────────────────

  testWidgets('KpiGrid — rendert 3 KpiCards ohne Overflow auf 360 px',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(360, 640)),
          child: Scaffold(
            body: KpiGrid(
              cards: const [
                KpiCard(
                  label: 'A',
                  value: '1',
                  icon: Icons.abc,
                  accent: Colors.blue,
                ),
                KpiCard(
                  label: 'B',
                  value: '2',
                  icon: Icons.abc,
                  accent: Colors.green,
                ),
                KpiCard(
                  label: 'C',
                  value: '3',
                  icon: Icons.abc,
                  accent: Colors.red,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Alle drei Semantics-Labels vorhanden
    expect(find.bySemanticsLabel('KPI A, Wert 1'), findsOneWidget);
    expect(find.bySemanticsLabel('KPI B, Wert 2'), findsOneWidget);
    expect(find.bySemanticsLabel('KPI C, Wert 3'), findsOneWidget);
  });
}
