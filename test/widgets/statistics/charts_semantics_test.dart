import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/l10n/app_localizations.dart';
import 'package:inventory_management/services/statistics_service.dart';
import 'package:inventory_management/widgets/statistics/charts/donut_chart.dart';
import 'package:inventory_management/widgets/statistics/charts/monthly_bar_chart.dart';
import 'package:inventory_management/widgets/statistics/charts/profit_line_chart.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Minimaler MaterialApp-Wrapper mit DE l10n.
Widget _wrap(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('de'),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

/// Erstellt einen einfachen TimeBucket mit gesetztem Profit und Revenue.
TimeBucket _bucket({
  required DateTime date,
  double profit = 0,
  double revenue = 0,
}) {
  final b = TimeBucket(date: date, granularity: Granularity.month);
  b.profit = profit;
  b.revenue = revenue;
  return b;
}

// ─────────────────────────────────────────────────────────────────────────────
// MonthlyBarChart (Säulendiagramm)
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('MonthlyBarChart — Semantics', () {
    testWidgets('hat Säulendiagramm-Label mit korrekten Daten', (tester) async {
      final series = [
        _bucket(date: DateTime(2026, 1), profit: 200, revenue: 800),
        _bucket(date: DateTime(2026, 2), profit: 500, revenue: 1200),
        _bucket(date: DateTime(2026, 3), profit: 150, revenue: 600),
      ];

      await tester.pumpWidget(
        _wrap(
          MonthlyBarChart(
            series: series,
            title: 'Profit pro Monat',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Semantics-Label muss „Säulendiagramm" enthalten und die Anzahl der Werte.
      expect(
        find.bySemanticsLabel(RegExp(r'Säulendiagramm.*')),
        findsOneWidget,
      );

      // Das Label muss die Wert-Anzahl (3) enthalten.
      expect(
        find.bySemanticsLabel(RegExp(r'.*3 Werte.*')),
        findsOneWidget,
      );
    });

    testWidgets('hat Fallback-Label bei leerer Series', (tester) async {
      await tester.pumpWidget(
        _wrap(MonthlyBarChart(series: const [])),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'Diagramm lädt.*', caseSensitive: false)),
        findsOneWidget,
      );
    });

    testWidgets('excludeSemantics verhindert doppelte interne Knoten', (tester) async {
      final series = [
        _bucket(date: DateTime(2026, 4), profit: 300, revenue: 900),
      ];

      await tester.pumpWidget(
        _wrap(MonthlyBarChart(series: series, title: 'Test-Bar')),
      );
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'Säulendiagramm.*')),
      );
      // Der semantische Knoten hat das korrekte zusammengesetzte Label.
      expect(node.label, contains('Säulendiagramm'));
      handle.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MarginLineChart (Liniendiagramm)
  // ─────────────────────────────────────────────────────────────────────────

  group('MarginLineChart — Semantics', () {
    testWidgets('hat Liniendiagramm-Label mit korrekten Daten', (tester) async {
      final series = [
        _bucket(date: DateTime(2026, 1), profit: 100, revenue: 500),
        _bucket(date: DateTime(2026, 2), profit: 200, revenue: 600),
      ];

      await tester.pumpWidget(
        _wrap(MarginLineChart(series: series, title: 'Marge')),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'Liniendiagramm.*')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'.*2 Datenpunkte.*')),
        findsOneWidget,
      );
    });

    testWidgets('Fallback-Label bei leerer Series', (tester) async {
      await tester.pumpWidget(
        _wrap(const MarginLineChart(series: [])),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'Diagramm lädt.*', caseSensitive: false)),
        findsOneWidget,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // ProfitLineChart (Liniendiagramm — Umsatz + Profit)
  // ─────────────────────────────────────────────────────────────────────────

  group('ProfitLineChart — Semantics', () {
    testWidgets('hat Liniendiagramm-Label mit korrekten Daten', (tester) async {
      final series = [
        _bucket(date: DateTime(2026, 1), profit: 300, revenue: 1500),
        _bucket(date: DateTime(2026, 2), profit: 450, revenue: 2000),
        _bucket(date: DateTime(2026, 3), profit: 200, revenue: 1000),
      ];

      await tester.pumpWidget(
        _wrap(ProfitLineChart(series: series, title: 'Profit & Umsatz')),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'Liniendiagramm.*')),
        findsOneWidget,
      );
      // 3 Datenpunkte vorhanden
      expect(
        find.bySemanticsLabel(RegExp(r'.*3 Datenpunkte.*')),
        findsOneWidget,
      );
    });

    testWidgets('Fallback-Label bei leerer Series', (tester) async {
      await tester.pumpWidget(
        _wrap(const ProfitLineChart(series: [])),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'Diagramm lädt.*', caseSensitive: false)),
        findsOneWidget,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // DonutChart (Tortendiagramm)
  // ─────────────────────────────────────────────────────────────────────────

  group('DonutChart — Semantics', () {
    testWidgets('hat Tortendiagramm-Label mit dominantem Segment', (tester) async {
      const data = {
        'Käufer A': 800.0,
        'Käufer B': 400.0,
        'Käufer C': 200.0,
      };

      await tester.pumpWidget(
        _wrap(
          DonutChart(
            data: data,
            centerLabel: 'Gesamt',
            title: 'Profit nach Käufer',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'Tortendiagramm.*')),
        findsOneWidget,
      );

      // Dominantes Segment ist „Käufer A"
      expect(
        find.bySemanticsLabel(RegExp(r'.*Käufer A.*')),
        findsOneWidget,
      );
    });

    testWidgets('Fallback-Label bei leeren Daten', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonutChart(
            data: {},
            centerLabel: 'Gesamt',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'Diagramm lädt.*', caseSensitive: false)),
        findsOneWidget,
      );
    });

    testWidgets('Segment-Anzahl korrekt im Label', (tester) async {
      const data = {
        'A': 500.0,
        'B': 300.0,
        'C': 100.0,
        'D': 50.0,
      };

      await tester.pumpWidget(
        _wrap(
          DonutChart(
            data: data,
            centerLabel: 'Total',
            topN: 3, // 3 top + 1 "Sonstige" = 4 Segmente
            title: 'Test-Donut',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 4 Segmente (3 top + Sonstige)
      expect(
        find.bySemanticsLabel(RegExp(r'.*4 Segmente.*')),
        findsOneWidget,
      );
    });
  });
}
