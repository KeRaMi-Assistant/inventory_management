import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/warehouse.dart';
import 'package:inventory_management/providers/inventory_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ignore_for_file: avoid_redundant_argument_values

// ── Fake-Repository ──────────────────────────────────────────────────────────

/// Minimale Fake-Implementierung für Warehouse-CRUD-Tests (Epic D / Task D7).
///
/// Protokolliert alle `insertWarehouse` / `updateWarehouse` /
/// `deleteWarehouse`-Aufrufe und simuliert das Verhalten des echten
/// Repositories.
class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  @override
  String? get activeWorkspaceId => 'ws-test';

  // ── interne Stores ──

  final List<Warehouse> insertedWarehouses = [];
  final List<Warehouse> updatedWarehouses = [];
  final List<String> deletedWarehouseIds = [];

  /// Seed-Lager, die [loadAll] zurückgibt.
  List<Warehouse> seedWarehouses = [];

  // ── Snapshot ──

  @override
  Future<CloudSnapshot> loadAll() async => CloudSnapshot(
        deals: const [],
        buyers: const [],
        shops: const [],
        suppliers: const [],
        inventoryItems: const [],
        movements: const [],
        activities: const [],
        warehouses: List.of(seedWarehouses),
      );

  // ── Stubs für andere von `loadData` benötigte Methoden ──

  @override
  Future<InventoryItem> insertInventoryItem(InventoryItem item) async => item;

  @override
  Future<InventoryItem> updateInventoryItem(InventoryItem item) async => item;

  @override
  Future<void> deleteInventoryItem(String id) async {}

  @override
  Future<InventoryMovement> insertMovement(InventoryMovement movement) async =>
      movement;

  // ── Warehouse-CRUD ──

  @override
  Future<Warehouse> insertWarehouse(Warehouse warehouse) async {
    final now = DateTime.utc(2026, 5, 20, 12, 0, 0);
    final saved = Warehouse(
      id: 'saved-wh-${insertedWarehouses.length + 1}',
      workspaceId: activeWorkspaceId ?? 'ws-test',
      userId: 'user-test',
      name: warehouse.name,
      address: warehouse.address,
      isDefault: warehouse.isDefault,
      isActive: warehouse.isActive,
      createdAt: now,
      updatedAt: now,
    );
    insertedWarehouses.add(saved);
    return saved;
  }

  @override
  Future<Warehouse> updateWarehouse(Warehouse warehouse) async {
    final now = DateTime.utc(2026, 5, 20, 13, 0, 0);
    final updated = warehouse.copyWith(updatedAt: now);
    updatedWarehouses.add(updated);
    return updated;
  }

  @override
  Future<void> deleteWarehouse(String id) async {
    deletedWarehouseIds.add(id);
  }
}

// ── Hilfsfunktion ─────────────────────────────────────────────────────────────

