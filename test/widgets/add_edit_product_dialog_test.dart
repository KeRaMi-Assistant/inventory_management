import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:inventory_management/l10n/app_localizations.dart';
import 'package:inventory_management/models/product.dart';
import 'package:inventory_management/models/workspace.dart';
import 'package:inventory_management/providers/active_workspace_provider.dart';
import 'package:inventory_management/providers/inventory_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';
import 'package:inventory_management/services/workspace_service.dart';
import 'package:inventory_management/widgets/add_edit_product_dialog.dart';

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
  Future<Product> insertProduct(Product product) async => product;

  @override
  Future<Product> updateProduct(Product product) async => product;
}

class _FakeInventoryProvider extends InventoryProvider {
  _FakeInventoryProvider() : super(repository: _FakeRepository());
}

class _FakeWsService extends WorkspaceService {
  _FakeWsService() : super.forTesting();

  @override
  Future<List<Workspace>> listMine() async => [];

  @override
  Future<List<WorkspaceMember>> listMembers(String workspaceId) async => [];
}

/// ActiveWorkspaceProvider mit festem admin-Rolle ohne echten Auth-Context.
class _FakeWorkspaceProvider extends ActiveWorkspaceProvider {
  _FakeWorkspaceProvider() : super(_FakeWsService());

  @override
  WorkspaceRole? get role => WorkspaceRole.admin;
}

// ─────────────────────────────────────────────────────────────────────────────
// Test-Helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _buildApp({Product? product}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<InventoryProvider>(
          create: (_) => _FakeInventoryProvider()),
      ChangeNotifierProvider<ActiveWorkspaceProvider>(
          create: (_) => _FakeWorkspaceProvider()),
    ],
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
                  builder: (_) => AddEditProductDialog(product: product),
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
    'ProductDialog öffnet sich — Form sichtbar',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      expect(find.byType(AddEditProductDialog), findsOneWidget);
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

      expect(find.byType(AddEditProductDialog), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsNothing);
      expect(find.byType(AddEditProductDialog), findsNothing);
    },
  );

  // ── 3. Namensfeld ändern → isDirty=true → X zeigt Confirm ────────────────
  testWidgets(
    'Name-Feld ändern → isDirty=true → X-Button zeigt Discard-Confirm',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      // Name-TextField ist das erste TextFormField im Dialog.
      final nameField = find.byType(TextFormField).first;
      await tester.tap(nameField);
      tester.takeException();
      await tester.enterText(nameField, 'Neues Produkt');
      tester.takeException();
      await tester.pump();
      tester.takeException();

      // UnsavedChangesGuard PopScope soll existieren
      expect(find.byKey(const Key('unsavedChangesGuard-dialog')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);
      expect(find.byType(AddEditProductDialog), findsOneWidget);
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
      expect(find.byType(AddEditProductDialog), findsNothing);
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
      expect(find.byType(AddEditProductDialog), findsOneWidget);
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

  // ── 7. Bestehender Product ohne Änderung → isDirty=false → direkt schließen
  testWidgets(
    'Bestehender Product: keine Änderungen → isDirty=false → direkt schließen',
    (tester) async {
      setSurface(tester);
      final existingProduct = Product(
        id: 'prod-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        name: 'Test-Produkt',
        unit: 'Stk',
        minStock: 0,
        isActive: true,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      await tester.pumpWidget(_buildApp(product: existingProduct));
      await _openDialog(tester);

      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsNothing);
      expect(find.byType(AddEditProductDialog), findsNothing);
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
}
