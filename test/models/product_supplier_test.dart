import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/product_supplier.dart';

void main() {
  // ── Hilfsfunktionen ────────────────────────────────────────────────────────

  final baseCreatedAt = DateTime.utc(2026, 5, 20, 10, 0, 0);
  final baseUpdatedAt = DateTime.utc(2026, 5, 20, 11, 0, 0);

  ProductSupplier makeBase({
    String? supplierSku,
    double? supplierPrice,
    bool isPreferred = false,
    DateTime? deletedAt,
  }) =>
      ProductSupplier(
        id: 'ps-id-1',
        workspaceId: 'ws-id-1',
        userId: 'user-id-1',
        productId: 'prod-id-1',
        supplierId: 'sup-id-1',
        supplierSku: supplierSku,
        supplierPrice: supplierPrice,
        isPreferred: isPreferred,
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
        deletedAt: deletedAt,
      );

  // ── toSupabaseInsert / fromSupabase Round-Trip ──────────────────────────────

  group('ProductSupplier Supabase Round-Trip', () {
    test('Round-Trip: alle nullable Felder null', () {
      final original = makeBase();
      final row = original.toSupabaseInsert();

      // Pflichtfelder
      expect(row['id'], equals('ps-id-1'));
      expect(row['workspace_id'], equals('ws-id-1'));
      expect(row['user_id'], equals('user-id-1'));
      expect(row['product_id'], equals('prod-id-1'));
      expect(row['supplier_id'], equals('sup-id-1'));
      expect(row['is_preferred'], isFalse);

      // Nullable Felder sind null (aber im Map vorhanden)
      expect(row['supplier_sku'], isNull);
      expect(row['supplier_price'], isNull);

      // Timestamps werden NICHT vom Client geschrieben
      expect(row.containsKey('created_at'), isFalse);
      expect(row.containsKey('updated_at'), isFalse);

      // fromSupabase: Timestamps simulieren
      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String();

      final restored = ProductSupplier.fromSupabase(fullRow);
      expect(restored.id, equals(original.id));
      expect(restored.workspaceId, equals(original.workspaceId));
      expect(restored.userId, equals(original.userId));
      expect(restored.productId, equals(original.productId));
      expect(restored.supplierId, equals(original.supplierId));
      expect(restored.supplierSku, isNull);
      expect(restored.supplierPrice, isNull);
      expect(restored.isPreferred, isFalse);
      expect(restored.deletedAt, isNull);
      expect(restored.createdAt, equals(baseCreatedAt));
      expect(restored.updatedAt, equals(baseUpdatedAt));
    });

    test('Round-Trip: alle nullable Felder gesetzt', () {
      final original = makeBase(
        supplierSku: 'SUP-SKU-123',
        supplierPrice: 7.50,
        isPreferred: true,
      );
      final row = original.toSupabaseInsert();

      expect(row['supplier_sku'], equals('SUP-SKU-123'));
      expect(row['supplier_price'], equals(7.50));
      expect(row['is_preferred'], isTrue);

      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String();

      final restored = ProductSupplier.fromSupabase(fullRow);
      expect(restored.supplierSku, equals('SUP-SKU-123'));
      expect(restored.supplierPrice, equals(7.50));
      expect(restored.isPreferred, isTrue);
    });

    test('fromSupabase liest supplierPrice als num und wandelt in double um', () {
      final row = {
        'id': 'ps-id-2',
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'product_id': 'prod-id-1',
        'supplier_id': 'sup-id-1',
        'supplier_price': 5, // int aus DB
        'is_preferred': false,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'deleted_at': null,
      };
      final restored = ProductSupplier.fromSupabase(row);
      expect(restored.supplierPrice, equals(5.0));
      expect(restored.supplierPrice, isA<double>());
    });

    test('fromSupabase: is_preferred fehlt → Default false', () {
      final row = {
        'id': 'ps-id-3',
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'product_id': 'prod-id-1',
        'supplier_id': 'sup-id-1',
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'deleted_at': null,
      };
      final restored = ProductSupplier.fromSupabase(row);
      expect(restored.isPreferred, isFalse);
    });

    test('fromSupabase liest deletedAt korrekt', () {
      final deletedAt = DateTime.utc(2026, 5, 21, 9, 0, 0);
      final row = {
        'id': 'ps-id-4',
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'product_id': 'prod-id-1',
        'supplier_id': 'sup-id-1',
        'is_preferred': false,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'deleted_at': deletedAt.toIso8601String(),
      };
      final restored = ProductSupplier.fromSupabase(row);
      expect(restored.deletedAt, equals(deletedAt));
    });

    test('toSupabaseInsert: id wird nur geschrieben wenn non-empty', () {
      final withId = makeBase();
      expect(withId.toSupabaseInsert().containsKey('id'), isTrue);

      final withoutId = ProductSupplier(
        id: '',
        workspaceId: 'ws-id-1',
        userId: 'user-id-1',
        productId: 'prod-id-1',
        supplierId: 'sup-id-1',
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
      );
      expect(withoutId.toSupabaseInsert().containsKey('id'), isFalse);
    });
  });

  // ── copyWith ───────────────────────────────────────────────────────────────

  group('ProductSupplier.copyWith', () {
    test('copyWith ohne Argumente ist identisch', () {
      final original = makeBase(supplierSku: 'SKU-X', supplierPrice: 5.0);
      final copy = original.copyWith();
      expect(copy.id, equals(original.id));
      expect(copy.productId, equals(original.productId));
      expect(copy.supplierId, equals(original.supplierId));
      expect(copy.supplierSku, equals(original.supplierSku));
      expect(copy.supplierPrice, equals(original.supplierPrice));
      expect(copy.isPreferred, equals(original.isPreferred));
    });

    test('copyWith ändert supplierId', () {
      final original = makeBase();
      final copy = original.copyWith(supplierId: 'new-sup-id');
      expect(copy.supplierId, equals('new-sup-id'));
      expect(original.supplierId, equals('sup-id-1'));
    });

    test('copyWith setzt supplierSku auf neuen Wert', () {
      final original = makeBase();
      final copy = original.copyWith(supplierSku: 'NEW-SKU');
      expect(copy.supplierSku, equals('NEW-SKU'));
    });

    test('copyWith kann supplierSku explizit auf null setzen (Sentinel)', () {
      final original = makeBase(supplierSku: 'OLD-SKU');
      final copy = original.copyWith(supplierSku: null);
      expect(copy.supplierSku, isNull);
    });

    test('copyWith lässt supplierSku unverändert wenn nicht übergeben', () {
      final original = makeBase(supplierSku: 'KEEP-SKU');
      final copy = original.copyWith(isPreferred: true);
      expect(copy.supplierSku, equals('KEEP-SKU'));
    });

    test('copyWith setzt supplierPrice auf neuen Wert', () {
      final original = makeBase();
      final copy = original.copyWith(supplierPrice: 99.99);
      expect(copy.supplierPrice, equals(99.99));
    });

    test('copyWith kann supplierPrice explizit auf null setzen (Sentinel)', () {
      final original = makeBase(supplierPrice: 10.0);
      final copy = original.copyWith(supplierPrice: null);
      expect(copy.supplierPrice, isNull);
    });

    test('copyWith lässt supplierPrice unverändert wenn nicht übergeben', () {
      final original = makeBase(supplierPrice: 3.14);
      final copy = original.copyWith(supplierSku: 'X');
      expect(copy.supplierPrice, equals(3.14));
    });

    test('copyWith ändert isPreferred', () {
      final original = makeBase(isPreferred: false);
      final copy = original.copyWith(isPreferred: true);
      expect(copy.isPreferred, isTrue);
      expect(original.isPreferred, isFalse);
    });

    test('copyWith kann deletedAt setzen', () {
      final original = makeBase();
      final deletedAt = DateTime.utc(2026, 5, 22, 8, 0, 0);
      final copy = original.copyWith(deletedAt: deletedAt);
      expect(copy.deletedAt, equals(deletedAt));
    });

    test('copyWith kann deletedAt explizit auf null setzen (Sentinel)', () {
      final deletedAt = DateTime.utc(2026, 5, 22, 8, 0, 0);
      final original = ProductSupplier(
        id: 'ps-id-1',
        workspaceId: 'ws-id-1',
        userId: 'user-id-1',
        productId: 'prod-id-1',
        supplierId: 'sup-id-1',
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
        deletedAt: deletedAt,
      );
      final copy = original.copyWith(deletedAt: null);
      expect(copy.deletedAt, isNull);
    });
  });

  // ── Konstruktor-Defaults ───────────────────────────────────────────────────

  group('ProductSupplier Konstruktor-Defaults', () {
    test('isPreferred Default ist false, supplierSku/Price/deletedAt sind null',
        () {
      final ps = ProductSupplier(
        id: 'x',
        workspaceId: 'ws',
        userId: 'u',
        productId: 'p',
        supplierId: 's',
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
      );
      expect(ps.isPreferred, isFalse);
      expect(ps.supplierSku, isNull);
      expect(ps.supplierPrice, isNull);
      expect(ps.deletedAt, isNull);
    });
  });
}
