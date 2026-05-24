import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/app_theme.dart';
import 'package:inventory_management/l10n/app_localizations.dart';
import 'package:inventory_management/utils/responsive.dart';
import 'package:inventory_management/widgets/app_feedback.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Baut eine vollständige MaterialApp mit dem gegebenen Viewport (logical px).
///
/// Die App enthält einen zentralen Button, der beim Tippen die angegebene
/// [showFeedback]-Callback aufruft. So können wir AppFeedback-Aufrufe
/// aus einem echten BuildContext heraus testen.
Widget _buildApp({
  required double width,
  required double height,
  required void Function(BuildContext context) showFeedback,
  ThemeData? theme,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: Size(width, height),
      padding: const EdgeInsets.only(bottom: 34), // typischer iPhone SafeArea
    ),
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('de'),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              key: const Key('triggerFeedback'),
              onPressed: () => showFeedback(ctx),
              child: const Text('Trigger'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Tippt den Trigger-Button und wartet auf die SnackBar-Animation.
Future<void> _tapTrigger(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('triggerFeedback')));
  await tester.pumpAndSettle();
}

const _phoneW = 360.0;
const _phoneH = 800.0;
const _desktopW = 1440.0;
const _desktopH = 900.0;

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── A1: success-SnackBar erscheint mit korrektem Key ─────────────────────

  testWidgets('success — SnackBar mit Key appFeedbackSuccess erscheint',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: _phoneW,
        height: _phoneH,
        showFeedback: (ctx) => AppFeedback.success(ctx, 'Gespeichert'),
      ),
    );
    await _tapTrigger(tester);

    expect(find.byKey(const Key('appFeedbackSuccess')), findsOneWidget);
    expect(find.text('Gespeichert'), findsOneWidget);
  });

  // ── A2: error-SnackBar erscheint mit korrektem Key ────────────────────────

  testWidgets('error — SnackBar mit Key appFeedbackError erscheint',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: _phoneW,
        height: _phoneH,
        showFeedback: (ctx) => AppFeedback.error(ctx, 'Fehler aufgetreten'),
      ),
    );
    await _tapTrigger(tester);

    expect(find.byKey(const Key('appFeedbackError')), findsOneWidget);
    expect(find.text('Fehler aufgetreten'), findsOneWidget);
  });

  // ── A3: info-SnackBar erscheint mit korrektem Key ─────────────────────────

  testWidgets('info — SnackBar mit Key appFeedbackInfo erscheint',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: _phoneW,
        height: _phoneH,
        showFeedback: (ctx) => AppFeedback.info(ctx, 'Hinweis'),
      ),
    );
    await _tapTrigger(tester);

    expect(find.byKey(const Key('appFeedbackInfo')), findsOneWidget);
    expect(find.text('Hinweis'), findsOneWidget);
  });

  // ── A4: Undo-Callback wird aufgerufen ────────────────────────────────────

  testWidgets('success mit Undo — Undo-Callback wird nach Tap aufgerufen',
      (tester) async {
    var undoCalled = false;

    await tester.pumpWidget(
      _buildApp(
        width: _phoneW,
        height: _phoneH,
        showFeedback: (ctx) => AppFeedback.success(
          ctx,
          'Gelöscht',
          onUndo: () => undoCalled = true,
        ),
      ),
    );
    await _tapTrigger(tester);

    // Undo-Action muss sichtbar sein
    expect(find.byKey(const Key('appFeedbackUndoAction')), findsOneWidget);
    expect(find.text('Rückgängig'), findsOneWidget);

    // Tap auf Undo
    await tester.tap(find.byKey(const Key('appFeedbackUndoAction')));
    await tester.pumpAndSettle();

    expect(undoCalled, isTrue);
  });

  // ── A5: Kein Undo-Button ohne Callback ────────────────────────────────────

  testWidgets('success ohne Undo — keine Undo-Action im Widget-Tree',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: _phoneW,
        height: _phoneH,
        showFeedback: (ctx) => AppFeedback.success(ctx, 'OK'),
      ),
    );
    await _tapTrigger(tester);

    expect(
        find.byKey(const Key('appFeedbackUndoAction')), findsNothing);
  });

  // ── A6: Benutzerdefiniertes Undo-Label ──────────────────────────────────

  testWidgets('success mit undoLabel — custom Label erscheint', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: _phoneW,
        height: _phoneH,
        showFeedback: (ctx) => AppFeedback.success(
          ctx,
          'Archiviert',
          onUndo: () {},
          undoLabel: 'Wiederherstellen',
        ),
      ),
    );
    await _tapTrigger(tester);

    expect(find.text('Wiederherstellen'), findsOneWidget);
    // Default-Label darf NICHT erscheinen
    expect(find.text('Rückgängig'), findsNothing);
  });

  // ── A7: Semantische Farben — Success (Light Mode) ─────────────────────────

  testWidgets('success — SnackBar-BgColor entspricht AppTheme.successBg (Light)',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: _phoneW,
        height: _phoneH,
        theme: AppTheme.light,
        showFeedback: (ctx) => AppFeedback.success(ctx, 'OK'),
      ),
    );
    await _tapTrigger(tester);

    final snackBar = tester.widget<SnackBar>(
      find.byKey(const Key('appFeedbackSuccess')),
    );

    // Farbe muss dem Light-Mode successBg entsprechen
    expect(snackBar.backgroundColor, equals(AppTheme.successBg));
  });

  // ── A8: Semantische Farben — Error (Light Mode) ───────────────────────────

  testWidgets('error — SnackBar-BgColor entspricht AppTheme.dangerBg (Light)',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: _phoneW,
        height: _phoneH,
        theme: AppTheme.light,
        showFeedback: (ctx) => AppFeedback.error(ctx, 'Fehler'),
      ),
    );
    await _tapTrigger(tester);

    final snackBar = tester.widget<SnackBar>(
      find.byKey(const Key('appFeedbackError')),
    );

    expect(snackBar.backgroundColor, equals(AppTheme.dangerBg));
  });

  // ── A9: Semantische Farben — Info (Light Mode) ────────────────────────────

  testWidgets('info — SnackBar-BgColor entspricht AppTheme.infoBg (Light)',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: _phoneW,
        height: _phoneH,
        theme: AppTheme.light,
        showFeedback: (ctx) => AppFeedback.info(ctx, 'Info'),
      ),
    );
    await _tapTrigger(tester);

    final snackBar = tester.widget<SnackBar>(
      find.byKey(const Key('appFeedbackInfo')),
    );

    expect(snackBar.backgroundColor, equals(AppTheme.infoBg));
  });

  // ── A10: Semantische Farben — Dark Mode ──────────────────────────────────

  testWidgets('success — BgColor im Dark-Mode ist successBgDark', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: _phoneW,
        height: _phoneH,
        theme: AppTheme.dark,
        showFeedback: (ctx) => AppFeedback.success(ctx, 'OK Dark'),
      ),
    );
    await _tapTrigger(tester);

    final snackBar = tester.widget<SnackBar>(
      find.byKey(const Key('appFeedbackSuccess')),
    );

    expect(snackBar.backgroundColor, equals(AppTheme.successBgDark));
  });

  // ── A11: Margin auf Phone > Margin auf Desktop ────────────────────────────

  testWidgets('floating margin auf Phone ist größer als auf Desktop',
      (tester) async {
    // ── Phone ──
    await tester.pumpWidget(
      _buildApp(
        width: _phoneW,
        height: _phoneH,
        showFeedback: (ctx) => AppFeedback.success(ctx, 'Phone'),
      ),
    );
    await _tapTrigger(tester);

    final phoneSnackBar = tester.widget<SnackBar>(
      find.byKey(const Key('appFeedbackSuccess')),
    );
    final phoneBottom =
        (phoneSnackBar.margin as EdgeInsets?)?.bottom ?? 0.0;

    // ── Desktop ──
    await tester.pumpWidget(
      _buildApp(
        width: _desktopW,
        height: _desktopH,
        showFeedback: (ctx) => AppFeedback.success(ctx, 'Desktop'),
      ),
    );
    await _tapTrigger(tester);

    final desktopSnackBar = tester.widget<SnackBar>(
      find.byKey(const Key('appFeedbackSuccess')),
    );
    final desktopBottom =
        (desktopSnackBar.margin as EdgeInsets?)?.bottom ?? 0.0;

    // Phone-Bottom muss deutlich größer sein (Nav-Bar + SafeArea + 8)
    expect(phoneBottom, greaterThan(desktopBottom));

    // Desktop ist 16dp
    expect(desktopBottom, equals(16.0));

    // Phone: kBottomNavHeight(80) + safeArea(34) + 8 = 122
    expect(phoneBottom, equals(kBottomNavHeight + 34.0 + 8.0));
  });

  // ── A12: Phone-Breakpoint ist 600dp (Breakpoints.phone) ───────────────────

  testWidgets('SnackBar unter 600dp Breite bekommt Nav-Margin', (tester) async {
    // 599dp — soll Nav-Margin haben
    await tester.pumpWidget(
      _buildApp(
        width: 599,
        height: 800,
        showFeedback: (ctx) => AppFeedback.success(ctx, 'Test'),
      ),
    );
    await _tapTrigger(tester);

    final snackBar = tester.widget<SnackBar>(
      find.byKey(const Key('appFeedbackSuccess')),
    );
    final bottom = (snackBar.margin as EdgeInsets?)?.bottom ?? 0.0;
    // Bottom muss > 16dp sein (Desktop-Schwelle)
    expect(bottom, greaterThan(16.0));
  });

  testWidgets('SnackBar ab 600dp Breite bekommt Desktop-Margin', (tester) async {
    // 600dp — soll Desktop-Margin haben
    await tester.pumpWidget(
      _buildApp(
        width: Breakpoints.phone, // 600
        height: 800,
        showFeedback: (ctx) => AppFeedback.success(ctx, 'Test'),
      ),
    );
    await _tapTrigger(tester);

    final snackBar = tester.widget<SnackBar>(
      find.byKey(const Key('appFeedbackSuccess')),
    );
    final bottom = (snackBar.margin as EdgeInsets?)?.bottom ?? 0.0;
    expect(bottom, equals(16.0));
  });

  // ── A13: Floating-Behavior ist gesetzt ────────────────────────────────────

  testWidgets('SnackBar hat SnackBarBehavior.floating', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: _phoneW,
        height: _phoneH,
        showFeedback: (ctx) => AppFeedback.info(ctx, 'Floating'),
      ),
    );
    await _tapTrigger(tester);

    final snackBar = tester.widget<SnackBar>(
      find.byKey(const Key('appFeedbackInfo')),
    );
    expect(snackBar.behavior, equals(SnackBarBehavior.floating));
  });

  // ── A14: Kein hardcoded Colors.* im SnackBar-Content ─────────────────────
  //
  // Compile-time-Check: AppFeedback nutzt ausschließlich AppTheme.*Of(context).
  // Da die Farben als Color-Literale übergeben werden (keine widget.color-Property),
  // prüfen wir, dass die SnackBar-BgColor NICHT einer hardcoded Material-Color
  // entspricht, die wir nie benutzen dürfen.

  testWidgets('success-BgColor ist kein Colors.green (kein hardcoded Color)',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: _phoneW,
        height: _phoneH,
        theme: AppTheme.light,
        showFeedback: (ctx) => AppFeedback.success(ctx, 'Test'),
      ),
    );
    await _tapTrigger(tester);

    final snackBar = tester.widget<SnackBar>(
      find.byKey(const Key('appFeedbackSuccess')),
    );

    // AppTheme.successBg ist NICHT Colors.green
    expect(snackBar.backgroundColor, isNot(equals(Colors.green)));
    // Es ist auch kein weißes SnackBar (Standard-Material)
    expect(snackBar.backgroundColor, isNot(equals(Colors.white)));
    // Und kein schwarzes (Material-Default)
    expect(snackBar.backgroundColor, isNot(equals(Colors.black)));

    // Stattdessen muss es exakt AppTheme.successBg sein
    expect(snackBar.backgroundColor, equals(AppTheme.successBg));
  });

  testWidgets('error-BgColor ist kein Colors.red (kein hardcoded Color)',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: _phoneW,
        height: _phoneH,
        theme: AppTheme.light,
        showFeedback: (ctx) => AppFeedback.error(ctx, 'Test'),
      ),
    );
    await _tapTrigger(tester);

    final snackBar = tester.widget<SnackBar>(
      find.byKey(const Key('appFeedbackError')),
    );

    expect(snackBar.backgroundColor, isNot(equals(Colors.red)));
    expect(snackBar.backgroundColor, equals(AppTheme.dangerBg));
  });

  // ── A15: ARB-Key appFeedbackUndoAction ist "Rückgängig" auf DE ───────────

  testWidgets('Undo-Label entspricht l10n.appFeedbackUndoAction', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: _phoneW,
        height: _phoneH,
        showFeedback: (ctx) =>
            AppFeedback.success(ctx, 'Test', onUndo: () {}),
      ),
    );
    await _tapTrigger(tester);

    // DE-Locale → "Rückgängig"
    expect(find.text('Rückgängig'), findsOneWidget);
  });

  // ── A16: Mehrfache Aufrufe — vorherige SnackBar wird ersetzt ─────────────

  testWidgets('Zweiter AppFeedback-Aufruf ersetzt ersten SnackBar',
      (tester) async {
    var callCount = 0;

    await tester.pumpWidget(
      _buildApp(
        width: _phoneW,
        height: _phoneH,
        showFeedback: (ctx) {
          callCount++;
          if (callCount == 1) {
            AppFeedback.success(ctx, 'Erste Nachricht');
          } else {
            AppFeedback.error(ctx, 'Zweite Nachricht');
          }
        },
      ),
    );

    // Ersten SnackBar zeigen
    await _tapTrigger(tester);
    expect(find.byKey(const Key('appFeedbackSuccess')), findsOneWidget);

    // Zweiten SnackBar zeigen — ersetzt ersten
    await _tapTrigger(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appFeedbackError')), findsOneWidget);
    // Erster darf nicht mehr da sein
    expect(find.byKey(const Key('appFeedbackSuccess')), findsNothing);
  });
}
