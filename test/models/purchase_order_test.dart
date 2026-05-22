import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/purchase_order.dart';

void main() {
  // ── Hilfsfunktionen ───────────────────────────────────────────────────────

  final baseCreatedAt = DateTime.utc(2026, 5, 22, 8, 0, 0);
  final baseUpdatedAt = DateTime.utc(2026, 5, 22, 9, 0, 0);

  PurchaseOrder makeBase({
    int? id = 42,
    String? supplierId,
    PurchaseOrderStatus status = PurchaseOrderStatus.draft,
    DateTime? orderDate,
    DateTime? expectedDate,
    String? note,
    double? totalNet,
    String? updatedBy,
    DateTime? deletedAt,
  }) =>
      PurchaseOrder(
        id: id,
        workspaceId: 'ws-id-1',
        userId: 'user-id-1',
        supplierId: supplierId,
        orderNumber: 'PO-2026-0001',
        status: status,
        orderDate: orderDate,
        expectedDate: expectedDate,
        note: note,
        totalNet: totalNet,
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
        updatedBy: updatedBy,
        version: 1,
        deletedAt: deletedAt,
      );

  // ── PurchaseOrderStatus Enum-Mapping ───────────────────────────────────────

  group('PurchaseOrderStatus Enum-Mapping', () {
    const allValues = {
      'draft': PurchaseOrderStatus.draft,
      'ordered': PurchaseOrderStatus.ordered,
      'partially_received': PurchaseOrderStatus.partiallyReceived,
      'received': PurchaseOrderStatus.received,
      'cancelled': PurchaseOrderStatus.cancelled,
    };

    test('fromDbValue liefert korrekten Enum-Wert für alle 5 DB-Strings', () {
      for (final entry in allValues.entries) {
        expect(
          PurchaseOrderStatus.fromDbValue(entry.key),
          equals(entry.value),
          reason: 'fromDbValue("${entry.key}") sollte ${entry.value} sein',
        );
      }
    });

    test('dbValue liefert korrekten DB-String für alle 5 Enum-Werte', () {
      for (final entry in allValues.entries) {
        expect(
          entry.value.dbValue,
          equals(entry.key),
          reason: '${entry.value}.dbValue sollte "${entry.key}" sein',
        );
      }
    });

    test('fromDbValue/dbValue-Symmetrie: Round-Trip für alle Werte', () {
      for (final status in PurchaseOrderStatus.values) {
        expect(
          PurchaseOrderStatus.fromDbValue(status.dbValue),
          equals(status),
          reason: 'Round-Trip für $status ist nicht symmetrisch',
        );
      }
    });

    test('fromDbValue mit unbekanntem String fällt auf draft zurück', () {
      expect(
        PurchaseOrderStatus.fromDbValue('unknown_status'),
        equals(PurchaseOrderStatus.draft),
      );
    });

    test('fromDbValue mit leerem String fällt auf draft zurück', () {
      expect(
        PurchaseOrderStatus.fromDbValue(''),
        equals(PurchaseOrderStatus.draft),
      );
    });
  });

  // ── toSupabaseInsert / fromSupabase Round-Trip ─────────────────────────────

  group('PurchaseOrder Supabase Round-Trip', () {
    test('Round-Trip: alle nullable Felder null, id non-null', () {
      final original = makeBase();
      final row = original.toSupabaseInsert();

      expect(row['id'], equals(42));
      expect(row['workspace_id'], equals('ws-id-1'));
      expect(row['user_id'], equals('user-id-1'));
      expect(row['order_number'], equals('PO-2026-0001'));
      expect(row['status'], equals('draft'));
      expect(row['supplier_id'], isNull);
      expect(row['order_date'], isNull);
      expect(row['expected_date'], isNull);
      expect(row['note'], isNull);
      expect(row['total_net'], isNull);

      // Timestamps nicht vom Client gesetzt (Trigger)
      expect(row.containsKey('created_at'), isFalse);
      expect(row.containsKey('updated_at'), isFalse);

      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String()
        ..['version'] = 1;

      final restored = PurchaseOrder.fromSupabase(fullRow);
      expect(restored.id, equals(42));
      expect(restored.workspaceId, equals('ws-id-1'));
      expect(restored.userId, equals('user-id-1'));
      expect(restored.orderNumber, equals('PO-2026-0001'));
      expect(restored.status, equals(PurchaseOrderStatus.draft));
      expect(restored.supplierId, isNull);
      expect(restored.orderDate, isNull);
      expect(restored.expectedDate, isNull);
      expect(restored.note, isNull);
      expect(restored.totalNet, isNull);
      expect(restored.deletedAt, isNull);
      expect(restored.createdAt, equals(baseCreatedAt));
      expect(restored.updatedAt, equals(baseUpdatedAt));
    });

    test('Round-Trip: alle nullable Felder gesetzt', () {
      final orderDate = DateTime.utc(2026, 5, 10);
      final expectedDate = DateTime.utc(2026, 5, 20);
      final original = makeBase(
        supplierId: 'sup-uuid-1',
        status: PurchaseOrderStatus.ordered,
        orderDate: orderDate,
        expectedDate: expectedDate,
        note: 'Eilbestellung',
        totalNet: 199.50,
        updatedBy: 'user-id-1',
      );
      final row = original.toSupabaseInsert();

      expect(row['supplier_id'], equals('sup-uuid-1'));
      expect(row['status'], equals('ordered'));
      expect(row['order_date'], equals(orderDate.toIso8601String()));
      expect(row['expected_date'], equals(expectedDate.toIso8601String()));
      expect(row['note'], equals('Eilbestellung'));
      expect(row['total_net'], equals(199.50));

      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String()
        ..['version'] = 1;

      final restored = PurchaseOrder.fromSupabase(fullRow);
      expect(restored.supplierId, equals('sup-uuid-1'));
      expect(restored.status, equals(PurchaseOrderStatus.ordered));
      expect(restored.orderDate, equals(orderDate));
      expect(restored.expectedDate, equals(expectedDate));
      expect(restored.note, equals('Eilbestellung'));
      expect(restored.totalNet, equals(199.50));
    });

    test('Round-Trip für jeden Status-Enum-Wert', () {
      for (final status in PurchaseOrderStatus.values) {
        final original = makeBase(status: status);
        final row = original.toSupabaseInsert();
        final fullRow = Map<String, dynamic>.from(row)
          ..['created_at'] = baseCreatedAt.toIso8601String()
          ..['updated_at'] = baseUpdatedAt.toIso8601String()
          ..['version'] = 1;
        final restored = PurchaseOrder.fromSupabase(fullRow);
        expect(
          restored.status,
          equals(status),
          reason: 'Status $status überlebt den Round-Trip nicht',
        );
      }
    });

    test('fromSupabase liest totalNet als num und wandelt in double um', () {
      final row = {
        'id': 7,
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'order_number': 'PO-X',
        'status': 'draft',
        'total_net': 100, // int aus DB
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'version': 1,
      };
      final restored = PurchaseOrder.fromSupabase(row);
      expect(restored.totalNet, equals(100.0));
      expect(restored.totalNet, isA<double>());
    });

    test('fromSupabase: status fehlt / null → Default draft', () {
      final row = {
        'id': 8,
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'order_number': 'PO-NULL',
        'status': null,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'version': 1,
      };
      final restored = PurchaseOrder.fromSupabase(row);
      expect(restored.status, equals(PurchaseOrderStatus.draft));
    });

    test('fromSupabase: version fehlt → Default 1', () {
      final row = {
        'id': 9,
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'order_number': 'PO-VER',
        'status': 'draft',
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
      };
      final restored = PurchaseOrder.fromSupabase(row);
      expect(restored.version, equals(1));
    });

    test('fromSupabase liest deletedAt korrekt', () {
      final deletedAt = DateTime.utc(2026, 5, 23, 12, 0, 0);
      final row = {
        'id': 10,
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'order_number': 'PO-DEL',
        'status': 'cancelled',
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'deleted_at': deletedAt.toIso8601String(),
        'version': 1,
      };
      final restored = PurchaseOrder.fromSupabase(row);
      expect(restored.deletedAt, equals(deletedAt));
    });

    test('toSupabaseInsert: id wird nicht geschrieben wenn null', () {
      final po = makeBase(id: null);
      expect(po.toSupabaseInsert().containsKey('id'), isFalse);
    });

    test('toSupabaseInsert: id wird geschrieben wenn non-null', () {
      final po = makeBase(id: 99);
      expect(po.toSupabaseInsert()['id'], equals(99));
    });

    test('fromSupabase: id als int aus DB (BIGSERIAL)', () {
      final row = {
        'id': 12345,
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'order_number': 'PO-INT',
        'status': 'draft',
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'version': 1,
      };
      final restored = PurchaseOrder.fromSupabase(row);
      expect(restored.id, equals(12345));
      expect(restored.id, isA<int>());
    });
  });

  // ── Konstruktor-Defaults ───────────────────────────────────────────────────

  group('PurchaseOrder Konstruktor-Defaults', () {
    test('status Default ist draft, version Default ist 1, id Default ist null',
        () {
      final po = PurchaseOrder(
        workspaceId: 'ws',
        userId: 'u',
        orderNumber: 'PO-DEF',
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
      );
      expect(po.id, isNull);
      expect(po.status, equals(PurchaseOrderStatus.draft));
      expect(po.version, equals(1));
      expect(po.supplierId, isNull);
      expect(po.orderDate, isNull);
      expect(po.expectedDate, isNull);
      expect(po.note, isNull);
      expect(po.totalNet, isNull);
      expect(po.updatedBy, isNull);
      expect(po.deletedAt, isNull);
    });
  });

  // ── copyWith ──────────────────────────────────────────────────────────────

  group('PurchaseOrder.copyWith', () {
    test('copyWith ohne Argumente ist identisch zum Original', () {
      final original = makeBase(
        supplierId: 'sup-1',
        status: PurchaseOrderStatus.ordered,
        totalNet: 50.0,
      );
      final copy = original.copyWith();
      expect(copy.id, equals(original.id));
      expect(copy.workspaceId, equals(original.workspaceId));
      expect(copy.supplierId, equals(original.supplierId));
      expect(copy.status, equals(original.status));
      expect(copy.totalNet, equals(original.totalNet));
      expect(copy.orderNumber, equals(original.orderNumber));
    });

    test('copyWith ändert orderNumber', () {
      final original = makeBase();
      final copy = original.copyWith(orderNumber: 'PO-9999');
      expect(copy.orderNumber, equals('PO-9999'));
      expect(original.orderNumber, equals('PO-2026-0001'));
    });

    test('copyWith ändert status', () {
      final original = makeBase(status: PurchaseOrderStatus.draft);
      final copy = original.copyWith(status: PurchaseOrderStatus.received);
      expect(copy.status, equals(PurchaseOrderStatus.received));
      expect(original.status, equals(PurchaseOrderStatus.draft));
    });

    test('copyWith setzt supplierId auf neuen Wert', () {
      final original = makeBase();
      final copy = original.copyWith(supplierId: 'new-sup');
      expect(copy.supplierId, equals('new-sup'));
    });

    test('copyWith kann supplierId explizit auf null setzen (Sentinel)', () {
      final original = makeBase(supplierId: 'old-sup');
      final copy = original.copyWith(supplierId: null);
      expect(copy.supplierId, isNull);
    });

    test('copyWith lässt supplierId unverändert wenn nicht übergeben', () {
      final original = makeBase(supplierId: 'keep-sup');
      final copy = original.copyWith(orderNumber: 'PO-X');
      expect(copy.supplierId, equals('keep-sup'));
    });

    test('copyWith setzt totalNet auf neuen Wert', () {
      final original = makeBase();
      final copy = original.copyWith(totalNet: 999.99);
      expect(copy.totalNet, equals(999.99));
    });

    test('copyWith kann totalNet explizit auf null setzen (Sentinel)', () {
      final original = makeBase(totalNet: 100.0);
      final copy = original.copyWith(totalNet: null);
      expect(copy.totalNet, isNull);
    });

    test('copyWith setzt orderDate auf neuen Wert', () {
      final original = makeBase();
      final newDate = DateTime.utc(2026, 6, 1);
      final copy = original.copyWith(orderDate: newDate);
      expect(copy.orderDate, equals(newDate));
    });

    test('copyWith kann orderDate explizit auf null setzen (Sentinel)', () {
      final original = makeBase(orderDate: DateTime.utc(2026, 5, 1));
      final copy = original.copyWith(orderDate: null);
      expect(copy.orderDate, isNull);
    });

    test('copyWith kann expectedDate explizit auf null setzen (Sentinel)', () {
      final original = makeBase(expectedDate: DateTime.utc(2026, 5, 30));
      final copy = original.copyWith(expectedDate: null);
      expect(copy.expectedDate, isNull);
    });

    test('copyWith kann note explizit auf null setzen (Sentinel)', () {
      final original = makeBase(note: 'notiz');
      final copy = original.copyWith(note: null);
      expect(copy.note, isNull);
    });

    test('copyWith kann id explizit auf null setzen (Sentinel)', () {
      final original = makeBase(id: 5);
      final copy = original.copyWith(id: null);
      expect(copy.id, isNull);
    });

    test('copyWith kann id setzen', () {
      final original = makeBase(id: null);
      final copy = original.copyWith(id: 77);
      expect(copy.id, equals(77));
    });

    test('copyWith kann deletedAt setzen', () {
      final original = makeBase();
      final deletedAt = DateTime.utc(2026, 5, 25, 10, 0, 0);
      final copy = original.copyWith(deletedAt: deletedAt);
      expect(copy.deletedAt, equals(deletedAt));
    });

    test('copyWith kann deletedAt explizit auf null setzen (Sentinel)', () {
      final deletedAt = DateTime.utc(2026, 5, 25);
      final original = PurchaseOrder(
        id: 1,
        workspaceId: 'ws',
        userId: 'u',
        orderNumber: 'PO-DEL',
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
        deletedAt: deletedAt,
      );
      final copy = original.copyWith(deletedAt: null);
      expect(copy.deletedAt, isNull);
    });

    test('copyWith ändert version', () {
      final original = makeBase();
      final copy = original.copyWith(version: 3);
      expect(copy.version, equals(3));
      expect(original.version, equals(1));
    });
  });
}
