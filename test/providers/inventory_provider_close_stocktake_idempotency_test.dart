// Tests für den Idempotenz-Guard in closeStocktake.
//
// Fokus: Wenn ein Stocktake bereits den Status `closed` hat, darf
// closeStocktake KEINE weiteren Movements, Bestandsangleiche oder
// DB-Writes auslösen — der Call muss still das übergebene Objekt
// zurückliefern.
//
// Das ist der Schutz vor Doppel-Tap / Retry-Szenarien in der UI.

import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/inventory_item.dart';
import 'package:inventory_management/models/product_stock.dart';
import 'package:inventory_management/models/stocktake.dart';
import 'package:inventory_management/models/stocktake_item.dart';
import 'package:inventory_management/models/warehouse.dart';
import 'package:inventory_management/providers/inventory_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ── Fake-Repository ──────────────────────────────────────────────────────────

class _FakeRepository extends SupabaseRepository {
  _FakeRepository() : super.forTesting();

  @override
  String? get activeWorkspaceId => 'ws-test';

  final List<Stocktake> updatedStocktakes = [];
  final List<InventoryMovement> insertedMovements = [];
  final List<InventoryItem> updatedInventoryItems = [];

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
  Future<Stocktake> updateStocktake(Stocktake stocktake) async {
    updatedStocktakes.add(stocktake);
    return stocktake;
  }

  @override
  Future<InventoryMovement> insertMovement(InventoryMovement movement) async {
    insertedMovements.add(movement);
    return movement;
  }

  @override
  Future<InventoryItem> updateInventoryItem(InventoryItem item) async {
    updatedInventoryItems.add(item);
    return item;
  }

  @override
  Future<List<ProductStock>> loadProductStock(String workspaceId) async => [];

  @override
  Future<List<Warehouse>> loadWarehouses(String workspaceId) async => [];
}

// ── Hilfsfunktionen ─────────────────────────────────────────────────────────

InventoryProvider _makeProvider(_FakeRepository repo) =>
    InventoryProvider(repository: repo);

Stocktake _makeStocktake({required StocktakeStatus status}) => Stocktake(
      id: 100,
      workspaceId: 'ws-test',
      userId: 'u',
      status: status,
      createdAt: DateTime.utc(2026, 5, 22),
      updatedAt: DateTime.utc(2026, 5, 22),
    );

