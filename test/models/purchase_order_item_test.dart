import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/purchase_order_item.dart';

void main() {
  // ── Hilfsfunktionen ───────────────────────────────────────────────────────

  final baseCreatedAt = DateTime.utc(2026, 5, 22, 8, 0, 0);
  final baseUpdatedAt = DateTime.utc(2026, 5, 22, 9, 0, 0);

  PurchaseOrderItem makeBase({
    String id = 'item-uuid-1',
    int? purchaseOrderId = 42,
    String? productId,
    int quantityOrdered = 10,
    int quantityReceived = 0,
    double? unitPrice,
    String? updatedBy,
    DateTime? deletedAt,
  }) =>
      PurchaseOrderItem(
        id: id,
        workspaceId: 'ws-id-1',
        purchaseOrderId: purchaseOrderId,
        productId: productId,
        quantityOrdered: quantityOrdered,
        quantityReceived: quantityReceived,
        unitPrice: unitPrice,
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
        updatedBy: updatedBy,
        version: 1,
        deletedAt: deletedAt,
      );

  // ── toSupabaseInsert / fromSupabase Round-Trip ─────────────────────────────

  group('PurchaseOrderItem Supabase Round-Trip', () {
    test('Round-Trip: nullable Felder null, purchaseOrderId non-null', () {
      final original = makeBase();
      final row = original.toSupabaseInsert();

      expect(row['id'], equals('item-uuid-1'));
      expect(row['workspace_id'], equals('ws-id-1'));
      expect(row['purchase_order_id'], equals(42));
      expect(row['product_id'], isNull);
      expect(row['quantity_ordered'], equals(10));
      expect(row['quantity_received'], equals(0));
      expect(row['unit_price'], isNull);

      // Timestamps nicht vom Client gesetzt (Trigger)
      expect(row.containsKey('created_at'), isFalse);
      expect(row.containsKey('updated_at'), isFalse);

      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String()
        ..['version'] = 1;

      final restored = PurchaseOrderItem.fromSupabase(fullRow);
      expect(restored.id, equals('item-uuid-1'));
      expect(restored.workspaceId, equals('ws-id-1'));
      expect(restored.purchaseOrderId, equals(42));
      expect(restored.productId, isNull);
      expect(restored.quantityOrdered, equals(10));
      expect(restored.quantityReceived, equals(0));
      expect(restored.unitPrice, isNull);
      expect(restored.deletedAt, isNull);
      expect(restored.createdAt, equals(baseCreatedAt));
      expect(restored.updatedAt, equals(baseUpdatedAt));
    });

    test('Round-Trip: alle nullable Felder gesetzt', () {
      final original = makeBase(
        productId: 'prod-uuid-1',
        quantityOrdered: 20,
        quantityReceived: 5,
        unitPrice: 12.50,
        updatedBy: 'user-id-1',
      );
      final row = original.toSupabaseInsert();

      expect(row['product_id'], equals('prod-uuid-1'));
      expect(row['quantity_ordered'], equals(20));
      expect(row['quantity_received'], equals(5));
      expect(row['unit_price'], equals(12.50));

      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String()
        ..['updated_by'] = 'user-id-1'
        ..['version'] = 1;

      final restored = PurchaseOrderItem.fromSupabase(fullRow);
      expect(restored.productId, equals('prod-uuid-1'));
      expect(restored.quantityOrdered, equals(20));
      expect(restored.quantityReceived, equals(5));
      expect(restored.unitPrice, equals(12.50));
      expect(restored.updatedBy, equals('user-id-1'));
    });

    test('fromSupabase liest unitPrice als num und wandelt in double um', () {
      final row = {
        'id': 'item-num-1',
        'workspace_id': 'ws-id-1',
        'purchase_order_id': 3,
        'quantity_ordered': 5,
        'quantity_received': 0,
        'unit_price': 8, // int aus DB
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'version': 1,
      };
      final restored = PurchaseOrderItem.fromSupabase(row);
      expect(restored.unitPrice, equals(8.0));
      expect(restored.unitPrice, isA<double>());
    });

    test('fromSupabase: purchaseOrderId als BIGINT (large int)', () {
      final row = {
        'id': 'item-bigint-1',
        'workspace_id': 'ws-id-1',
        'purchase_order_id': 9999999999,
        'quantity_ordered': 1,
        'quantity_received': 0,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'version': 1,
      };
      final restored = PurchaseOrderItem.fromSupabase(row);
      expect(restored.purchaseOrderId, equals(9999999999));
      expect(restored.purchaseOrderId, isA<int>());
    });

    test('fromSupabase: quantity_ordered fehlt → Default 0', () {
      final row = {
        'id': 'item-qty-1',
        'workspace_id': 'ws-id-1',
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'version': 1,
      };
      final restored = PurchaseOrderItem.fromSupabase(row);
      expect(restored.quantityOrdered, equals(0));
      expect(restored.quantityReceived, equals(0));
    });

    test('fromSupabase: version fehlt → Default 1', () {
      final row = {
        'id': 'item-ver-1',
        'workspace_id': 'ws-id-1',
        'quantity_ordered': 3,
        'quantity_received': 0,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
      };
      final restored = PurchaseOrderItem.fromSupabase(row);
      expect(restored.version, equals(1));
    });

    test('fromSupabase liest deletedAt korrekt', () {
      final deletedAt = DateTime.utc(2026, 5, 24, 15, 0, 0);
      final row = {
        'id': 'item-del-1',
        'workspace_id': 'ws-id-1',
        'quantity_ordered': 2,
        'quantity_received': 0,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'deleted_at': deletedAt.toIso8601String(),
        'version': 1,
      };
      final restored = PurchaseOrderItem.fromSupabase(row);
      expect(restored.deletedAt, equals(deletedAt));
    });

    test('toSupabaseInsert: purchaseOrderId nicht geschrieben wenn null', () {
      final item = makeBase(purchaseOrderId: null);
      expect(item.toSupabaseInsert().containsKey('purchase_order_id'), isFalse);
    });

    test('toSupabaseInsert: purchaseOrderId geschrieben wenn non-null', () {
      final item = makeBase(purchaseOrderId: 7);
      expect(item.toSupabaseInsert()['purchase_order_id'], equals(7));
    });

    test('toSupabaseInsert: id wird immer geschrieben', () {
      final item = makeBase(id: 'my-uuid');
      expect(item.toSupabaseInsert()['id'], equals('my-uuid'));
    });
  });

  // ── Konstruktor-Defaults ───────────────────────────────────────────────────

  group('PurchaseOrderItem Konstruktor-Defaults', () {
    test(
        'quantityReceived Default ist 0, version Default ist 1, '
        'purchaseOrderId Default ist null', () {
      final item = PurchaseOrderItem(
        id: 'x',
        workspaceId: 'ws',
        quantityOrdered: 5,
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
      );
      expect(item.quantityReceived, equals(0));
      expect(item.version, equals(1));
      expect(item.purchaseOrderId, isNull);
      expect(item.productId, isNull);
      expect(item.unitPrice, isNull);
      expect(item.updatedBy, isNull);
      expect(item.deletedAt, isNull);
    });
  });

  // ── copyWith ──────────────────────────────────────────────────────────────

  group('PurchaseOrderItem.copyWith', () {
    test('copyWith ohne Argumente ist identisch zum Original', () {
      final original = makeBase(
        productId: 'prod-1',
        quantityOrdered: 15,
        quantityReceived: 3,
        unitPrice: 5.0,
      );
      final copy = original.copyWith();
      expect(copy.id, equals(original.id));
      expect(copy.workspaceId, equals(original.workspaceId));
      expect(copy.purchaseOrderId, equals(original.purchaseOrderId));
      expect(copy.productId, equals(original.productId));
      expect(copy.quantityOrdered, equals(original.quantityOrdered));
      expect(copy.quantityReceived, equals(original.quantityReceived));
      expect(copy.unitPrice, equals(original.unitPrice));
    });

    test('copyWith ändert quantityOrdered', () {
      final original = makeBase(quantityOrdered: 10);
      final copy = original.copyWith(quantityOrdered: 25);
      expect(copy.quantityOrdered, equals(25));
      expect(original.quantityOrdered, equals(10));
    });

    test('copyWith ändert quantityReceived', () {
      final original = makeBase(quantityReceived: 0);
      final copy = original.copyWith(quantityReceived: 7);
      expect(copy.quantityReceived, equals(7));
      expect(original.quantityReceived, equals(0));
    });

    test('copyWith setzt productId auf neuen Wert', () {
      final original = makeBase();
      final copy = original.copyWith(productId: 'new-prod-uuid');
      expect(copy.productId, equals('new-prod-uuid'));
    });

    test('copyWith kann productId explizit auf null setzen (Sentinel)', () {
      final original = makeBase(productId: 'some-prod');
      final copy = original.copyWith(productId: null);
      expect(copy.productId, isNull);
    });

    test('copyWith lässt productId unverändert wenn nicht übergeben', () {
      final original = makeBase(productId: 'keep-prod');
      final copy = original.copyWith(quantityOrdered: 5);
      expect(copy.productId, equals('keep-prod'));
    });

    test('copyWith setzt purchaseOrderId auf neuen Wert', () {
      final original = makeBase(purchaseOrderId: null);
      final copy = original.copyWith(purchaseOrderId: 99);
      expect(copy.purchaseOrderId, equals(99));
    });

    test('copyWith kann purchaseOrderId explizit auf null setzen (Sentinel)',
        () {
      final original = makeBase(purchaseOrderId: 10);
      final copy = original.copyWith(purchaseOrderId: null);
      expect(copy.purchaseOrderId, isNull);
    });

    test('copyWith setzt unitPrice auf neuen Wert', () {
      final original = makeBase();
      final copy = original.copyWith(unitPrice: 49.99);
      expect(copy.unitPrice, equals(49.99));
    });

    test('copyWith kann unitPrice explizit auf null setzen (Sentinel)', () {
      final original = makeBase(unitPrice: 20.0);
      final copy = original.copyWith(unitPrice: null);
      expect(copy.unitPrice, isNull);
    });

    test('copyWith lässt unitPrice unverändert wenn nicht übergeben', () {
      final original = makeBase(unitPrice: 3.14);
      final copy = original.copyWith(quantityOrdered: 1);
      expect(copy.unitPrice, equals(3.14));
    });

    test('copyWith kann deletedAt setzen', () {
      final original = makeBase();
      final deletedAt = DateTime.utc(2026, 5, 26, 10, 0, 0);
      final copy = original.copyWith(deletedAt: deletedAt);
      expect(copy.deletedAt, equals(deletedAt));
    });

    test('copyWith kann deletedAt explizit auf null setzen (Sentinel)', () {
      final deletedAt = DateTime.utc(2026, 5, 26);
      final original = PurchaseOrderItem(
        id: 'x',
        workspaceId: 'ws',
        quantityOrdered: 1,
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
        deletedAt: deletedAt,
      );
      final copy = original.copyWith(deletedAt: null);
      expect(copy.deletedAt, isNull);
    });

    test('copyWith ändert version', () {
      final original = makeBase();
      final copy = original.copyWith(version: 4);
      expect(copy.version, equals(4));
      expect(original.version, equals(1));
    });

    test('copyWith ändert id', () {
      final original = makeBase(id: 'old-uuid');
      final copy = original.copyWith(id: 'new-uuid');
      expect(copy.id, equals('new-uuid'));
      expect(original.id, equals('old-uuid'));
    });
  });
}
