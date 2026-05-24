import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/l10n/app_localizations.dart';
import 'package:inventory_management/widgets/confirm_dialog.dart';
import 'package:inventory_management/widgets/member_remove_confirm_dialog.dart';

// ignore_for_file: avoid_redundant_argument_values

// ─────────────────────────────────────────────────────────────────────────────
// Test-Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Baut eine MaterialApp in der gegebenen Breite × Höhe.
/// [onConfirm] wird mit dem Result der showConfirmDialog-Future aufgerufen,
/// sobald der Dialog geschlossen wird.
Widget _buildApp({
  required double width,
  required double height,
  required String title,
  required String message,
  required String confirmLabel,
  bool isDestructive = false,
  String? requireTypeName,
  ValueChanged<bool>? onResult,
}) {
  return MediaQuery(
    data: MediaQueryData(size: Size(width, height)),
    child: MaterialApp(
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
              key: const Key('openDialog'),
              onPressed: () async {
                final result = await showConfirmDialog(
                  context: ctx,
                  title: title,
                  message: message,
                  confirmLabel: confirmLabel,
                  isDestructive: isDestructive,
                  requireTypeName: requireTypeName,
                );
                onResult?.call(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Viewport-Konstanten (physische Größe in logical pixels)
const _phoneW = 360.0;
const _phoneH = 800.0;
const _desktopW = 1200.0;
const _desktopH = 900.0;

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── HapticFeedback-Mock ────────────────────────────────────────────────────
  // Wir müssen den PlatformChannel mocken, sonst crasht der Test auf
  // Desktop (kein Vibrator).
  final List<MethodCall> hapticCalls = [];

  setUp(() {
    hapticCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          hapticCalls.add(call);
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  // ── 1. Confirm → returns true ───────────────────────────────────────────
  group('Confirm returns true', () {
    testWidgets('Desktop: Confirm-Button gibt true zurück', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _buildApp(
          width: _desktopW,
          height: _desktopH,
          title: 'Titel',
          message: 'Nachricht',
          confirmLabel: 'Bestätigen',
          onResult: (r) => result = r,
        ),
      );

      await tester.tap(find.byKey(const Key('openDialog')));
      await tester.pumpAndSettle();

      // Dialog sichtbar
      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirmDialog-confirm')));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('Phone: Confirm-Button gibt true zurück', (tester) async {
      tester.view.physicalSize = const Size(_phoneW, _phoneH);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool? result;
      await tester.pumpWidget(
        _buildApp(
          width: _phoneW,
          height: _phoneH,
          title: 'Titel',
          message: 'Nachricht',
          confirmLabel: 'Bestätigen',
          onResult: (r) => result = r,
        ),
      );

      await tester.tap(find.byKey(const Key('openDialog')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirmDialog-confirm')));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });

  // ── 2. Cancel → returns false ───────────────────────────────────────────
  group('Cancel returns false', () {
    testWidgets('Desktop: Cancel-Button gibt false zurück', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _buildApp(
          width: _desktopW,
          height: _desktopH,
          title: 'Titel',
          message: 'Nachricht',
          confirmLabel: 'Bestätigen',
          onResult: (r) => result = r,
        ),
      );

      await tester.tap(find.byKey(const Key('openDialog')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirmDialog-cancel')));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('Phone: Cancel-Button gibt false zurück', (tester) async {
      tester.view.physicalSize = const Size(_phoneW, _phoneH);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool? result;
      await tester.pumpWidget(
        _buildApp(
          width: _phoneW,
          height: _phoneH,
          title: 'Titel',
          message: 'Nachricht',
          confirmLabel: 'Bestätigen',
          onResult: (r) => result = r,
        ),
      );

      await tester.tap(find.byKey(const Key('openDialog')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirmDialog-cancel')));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });

  // ── 3. requireTypeName blockt Confirm bis Name korrekt ──────────────────
  group('requireTypeName mode', () {
    testWidgets('Confirm-Button deaktiviert bis korrekte Eingabe (Desktop)',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          width: _desktopW,
          height: _desktopH,
          title: 'Löschen',
          message: 'Wirklich löschen?',
          confirmLabel: 'Löschen',
          requireTypeName: 'test@example.com',
        ),
      );

      await tester.tap(find.byKey(const Key('openDialog')));
      await tester.pumpAndSettle();

      // TextField sichtbar
      expect(find.byKey(const Key('confirmDialog-typeName-field')), findsOneWidget);

      // Confirm ist initial disabled
      final confirmBtn = tester.widget<FilledButton>(
        find.byKey(const Key('confirmDialog-confirm')),
      );
      expect(confirmBtn.onPressed, isNull);

      // Falsche Eingabe
      await tester.enterText(
          find.byKey(const Key('confirmDialog-typeName-field')),
          'wrong@example.com');
      await tester.pump();

      final confirmBtnWrong = tester.widget<FilledButton>(
        find.byKey(const Key('confirmDialog-confirm')),
      );
      expect(confirmBtnWrong.onPressed, isNull);

      // Korrekte Eingabe
      await tester.enterText(
          find.byKey(const Key('confirmDialog-typeName-field')),
          'test@example.com');
      await tester.pump();

      final confirmBtnCorrect = tester.widget<FilledButton>(
        find.byKey(const Key('confirmDialog-confirm')),
      );
      expect(confirmBtnCorrect.onPressed, isNotNull);
    });

    testWidgets('Confirm gibt true wenn Name korrekt (Desktop)', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _buildApp(
          width: _desktopW,
          height: _desktopH,
          title: 'Löschen',
          message: 'Wirklich löschen?',
          confirmLabel: 'Löschen',
          requireTypeName: 'test@example.com',
          onResult: (r) => result = r,
        ),
      );

      await tester.tap(find.byKey(const Key('openDialog')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('confirmDialog-typeName-field')),
          'test@example.com');
      await tester.pump();

      await tester.tap(find.byKey(const Key('confirmDialog-confirm')));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });

  // ── 4. Back-Geste (System Back) ohne Match → Dialog bleibt offen ─────────
  //
  // PopScope(canPop: false) blockiert den Android Back-Button / iOS swipe-back.
  // Wir simulieren das über `tester.binding.handlePopRoute()`, das genau den
  // SystemChannel-Back-Event emuliert, den Flutter auf Android auslöst.
  testWidgets(
    'Back-Button bei requireTypeName ohne Match lässt Dialog offen',
    (tester) async {
      bool? result;
      await tester.pumpWidget(
        _buildApp(
          width: _desktopW,
          height: _desktopH,
          title: 'Löschen',
          message: 'Wirklich löschen?',
          confirmLabel: 'Löschen',
          requireTypeName: 'confirm-me',
          isDestructive: true,
          onResult: (r) => result = r,
        ),
      );

      await tester.tap(find.byKey(const Key('openDialog')));
      await tester.pumpAndSettle();

      // Dialog sichtbar
      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);

      // Ohne Eingabe: Confirm-Button ist disabled.
      // Dies ist der direkte Proxy für _canConfirm (= !_typeNameMatches),
      // dasselbe Flag das PopScope.canPop steuert.
      final confirmBefore = tester.widget<FilledButton>(
        find.byKey(const Key('confirmDialog-confirm')),
      );
      expect(confirmBefore.onPressed, isNull,
          reason: 'Confirm muss disabled sein ohne passende Eingabe');

      // System-Back simulieren → PopScope(canPop: false) soll Pop verhindern
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Dialog muss noch sichtbar sein
      expect(find.byKey(const Key('confirmDialog')), findsOneWidget,
          reason: 'Dialog muss nach System-Back offen bleiben');
      expect(result, isNull,
          reason: 'result darf nicht gesetzt sein');

      // Korrekte Eingabe → Confirm-Button wird aktiv
      await tester.enterText(
          find.byKey(const Key('confirmDialog-typeName-field')), 'confirm-me');
      await tester.pump();

      final confirmAfter = tester.widget<FilledButton>(
        find.byKey(const Key('confirmDialog-confirm')),
      );
      expect(confirmAfter.onPressed, isNotNull,
          reason: 'Confirm muss aktiv sein nach korrekter Eingabe');

      // Cancel schließt den Dialog
      await tester.tap(find.byKey(const Key('confirmDialog-cancel')));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    },
  );

  // ── 5. Unicode-Bidi-Sanitize ─────────────────────────────────────────────
  testWidgets(
    'Unicode-Bidi-Chars werden aus requireTypeName gefiltert',
    (tester) async {
      // 'mail' + U+202E (RLO = Right-to-Left Override) + 'evil.com'
      // Wird als 'mailevil.com' angezeigt, ist aber visuell anders.
      // Literal U+202E wird via String.fromCharCode konstruiert um den
      // Dart-Analyzer-Warning text_direction_code_point_in_literal zu vermeiden.
      final bidiName = 'mail${String.fromCharCode(0x202E)}evil.com';
      const sanitizedName = 'mailevil.com'; // U+202E ist raus

      bool? result;
      await tester.pumpWidget(
        _buildApp(
          width: _desktopW,
          height: _desktopH,
          title: 'Test',
          message: 'Bidi-Test',
          confirmLabel: 'OK',
          requireTypeName: bidiName,
          onResult: (r) => result = r,
        ),
      );

      await tester.tap(find.byKey(const Key('openDialog')));
      await tester.pumpAndSettle();

      // TextField-Hint und Label zeigen den sanitisierten String
      // (kein U+202E im Widget-Tree sichtbar)
      expect(find.byKey(const Key('confirmDialog-typeName-field')), findsOneWidget);

      // Mit dem originalen Bidi-String eintippen → Confirm bleibt disabled
      await tester.enterText(
          find.byKey(const Key('confirmDialog-typeName-field')), bidiName);
      await tester.pump();

      // Bidi-Name im Input != sanitizedName → kein Match (Sicherheitsmerkmal:
      // der Raw-Input mit Bidi-Char matcht nicht den sanitisierten Namen)
      //
      // Hinweis: Flutter's TextField filtert U+202E nicht automatisch, daher
      // treffen wir eine Design-Entscheidung: Der Input wird NICHT gesanitized —
      // nur der requireTypeName-Vergleichswert wird sanitized.
      // Das bedeutet: User muss den sichtbaren (sanitisierten) String tippen.
      final confirmBtnBidi = tester.widget<FilledButton>(
        find.byKey(const Key('confirmDialog-confirm')),
      );
      expect(confirmBtnBidi.onPressed, isNull,
          reason: 'Raw Bidi-Input darf nicht matchen');

      // Mit dem sanitisierten String eintippen → Confirm wird aktiviert
      await tester.enterText(
          find.byKey(const Key('confirmDialog-typeName-field')), sanitizedName);
      await tester.pump();

      final confirmBtnSanitized = tester.widget<FilledButton>(
        find.byKey(const Key('confirmDialog-confirm')),
      );
      expect(confirmBtnSanitized.onPressed, isNotNull,
          reason: 'Sanitisierter Input muss matchen');

      // Bestätigen
      await tester.tap(find.byKey(const Key('confirmDialog-confirm')));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    },
  );

  // ── 6. Phone-Viewport → BottomSheet; Desktop → Dialog ───────────────────
  group('Viewport-abhängiges Rendering', () {
    testWidgets('Phone-Viewport rendert BottomSheet', (tester) async {
      tester.view.physicalSize = const Size(_phoneW, _phoneH);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildApp(
          width: _phoneW,
          height: _phoneH,
          title: 'Titel',
          message: 'Nachricht',
          confirmLabel: 'OK',
        ),
      );

      await tester.tap(find.byKey(const Key('openDialog')));
      await tester.pumpAndSettle();

      // BottomSheet erkennbar: kein AlertDialog im Widget-Tree
      expect(find.byType(AlertDialog), findsNothing);
      // Unser Root-Container ist vorhanden
      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);
    });

    testWidgets('Desktop-Viewport rendert AlertDialog', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          width: _desktopW,
          height: _desktopH,
          title: 'Titel',
          message: 'Nachricht',
          confirmLabel: 'OK',
        ),
      );

      await tester.tap(find.byKey(const Key('openDialog')));
      await tester.pumpAndSettle();

      // AlertDialog vorhanden
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);
    });
  });

  // ── 7. HapticFeedback bei isDestructive ─────────────────────────────────
  testWidgets('HapticFeedback.lightImpact() wird bei isDestructive gerufen',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: _desktopW,
        height: _desktopH,
        title: 'Löschen',
        message: 'Wirklich?',
        confirmLabel: 'Löschen',
        isDestructive: true,
      ),
    );

    await tester.tap(find.byKey(const Key('openDialog')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmDialog-confirm')));
    await tester.pumpAndSettle();

    expect(
      hapticCalls.any((c) => c.arguments == 'HapticFeedbackType.lightImpact'),
      isTrue,
    );
  });

  // ── 8. MemberRemoveConfirmDialog (Wrapper-Regression) ────────────────────
  group('MemberRemoveConfirmDialog (Thin-Wrapper)', () {
    testWidgets('show() öffnet Dialog und gibt true bei Confirm zurück',
        (tester) async {
      bool? result;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(_desktopW, _desktopH)),
          child: MaterialApp(
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
                builder: (ctx) => ElevatedButton(
                  key: const Key('openWrapper'),
                  onPressed: () async {
                    result = await MemberRemoveConfirmDialog.show(
                        ctx, 'user@example.com');
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('openWrapper')));
      await tester.pumpAndSettle();

      // Dialog mit dem allgemeinen confirmDialog-Key vorhanden
      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);

      // Confirm drücken
      await tester.tap(find.byKey(const Key('confirmDialog-confirm')));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('show() gibt false bei Cancel zurück', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(_desktopW, _desktopH)),
          child: MaterialApp(
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
                builder: (ctx) => ElevatedButton(
                  key: const Key('openWrapper'),
                  onPressed: () async {
                    result = await MemberRemoveConfirmDialog.show(
                        ctx, 'user@example.com');
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('openWrapper')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirmDialog-cancel')));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });
}