StocktakeItem _makeItem({
  String productId = 'prod-1',
  int expectedQty = 10,
  int? countedQty = 7,
}) {
  final now = DateTime.utc(2026, 5, 22, 10);
  return StocktakeItem(
    id: 'si-1',
    workspaceId: 'ws-test',
    stocktakeId: 100,
    productId: productId,
    expectedQty: expectedQty,
    countedQty: countedQty,
    createdAt: now,
    updatedAt: now,
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('closeStocktake — Idempotenz-Guard (status=closed)', () {
    test('gibt das übergebene Objekt zurück ohne DB-Writes', () async {
      final repo = _FakeRepository();
      final provider = _makeProvider(repo);
      await provider.loadData();

      final alreadyClosed = _makeStocktake(status: StocktakeStatus.closed);
      final items = [_makeItem(countedQty: 7)];

      final result = await provider.closeStocktake(alreadyClosed, items);

      // Rückgabe ist das Original (kein neues Objekt aus DB).
      expect(result.status, equals(StocktakeStatus.closed));
      expect(result.id, equals(alreadyClosed.id));

      // Kein einziger DB-Write darf stattgefunden haben.
      expect(repo.updatedStocktakes, isEmpty,
          reason: 'Bereits geschlossene Inventur darf nicht nochmals geschrieben werden');
      expect(repo.insertedMovements, isEmpty,
          reason: 'Kein Movement bei bereits geschlossener Inventur');
      expect(repo.updatedInventoryItems, isEmpty,
          reason: 'Kein Bestandsangleich bei bereits geschlossener Inventur');
    });

    test('identisches Objekt wird zurückgegeben (Referenz-Check)', () async {
      final repo = _FakeRepository();
      final provider = _makeProvider(repo);
      await provider.loadData();

      final alreadyClosed = _makeStocktake(status: StocktakeStatus.closed);
      final result = await provider.closeStocktake(alreadyClosed, []);

      // Gleiche Werte wie das Eingabe-Objekt.
      expect(result.id, equals(alreadyClosed.id));
      expect(result.status, equals(alreadyClosed.status));
      expect(result.closedAt, equals(alreadyClosed.closedAt));
    });

    test('guard greift auch wenn Items Differenzen haben', () async {
      // Sicherstellen, dass auch mit ungelösten Differenzen KEINE Buchungen
      // entstehen, wenn der Guard früh zurückkehrt.
      final repo = _FakeRepository();
      final provider = _makeProvider(repo);
      await provider.loadData();

      final alreadyClosed = _makeStocktake(status: StocktakeStatus.closed);
      final itemsWithDiffs = [
        _makeItem(productId: 'prod-1', expectedQty: 10, countedQty: 5),
        _makeItem(productId: 'prod-2', expectedQty: 8, countedQty: 8),
        _makeItem(productId: 'prod-3', expectedQty: 3, countedQty: 0),
      ];

      await provider.closeStocktake(alreadyClosed, itemsWithDiffs);

      expect(repo.insertedMovements, isEmpty,
          reason: 'Differenz-Movements dürfen bei guard=closed nicht entstehen');
    });

    test('guard greift auch mit leerer Item-Liste', () async {
      final repo = _FakeRepository();
      final provider = _makeProvider(repo);
      await provider.loadData();

      final alreadyClosed = _makeStocktake(status: StocktakeStatus.closed);
      await provider.closeStocktake(alreadyClosed, []);

      expect(repo.updatedStocktakes, isEmpty);
    });

    test('counting-Status durchläuft den Guard NICHT (normaler Pfad)', () async {
      // Kontrast-Test: bei status=counting soll der normale Pfad laufen.
      final repo = _FakeRepository();
      final provider = _makeProvider(repo);
      await provider.loadData();

      final counting = _makeStocktake(status: StocktakeStatus.counting);
      await provider.closeStocktake(counting, []);

      // Normaler Pfad: updateStocktake wird genau einmal aufgerufen.
      expect(repo.updatedStocktakes, hasLength(1));
      expect(repo.updatedStocktakes.first.status, equals(StocktakeStatus.closed));
    });

    test('doppelter close-Call: zweiter Call trifft Guard', () async {
      // Simuliert Doppel-Tap: erster Call schließt, zweiter Call trifft Guard.
      final repo = _FakeRepository();
      final provider = _makeProvider(repo);
      await provider.loadData();

      final counting = _makeStocktake(status: StocktakeStatus.counting);

      // Erster Call: normal.
      final firstResult = await provider.closeStocktake(counting, []);
      expect(firstResult.status, equals(StocktakeStatus.closed));
      expect(repo.updatedStocktakes, hasLength(1));

      // Zweiter Call mit dem bereits-closed Ergebnis → Guard.
      await provider.closeStocktake(firstResult, []);
      // Kein weiterer DB-Write im zweiten Call.
      expect(repo.updatedStocktakes, hasLength(1),
          reason: 'Zweiter Call darf kein weiteres updateStocktake auslösen');
    });
  });

  // ── Fehlerbehandlung: Vorbedingungen ────────────────────────────────────

  group('closeStocktake — Fehlerbehandlung Vorbedingungen', () {
    test('wirft ArgumentError wenn Stocktake keine id hat', () async {
      final repo = _FakeRepository();
      final provider = _makeProvider(repo);
      await provider.loadData();

      final noIdStocktake = Stocktake(
        workspaceId: 'ws-test',
        userId: 'u',
        status: StocktakeStatus.counting,
        createdAt: DateTime.utc(2026, 5, 22),
        updatedAt: DateTime.utc(2026, 5, 22),
      );

      expect(
        () => provider.closeStocktake(noIdStocktake, []),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
