import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/product_category.dart';

void main() {
  // ── Hilfsfunktionen ────────────────────────────────────────────────────────

  final baseCreatedAt = DateTime.utc(2026, 5, 20, 10, 0, 0);
  final baseUpdatedAt = DateTime.utc(2026, 5, 20, 11, 0, 0);

  ProductCategory makeBase({String? parentId}) => ProductCategory(
        id: 'cat-id-1',
        workspaceId: 'ws-id-1',
        userId: 'user-id-1',
        name: 'Elektronik',
        parentId: parentId,
        sortOrder: 2,
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
      );

  // ── toSupabaseInsert / fromSupabase Round-Trip ──────────────────────────────

  group('ProductCategory Supabase Round-Trip', () {
    test('Round-Trip ohne parentId und deletedAt', () {
      final original = makeBase();
      final row = original.toSupabaseInsert();

      // Pflichtfelder müssen vorhanden sein
      expect(row['id'], equals('cat-id-1'));
      expect(row['workspace_id'], equals('ws-id-1'));
      expect(row['user_id'], equals('user-id-1'));
      expect(row['name'], equals('Elektronik'));
      expect(row['parent_id'], isNull);
      expect(row['sort_order'], equals(2));

      // Timestamps werden nicht in toSupabaseInsert geschrieben (DB-Defaults)
      expect(row.containsKey('created_at'), isFalse);
      expect(row.containsKey('updated_at'), isFalse);

      // fromSupabase benötigt die Timestamp-Felder — simulieren
      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String()
        ..remove('id'); // falls id fehlt (db-generiert) — teste mit id
      fullRow['id'] = 'cat-id-1';

      final restored = ProductCategory.fromSupabase(fullRow);
      expect(restored.id, equals(original.id));
      expect(restored.workspaceId, equals(original.workspaceId));
      expect(restored.userId, equals(original.userId));
      expect(restored.name, equals(original.name));
      expect(restored.parentId, isNull);
      expect(restored.sortOrder, equals(original.sortOrder));
      expect(restored.createdAt, equals(baseCreatedAt));
      expect(restored.updatedAt, equals(baseUpdatedAt));
      expect(restored.deletedAt, isNull);
    });

    test('Round-Trip mit parentId gesetzt', () {
      final original = makeBase(parentId: 'parent-cat-id');
      final row = original.toSupabaseInsert();
      expect(row['parent_id'], equals('parent-cat-id'));

      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String();

      final restored = ProductCategory.fromSupabase(fullRow);
      expect(restored.parentId, equals('parent-cat-id'));
    });

    test('fromSupabase liest deletedAt korrekt', () {
      final deletedAt = DateTime.utc(2026, 5, 21, 9, 0, 0);
      final row = {
        'id': 'cat-id-2',
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'name': 'Gelöscht',
        'parent_id': null,
        'sort_order': 0,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'deleted_at': deletedAt.toIso8601String(),
      };
      final restored = ProductCategory.fromSupabase(row);
      expect(restored.deletedAt, equals(deletedAt));
    });

    test('fromSupabase: sort_order fehlt → Default 0', () {
      final row = {
        'id': 'cat-id-3',
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'name': 'Ohne Sortierung',
        'parent_id': null,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'deleted_at': null,
      };
      final restored = ProductCategory.fromSupabase(row);
      expect(restored.sortOrder, equals(0));
    });

    test('fromSupabase: sort_order als int aus DB gelesen', () {
      final row = {
        'id': 'cat-id-4',
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'name': 'Mit Sortierung',
        'parent_id': null,
        'sort_order': 5, // int aus DB
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'deleted_at': null,
      };
      final restored = ProductCategory.fromSupabase(row);
      expect(restored.sortOrder, equals(5));
    });

    test('toSupabaseInsert: id wird nur geschrieben wenn non-empty', () {
      final withId = makeBase();
      expect(withId.toSupabaseInsert().containsKey('id'), isTrue);

      final withoutId = ProductCategory(
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

  group('ProductCategory.copyWith', () {
    test('copyWith ohne Argumente ist identisch', () {
      final original = makeBase(parentId: 'p-id');
      final copy = original.copyWith();
      expect(copy.id, equals(original.id));
      expect(copy.workspaceId, equals(original.workspaceId));
      expect(copy.userId, equals(original.userId));
      expect(copy.name, equals(original.name));
      expect(copy.parentId, equals(original.parentId));
      expect(copy.sortOrder, equals(original.sortOrder));
      expect(copy.deletedAt, isNull);
    });

    test('copyWith ändert name', () {
      final original = makeBase();
      final copy = original.copyWith(name: 'Haushalt');
      expect(copy.name, equals('Haushalt'));
      expect(original.name, equals('Elektronik'));
    });

    test('copyWith setzt parentId auf neuen Wert', () {
      final original = makeBase();
      final copy = original.copyWith(parentId: 'new-parent');
      expect(copy.parentId, equals('new-parent'));
    });

    test('copyWith kann parentId explizit auf null setzen (Sentinel)', () {
      final original = makeBase(parentId: 'some-parent');
      final copy = original.copyWith(parentId: null);
      expect(copy.parentId, isNull);
    });

    test('copyWith lässt parentId unverändert wenn nicht übergeben', () {
      final original = makeBase(parentId: 'keep-parent');
      final copy = original.copyWith(name: 'Andere Kategorie');
      expect(copy.parentId, equals('keep-parent'));
    });

    test('copyWith kann deletedAt setzen', () {
      final original = makeBase();
      final deletedAt = DateTime.utc(2026, 5, 22, 8, 0, 0);
      final copy = original.copyWith(deletedAt: deletedAt);
      expect(copy.deletedAt, equals(deletedAt));
    });

    test('copyWith kann deletedAt explizit auf null setzen (Sentinel)', () {
      final deletedAt = DateTime.utc(2026, 5, 22, 8, 0, 0);
      final original = ProductCategory(
        id: 'cat-id-1',
        workspaceId: 'ws-id-1',
        userId: 'user-id-1',
        name: 'Elektronik',
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
        deletedAt: deletedAt,
      );
      final copy = original.copyWith(deletedAt: null);
      expect(copy.deletedAt, isNull);
    });

    test('copyWith ändert sortOrder', () {
      final original = makeBase();
      final copy = original.copyWith(sortOrder: 10);
      expect(copy.sortOrder, equals(10));
      expect(original.sortOrder, equals(2));
    });
  });

  // ── Konstruktor-Defaults ───────────────────────────────────────────────────

  group('ProductCategory Konstruktor-Defaults', () {
    test('sortOrder Default ist 0, parentId und deletedAt sind null', () {
      final cat = ProductCategory(
        id: 'x',
        workspaceId: 'ws',
        userId: 'u',
        name: 'Test',
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
      );
      expect(cat.sortOrder, equals(0));
      expect(cat.parentId, isNull);
      expect(cat.deletedAt, isNull);
    });
  });
}
