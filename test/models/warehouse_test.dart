import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/warehouse.dart';

void main() {
  // ── Hilfsfunktionen ────────────────────────────────────────────────────────

  final baseCreatedAt = DateTime.utc(2026, 5, 20, 10, 0, 0);
  final baseUpdatedAt = DateTime.utc(2026, 5, 20, 11, 0, 0);

  Warehouse makeBase({String? address, bool isDefault = false}) => Warehouse(
        id: 'wh-id-1',
        workspaceId: 'ws-id-1',
        userId: 'user-id-1',
        name: 'Hauptlager',
        address: address,
        isDefault: isDefault,
        isActive: true,
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
      );

  // ── toSupabaseInsert / fromSupabase Round-Trip ──────────────────────────────

  group('Warehouse Supabase Round-Trip', () {
    test('Round-Trip ohne address und deletedAt', () {
      final original = makeBase();
      final row = original.toSupabaseInsert();

      // Pflichtfelder müssen vorhanden sein
      expect(row['id'], equals('wh-id-1'));
      expect(row['workspace_id'], equals('ws-id-1'));
      expect(row['user_id'], equals('user-id-1'));
      expect(row['name'], equals('Hauptlager'));
      expect(row['address'], isNull);
      expect(row['is_default'], isFalse);
      expect(row['is_active'], isTrue);

      // Timestamps werden nicht in toSupabaseInsert geschrieben (DB-Defaults)
      expect(row.containsKey('created_at'), isFalse);
      expect(row.containsKey('updated_at'), isFalse);

      // fromSupabase benötigt die Timestamp-Felder — simulieren
      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String()
        ..['deleted_at'] = null;

      final restored = Warehouse.fromSupabase(fullRow);
      expect(restored.id, equals(original.id));
      expect(restored.workspaceId, equals(original.workspaceId));
      expect(restored.userId, equals(original.userId));
      expect(restored.name, equals(original.name));
      expect(restored.address, isNull);
      expect(restored.isDefault, isFalse);
      expect(restored.isActive, isTrue);
      expect(restored.createdAt, equals(baseCreatedAt));
      expect(restored.updatedAt, equals(baseUpdatedAt));
      expect(restored.deletedAt, isNull);
    });

    test('Round-Trip mit address gesetzt', () {
      final original = makeBase(address: 'Musterstraße 1, 12345 Berlin');
      final row = original.toSupabaseInsert();
      expect(row['address'], equals('Musterstraße 1, 12345 Berlin'));

      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String();

      final restored = Warehouse.fromSupabase(fullRow);
      expect(restored.address, equals('Musterstraße 1, 12345 Berlin'));
    });

    test('Round-Trip mit isDefault = true', () {
      final original = makeBase(isDefault: true);
      final row = original.toSupabaseInsert();
      expect(row['is_default'], isTrue);

      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String();

      final restored = Warehouse.fromSupabase(fullRow);
      expect(restored.isDefault, isTrue);
    });

    test('fromSupabase liest deletedAt korrekt', () {
      final deletedAt = DateTime.utc(2026, 5, 21, 9, 0, 0);
      final row = {
        'id': 'wh-id-2',
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'name': 'Gelöschtes Lager',
        'address': null,
        'is_default': false,
        'is_active': false,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'deleted_at': deletedAt.toIso8601String(),
      };
      final restored = Warehouse.fromSupabase(row);
      expect(restored.deletedAt, equals(deletedAt));
      expect(restored.isActive, isFalse);
    });

    test('fromSupabase: is_default fehlt → Default false', () {
      final row = {
        'id': 'wh-id-3',
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'name': 'Ohne Default-Flag',
        'address': null,
        'is_active': true,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'deleted_at': null,
      };
      final restored = Warehouse.fromSupabase(row);
      expect(restored.isDefault, isFalse);
    });

    test('fromSupabase: is_active fehlt → Default true', () {
      final row = {
        'id': 'wh-id-4',
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'name': 'Ohne Active-Flag',
        'address': null,
        'is_default': false,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'deleted_at': null,
      };
      final restored = Warehouse.fromSupabase(row);
      expect(restored.isActive, isTrue);
    });

    test('toSupabaseInsert: id wird nur geschrieben wenn non-empty', () {
      final withId = makeBase();
      expect(withId.toSupabaseInsert().containsKey('id'), isTrue);

      final withoutId = Warehouse(
        id: '',
        workspaceId: 'ws-id-1',
        userId: 'user-id-1',
        name: 'Neues Lager',
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
      );
      expect(withoutId.toSupabaseInsert().containsKey('id'), isFalse);
    });
  });

  // ── copyWith ───────────────────────────────────────────────────────────────

  group('Warehouse.copyWith', () {
    test('copyWith ohne Argumente ist identisch', () {
      final original = makeBase(address: 'Teststraße 1', isDefault: true);
      final copy = original.copyWith();
      expect(copy.id, equals(original.id));
      expect(copy.workspaceId, equals(original.workspaceId));
      expect(copy.userId, equals(original.userId));
      expect(copy.name, equals(original.name));
      expect(copy.address, equals(original.address));
      expect(copy.isDefault, equals(original.isDefault));
      expect(copy.isActive, equals(original.isActive));
      expect(copy.deletedAt, isNull);
    });

    test('copyWith ändert name', () {
      final original = makeBase();
      final copy = original.copyWith(name: 'Außenlager');
      expect(copy.name, equals('Außenlager'));
      expect(original.name, equals('Hauptlager'));
    });

    test('copyWith setzt address auf neuen Wert', () {
      final original = makeBase();
      final copy = original.copyWith(address: 'Neue Str. 5');
      expect(copy.address, equals('Neue Str. 5'));
    });

    test('copyWith kann address explizit auf null setzen (Sentinel)', () {
      final original = makeBase(address: 'Alte Adresse');
      final copy = original.copyWith(address: null);
      expect(copy.address, isNull);
    });

    test('copyWith lässt address unverändert wenn nicht übergeben', () {
      final original = makeBase(address: 'Behalte mich');
      final copy = original.copyWith(name: 'Anderer Name');
      expect(copy.address, equals('Behalte mich'));
    });

    test('copyWith kann deletedAt setzen', () {
      final original = makeBase();
      final deletedAt = DateTime.utc(2026, 5, 22, 8, 0, 0);
      final copy = original.copyWith(deletedAt: deletedAt);
      expect(copy.deletedAt, equals(deletedAt));
    });

    test('copyWith kann deletedAt explizit auf null setzen (Sentinel)', () {
      final deletedAt = DateTime.utc(2026, 5, 22, 8, 0, 0);
      final original = Warehouse(
        id: 'wh-id-1',
        workspaceId: 'ws-id-1',
        userId: 'user-id-1',
        name: 'Hauptlager',
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
        deletedAt: deletedAt,
      );
      final copy = original.copyWith(deletedAt: null);
      expect(copy.deletedAt, isNull);
    });

    test('copyWith ändert isDefault', () {
      final original = makeBase(isDefault: false);
      final copy = original.copyWith(isDefault: true);
      expect(copy.isDefault, isTrue);
      expect(original.isDefault, isFalse);
    });

    test('copyWith ändert isActive', () {
      final original = makeBase();
      final copy = original.copyWith(isActive: false);
      expect(copy.isActive, isFalse);
      expect(original.isActive, isTrue);
    });
  });

  // ── Konstruktor-Defaults ───────────────────────────────────────────────────

  group('Warehouse Konstruktor-Defaults', () {
    test('isDefault Default ist false, isActive Default ist true, address null', () {
      final wh = Warehouse(
        id: 'x',
        workspaceId: 'ws',
        userId: 'u',
        name: 'Test',
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
      );
      expect(wh.isDefault, isFalse);
      expect(wh.isActive, isTrue);
      expect(wh.address, isNull);
      expect(wh.deletedAt, isNull);
    });
  });
}
