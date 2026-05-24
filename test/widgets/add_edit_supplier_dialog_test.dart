import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:inventory_management/l10n/app_localizations.dart';
import 'package:inventory_management/models/supplier.dart';
import 'package:inventory_management/providers/inventory_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';
import 'package:inventory_management/widgets/add_edit_supplier_dialog.dart';

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
  Future<Supplier> insertSupplier(Supplier supplier) async => supplier;

  @override
  Future<Supplier> updateSupplier(Supplier supplier) async => supplier;
}

class _FakeInventoryProvider extends InventoryProvider {
  _FakeInventoryProvider() : super(repository: _FakeRepository());
}

// ─────────────────────────────────────────────────────────────────────────────
// Test-Helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _buildApp({Supplier? supplier}) {
  return ChangeNotifierProvider<InventoryProvider>(
    create: (_) => _FakeInventoryProvider(),
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
                  builder: (_) => AddEditSupplierDialog(supplier: supplier),
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
    'SupplierDialog öffnet sich — Form sichtbar',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      expect(find.byType(AddEditSupplierDialog), findsOneWidget);
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

      expect(find.byType(AddEditSupplierDialog), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsNothing);
      expect(find.byType(AddEditSupplierDialog), findsNothing);
    },
  );

  // ── 3. Namensfeld ändern → isDirty=true → X zeigt Confirm ────────────────
  testWidgets(
    'Name-Feld ändern → isDirty=true → X-Button zeigt Discard-Confirm',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      // Name-TextField ist das erste TextFormField im Lieferanten-Dialog.
      final nameField = find.byType(TextFormField).first;
      await tester.tap(nameField);
      tester.takeException();
      await tester.enterText(nameField, 'Neuer Lieferant');
      tester.takeException();
      await tester.pump();
      tester.takeException();

      // UnsavedChangesGuard PopScope soll existieren
      expect(find.byKey(const Key('unsavedChangesGuard-dialog')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);
      expect(find.byType(AddEditSupplierDialog), findsOneWidget);
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
      expect(find.byType(AddEditSupplierDialog), findsNothing);
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
      expect(find.byType(AddEditSupplierDialog), findsOneWidget);
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

  // ── 7. Bestehender Supplier ohne Änderung → isDirty=false → direkt schließen
  testWidgets(
    'Bestehender Supplier: keine Änderungen → isDirty=false → direkt schließen',
    (tester) async {
      setSurface(tester);
      const existingSupplier = Supplier(
        id: 'sup-1',
        name: 'Test-Lieferant',
      );

      await tester.pumpWidget(_buildApp(supplier: existingSupplier));
      await _openDialog(tester);

      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsNothing);
      expect(find.byType(AddEditSupplierDialog), findsNothing);
    },
  );

  // ── 8. Back-Button bei isDirty=true → Confirm ────────────────────────────
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

  // ── 9. Active-Switch ändert Dirty-State ──────────────────────────────────
  testWidgets(
    'Active-Switch toggle → isDirty=true → X zeigt Confirm',
    (tester) async {
      setSurface(tester);
      // Starte mit existierendem aktiven Supplier
      const existingSupplier = Supplier(
        id: 'sup-1',
        name: 'Test-Lieferant',
        active: true,
      );
      await tester.pumpWidget(_buildApp(supplier: existingSupplier));
      await _openDialog(tester);

      // Switch tippen (toggled _active von true auf false)
      await tester.tap(find.byType(Switch));
      await tester.pump();
      tester.takeException();

      // X-Button → Guard sollte Confirm zeigen
      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);
    },
  );
}
