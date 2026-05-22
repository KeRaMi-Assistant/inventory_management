import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/inventory_item.dart';

void main() {
  // ── Hilfsfunktion ──────────────────────────────────────────────────────────

  InventoryMovement makeBase({
    InventoryMovementType movementType = InventoryMovementType.correction,
    double? unitCost,
  }) =>
      InventoryMovement(
        id: 'test-id-1',
        itemId: 'item-id-1',
        date: DateTime.utc(2026, 5, 20, 12, 0, 0),
        quantityChange: 5,
        reason: 'Testbuchung',
        movementType: movementType,
        unitCost: unitCost,
      );

  // ── InventoryMovementType.fromDbValue / dbValue ────────────────────────────

  group('InventoryMovementType Enum-Mapping', () {
    const allTypes = {
      'goods_in': InventoryMovementType.goodsIn,
      'goods_out': InventoryMovementType.goodsOut,
      'correction': InventoryMovementType.correction,
      'stocktake': InventoryMovementType.stocktake,
      'transfer': InventoryMovementType.transfer,
      'sale': InventoryMovementType.sale,
    };

    test('fromDbValue liefert korrekten Enum-Wert für alle 6 DB-Strings', () {
      for (final entry in allTypes.entries) {
        expect(
          InventoryMovementType.fromDbValue(entry.key),
          equals(entry.value),
          reason: 'fromDbValue("${entry.key}") sollte ${entry.value} sein',
        );
      }
    });

    test('dbValue liefert korrekten DB-String für alle 6 Enum-Werte', () {
      for (final entry in allTypes.entries) {
        expect(
          entry.value.dbValue,
          equals(entry.key),
          reason: '${entry.value}.dbValue sollte "${entry.key}" sein',
        );
      }
    });

    test('fromDbValue/dbValue-Symmetrie: dbValue → fromDbValue Round-Trip', () {
      for (final type in InventoryMovementType.values) {
        expect(
          InventoryMovementType.fromDbValue(type.dbValue),
          equals(type),
          reason: 'Round-Trip für $type ist nicht symmetrisch',
        );
      }
    });

    test('fromDbValue mit unbekanntem String fällt auf correction zurück', () {
      expect(
        InventoryMovementType.fromDbValue('unknown_type'),
        equals(InventoryMovementType.correction),
      );
    });

    test('fromDbValue mit leerem String fällt auf correction zurück', () {
      expect(
        InventoryMovementType.fromDbValue(''),
        equals(InventoryMovementType.correction),
      );
    });
  });

  // ── toSupabaseInsert / fromSupabase Round-Trip ──────────────────────────────

  group('InventoryMovement Supabase Round-Trip', () {
    for (final type in InventoryMovementType.values) {
      test('Round-Trip movementType=${type.dbValue} ohne unitCost', () {
        final original = makeBase(movementType: type);
        final row = original.toSupabaseInsert();

        // movement_type muss als DB-String gesetzt sein
        expect(row['movement_type'], equals(type.dbValue));
        // unit_cost darf NICHT im Map vorkommen wenn null
        expect(row.containsKey('unit_cost'), isFalse);

        final restored = InventoryMovement.fromSupabase(row);
        expect(restored.movementType, equals(type));
        expect(restored.unitCost, isNull);
        expect(restored.id, equals(original.id));
        expect(restored.itemId, equals(original.itemId));
        expect(restored.quantityChange, equals(original.quantityChange));
        expect(restored.reason, equals(original.reason));
      });

      test('Round-Trip movementType=${type.dbValue} mit unitCost=12.50', () {
        final original = makeBase(movementType: type, unitCost: 12.50);
        final row = original.toSupabaseInsert();

        expect(row['movement_type'], equals(type.dbValue));
        expect(row['unit_cost'], equals(12.50));

        final restored = InventoryMovement.fromSupabase(row);
        expect(restored.movementType, equals(type));
        expect(restored.unitCost, equals(12.50));
      });
    }

    test('fromSupabase mit fehlendem movement_type fällt auf correction zurück',
        () {
      final row = makeBase().toSupabaseInsert()..remove('movement_type');
      final restored = InventoryMovement.fromSupabase(row);
      expect(restored.movementType, equals(InventoryMovementType.correction));
    });

    test('fromSupabase mit unbekanntem movement_type fällt auf correction zurück',
        () {
      final row = makeBase().toSupabaseInsert();
      row['movement_type'] = 'invalid_value';
      final restored = InventoryMovement.fromSupabase(row);
      expect(restored.movementType, equals(InventoryMovementType.correction));
    });

    test('unitCost null: unit_cost fehlt in toSupabaseInsert', () {
      final m = makeBase(unitCost: null);
      final row = m.toSupabaseInsert();
      expect(row.containsKey('unit_cost'), isFalse);
    });

    test('unitCost non-null: unit_cost ist in toSupabaseInsert enthalten', () {
      final m = makeBase(unitCost: 99.99);
      final row = m.toSupabaseInsert();
      expect(row['unit_cost'], equals(99.99));
    });

    test('fromSupabase liest unit_cost als num und wandelt in double um', () {
      final row = makeBase().toSupabaseInsert();
      row['unit_cost'] = 7; // int aus DB (num)
      final restored = InventoryMovement.fromSupabase(row);
      expect(restored.unitCost, equals(7.0));
      expect(restored.unitCost, isA<double>());
    });
  });

  // ── copyWith ───────────────────────────────────────────────────────────────

  group('InventoryMovement.copyWith', () {
    test('copyWith ohne Argumente ist identisch zum Original', () {
      final original = makeBase(
        movementType: InventoryMovementType.goodsIn,
        unitCost: 5.0,
      );
      final copy = original.copyWith();
      expect(copy.movementType, equals(original.movementType));
      expect(copy.unitCost, equals(original.unitCost));
      expect(copy.id, equals(original.id));
      expect(copy.reason, equals(original.reason));
    });

    test('copyWith ändert movementType', () {
      final original = makeBase(movementType: InventoryMovementType.correction);
      final copy = original.copyWith(movementType: InventoryMovementType.sale);
      expect(copy.movementType, equals(InventoryMovementType.sale));
      expect(original.movementType, equals(InventoryMovementType.correction));
    });

    test('copyWith setzt unitCost auf einen neuen Wert', () {
      final original = makeBase(unitCost: null);
      final copy = original.copyWith(unitCost: 42.0);
      expect(copy.unitCost, equals(42.0));
      expect(original.unitCost, isNull);
    });

    test('copyWith kann unitCost explizit auf null setzen (Sentinel)', () {
      final original = makeBase(unitCost: 10.0);
      final copy = original.copyWith(unitCost: null);
      expect(copy.unitCost, isNull);
    });

    test('copyWith lässt unitCost unverändert wenn nicht übergeben', () {
      final original = makeBase(unitCost: 3.14);
      final copy = original.copyWith(reason: 'anderer Grund');
      expect(copy.unitCost, equals(3.14));
    });
  });

  // ── Konstruktor-Default ────────────────────────────────────────────────────

  group('InventoryMovement Konstruktor-Default', () {
    test('movementType Default ist correction, unitCost Default ist null', () {
      final m = InventoryMovement(
        id: 'x',
        itemId: 'y',
        date: DateTime.utc(2026, 1, 1),
        quantityChange: 1,
        reason: 'test',
      );
      expect(m.movementType, equals(InventoryMovementType.correction));
      expect(m.unitCost, isNull);
    });

    test('productId Default ist null', () {
      final m = InventoryMovement(
        id: 'x',
        itemId: 'y',
        date: DateTime.utc(2026, 1, 1),
        quantityChange: 1,
        reason: 'test',
      );
      expect(m.productId, isNull);
    });
  });

  // ── productId Round-Trip ───────────────────────────────────────────────────

  group('InventoryMovement productId', () {
    test('productId null: product_id fehlt in toSupabaseInsert', () {
      final m = makeBase();
      final row = m.toSupabaseInsert();
      expect(row.containsKey('product_id'), isFalse);
    });

    test('productId non-null: product_id ist in toSupabaseInsert enthalten', () {
      final m = makeBase().copyWith(productId: 'prod-uuid-1');
      final row = m.toSupabaseInsert();
      expect(row['product_id'], equals('prod-uuid-1'));
    });

    test('fromSupabase liest productId korrekt', () {
      final row = makeBase().toSupabaseInsert()
        ..['product_id'] = 'prod-uuid-2';
      final restored = InventoryMovement.fromSupabase(row);
      expect(restored.productId, equals('prod-uuid-2'));
    });

    test('fromSupabase: product_id fehlt → null', () {
      final row = makeBase().toSupabaseInsert();
      // key nicht vorhanden
      row.remove('product_id');
      final restored = InventoryMovement.fromSupabase(row);
      expect(restored.productId, isNull);
    });

    test('fromSupabase: product_id null → null', () {
      final row = makeBase().toSupabaseInsert();
      row['product_id'] = null;
      final restored = InventoryMovement.fromSupabase(row);
      expect(restored.productId, isNull);
    });

    test('Round-Trip: productId gesetzt', () {
      final original = makeBase().copyWith(productId: 'prod-round-trip');
      final row = original.toSupabaseInsert();
      final restored = InventoryMovement.fromSupabase(row);
      expect(restored.productId, equals('prod-round-trip'));
    });

    test('copyWith setzt productId auf neuen Wert', () {
      final original = makeBase();
      final copy = original.copyWith(productId: 'new-prod-id');
      expect(copy.productId, equals('new-prod-id'));
      expect(original.productId, isNull);
    });

    test('copyWith kann productId explizit auf null setzen (Sentinel)', () {
      final original = makeBase().copyWith(productId: 'some-prod-id');
      final copy = original.copyWith(productId: null);
      expect(copy.productId, isNull);
    });

    test('copyWith lässt productId unverändert wenn nicht übergeben', () {
      final original = makeBase().copyWith(productId: 'keep-prod-id');
      final copy = original.copyWith(reason: 'anderer Grund');
      expect(copy.productId, equals('keep-prod-id'));
    });
  });
}
