import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/product_category.dart';
import 'package:inventory_management/providers/catalog_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ignore_for_file: avoid_redundant_argument_values

// ── Fake-Repository ──────────────────────────────────────────────────────────

/// Minimale Fake-Implementierung für Kategorie-CRUD-Tests (B5).
/// Alle insertProductCategory/updateProductCategory/deleteProductCategory-
/// Aufrufe werden protokolliert und simulieren das Verhalten des echten
/// Repositories ohne Supabase-Verbindung.
class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  @override
  String? get activeWorkspaceId => 'ws-test';

  final List<ProductCategory> insertedCategories = [];
  final List<ProductCategory> updatedCategories = [];
  final List<String> deletedCategoryIds = [];

  List<ProductCategory> seedCategories = [];

  @override
  Future<CloudSnapshot> loadAll() async => CloudSnapshot(
        deals: const [],
        buyers: const [],
        shops: const [],
        suppliers: const [],
        inventoryItems: const [],
        movements: const [],
        activities: const [],
        productCategories: List.of(seedCategories),
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

  // ── Kategorie-CRUD ──

  @override
  Future<ProductCategory> insertProductCategory(
      ProductCategory category) async {
    final now = DateTime.utc(2026, 5, 20, 12, 0, 0);
    final saved = ProductCategory(
      id: 'saved-cat-${insertedCategories.length + 1}',
      workspaceId: activeWorkspaceId ?? 'ws-test',
      userId: 'user-test',
      name: category.name,
      parentId: category.parentId,
      sortOrder: category.sortOrder,
      createdAt: now,
      updatedAt: now,
    );
    insertedCategories.add(saved);
    return saved;
  }

  @override
  Future<ProductCategory> updateProductCategory(
      ProductCategory category) async {
    final now = DateTime.utc(2026, 5, 20, 13, 0, 0);
    final updated = category.copyWith(updatedAt: now);
    updatedCategories.add(updated);
    return updated;
  }

  @override
  Future<void> deleteProductCategory(String id) async {
    deletedCategoryIds.add(id);
  }
}

// ── Hilfsfunktion ────────────────────────────────────────────────────────────

