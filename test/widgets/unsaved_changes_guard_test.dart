import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/l10n/app_localizations.dart';
import 'package:inventory_management/widgets/unsaved_changes_guard.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test-Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Baut eine MaterialApp mit einem Dialog, der einen [UnsavedChangesGuard]
/// enthält. Der Dialog wird per ElevatedButton geöffnet.
///
/// [isDirty] steuert den Guard-Status.
/// [onDiscardConfirmed] wird nach erfolgreichem Discard aufgerufen.
/// [customTitle]/[customMessage]/[customLabel] für den optionalen Custom-Text-Test.
Widget _buildApp({
  required bool isDirty,
  VoidCallback? onDiscardConfirmed,
  String? customTitle,
  String? customMessage,
  String? customLabel,
}) {
  return MediaQuery(
    // Phone-Viewport — Mobile-First
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
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              key: const Key('openDialog'),
              onPressed: () {
                showDialog<void>(
                  context: ctx,
                  builder: (_) => Dialog(
                    child: UnsavedChangesGuard(
                      isDirty: isDirty,
                      discardConfirmTitle: customTitle,
                      discardConfirmMessage: customMessage,
                      discardConfirmLabel: customLabel,
                      onDiscardConfirmed: onDiscardConfirmed,
                      child: const SizedBox(
                        key: Key('dialogContent'),
                        width: 200,
                        height: 100,
                        child: Text('Form content'),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Öffnet den Dialog und gibt den BuildContext des Dialogs zurück.
Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('openDialog')));
  await tester.pumpAndSettle();
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. isDirty: false → Back popt direkt ──────────────────────────────────
  testWidgets(
    'isDirty: false — Back-Button popt direkt ohne Confirm-Dialog',
    (tester) async {
      await tester.pumpWidget(_buildApp(isDirty: false));
      await _openDialog(tester);

      // Dialog-Content ist sichtbar
      expect(find.byKey(const Key('dialogContent')), findsOneWidget);

      // PopScope mit canPop=true → simuliere Pop via Navigator
      final NavigatorState navigator = tester.state(find.byType(Navigator).first);
      navigator.pop();
      await tester.pumpAndSettle();

      // Confirm-Dialog erscheint NICHT
      expect(find.byKey(const Key('confirmDialog')), findsNothing);

      // Dialog-Content ist weg (wurde gepoppt)
      expect(find.byKey(const Key('dialogContent')), findsNothing);
    },
  );

  // ── 2. isDirty: true → Back zeigt ConfirmDialog ───────────────────────────
  testWidgets(
    'isDirty: true — Back-Button zeigt Discard-ConfirmDialog',
    (tester) async {
      await tester.pumpWidget(_buildApp(isDirty: true));
      await _openDialog(tester);

      // Dialog-Content ist sichtbar
      expect(find.byKey(const Key('dialogContent')), findsOneWidget);

      // Simuliere Systemback (canPop=false, triggt onPopInvokedWithResult)
      // PhysicalButton / Android-Back via didPopRoute:
      final bool handled =
          await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Pop wurde blockiert UND Confirm-Dialog erscheint
      expect(handled, isTrue);
      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);

      // Ursprünglicher Dialog-Content ist noch da (im Hintergrund)
      expect(find.byKey(const Key('dialogContent')), findsOneWidget);
    },
  );

  // ── 3. Confirm → Pop passiert + onDiscardConfirmed gerufen ────────────────
  testWidgets(
    'isDirty: true — Confirm popt Dialog und ruft onDiscardConfirmed',
    (tester) async {
      bool discardCalled = false;
      await tester.pumpWidget(
        _buildApp(isDirty: true, onDiscardConfirmed: () => discardCalled = true),
      );
      await _openDialog(tester);

      // Back simulieren → Confirm-Dialog erscheint
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);

      // Confirm-Button tippen
      await tester.tap(find.byKey(const Key('confirmDialog-confirm')));
      await tester.pumpAndSettle();

      // Callback wurde gerufen
      expect(discardCalled, isTrue);

      // Confirm-Dialog weg
      expect(find.byKey(const Key('confirmDialog')), findsNothing);

      // Originaler Dialog-Content ist weg (gepoppt)
      expect(find.byKey(const Key('dialogContent')), findsNothing);
    },
  );

  // ── 4. Cancel → Pop NICHT passiert, Dialog bleibt offen ──────────────────
  testWidgets(
    'isDirty: true — Cancel lässt Dialog offen',
    (tester) async {
      bool discardCalled = false;
      await tester.pumpWidget(
        _buildApp(isDirty: true, onDiscardConfirmed: () => discardCalled = true),
      );
      await _openDialog(tester);

      // Back simulieren → Confirm-Dialog erscheint
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);

      // Cancel-Button tippen
      await tester.tap(find.byKey(const Key('confirmDialog-cancel')));
      await tester.pumpAndSettle();

      // Callback wurde NICHT gerufen
      expect(discardCalled, isFalse);

      // Confirm-Dialog weg
      expect(find.byKey(const Key('confirmDialog')), findsNothing);

      // Originaler Dialog-Content noch sichtbar
      expect(find.byKey(const Key('dialogContent')), findsOneWidget);
    },
  );

  // ── 5. Custom Titles/Messages werden korrekt durchgereicht ────────────────
  testWidgets(
    'Custom discardConfirmTitle, discardConfirmMessage, discardConfirmLabel '
    'werden im Confirm-Dialog angezeigt',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          isDirty: true,
          customTitle: 'Eigener Titel',
          customMessage: 'Eigene Nachricht',
          customLabel: 'Wegwerfen',
        ),
      );
      await _openDialog(tester);

      // Back simulieren
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);

      // Custom-Texte sind sichtbar
      expect(find.text('Eigener Titel'), findsOneWidget);
      expect(find.text('Eigene Nachricht'), findsOneWidget);
      expect(find.text('Wegwerfen'), findsOneWidget);
    },
  );
}
