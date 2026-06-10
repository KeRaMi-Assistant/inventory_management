import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:inventory_management/l10n/app_localizations.dart';
import 'package:inventory_management/models/shop.dart';
import 'package:inventory_management/providers/deals_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';
import 'package:inventory_management/widgets/add_edit_shop_dialog.dart';

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
}

class _FakeDealsProvider extends DealsProvider {
  _FakeDealsProvider() : super(repository: _FakeRepository());

  @override
  List<Shop> get shops => const [];
}

// ─────────────────────────────────────────────────────────────────────────────
// Test-Helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _buildApp({Shop? shop}) {
  return ChangeNotifierProvider<DealsProvider>(
    create: (_) => _FakeDealsProvider(),
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
                  builder: (_) => AddEditShopDialog(shop: shop),
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

  // ── 1. Dialog öffnet ohne Fehler ─────────────────────────────────────────
  testWidgets(
    'Dialog öffnet sich — Form-Felder sichtbar',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      expect(find.byType(AddEditShopDialog), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);
    },
  );

  // ── 2. Neue leere Form: isDirty=false → X-Button schließt direkt ─────────
  testWidgets(
    'Neue leere Form — X-Button schließt Dialog ohne Confirm (isDirty=false)',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      expect(find.byType(AddEditShopDialog), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsNothing);
      expect(find.byType(AddEditShopDialog), findsNothing);
    },
  );

  // ── 3. Dirty nach Textänderung → X-Button zeigt Discard-Confirm ──────────
  testWidgets(
    'Name-Feld ändern → isDirty=true → X-Button zeigt Discard-Confirm',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      // Name-Feld befüllen
      final nameField = find.byType(TextFormField).first;
      await tester.tap(nameField);
      tester.takeException();
      await tester.enterText(nameField, 'MeinShop');
      tester.takeException();
      await tester.pump();
      tester.takeException();

      // PopScope-Guard soll existieren
      expect(
          find.byKey(const Key('unsavedChangesGuard-dialog')), findsOneWidget);

      // X-Button tippen
      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      // Discard-Confirm erscheint
      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);
      // Dialog noch offen
      expect(find.byType(AddEditShopDialog), findsOneWidget);
    },
  );

  // ── 4. Dirty → "Verwerfen" schließt Dialog ───────────────────────────────
  testWidgets(
    'isDirty=true → Discard-Confirm → "Verwerfen" schließt Dialog',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Dirty-Shop');
      tester.takeException();
      await tester.pump();
      tester.takeException();

      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirmDialog-confirm')));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsNothing);
      expect(find.byType(AddEditShopDialog), findsNothing);
    },
  );

  // ── 5. Dirty → Cancel im Guard-Confirm → Dialog bleibt offen ─────────────
  testWidgets(
    'isDirty=true → Discard-Confirm → Cancel lässt Dialog offen',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Dirty-Shop');
      tester.takeException();
      await tester.pump();
      tester.takeException();

      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirmDialog-cancel')));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsNothing);
      expect(find.byType(AddEditShopDialog), findsOneWidget);
    },
  );

  // ── 6. Cancel-Button (Actions-Zeile) dirty → zeigt Confirm ───────────────
  testWidgets(
    'Actions-Cancel-Button bei isDirty=true zeigt Discard-Confirm',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Dirty-Shop');
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

  // ── 7. Bestehender Shop ohne Änderung → isDirty=false → direkt schließen ──
  testWidgets(
    'Bestehender Shop: keine Änderungen → isDirty=false → direkt schließen',
    (tester) async {
      setSurface(tester);
      const existingShop = Shop(
        id: 's-1',
        name: 'TestShop',
        region: 'DE',
        channel: 'Online',
        active: true,
        url: 'https://testshop.de',
      );

      await tester.pumpWidget(_buildApp(shop: existingShop));
      await _openDialog(tester);

      await tester.tap(find.byIcon(Icons.close));
      await _pumpAndConsume(tester);

      expect(find.byKey(const Key('confirmDialog')), findsNothing);
      expect(find.byType(AddEditShopDialog), findsNothing);
    },
  );

  // ── 8. Back-Button bei isDirty=true → Confirm erscheint (PopScope-Test) ───
  testWidgets(
    'isDirty=true — Android-Back löst Discard-Confirm aus',
    (tester) async {
      setSurface(tester);
      await tester.pumpWidget(_buildApp());
      await _openDialog(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Dirty-Shop');
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