ProductCategory _makeCategory({
  required String id,
  required String name,
  int sortOrder = 0,
  String? parentId,
}) {
  final now = DateTime.utc(2026, 5, 20, 10, 0, 0);
  return ProductCategory(
    id: id,
    workspaceId: 'ws-test',
    userId: 'user-test',
    name: name,
    parentId: parentId,
    sortOrder: sortOrder,
    createdAt: now,
    updatedAt: now,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _FakeRepository repo;
  late CatalogProvider provider;

  setUp(() {
    repo = _FakeRepository();
    provider = CatalogProvider(repository: repo);
  });

  tearDown(() => provider.dispose());

  // ── addProductCategory ────────────────────────────────────────────────────

  group('addProductCategory', () {
    test('ruft insertProductCategory auf und speichert im State', () async {
      final category = _makeCategory(id: '', name: 'Elektronik');
      await provider.addProductCategory(category);

      expect(repo.insertedCategories, hasLength(1));
      expect(provider.productCategories, hasLength(1));
      expect(provider.productCategories.first.name, equals('Elektronik'));
    });

    test('gespeicherte Kategorie hat die vom Repository vergebene id',
        () async {
      final category = _makeCategory(id: '', name: 'Werkzeug');
      await provider.addProductCategory(category);

      expect(provider.productCategories.first.id, equals('saved-cat-1'));
    });

    test('mehrere Kategorien werden nach sortOrder sortiert', () async {
      await provider
          .addProductCategory(_makeCategory(id: '', name: 'C', sortOrder: 30));
      await provider
          .addProductCategory(_makeCategory(id: '', name: 'A', sortOrder: 10));
      await provider
          .addProductCategory(_makeCategory(id: '', name: 'B', sortOrder: 20));

      expect(
        provider.productCategories.map((c) => c.name).toList(),
        equals(['A', 'B', 'C']),
      );
    });

    test('ruft notifyListeners auf', () async {
      var notified = false;
      provider.addListener(() => notified = true);

      await provider
          .addProductCategory(_makeCategory(id: '', name: 'Listener Test'));

      expect(notified, isTrue);
    });
  });

  // ── updateProductCategory ─────────────────────────────────────────────────

  group('updateProductCategory', () {
    test('aktualisiert bestehende Kategorie im State', () async {
      repo.seedCategories = [
        _makeCategory(id: 'cat-1', name: 'Alt', sortOrder: 0),
      ];
      await provider.loadData();

      final updated = _makeCategory(id: 'cat-1', name: 'Neu', sortOrder: 0);
      await provider.updateProductCategory(updated);

      expect(repo.updatedCategories, hasLength(1));
      final stateCategory =
          provider.productCategories.where((c) => c.id == 'cat-1').first;
      expect(stateCategory.name, equals('Neu'));
    });

    test('ruft updateProductCategory im Repository auf', () async {
      repo.seedCategories = [
        _makeCategory(id: 'cat-2', name: 'Original', sortOrder: 0)
      ];
      await provider.loadData();

      final updated =
          _makeCategory(id: 'cat-2', name: 'Geändert', sortOrder: 0);
      await provider.updateProductCategory(updated);

      expect(repo.updatedCategories, hasLength(1));
      expect(repo.updatedCategories.first.id, equals('cat-2'));
    });

    test('mit unbekannter id → State unverändert, kein Fehler', () async {
      repo.seedCategories = [
        _makeCategory(id: 'cat-3', name: 'Existiert', sortOrder: 0)
      ];
      await provider.loadData();
      final countBefore = provider.productCategories.length;

      final ghost =
          _makeCategory(id: 'does-not-exist', name: 'Ghost', sortOrder: 0);
      await provider.updateProductCategory(ghost);

      expect(provider.productCategories.length, equals(countBefore));
      expect(provider.productCategories.first.name, equals('Existiert'));
    });

    test('Sortierung nach sortOrder bleibt korrekt nach Update', () async {
      repo.seedCategories = [
        _makeCategory(id: 'cat-a', name: 'Erste', sortOrder: 10),
        _makeCategory(id: 'cat-b', name: 'Zweite', sortOrder: 20),
      ];
      await provider.loadData();

      // sortOrder von cat-b auf 5 setzen → wandert vor cat-a
      final updated = _makeCategory(id: 'cat-b', name: 'Zweite', sortOrder: 5);
      await provider.updateProductCategory(updated);

      expect(
        provider.productCategories.map((c) => c.name).toList(),
        equals(['Zweite', 'Erste']),
      );
    });

    test('ruft notifyListeners auf', () async {
      repo.seedCategories = [
        _makeCategory(id: 'cat-nl', name: 'Kategorie', sortOrder: 0)
      ];
      await provider.loadData();

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.updateProductCategory(
          _makeCategory(id: 'cat-nl', name: 'Geändert', sortOrder: 0));

      expect(notified, isTrue);
    });
  });

  // ── deleteProductCategory ─────────────────────────────────────────────────

  group('deleteProductCategory', () {
    test('entfernt Kategorie aus dem State', () async {
      repo.seedCategories = [
        _makeCategory(id: 'del-1', name: 'Zu löschen', sortOrder: 0),
      ];
      await provider.loadData();

      await provider.deleteProductCategory('del-1');

      expect(provider.productCategories, isEmpty);
      expect(repo.deletedCategoryIds, contains('del-1'));
    });

    test('verbleibende Kategorien bleiben im State', () async {
      repo.seedCategories = [
        _makeCategory(id: 'keep-1', name: 'Behalten', sortOrder: 0),
        _makeCategory(id: 'del-2', name: 'Löschen', sortOrder: 1),
      ];
      await provider.loadData();

      await provider.deleteProductCategory('del-2');

      expect(provider.productCategories, hasLength(1));
      expect(provider.productCategories.first.id, equals('keep-1'));
    });

    test('mit unbekannter id: kein Fehler, State unverändert', () async {
      repo.seedCategories = [
        _makeCategory(id: 'existing', name: 'Noch da', sortOrder: 0)
      ];
      await provider.loadData();

      await expectLater(
        provider.deleteProductCategory('non-existent-id'),
        completes,
      );

      expect(provider.productCategories, hasLength(1));
    });

    test('ruft notifyListeners auf', () async {
      repo.seedCategories = [
        _makeCategory(id: 'notif-cat', name: 'Kategorie', sortOrder: 0)
      ];
      await provider.loadData();

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.deleteProductCategory('notif-cat');

      expect(notified, isTrue);
    });
  });
}
