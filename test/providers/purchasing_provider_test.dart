import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/activity_entry.dart';
import 'package:inventory_management/models/purchase_order.dart';
import 'package:inventory_management/models/supplier.dart';
import 'package:inventory_management/providers/purchasing_provider.dart';
import 'package:inventory_management/services/carrier_service.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ignore_for_file: avoid_redundant_argument_values

// ── Fake-Repository ──────────────────────────────────────────────────────────

/// Fake-Repository für [PurchasingProvider]-Tests.
///
/// - `insertSupplier` vergibt eine deterministische UUID-artige id, falls die
///   übergebene id leer ist (wie das echte Repository).
/// - `loadAll` liefert die geseedeten Suppliers + POs zurück.
/// - Activity-Inserts werden protokolliert (DB-only-`_log`-Verifikation).
class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  @override
  String? get activeWorkspaceId => 'ws-test';

  int _supplierSeq = 0;

  final List<Supplier> insertedSuppliers = [];
  final List<Supplier> updatedSuppliers = [];
  final List<String> deletedSupplierIds = [];
  final List<ActivityEntry> insertedActivities = [];

  /// Seed-Daten für den Snapshot.
  List<Supplier> seedSuppliers = [];
  List<PurchaseOrder> seedPurchaseOrders = [];

  @override
  Future<CloudSnapshot> loadAll() async => CloudSnapshot(
        deals: const [],
        buyers: const [],
        shops: const [],
        suppliers: List.of(seedSuppliers),
        inventoryItems: const [],
        movements: const [],
        activities: const [],
        purchaseOrders: List.of(seedPurchaseOrders),
      );

  @override
  Future<Supplier> insertSupplier(Supplier supplier) async {
    final saved = supplier.id.isEmpty
        ? supplier.copyWith(id: 'sup-${++_supplierSeq}')
        : supplier;
    insertedSuppliers.add(saved);
    return saved;
  }

  @override
  Future<Supplier> updateSupplier(Supplier supplier) async {
    updatedSuppliers.add(supplier);
    return supplier;
  }

  @override
  Future<void> deleteSupplier(String id) async {
    deletedSupplierIds.add(id);
  }

  @override
  Future<ActivityEntry> insertActivity(ActivityEntry entry) async {
    insertedActivities.add(entry);
    return entry;
  }
}

// ── Hilfsfunktionen ──────────────────────────────────────────────────────────

Supplier _makeSupplier({
  required String id,
  required String name,
  bool active = true,
}) =>
    Supplier(id: id, name: name, active: active);

