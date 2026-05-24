import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:inventory_management/l10n/app_localizations.dart';
import 'package:inventory_management/models/mailbox_account.dart';
import 'package:inventory_management/providers/inbox_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';
import 'package:inventory_management/widgets/add_edit_mailbox_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fakes
// ─────────────────────────────────────────────────────────────────────────────

class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  @override
  String? get activeWorkspaceId => 'ws-test';

  @override
  Future<CloudSnapshot> loadAll() async => const CloudSnapshot(
        deals: [],
        buyers: [],
        shops: [],
        suppliers: [],
        inventoryItems: [],
        movements: [],
        activities: [],
      );

  @override
  Future<MailboxAccount> insertMailboxAccount(
    MailboxAccount account, {
    required String password,
  }) async =>
      account;

  @override
  Future<MailboxAccount> updateMailboxAccount(
    MailboxAccount account, {
    String? newPassword,
  }) async =>
      account;
}

class _FakeInboxProvider extends InboxProvider {
  _FakeInboxProvider() : super(repository: _FakeRepository());
}

// ─────────────────────────────────────────────────────────────────────────────
// Test-Helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _buildApp({MailboxAccount? existing}) {
  return ChangeNotifierProvider<InboxProvider>(
    create: (_) => _FakeInboxProvider(),
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
                  barrierDismissible: false,
                  builder: (_) => AddEditMailboxDialog(existing: existing),
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

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('openDialog')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  tester.takeException();
}

Future<void> _pumpAndConsume(WidgetTester tester) async {
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    tester.takeException();
  }
}

/// Erstellt eine Beispiel-MailboxAccount zum Testen des Edit-Modus.
const _sampleAccount = MailboxAccount(
  id: 'mb-1',
  workspaceId: 'ws-test',
  label: 'Gmail Reseller',
  imapHost: 'imap.gmail.com',
  imapPort: 993,
  useSsl: true,
  username: 'test@gmail.com',
  folder: 'INBOX',
  enabled: true,
);

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  void setSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // ── 1. Dialog öffnet ohne Fehler ──────────────────────────────────────────
  testWidgets(
    'MailboxDialog öffnet sich — Form sichtbar',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      expect(find.byType(AddEditMailboxDialog), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);
    },
  );

  // ── 2. Leere Form: isDirty=false → X schließt direkt ─────────────────────
  testWidgets(
    'Leere neue Form — X-Button schließt ohne Confirm (isDirty=false)',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      expect(find.byType(AddEditMailboxDialog), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsNothing);
      expect(find.byType(AddEditMailboxDialog), findsNothing);
    },
  );

  // ── 3. Namensfeld ändern → isDirty=true → X zeigt Discard-Confirm ────────
  testWidgets(
    'Label-Feld ändern → isDirty=true → X-Button zeigt Discard-Confirm',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      // Erstes TextFormField ist das Label-Feld.
      final labelField = find.byType(TextFormField).first;
      await tester.tap(labelField);
      tester.takeException();
      await tester.enterText(labelField, 'Mein Testpostfach');
      tester.takeException();
      await tester.pump();
      tester.takeException();

      // UnsavedChangesGuard PopScope soll existieren
      expect(
          find.byKey(const Key('unsavedChangesGuard-dialog')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);
      expect(find.byType(AddEditMailboxDialog), findsOneWidget);
    },
  );

  // ── 4. Dirty → Confirm "Verwerfen" schließt Dialog ───────────────────────
  testWidgets(
    'isDirty=true → Discard-Confirm → Verwerfen schließt Dialog',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Dirty-Wert');
      tester.takeException();
      await tester.pump();
      tester.takeException();

      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirmDialog-confirm')));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsNothing);
      expect(find.byType(AddEditMailboxDialog), findsNothing);
    },
  );

  // ── 5. Dirty → Cancel im Confirm → Dialog bleibt offen ───────────────────
  testWidgets(
    'isDirty=true → Discard-Confirm → Abbrechen lässt Dialog offen',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Dirty-Wert');
      tester.takeException();
      await tester.pump();
      tester.takeException();

      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirmDialog-cancel')));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsNothing);
      expect(find.byType(AddEditMailboxDialog), findsOneWidget);
    },
  );

  // ── 6. Cancel-Button (Actions-Zeile) bei isDirty=true → Confirm ──────────
  testWidgets(
    'Actions-Cancel-Button bei isDirty=true zeigt Discard-Confirm',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Dirty-Wert');
      tester.takeException();
      await tester.pump();
      tester.takeException();

      final cancelBtn = find.widgetWithText(TextButton, 'Abbrechen');
      expect(cancelBtn, findsOneWidget);

      await tester.tap(cancelBtn);
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);
    },
  );

  // ── 7. Bestehender Account ohne Änderung → isDirty=false → direkt schließen
  testWidgets(
    'Bestehender Account: keine Änderungen → isDirty=false → direkt schließen',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp(existing: _sampleAccount));
      await _openDialog(tester);

      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsNothing);
      expect(find.byType(AddEditMailboxDialog), findsNothing);
    },
  );

  // ── 8. SSL-Switch-Änderung → isDirty=true ────────────────────────────────
  testWidgets(
    'SSL-Switch toggle bei bestehendem Account → isDirty=true → Confirm',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp(existing: _sampleAccount));
      await _openDialog(tester);

      // Erstes Switch-Widget im Dialog ist SSL/TLS.
      await tester.tap(find.byType(Switch).first);
      await tester.pump();
      tester.takeException();

      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);
    },
  );

  // ── 9. Inline-Validation: ungültige E-Mail → Fehler nach Interaktion ──────
  testWidgets(
    'Inline-Validation: ungültige E-Mail zeigt Fehlermeldung',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      // Username-Feld (4. TextFormField — Label, Host, Port, Username)
      final usernameField = find.byType(TextFormField).at(3);
      await tester.tap(usernameField);
      tester.takeException();

      // Ungültige E-Mail eingeben
      await tester.enterText(usernameField, 'keine-email');
      tester.takeException();
      // Fokus wechseln um onUserInteraction zu triggern
      await tester.tap(find.byType(TextFormField).first);
      await tester.pump();
      tester.takeException();

      // Fehlermeldung für ungültige E-Mail soll sichtbar sein
      expect(find.text('Ungültige E-Mail-Adresse'), findsOneWidget);
    },
  );

  // ── 10. Inline-Validation: ungültiger Port → Fehler nach Interaktion ──────
  testWidgets(
    'Inline-Validation: ungültiger Port zeigt Fehlermeldung',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      // Port-Feld ist das 3. TextFormField (Label, Host, Port)
      final portField = find.byType(TextFormField).at(2);
      await tester.tap(portField);
      tester.takeException();

      // Zu hohen Port eingeben (> 65535)
      await tester.enterText(portField, '99999');
      tester.takeException();
      // Fokus wechseln
      await tester.tap(find.byType(TextFormField).first);
      await tester.pump();
      tester.takeException();

      // Fehlermeldung für ungültigen Port soll sichtbar sein
      expect(find.text('Port muss zwischen 1 und 65535 liegen'), findsOneWidget);
    },
  );

  // ── 11. Back-Button bei isDirty=true → Confirm ───────────────────────────
  testWidgets(
    'isDirty=true — Android-Back löst Discard-Confirm aus',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Dirty-Wert');
      tester.takeException();
      await tester.pump();
      tester.takeException();

      final bool handled = await tester.binding.handlePopRoute();
      await _pumpAndConsume(tester);

      expect(handled, isTrue);
      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);
    },
  );
}
