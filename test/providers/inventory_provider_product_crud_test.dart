import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/product.dart';
import 'package:inventory_management/providers/inventory_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ignore_for_file: avoid_redundant_argument_values

// ── Fake-Repository ──────────────────────────────────────────────────────────

/// Minimale Fake-Implementierung für Produkt-CRUD-Tests (AF7a).
/// Alle insertProduct/updateProduct/deleteProduct-Aufrufe werden protokolliert
/// und simulieren das Verhalten des echten Repositories.
class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  @override
  String? get activeWorkspaceId => 'ws-test';

  final List<Product> insertedProducts = [];
  final List<Product> updatedProducts = [];
  final List<String> deletedProductIds = [];

  List<Product> seedProducts = [];

  @override
  Future<CloudSnapshot> loadAll() async => CloudSnapshot(
        deals: const [],
        buyers: const [],
        shops: const [],
        suppliers: const [],
        inventoryItems: const [],
        movements: const [],
        activities: const [],
        products: List.of(seedProducts),
      );

  // ── Item-Stubs (für loadData) ──

  @override
  Future<InventoryItem> insertInventoryItem(InventoryItem item) async => item;

  @override
  Future<InventoryItem> updateInventoryItem(InventoryItem item) async => item;

  @override
  Future<void> deleteInventoryItem(String id) async {}

  @override
  Future<InventoryMovement> insertMovement(InventoryMovement movement) async =>
      movement;

  // ── Produkt-CRUD ──

  @override
  Future<Product> insertProduct(Product product) async {
    final now = DateTime.utc(2026, 5, 20, 12, 0, 0);
    final saved = Product(
      id: 'saved-${insertedProducts.length + 1}',
      workspaceId: activeWorkspaceId ?? 'ws-test',
      userId: 'user-test',
      name: product.name,
      sku: product.sku,
      unit: product.unit,
      minStock: product.minStock,
      isActive: product.isActive,
      createdAt: now,
      updatedAt: now,
    );
    insertedProducts.add(saved);
    return saved;
  }

  @override
  Future<Product> updateProduct(Product product) async {
    final now = DateTime.utc(2026, 5, 20, 13, 0, 0);
    final updated = product.copyWith(updatedAt: now);
    updatedProducts.add(updated);
    return updated;
  }

  @override
  Future<void> deleteProduct(String id) async {
    deletedProductIds.add(id);
  }
}

// ── Hilfsfunktion ─────────────────────────────────────────────────────────────