Warehouse _makeWarehouse({
  required String id,
  required String name,
  String? address,
  bool isDefault = false,
  bool isActive = true,
}) {
  final now = DateTime.utc(2026, 5, 20, 10, 0, 0);
  return Warehouse(
    id: id,
    workspaceId: 'ws-test',
    userId: 'user-test',
    name: name,
    address: address,
    isDefault: isDefault,
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

  // ── addWarehouse ──────────────────────────────────────────────────────────

  group('addWarehouse', () {
    test('addWarehouse ruft insertWarehouse auf und speichert im State',
        () async {
      final warehouse = _makeWarehouse(id: '', name: 'Neues Lager');
      await provider.addWarehouse(warehouse);

      expect(repo.insertedWarehouses, hasLength(1));
      expect(provider.warehouses, hasLength(1));
      expect(provider.warehouses.first.name, equals('Neues Lager'));
    });

    test(
        'addWarehouse: gespeichertes Lager hat die vom Repository vergebene id',
        () async {
      final warehouse = _makeWarehouse(id: '', name: 'Test Lager');
      await provider.addWarehouse(warehouse);

      // Das Repository vergab 'saved-wh-1'
      expect(provider.warehouses.first.id, equals('saved-wh-1'));
    });

    test('addWarehouse: mehrere Lager werden alphabetisch sortiert', () async {
      await provider.addWarehouse(_makeWarehouse(id: '', name: 'Zentrallager'));
      await provider.addWarehouse(_makeWarehouse(id: '', name: 'Außenlager'));
      await provider.addWarehouse(_makeWarehouse(id: '', name: 'Hauptlager'));

      expect(
        provider.warehouses.map((w) => w.name).toList(),
        equals(['Außenlager', 'Hauptlager', 'Zentrallager']),
      );
    });

    test('addWarehouse ruft notifyListeners auf', () async {
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.addWarehouse(_makeWarehouse(id: '', name: 'Listener Test'));

      expect(notified, isTrue);
    });
  });

  // ── updateWarehouse ───────────────────────────────────────────────────────

  group('updateWarehouse', () {
    test('updateWarehouse aktualisiert bestehendes Lager im State', () async {
      repo.seedWarehouses = [
        _makeWarehouse(id: 'wh-1', name: 'Alt'),
      ];
      await provider.loadData();

      final updated = _makeWarehouse(id: 'wh-1', name: 'Neu');
      await provider.updateWarehouse(updated);

      expect(repo.updatedWarehouses, hasLength(1));
      final stateWarehouse =
          provider.warehouses.where((w) => w.id == 'wh-1').first;
      expect(stateWarehouse.name, equals('Neu'));
    });

    test('updateWarehouse ruft updateWarehouse im Repository auf', () async {
      repo.seedWarehouses = [_makeWarehouse(id: 'wh-2', name: 'Original')];
      await provider.loadData();

      final updated = _makeWarehouse(id: 'wh-2', name: 'Geändert');
      await provider.updateWarehouse(updated);

      expect(repo.updatedWarehouses, hasLength(1));
      expect(repo.updatedWarehouses.first.id, equals('wh-2'));
    });

    test('updateWarehouse mit unbekannter id → State unverändert', () async {
      repo.seedWarehouses = [_makeWarehouse(id: 'wh-3', name: 'Existiert')];
      await provider.loadData();
      final countBefore = provider.warehouses.length;

      final ghost = _makeWarehouse(id: 'does-not-exist', name: 'Ghost');
      await provider.updateWarehouse(ghost);

      // Repository-Aufruf passiert, aber der State-Update-Index war -1 → kein Eintrag
      expect(provider.warehouses.length, equals(countBefore));
      // Das existierende Lager bleibt unverändert
      expect(provider.warehouses.first.name, equals('Existiert'));
    });

    test('updateWarehouse: Sortierung bleibt korrekt nach Update', () async {
      repo.seedWarehouses = [
        _makeWarehouse(id: 'wh-a', name: 'Berlin'),
        _makeWarehouse(id: 'wh-b', name: 'Aachen'),
      ];
      await provider.loadData();

      // 'Aachen' → 'Zwickau' umbenennen
      final updated = _makeWarehouse(id: 'wh-b', name: 'Zwickau');
      await provider.updateWarehouse(updated);

      expect(
        provider.warehouses.map((w) => w.name).toList(),
        equals(['Berlin', 'Zwickau']),
      );
    });

    test('updateWarehouse ruft notifyListeners auf', () async {
      repo.seedWarehouses = [_makeWarehouse(id: 'wh-nl', name: 'Lager')];
      await provider.loadData();

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.updateWarehouse(
          _makeWarehouse(id: 'wh-nl', name: 'Geändert'));

      expect(notified, isTrue);
    });
  });

  // ── deleteWarehouse ───────────────────────────────────────────────────────

  group('deleteWarehouse', () {
    test('deleteWarehouse entfernt Lager aus dem State', () async {
      repo.seedWarehouses = [
        _makeWarehouse(id: 'del-1', name: 'Zu löschen'),
      ];
      await provider.loadData();

      await provider.deleteWarehouse('del-1');

      expect(provider.warehouses, isEmpty);
      expect(repo.deletedWarehouseIds, contains('del-1'));
    });

    test('deleteWarehouse: verbleibende Lager bleiben im State', () async {
      repo.seedWarehouses = [
        _makeWarehouse(id: 'keep-1', name: 'Behalten'),
        _makeWarehouse(id: 'del-2', name: 'Löschen'),
      ];
      await provider.loadData();

      await provider.deleteWarehouse('del-2');

      expect(provider.warehouses, hasLength(1));
      expect(provider.warehouses.first.id, equals('keep-1'));
    });

    test(
        'deleteWarehouse mit unbekannter id: kein Fehler, State unverändert',
        () async {
      repo.seedWarehouses = [_makeWarehouse(id: 'existing', name: 'Noch da')];
      await provider.loadData();

      // Kein Throw erwartet
      await expectLater(
        provider.deleteWarehouse('non-existent-id'),
        completes,
      );

      expect(provider.warehouses, hasLength(1));
    });

    test('deleteWarehouse ruft notifyListeners auf', () async {
      repo.seedWarehouses = [
        _makeWarehouse(id: 'notif-wh', name: 'Lager'),
      ];
      await provider.loadData();

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.deleteWarehouse('notif-wh');

      expect(notified, isTrue);
    });
  });

  // ── _bootstrapDefaultWarehouse ────────────────────────────────────────────
  // Testet den Pfad: loadData() + leere Warehouse-Liste → Default-Lager wird
  // angelegt. Der Bootstrap läuft innerhalb von loadData() wenn _warehouses
  // leer und activeWorkspaceId != null.

  group('_bootstrapDefaultWarehouse (via loadData)', () {
    test(
        'loadData mit leerer Warehouse-Liste legt Default-Lager "Hauptlager" an',
        () async {
      // seedWarehouses bleibt leer → Bootstrap wird ausgeführt
      repo.seedWarehouses = [];
      await provider.loadData();

      // insertWarehouse wurde aufgerufen
      expect(repo.insertedWarehouses, hasLength(1));
      expect(repo.insertedWarehouses.first.name, equals('Hauptlager'));
      expect(repo.insertedWarehouses.first.isDefault, isTrue);

      // Provider-State enthält das angelegte Default-Lager
      expect(provider.warehouses, hasLength(1));
      expect(provider.warehouses.first.name, equals('Hauptlager'));
    });

    test(
        'loadData mit vorhandenen Lagern überspringt Bootstrap',
        () async {
      repo.seedWarehouses = [
        _makeWarehouse(id: 'existing-wh', name: 'Bestehendes Lager'),
      ];
      await provider.loadData();

      // insertWarehouse darf NICHT aufgerufen worden sein
      expect(repo.insertedWarehouses, isEmpty);
      expect(provider.warehouses, hasLength(1));
      expect(provider.warehouses.first.name, equals('Bestehendes Lager'));
    });
  });
}
