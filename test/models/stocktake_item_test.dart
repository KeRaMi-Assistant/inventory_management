import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/stocktake_item.dart';

void main() {
  final baseCreatedAt = DateTime.utc(2026, 5, 22, 8, 0, 0);
  final baseUpdatedAt = DateTime.utc(2026, 5, 22, 9, 0, 0);

  StocktakeItem makeBase({
    String id = 'item-uuid-1',
    int? stocktakeId = 1,
    String productId = 'prod-uuid-1',
    int expectedQty = 10,
    int? countedQty,
    String? updatedBy,
  }) =>
      StocktakeItem(
        id: id,
        workspaceId: 'ws-id-1',
        stocktakeId: stocktakeId,
        productId: productId,
        expectedQty: expectedQty,
        countedQty: countedQty,
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
        updatedBy: updatedBy,
        version: 1,
      );

  // ── Supabase Round-Trip ───────────────────────────────────────────────────

  group('StocktakeItem Supabase Round-Trip', () {
    test('Round-Trip: counted_qty null (ungezählt)', () {
      final original = makeBase();
      final row = original.toSupabaseInsert();

      expect(row['id'], equals('item-uuid-1'));
      expect(row['workspace_id'], equals('ws-id-1'));
      expect(row['stocktake_id'], equals(1));
      expect(row['product_id'], equals('prod-uuid-1'));
      expect(row['expected_qty'], equals(10));
      expect(row['counted_qty'], isNull);
      // Timestamps werden nicht vom Client gesetzt (Trigger)
      expect(row.containsKey('created_at'), isFalse);
      expect(row.containsKey('updated_at'), isFalse);

      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String()
        ..['version'] = 1;

      final restored = StocktakeItem.fromSupabase(fullRow);
      expect(restored.id, equals('item-uuid-1'));
      expect(restored.workspaceId, equals('ws-id-1'));
      expect(restored.stocktakeId, equals(1));
      expect(restored.productId, equals('prod-uuid-1'));
      expect(restored.expectedQty, equals(10));
      expect(restored.countedQty, isNull);
      expect(restored.isCounted, isFalse);
    });

    test('Round-Trip: counted_qty gesetzt (gezählt)', () {
      final original = makeBase(countedQty: 8);
      final row = original.toSupabaseInsert();
      expect(row['counted_qty'], equals(8));

      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String()
        ..['version'] = 1;

      final restored = StocktakeItem.fromSupabase(fullRow);
      expect(restored.countedQty, equals(8));
      expect(restored.isCounted, isTrue);
    });

    test('toSupabaseInsert: stocktake_id wird nicht geschrieben wenn null', () {
      final item = makeBase(stocktakeId: null);
      expect(item.toSupabaseInsert().containsKey('stocktake_id'), isFalse);
    });

    test('toSupabaseInsert: stocktake_id wird geschrieben wenn non-null', () {
      final item = makeBase(stocktakeId: 42);
      expect(item.toSupabaseInsert()['stocktake_id'], equals(42));
    });

    test('fromSupabase: stocktake_id als int aus DB (BIGINT)', () {
      final row = {
        'id': 'uuid-1',
        'workspace_id': 'ws',
        'stocktake_id': 99,
        'product_id': 'prod-1',
        'expected_qty': 5,
        'counted_qty': null,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'version': 1,
      };
      final restored = StocktakeItem.fromSupabase(row);
      expect(restored.stocktakeId, equals(99));
      expect(restored.stocktakeId, isA<int>());
    });

    test('fromSupabase: version fehlt → Default 1', () {
      final row = {
        'id': 'uuid-1',
        'workspace_id': 'ws',
        'product_id': 'prod-1',
        'expected_qty': 5,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
      };
      expect(StocktakeItem.fromSupabase(row).version, equals(1));
    });

    test('fromSupabase: expected_qty fehlt → Default 0', () {
      final row = {
        'id': 'uuid-1',
        'workspace_id': 'ws',
        'product_id': 'prod-1',
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'version': 1,
      };
      expect(StocktakeItem.fromSupabase(row).expectedQty, equals(0));
    });
  });

  // ── Berechnete Getter ─────────────────────────────────────────────────────

  group('StocktakeItem Getter', () {
    test('isCounted: false wenn counted_qty null', () {
      expect(makeBase(countedQty: null).isCounted, isFalse);
    });

    test('isCounted: true wenn counted_qty gesetzt', () {
      expect(makeBase(countedQty: 5).isCounted, isTrue);
    });

    test('isCounted: true auch bei counted_qty == 0', () {
      expect(makeBase(countedQty: 0).isCounted, isTrue);
    });

    test('difference: null wenn noch nicht gezählt', () {
      expect(makeBase(expectedQty: 10, countedQty: null).difference, isNull);
    });

    test('difference: 0 wenn gezählt gleich erwartet', () {
      expect(makeBase(expectedQty: 10, countedQty: 10).difference, equals(0));
    });

    test('difference: negativ wenn weniger gezählt als erwartet (Schwund)', () {
      expect(makeBase(expectedQty: 10, countedQty: 7).difference, equals(-3));
    });

    test('difference: positiv wenn mehr gezählt als erwartet (Überschuss)', () {
      expect(makeBase(expectedQty: 10, countedQty: 13).difference, equals(3));
    });
  });

  // ── copyWith ─────────────────────────────────────────────────────────────

  group('StocktakeItem.copyWith', () {
    test('copyWith ohne Argumente ist identisch zum Original', () {
      final original = makeBase(countedQty: 5);
      final copy = original.copyWith();
      expect(copy.id, equals(original.id));
      expect(copy.workspaceId, equals(original.workspaceId));
      expect(copy.stocktakeId, equals(original.stocktakeId));
      expect(copy.productId, equals(original.productId));
      expect(copy.expectedQty, equals(original.expectedQty));
      expect(copy.countedQty, equals(original.countedQty));
    });

    test('copyWith setzt counted_qty auf neuen Wert', () {
      final original = makeBase(countedQty: null);
      final copy = original.copyWith(countedQty: 8);
      expect(copy.countedQty, equals(8));
    });

    test('copyWith kann counted_qty explizit auf null setzen (Sentinel)', () {
      final original = makeBase(countedQty: 5);
      final copy = original.copyWith(countedQty: null);
      expect(copy.countedQty, isNull);
    });

    test('copyWith setzt expected_qty', () {
      final original = makeBase(expectedQty: 10);
      final copy = original.copyWith(expectedQty: 20);
      expect(copy.expectedQty, equals(20));
      expect(original.expectedQty, equals(10));
    });

    test('copyWith kann stocktake_id auf null setzen (Sentinel)', () {
      final original = makeBase(stocktakeId: 7);
      final copy = original.copyWith(stocktakeId: null);
      expect(copy.stocktakeId, isNull);
    });

    test('copyWith ändert version', () {
      final original = makeBase();
      final copy = original.copyWith(version: 3);
      expect(copy.version, equals(3));
      expect(original.version, equals(1));
    });
  });
}