Product _makeProduct({
  required String id,
  required String name,
  String? sku,
  int minStock = 0,
  bool isActive = true,
}) {
  final now = DateTime.utc(2026, 5, 20, 10, 0, 0);
  return Product(
    id: id,
    workspaceId: 'ws-test',
    userId: 'user-test',
    name: name,
    sku: sku,
    minStock: minStock,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _FakeRepository repo;
  late InventoryProvider provider;

  setUp(() {
    repo = _FakeRepository();
    provider = InventoryProvider(repository: repo);
  });

  tearDown(() => provider.dispose());

  // ── addProduct ────────────────────────────────────────────────────────────

  group('addProduct', () {
    test('addProduct ruft insertProduct auf und speichert im State', () async {
      final product = _makeProduct(id: '', name: 'Neuer Artikel');
      await provider.addProduct(product);

      expect(repo.insertedProducts, hasLength(1));
      expect(provider.products, hasLength(1));
      expect(provider.products.first.name, equals('Neuer Artikel'));
    });

    test('addProduct: gespeicherter Artikel hat die vom Repository vergebene id',
        () async {
      final product = _makeProduct(id: '', name: 'Test Artikel');
      await provider.addProduct(product);

      // Das Repository vergab 'saved-1'
      expect(provider.products.first.id, equals('saved-1'));
    });

    test('addProduct: mehrere Artikel werden alphabetisch sortiert', () async {
      await provider.addProduct(_makeProduct(id: '', name: 'Zwieback'));
      await provider.addProduct(_makeProduct(id: '', name: 'Apfel'));
      await provider.addProduct(_makeProduct(id: '', name: 'Mango'));

      expect(provider.products.map((p) => p.name).toList(),
          equals(['Apfel', 'Mango', 'Zwieback']));
    });

    test('addProduct ruft notifyListeners auf', () async {
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.addProduct(_makeProduct(id: '', name: 'Listener Test'));

      expect(notified, isTrue);
    });
  });

  // ── updateProduct ─────────────────────────────────────────────────────────

  group('updateProduct', () {
    test('updateProduct aktualisiert bestehenden Artikel im State', () async {
      // Artikel zuerst in den State laden
      repo.seedProducts = [
        _makeProduct(id: 'prod-1', name: 'Alt'),
      ];
      await provider.loadData();

      final updated = _makeProduct(id: 'prod-1', name: 'Neu');
      await provider.updateProduct(updated);

      expect(repo.updatedProducts, hasLength(1));
      final stateProduct =
          provider.products.where((p) => p.id == 'prod-1').first;
      expect(stateProduct.name, equals('Neu'));
    });

    test('updateProduct ruft updateProduct im Repository auf', () async {
      repo.seedProducts = [_makeProduct(id: 'prod-2', name: 'Original')];
      await provider.loadData();

      final updated = _makeProduct(id: 'prod-2', name: 'Geändert');
      await provider.updateProduct(updated);

      expect(repo.updatedProducts, hasLength(1));
      expect(repo.updatedProducts.first.id, equals('prod-2'));
    });

    test('updateProduct mit unbekannter id → State unverändert', () async {
      repo.seedProducts = [_makeProduct(id: 'prod-3', name: 'Existiert')];
      await provider.loadData();
      final countBefore = provider.products.length;

      final ghost = _makeProduct(id: 'does-not-exist', name: 'Ghost');
      await provider.updateProduct(ghost);

      // Repository-Aufruf passiert, aber der State-Update-Index war -1 → kein Eintrag
      expect(provider.products.length, equals(countBefore));
      // 'Existiert' bleibt unverändert
      expect(provider.products.first.name, equals('Existiert'));
    });

    test('updateProduct: Sortierung bleibt korrekt nach Update', () async {
      repo.seedProducts = [
        _makeProduct(id: 'p1', name: 'Banane'),
        _makeProduct(id: 'p2', name: 'Apfel'),
      ];
      await provider.loadData();

      // Umbenennen 'Apfel' → 'Zitrone'
      final updated = _makeProduct(id: 'p2', name: 'Zitrone');
      await provider.updateProduct(updated);

      expect(
        provider.products.map((p) => p.name).toList(),
        equals(['Banane', 'Zitrone']),
      );
    });

    test('updateProduct ruft notifyListeners auf', () async {
      repo.seedProducts = [_makeProduct(id: 'p-nl', name: 'Artikel')];
      await provider.loadData();

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.updateProduct(_makeProduct(id: 'p-nl', name: 'Geändert'));

      expect(notified, isTrue);
    });
  });

  // ── deleteProduct ─────────────────────────────────────────────────────────

  group('deleteProduct', () {
    test('deleteProduct entfernt Artikel aus dem State', () async {
      repo.seedProducts = [
        _makeProduct(id: 'del-1', name: 'Zu löschen'),
      ];
      await provider.loadData();

      await provider.deleteProduct('del-1');

      expect(provider.products, isEmpty);
      expect(repo.deletedProductIds, contains('del-1'));
    });

    test('deleteProduct: verbleibende Artikel bleiben im State', () async {
      repo.seedProducts = [
        _makeProduct(id: 'keep-1', name: 'Behalten'),
        _makeProduct(id: 'del-2', name: 'Löschen'),
      ];
      await provider.loadData();

      await provider.deleteProduct('del-2');

      expect(provider.products, hasLength(1));
      expect(provider.products.first.id, equals('keep-1'));
    });

    test('deleteProduct mit unbekannter id: kein Fehler, State unverändert',
        () async {
      repo.seedProducts = [_makeProduct(id: 'existing', name: 'Noch da')];
      await provider.loadData();

      // Kein Throw erwartet
      await expectLater(
        provider.deleteProduct('non-existent-id'),
        completes,
      );

      expect(provider.products, hasLength(1));
    });

    test('deleteProduct ruft notifyListeners auf', () async {
      repo.seedProducts = [_makeProduct(id: 'notif-prod', name: 'Artikel')];
      await provider.loadData();

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.deleteProduct('notif-prod');

      expect(notified, isTrue);
    });
  });
}
