import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/stocktake.dart';

void main() {
  final baseCreatedAt = DateTime.utc(2026, 5, 22, 8, 0, 0);
  final baseUpdatedAt = DateTime.utc(2026, 5, 22, 9, 0, 0);

  Stocktake makeBase({
    int? id = 1,
    String? warehouseId,
    StocktakeStatus status = StocktakeStatus.open,
    String? title,
    DateTime? startedAt,
    DateTime? closedAt,
    String? updatedBy,
    DateTime? deletedAt,
  }) =>
      Stocktake(
        id: id,
        workspaceId: 'ws-id-1',
        userId: 'user-id-1',
        warehouseId: warehouseId,
        status: status,
        title: title,
        startedAt: startedAt,
        closedAt: closedAt,
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
        updatedBy: updatedBy,
        version: 1,
        deletedAt: deletedAt,
      );

  // ── StocktakeStatus Enum-Mapping ─────────────────────────────────────────

  group('StocktakeStatus Enum-Mapping', () {
    const allValues = {
      'open': StocktakeStatus.open,
      'counting': StocktakeStatus.counting,
      'closed': StocktakeStatus.closed,
      'cancelled': StocktakeStatus.cancelled,
    };

    test('fromDbValue liefert korrekten Enum-Wert für alle 4 DB-Strings', () {
      for (final entry in allValues.entries) {
        expect(
          StocktakeStatus.fromDbValue(entry.key),
          equals(entry.value),
          reason: 'fromDbValue("${entry.key}") sollte ${entry.value} sein',
        );
      }
    });

    test('dbValue liefert korrekten DB-String für alle 4 Enum-Werte', () {
      for (final entry in allValues.entries) {
        expect(
          entry.value.dbValue,
          equals(entry.key),
          reason: '${entry.value}.dbValue sollte "${entry.key}" sein',
        );
      }
    });

    test('fromDbValue/dbValue Round-Trip für alle Werte', () {
      for (final status in StocktakeStatus.values) {
        expect(
          StocktakeStatus.fromDbValue(status.dbValue),
          equals(status),
          reason: 'Round-Trip für $status ist nicht symmetrisch',
        );
      }
    });

    test('fromDbValue mit unbekanntem String fällt auf open zurück', () {
      expect(
        StocktakeStatus.fromDbValue('invalid_status'),
        equals(StocktakeStatus.open),
      );
    });

    test('fromDbValue mit leerem String fällt auf open zurück', () {
      expect(
        StocktakeStatus.fromDbValue(''),
        equals(StocktakeStatus.open),
      );
    });
  });

  // ── Supabase Round-Trip ───────────────────────────────────────────────────

  group('Stocktake Supabase Round-Trip', () {
    test('Round-Trip: alle nullable Felder null, id non-null', () {
      final original = makeBase();
      final row = original.toSupabaseInsert();

      expect(row['id'], equals(1));
      expect(row['workspace_id'], equals('ws-id-1'));
      expect(row['user_id'], equals('user-id-1'));
      expect(row['status'], equals('open'));
      expect(row['warehouse_id'], isNull);
      expect(row['title'], isNull);
      expect(row['started_at'], isNull);
      expect(row['closed_at'], isNull);
      // Timestamps werden nicht vom Client gesetzt (Trigger)
      expect(row.containsKey('created_at'), isFalse);
      expect(row.containsKey('updated_at'), isFalse);

      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String()
        ..['version'] = 1;

      final restored = Stocktake.fromSupabase(fullRow);
      expect(restored.id, equals(1));
      expect(restored.workspaceId, equals('ws-id-1'));
      expect(restored.userId, equals('user-id-1'));
      expect(restored.status, equals(StocktakeStatus.open));
      expect(restored.warehouseId, isNull);
      expect(restored.title, isNull);
      expect(restored.startedAt, isNull);
      expect(restored.closedAt, isNull);
      expect(restored.deletedAt, isNull);
      expect(restored.createdAt, equals(baseCreatedAt));
      expect(restored.updatedAt, equals(baseUpdatedAt));
    });

    test('Round-Trip: alle nullable Felder gesetzt', () {
      final startedAt = DateTime.utc(2026, 5, 22, 10, 0, 0);
      final closedAt = DateTime.utc(2026, 5, 22, 18, 0, 0);
      final original = makeBase(
        warehouseId: 'wh-uuid-1',
        status: StocktakeStatus.closed,
        title: 'Jahresabschluss 2026',
        startedAt: startedAt,
        closedAt: closedAt,
        updatedBy: 'user-id-1',
      );
      final row = original.toSupabaseInsert();

      expect(row['warehouse_id'], equals('wh-uuid-1'));
      expect(row['status'], equals('closed'));
      expect(row['title'], equals('Jahresabschluss 2026'));
      expect(row['started_at'], equals(startedAt.toIso8601String()));
      expect(row['closed_at'], equals(closedAt.toIso8601String()));

      final fullRow = Map<String, dynamic>.from(row)
        ..['created_at'] = baseCreatedAt.toIso8601String()
        ..['updated_at'] = baseUpdatedAt.toIso8601String()
        ..['version'] = 1;

      final restored = Stocktake.fromSupabase(fullRow);
      expect(restored.warehouseId, equals('wh-uuid-1'));
      expect(restored.status, equals(StocktakeStatus.closed));
      expect(restored.title, equals('Jahresabschluss 2026'));
      expect(restored.startedAt, equals(startedAt));
      expect(restored.closedAt, equals(closedAt));
    });

    test('Round-Trip für jeden Status-Enum-Wert', () {
      for (final status in StocktakeStatus.values) {
        final original = makeBase(status: status);
        final row = original.toSupabaseInsert();
        final fullRow = Map<String, dynamic>.from(row)
          ..['created_at'] = baseCreatedAt.toIso8601String()
          ..['updated_at'] = baseUpdatedAt.toIso8601String()
          ..['version'] = 1;
        final restored = Stocktake.fromSupabase(fullRow);
        expect(
          restored.status,
          equals(status),
          reason: 'Status $status überlebt den Round-Trip nicht',
        );
      }
    });

    test('toSupabaseInsert: id wird nicht geschrieben wenn null', () {
      final st = makeBase(id: null);
      expect(st.toSupabaseInsert().containsKey('id'), isFalse);
    });

    test('toSupabaseInsert: id wird geschrieben wenn non-null', () {
      final st = makeBase(id: 99);
      expect(st.toSupabaseInsert()['id'], equals(99));
    });

    test('fromSupabase: id als int aus DB (BIGSERIAL)', () {
      final row = {
        'id': 12345,
        'workspace_id': 'ws-id-1',
        'user_id': 'user-id-1',
        'status': 'open',
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'version': 1,
      };
      final restored = Stocktake.fromSupabase(row);
      expect(restored.id, equals(12345));
      expect(restored.id, isA<int>());
    });

    test('fromSupabase: status null → Default open', () {
      final row = {
        'id': 1,
        'workspace_id': 'ws',
        'user_id': 'u',
        'status': null,
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'version': 1,
      };
      expect(Stocktake.fromSupabase(row).status, equals(StocktakeStatus.open));
    });

    test('fromSupabase: version fehlt → Default 1', () {
      final row = {
        'id': 1,
        'workspace_id': 'ws',
        'user_id': 'u',
        'status': 'open',
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
      };
      expect(Stocktake.fromSupabase(row).version, equals(1));
    });

    test('fromSupabase: deletedAt wird korrekt gelesen', () {
      final deletedAt = DateTime.utc(2026, 6, 1, 12);
      final row = {
        'id': 1,
        'workspace_id': 'ws',
        'user_id': 'u',
        'status': 'cancelled',
        'created_at': baseCreatedAt.toIso8601String(),
        'updated_at': baseUpdatedAt.toIso8601String(),
        'version': 1,
        'deleted_at': deletedAt.toIso8601String(),
      };
      expect(Stocktake.fromSupabase(row).deletedAt, equals(deletedAt));
    });
  });

  // ── Konstruktor-Defaults ──────────────────────────────────────────────────

  group('Stocktake Konstruktor-Defaults', () {
    test('status Default ist open, version Default ist 1, id Default ist null', () {
      final st = Stocktake(
        workspaceId: 'ws',
        userId: 'u',
        createdAt: baseCreatedAt,
        updatedAt: baseUpdatedAt,
      );
      expect(st.id, isNull);
      expect(st.status, equals(StocktakeStatus.open));
      expect(st.version, equals(1));
      expect(st.warehouseId, isNull);
      expect(st.title, isNull);
      expect(st.startedAt, isNull);
      expect(st.closedAt, isNull);
      expect(st.updatedBy, isNull);
      expect(st.deletedAt, isNull);
    });
  });

  // ── copyWith ─────────────────────────────────────────────────────────────

  group('Stocktake.copyWith', () {
    test('copyWith ohne Argumente ist identisch zum Original', () {
      final original = makeBase(
        warehouseId: 'wh-1',
        status: StocktakeStatus.counting,
        title: 'Test',
      );
      final copy = original.copyWith();
      expect(copy.id, equals(original.id));
      expect(copy.workspaceId, equals(original.workspaceId));
      expect(copy.warehouseId, equals(original.warehouseId));
      expect(copy.status, equals(original.status));
      expect(copy.title, equals(original.title));
    });

    test('copyWith ändert status', () {
      final original = makeBase(status: StocktakeStatus.open);
      final copy = original.copyWith(status: StocktakeStatus.closed);
      expect(copy.status, equals(StocktakeStatus.closed));
      expect(original.status, equals(StocktakeStatus.open));
    });

    test('copyWith kann warehouseId auf null setzen (Sentinel)', () {
      final original = makeBase(warehouseId: 'wh-1');
      final copy = original.copyWith(warehouseId: null);
      expect(copy.warehouseId, isNull);
    });

    test('copyWith kann title auf null setzen (Sentinel)', () {
      final original = makeBase(title: 'Alt-Titel');
      final copy = original.copyWith(title: null);
      expect(copy.title, isNull);
    });

    test('copyWith kann startedAt setzen', () {
      final t = DateTime.utc(2026, 5, 22, 10);
      final original = makeBase();
      final copy = original.copyWith(startedAt: t);
      expect(copy.startedAt, equals(t));
    });

    test('copyWith kann closedAt setzen', () {
      final t = DateTime.utc(2026, 5, 22, 18);
      final original = makeBase();
      final copy = original.copyWith(closedAt: t);
      expect(copy.closedAt, equals(t));
    });

    test('copyWith kann id auf null setzen (Sentinel)', () {
      final original = makeBase(id: 5);
      final copy = original.copyWith(id: null);
      expect(copy.id, isNull);
    });

    test('copyWith kann deletedAt setzen und wieder auf null setzen', () {
      final t = DateTime.utc(2026, 5, 30);
      final original = makeBase();
      final withDeleted = original.copyWith(deletedAt: t);
      expect(withDeleted.deletedAt, equals(t));
      final cleared = withDeleted.copyWith(deletedAt: null);
      expect(cleared.deletedAt, isNull);
    });

    test('copyWith ändert version', () {
      final original = makeBase();
      final copy = original.copyWith(version: 5);
      expect(copy.version, equals(5));
      expect(original.version, equals(1));
    });
  });
}
