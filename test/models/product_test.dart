import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/product.dart';

void main() {
  // ── Hilfsfunktionen ────────────────────────────────────────────────────────

  final baseCreatedAt = DateTime.utc(2026, 5, 20, 10, 0, 0);
  final baseUpdatedAt = DateTime.utc(2026, 5, 20, 11, 0, 0);

  Product makeBase({
    String? categoryId,
    String? defaultSupplierId,
    String? sku,
    String? ean,
    double? defaultCostPrice,
    double? defaultSalePrice,
    double? taxRate,
    String? note,
    DateTime? deletedAt,
  }) =>
      Product(
        id: 'prod-id-1',
        workspaceId: 'ws-id-1',
        userId: 'user-id-1',
        name: 'Testprodukt',
        sku: sku,
        ean: ean,
        categoryId: categoryId,
        defaultSupplierId: defaultSupplierId,
        unit: 'Stk',
        defaultCostPrice: defaultCostPrice,
        defaultSalePrice: defaultSalePrice,
        minStock: 5,
        taxRate: taxRate,
        note: note,
        isActive: true,
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
        deletedAt: deletedAt,
      );

  // ── toSupabaseInsert / fromSupabase Round-Trip ──────────────────────────────

  group('Product Supabase Round-Trip', () {
    test('Round-Trip: alle nullable Felder null', () {
      final original = makeBase();
      final row = original.toSupabaseInsert();

      // Pflichtfelder
      expect(row['id'], equals('prod-id-1'));
      expect(row['workspace_id'], equals('ws-id-1'));
      expect(row['user_id'], equals('user-id-1'));
      expect(row['name'], equals('Testprodukt'));
      expect(row['unit'], equals('Stk'));
      expect(row['min_stock'], equals(5));
      expect(row['is_active'], isTrue);

      // Nullable Felder sind null (aber im Map vorhanden)
      expect(row['sku'], isNull);
      expect(row['ean'], isNull);
      expect(row['category_id'], isNull);
      expect(row['default_supplier_id'], isNull);
      expect(row['default_cost_price'], isNull);
      expect(row['default_sale_price'], isNull);
      expect(row['tax_rate'], isNull);
      expect(row['note'], isNull);

      // Timestamps werden NICHT von Client geschrieben (DB-Default / Trigger)
      expect(row.containsKey('created_at'), isFalse);
      expect(row.containsKey('updated_at'), isFalse);

      // fromSupabase: Timestamps simulieren
      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String();

      final restored = Product.fromSupabase(fullRow);
      expect(restored.id, equals(original.id));
      expect(restored.workspaceId, equals(original.workspaceId));
      expect(restored.userId, equals(original.userId));
      expect(restored.name, equals(original.name));
      expect(restored.unit, equals('Stk'));
      expect(restored.minStock, equals(5));
      expect(restored.isActive, isTrue);
      expect(restored.sku, isNull);
      expect(restored.ean, isNull);
      expect(restored.categoryId, isNull);
      expect(restored.defaultSupplierId, isNull);
      expect(restored.defaultCostPrice, isNull);
      expect(restored.defaultSalePrice, isNull);
      expect(restored.taxRate, isNull);
      expect(restored.note, isNull);
      expect(restored.deletedAt, isNull);
      expect(restored.createdAt, equals(baseCreatedAt));
      expect(restored.updatedAt, equals(baseUpdatedAt));
    });

    test('Round-Trip: alle nullable Felder gesetzt', () {
      final original = makeBase(
        sku: 'SKU-001',
        ean: '1234567890123',
        categoryId: 'cat-id-1',
        defaultSupplierId: 'sup-id-1',
        defaultCostPrice: 9.99,
        defaultSalePrice: 19.99,
        taxRate: 19.0,
        note: 'Testnotiz',
      );
      final row = original.toSupabaseInsert();

      expect(row['sku'], equals('SKU-001'));
      expect(row['ean'], equals('1234567890123'));
      expect(row['category_id'], equals('cat-id-1'));
      expect(row['default_supplier_id'], equals('sup-id-1'));
      expect(row['default_cost_price'], equals(9.99));
      expect(row['default_sale_price'], equals(19.99));
      expect(row['tax_rate'], equals(19.0));
      expect(row['note'], equals('Testnotiz'));

      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String();

      final restored = Product.fromSupabase(fullRow);
      expect(restored.sku, equals('SKU-001'));
      expect(restored.ean, equals('1234567890123'));
      expect(restored.categoryId, equals('cat-id-1'));
      expect(restored.defaultSupplierId, equals('sup-id-1'));
      expect(restored.defaultCostPrice, equals(9.99));
      expect(restored.defaultSalePrice, equals(19.99));
      expect(restored.taxRate, equals(19.0));
      expect(restored.note, equals('Testnotiz'));
    });

    test('fromSupabase liest Preise als num und wandelt in double um', () {
      final row = {
        'id': 'prod-id-2',
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'name': 'NumTest',
        'unit': 'Stk',
        'min_stock': 0,
        'is_active': true,
        'default_cost_price': 5, // int aus DB
        'default_sale_price': 10, // int aus DB
        'tax_rate': 7, // int aus DB
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'deleted_at': null,
      };
      final restored = Product.fromSupabase(row);
      expect(restored.defaultCostPrice, equals(5.0));
      expect(restored.defaultCostPrice, isA<double>());
      expect(restored.defaultSalePrice, equals(10.0));
      expect(restored.taxRate, equals(7.0));
    });

    test('fromSupabase: min_stock fehlt → Default 0', () {
      final row = {
        'id': 'prod-id-3',
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'name': 'Ohne MinStock',
        'unit': 'kg',
        'is_active': true,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'deleted_at': null,
      };
      final restored = Product.fromSupabase(row);
      expect(restored.minStock, equals(0));
    });

    test('fromSupabase: unit fehlt → Default Stk', () {
      final row = {
        'id': 'prod-id-4',
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'name': 'Ohne Unit',
        'is_active': true,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'deleted_at': null,
      };
      final restored = Product.fromSupabase(row);
      expect(restored.unit, equals('Stk'));
    });

    test('fromSupabase: is_active fehlt → Default true', () {
      final row = {
        'id': 'prod-id-5',
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'name': 'Ohne IsActive',
        'unit': 'Stk',
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'deleted_at': null,
      };
      final restored = Product.fromSupabase(row);
      expect(restored.isActive, isTrue);
    });

    test('fromSupabase liest deletedAt korrekt', () {
      final deletedAt = DateTime.utc(2026, 5, 21, 9, 0, 0);
      final row = {
        'id': 'prod-id-6',
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'name': 'Gelöscht',
        'unit': 'Stk',
        'min_stock': 0,
        'is_active': false,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'deleted_at': deletedAt.toIso8601String(),
      };
      final restored = Product.fromSupabase(row);
      expect(restored.deletedAt, equals(deletedAt));
    });

    test('toSupabaseInsert: id wird nur geschrieben wenn non-empty', () {
      final withId = makeBase();
      expect(withId.toSupabaseInsert().containsKey('id'), isTrue);

      final withoutId = Product(
        id: '',
        workspaceId: 'ws-id-1',
        userId: 'user-id-1',
        name: 'Neu',
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
      );
      expect(withoutId.toSupabaseInsert().containsKey('id'), isFalse);
    });
  });

  // ── copyWith ───────────────────────────────────────────────────────────────

  group('Product.copyWith', () {
    test('copyWith ohne Argumente ist identisch', () {
      final original = makeBase(
        sku: 'SKU-X',
        categoryId: 'cat-id',
        defaultCostPrice: 5.0,
      );
      final copy = original.copyWith();
      expect(copy.id, equals(original.id));
      expect(copy.name, equals(original.name));
      expect(copy.sku, equals(original.sku));
      expect(copy.categoryId, equals(original.categoryId));
      expect(copy.defaultCostPrice, equals(original.defaultCostPrice));
      expect(copy.unit, equals(original.unit));
      expect(copy.minStock, equals(original.minStock));
      expect(copy.isActive, equals(original.isActive));
    });

    test('copyWith ändert name', () {
      final original = makeBase();
      final copy = original.copyWith(name: 'Neuer Name');
      expect(copy.name, equals('Neuer Name'));
      expect(original.name, equals('Testprodukt'));
    });

    test('copyWith ändert unit', () {
      final original = makeBase();
      final copy = original.copyWith(unit: 'kg');
      expect(copy.unit, equals('kg'));
      expect(original.unit, equals('Stk'));
    });

    test('copyWith setzt sku auf neuen Wert', () {
      final original = makeBase();
      final copy = original.copyWith(sku: 'NEW-SKU');
      expect(copy.sku, equals('NEW-SKU'));
    });

    test('copyWith kann sku explizit auf null setzen (Sentinel)', () {
      final original = makeBase(sku: 'OLD-SKU');
      final copy = original.copyWith(sku: null);
      expect(copy.sku, isNull);
    });

    test('copyWith lässt sku unverändert wenn nicht übergeben', () {
      final original = makeBase(sku: 'KEEP-SKU');
      final copy = original.copyWith(name: 'Anderer Name');
      expect(copy.sku, equals('KEEP-SKU'));
    });

    test('copyWith setzt categoryId auf neuen Wert', () {
      final original = makeBase();
      final copy = original.copyWith(categoryId: 'new-cat-id');
      expect(copy.categoryId, equals('new-cat-id'));
    });

    test('copyWith kann categoryId explizit auf null setzen (Sentinel)', () {
      final original = makeBase(categoryId: 'some-cat');
      final copy = original.copyWith(categoryId: null);
      expect(copy.categoryId, isNull);
    });

    test('copyWith setzt defaultSupplierId auf neuen Wert', () {
      final original = makeBase();
      final copy = original.copyWith(defaultSupplierId: 'sup-new');
      expect(copy.defaultSupplierId, equals('sup-new'));
    });

    test('copyWith kann defaultSupplierId explizit auf null setzen (Sentinel)',
        () {
      final original = makeBase(defaultSupplierId: 'sup-old');
      final copy = original.copyWith(defaultSupplierId: null);
      expect(copy.defaultSupplierId, isNull);
    });

    test('copyWith setzt defaultCostPrice auf neuen Wert', () {
      final original = makeBase();
      final copy = original.copyWith(defaultCostPrice: 42.0);
      expect(copy.defaultCostPrice, equals(42.0));
    });

    test('copyWith kann defaultCostPrice explizit auf null setzen (Sentinel)',
        () {
      final original = makeBase(defaultCostPrice: 10.0);
      final copy = original.copyWith(defaultCostPrice: null);
      expect(copy.defaultCostPrice, isNull);
    });

    test('copyWith kann taxRate explizit auf null setzen (Sentinel)', () {
      final original = makeBase(taxRate: 19.0);
      final copy = original.copyWith(taxRate: null);
      expect(copy.taxRate, isNull);
    });

    test('copyWith kann note explizit auf null setzen (Sentinel)', () {
      final original = makeBase(note: 'notiz');
      final copy = original.copyWith(note: null);
      expect(copy.note, isNull);
    });

    test('copyWith ändert minStock', () {
      final original = makeBase();
      final copy = original.copyWith(minStock: 20);
      expect(copy.minStock, equals(20));
      expect(original.minStock, equals(5));
    });

    test('copyWith ändert isActive', () {
      final original = makeBase();
      expect(original.isActive, isTrue);
      final copy = original.copyWith(isActive: false);
      expect(copy.isActive, isFalse);
    });

    test('copyWith kann deletedAt setzen', () {
      final original = makeBase();
      final deletedAt = DateTime.utc(2026, 5, 22, 8, 0, 0);
      final copy = original.copyWith(deletedAt: deletedAt);
      expect(copy.deletedAt, equals(deletedAt));
    });

    test('copyWith kann deletedAt explizit auf null setzen (Sentinel)', () {
      final deletedAt = DateTime.utc(2026, 5, 22, 8, 0, 0);
      final original = Product(
        id: 'prod-id-1',
        workspaceId: 'ws-id-1',
        userId: 'user-id-1',
        name: 'Testprodukt',
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
        deletedAt: deletedAt,
      );
      final copy = original.copyWith(deletedAt: null);
      expect(copy.deletedAt, isNull);
    });
  });

  // ── Konstruktor-Defaults ───────────────────────────────────────────────────

  group('Product Konstruktor-Defaults', () {
    test('unit Default ist Stk, minStock Default ist 0, isActive Default ist true', () {
      final product = Product(
        id: 'x',
        workspaceId: 'ws',
        userId: 'u',
        name: 'Test',
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
      );
      expect(product.unit, equals('Stk'));
      expect(product.minStock, equals(0));
      expect(product.isActive, isTrue);
      expect(product.sku, isNull);
      expect(product.ean, isNull);
      expect(product.categoryId, isNull);
      expect(product.defaultSupplierId, isNull);
      expect(product.defaultCostPrice, isNull);
      expect(product.defaultSalePrice, isNull);
      expect(product.taxRate, isNull);
      expect(product.note, isNull);
      expect(product.deletedAt, isNull);
    });
  });
}