PurchaseOrder _makePo({
  required int id,
  String orderNumber = 'PO-0001',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return PurchaseOrder(
    id: id,
    workspaceId: 'ws-test',
    userId: 'user-test',
    orderNumber: orderNumber,
    status: PurchaseOrderStatus.draft,
    createdAt: createdAt ?? DateTime.utc(2026, 6, 8, 10),
    // updatedAt bewusst von createdAt ENTKOPPELT (fixer Default): so erkennt
    // der Sort-Test einen versehentlichen Komparator-Swap createdAt→updatedAt.
    updatedAt: updatedAt ?? DateTime.utc(2026, 6, 8, 10),
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late _FakeRepository repo;
  late PurchasingProvider provider;

  setUp(() {
    repo = _FakeRepository();
    provider = PurchasingProvider(repository: repo);
  });

  tearDown(() => provider.dispose());

  // ── Supplier-CRUD ──────────────────────────────────────────────────────────

  group('addSupplier', () {
    test('fügt Supplier hinzu und sortiert alphabetisch (case-insensitive)',
        () async {
      await provider.addSupplier(_makeSupplier(id: 's1', name: 'Zeta'));
      await provider.addSupplier(_makeSupplier(id: 's2', name: 'alpha'));
      await provider.addSupplier(_makeSupplier(id: 's3', name: 'Mike'));

      expect(repo.insertedSuppliers, hasLength(3));
      expect(
        provider.suppliers.map((s) => s.name).toList(),
        equals(['alpha', 'Mike', 'Zeta']),
      );
    });

    test('schreibt einen DB-Activity-Log-Eintrag (DB-only, kein In-Memory)',
        () async {
      await provider.addSupplier(_makeSupplier(id: 's1', name: 'Acme'));

      expect(repo.insertedActivities, hasLength(1));
      expect(repo.insertedActivities.first.type, equals('supplier'));
    });

    test('ruft notifyListeners auf', () async {
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.addSupplier(_makeSupplier(id: 's1', name: 'Acme'));

      expect(notified, isTrue);
    });
  });

  group('updateSupplier', () {
    test('aktualisiert bestehenden Supplier und re-sortiert', () async {
      repo.seedSuppliers = [
        _makeSupplier(id: 's1', name: 'Bravo'),
        _makeSupplier(id: 's2', name: 'Delta'),
      ];
      await provider.loadData();

      await provider.updateSupplier(_makeSupplier(id: 's1', name: 'Zulu'));

      expect(repo.updatedSuppliers, hasLength(1));
      // 'Delta' < 'Zulu' → Delta zuerst.
      expect(
        provider.suppliers.map((s) => s.name).toList(),
        equals(['Delta', 'Zulu']),
      );
    });

    test('mit unbekannter id → State unverändert, kein notify', () async {
      repo.seedSuppliers = [_makeSupplier(id: 's1', name: 'Bravo')];
      await provider.loadData();

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.updateSupplier(_makeSupplier(id: 'ghost', name: 'X'));

      expect(provider.suppliers, hasLength(1));
      expect(notified, isFalse);
    });
  });

  group('deleteSupplier', () {
    test('entfernt Supplier aus dem State und ruft Repository', () async {
      repo.seedSuppliers = [
        _makeSupplier(id: 's1', name: 'Keep'),
        _makeSupplier(id: 's2', name: 'Drop'),
      ];
      await provider.loadData();

      await provider.deleteSupplier('s2');

      expect(repo.deletedSupplierIds, contains('s2'));
      expect(provider.suppliers, hasLength(1));
      expect(provider.suppliers.first.id, equals('s1'));
    });
  });

  group('activeSuppliers', () {
    test('liefert nur aktive Supplier', () async {
      repo.seedSuppliers = [
        _makeSupplier(id: 's1', name: 'Active', active: true),
        _makeSupplier(id: 's2', name: 'Inactive', active: false),
      ];
      await provider.loadData();

      expect(provider.activeSuppliers, hasLength(1));
      expect(provider.activeSuppliers.first.id, equals('s1'));
    });
  });

  // ── seedCarrierSuppliers — Idempotenz ────────────────────────────────────

  group('seedCarrierSuppliers', () {
    test('fügt alle Carrier-Seeds auf leerem State hinzu', () async {
      final result = await provider.seedCarrierSuppliers();

      expect(result.added, equals(carrierSupplierSeeds.length));
      expect(result.skipped, equals(0));
      expect(provider.suppliers, hasLength(carrierSupplierSeeds.length));
    });

    test('ist idempotent: zweiter Aufruf fügt nichts hinzu', () async {
      final first = await provider.seedCarrierSuppliers();
      expect(first.added, equals(carrierSupplierSeeds.length));

      final second = await provider.seedCarrierSuppliers();
      expect(second.added, equals(0));
      expect(second.skipped, equals(carrierSupplierSeeds.length));
      // Keine Duplikate.
      expect(provider.suppliers, hasLength(carrierSupplierSeeds.length));
    });

    test('überspringt bereits vorhandene Namen (case-insensitive)', () async {
      // Ein Carrier ist bereits da (lowercased) → wird übersprungen.
      repo.seedSuppliers = [_makeSupplier(id: 's1', name: 'dhl')];
      await provider.loadData();

      final result = await provider.seedCarrierSuppliers();

      expect(result.skipped, greaterThanOrEqualTo(1));
      expect(result.added, equals(carrierSupplierSeeds.length - 1));
    });
  });

  // ── loadData — Sortierung ─────────────────────────────────────────────────

  group('loadData', () {
    test('sortiert Suppliers alphabetisch (case-insensitive)', () async {
      repo.seedSuppliers = [
        _makeSupplier(id: 's1', name: 'Zeta'),
        _makeSupplier(id: 's2', name: 'alpha'),
      ];
      await provider.loadData();

      expect(
        provider.suppliers.map((s) => s.name).toList(),
        equals(['alpha', 'Zeta']),
      );
    });

    test('sortiert POs absteigend nach createdAt (nicht updatedAt)', () async {
      // Beide POs haben identisches updatedAt (Default), nur createdAt
      // differiert + die Insertion-Reihenfolge ist OLD-vor-NEW. Würde der
      // Komparator versehentlich nach updatedAt sortieren, bliebe die
      // (stabile) Insertion-Reihenfolge OLD-vor-NEW → first==NEW schlägt fehl.
      repo.seedPurchaseOrders = [
        _makePo(id: 1, orderNumber: 'OLD', createdAt: DateTime.utc(2026, 1, 1)),
        _makePo(id: 2, orderNumber: 'NEW', createdAt: DateTime.utc(2026, 6, 1)),
        _makePo(id: 3, orderNumber: 'MID', createdAt: DateTime.utc(2026, 3, 1)),
      ];
      await provider.loadData();

      expect(
        provider.purchaseOrders.map((p) => p.orderNumber).toList(),
        equals(['NEW', 'MID', 'OLD']),
      );
    });

    test('PO-Sort ist stabil bei identischem createdAt', () async {
      final ts = DateTime.utc(2026, 4, 1);
      repo.seedPurchaseOrders = [
        _makePo(id: 1, orderNumber: 'FIRST', createdAt: ts),
        _makePo(id: 2, orderNumber: 'SECOND', createdAt: ts),
      ];
      await provider.loadData();

      // Gleicher createdAt → Insertion-Reihenfolge bleibt erhalten.
      expect(
        provider.purchaseOrders.map((p) => p.orderNumber).toList(),
        equals(['FIRST', 'SECOND']),
      );
    });

    test('setzt initialLoadAttempted nach Abschluss', () async {
      expect(provider.initialLoadAttempted, isFalse);
      await provider.loadData();
      expect(provider.initialLoadAttempted, isTrue);
    });

    test('coalesct gleichzeitige loadData-Calls (gleiches Future)', () {
      final a = provider.loadData();
      final b = provider.loadData();
      expect(identical(a, b), isTrue);
    });
  });

  // ── clearLocalState ────────────────────────────────────────────────────────

  group('clearLocalState', () {
    test('leert Suppliers + POs und setzt Flags zurück', () async {
      repo.seedSuppliers = [_makeSupplier(id: 's1', name: 'Acme')];
      repo.seedPurchaseOrders = [_makePo(id: 1)];
      await provider.loadData();
      expect(provider.suppliers, isNotEmpty);
      expect(provider.purchaseOrders, isNotEmpty);

      provider.clearLocalState();

      expect(provider.suppliers, isEmpty);
      expect(provider.purchaseOrders, isEmpty);
      expect(provider.initialLoadAttempted, isFalse);
      expect(provider.lastError, isNull);
    });
  });

  // ── Cross-domain write-back hooks ──────────────────────────────────────────

  group('cross-domain hooks', () {
    test('upsertSupplierFromImport + sortSuppliers landen im Cache', () async {
      provider.upsertSupplierFromImport(_makeSupplier(id: 's2', name: 'Zeta'));
      provider.upsertSupplierFromImport(_makeSupplier(id: 's1', name: 'alpha'));
      provider.sortSuppliers();

      expect(
        provider.suppliers.map((s) => s.name).toList(),
        equals(['alpha', 'Zeta']),
      );
    });

    test('insertPurchaseOrderFromImport fügt vorne ein, sortPurchaseOrders sortiert',
        () async {
      provider.insertPurchaseOrderFromImport(
        _makePo(id: 1, orderNumber: 'A', createdAt: DateTime.utc(2026, 1, 1)),
      );
      provider.insertPurchaseOrderFromImport(
        _makePo(id: 2, orderNumber: 'B', createdAt: DateTime.utc(2026, 6, 1)),
      );
      provider.sortPurchaseOrders();

      expect(provider.purchaseOrders.first.orderNumber, equals('B'));
    });

    test('replacePurchaseOrderHeader ersetzt PO in-place per id', () async {
      repo.seedPurchaseOrders = [
        _makePo(id: 1, orderNumber: 'PO-1'),
      ];
      await provider.loadData();

      final fresh = _makePo(id: 1, orderNumber: 'PO-1-FRESH');
      provider.replacePurchaseOrderHeader(fresh);

      expect(provider.purchaseOrders.first.orderNumber, equals('PO-1-FRESH'));
    });

    test('replacePurchaseOrderHeader ist no-op bei unbekannter id', () async {
      repo.seedPurchaseOrders = [_makePo(id: 1, orderNumber: 'PO-1')];
      await provider.loadData();

      provider.replacePurchaseOrderHeader(
        _makePo(id: 999, orderNumber: 'GHOST'),
      );

      expect(provider.purchaseOrders, hasLength(1));
      expect(provider.purchaseOrders.first.orderNumber, equals('PO-1'));
    });

    test('notifyAfterCrossDomainWrite ruft notifyListeners', () {
      var notified = false;
      provider.addListener(() => notified = true);

      provider.notifyAfterCrossDomainWrite();

      expect(notified, isTrue);
    });
  });
}
