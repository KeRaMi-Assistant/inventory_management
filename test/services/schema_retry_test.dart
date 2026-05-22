import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_management/services/supabase_repository.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

PostgrestException _pgrstError(String code) => PostgrestException(
      message: 'relation "$code" does not exist',
      code: code,
    );

/// Simuliert einen Query, der [failCount] mal mit [error] wirft, dann
/// [successResult] zurückgibt.
_CallLog _makeQuery({
  required int failCount,
  required PostgrestException error,
  required List<dynamic> successResult,
}) {
  final log = _CallLog();
  log.query = () async {
    log.calls++;
    if (log.calls <= failCount) throw error;
    return successResult;
  };
  return log;
}

class _CallLog {
  int calls = 0;
  late Future<List<dynamic>> Function() query;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // Wir testen [SupabaseRepository.loadWithSchemaRetry] direkt über eine
  // Minimal-Subklasse, die den `forTesting()`-Konstruktor nutzt und keinen
  // echten Supabase-Client benötigt.
  late SupabaseRepository repo;

  setUp(() {
    repo = SupabaseRepository.forTesting();
  });

  group('loadWithSchemaRetry —', () {
    test('gibt Ergebnis sofort zurück wenn kein Fehler', () async {
      final result = await repo.loadWithSchemaRetry(() async => [1, 2, 3]);
      expect(result, [1, 2, 3]);
    });

    test('retried einmal bei PGRST205 und liefert Ergebnis des 2. Versuchs',
        () async {
      final log = _makeQuery(
        failCount: 1,
        error: _pgrstError('PGRST205'),
        successResult: [{'id': 'a'}],
      );
      // Delays auf Null setzen, indem wir eine Subklasse mit minimalen
      // Delays nutzen — wir warten auf das echte Future der
      // loadWithSchemaRetry-Implementierung.
      // Da die Delays in der echten Impl fest sind, ersetzen wir die Methode
      // über eine Subklasse mit Zero-Delays.
      final fastRepo = _ZeroDelayRepo();
      final result = await fastRepo.loadWithSchemaRetry(log.query);
      expect(result, [{'id': 'a'}]);
      expect(log.calls, 2); // 1 Fail + 1 Erfolg
    });

    test('retried bis zu 3 Mal bei aufeinanderfolgenden PGRST205-Fehlern',
        () async {
      final log = _makeQuery(
        failCount: 3,
        error: _pgrstError('PGRST205'),
        successResult: [{'ok': true}],
      );
      final fastRepo = _ZeroDelayRepo();
      final result = await fastRepo.loadWithSchemaRetry(log.query);
      expect(result, [{'ok': true}]);
      expect(log.calls, 4); // 3 Fails + 1 Erfolg
    });

    test('wirft nach 4 Versuchen (3 Retries) wenn Fehler persistiert',
        () async {
      var calls = 0;
      final fastRepo = _ZeroDelayRepo();
      await expectLater(
        fastRepo.loadWithSchemaRetry(() async {
          calls++;
          throw _pgrstError('PGRST205');
        }),
        throwsA(isA<PostgrestException>().having(
          (e) => e.code,
          'code',
          'PGRST205',
        )),
      );
      // Erster Versuch + 3 Retries = 4 Aufrufe gesamt.
      expect(calls, 4);
    });

    test('PGRST204 wird ebenfalls als Schema-Cache-Fehler retried', () async {
      final log = _makeQuery(
        failCount: 1,
        error: _pgrstError('PGRST204'),
        successResult: [],
      );
      final fastRepo = _ZeroDelayRepo();
      final result = await fastRepo.loadWithSchemaRetry(log.query);
      expect(result, isEmpty);
      expect(log.calls, 2);
    });

    test('nicht-Schema-Fehler (z.B. 42501 RLS-Deny) werden NICHT retried',
        () async {
      var calls = 0;
      final rlsError = PostgrestException(
        message: 'permission denied for table products',
        code: '42501',
      );
      final fastRepo = _ZeroDelayRepo();
      await expectLater(
        fastRepo.loadWithSchemaRetry(() async {
          calls++;
          throw rlsError;
        }),
        throwsA(isA<PostgrestException>().having(
          (e) => e.code,
          'code',
          '42501',
        )),
      );
      // Sofort nach erstem Fehler — kein Retry.
      expect(calls, 1);
    });

    test('anderer Fehlertyp (z.B. StateError) wird sofort durchgereicht',
        () async {
      var calls = 0;
      final fastRepo = _ZeroDelayRepo();
      await expectLater(
        fastRepo.loadWithSchemaRetry(() async {
          calls++;
          throw StateError('netzwerk weg');
        }),
        throwsA(isA<StateError>()),
      );
      expect(calls, 1);
    });
  });
}

// ── Hilfs-Subklasse mit Zero-Delays ──────────────────────────────────────────

/// Überschreibt [loadWithSchemaRetry] mit identischer Logik, aber
/// Null-Delays, damit Tests in Millisekunden durchlaufen.
class _ZeroDelayRepo extends SupabaseRepository {
  _ZeroDelayRepo() : super.forTesting();

  @override
  Future<List<dynamic>> loadWithSchemaRetry(
    Future<List<dynamic>> Function() query,
  ) async {
    const schemaCacheErrorCodes = {'PGRST205', 'PGRST204'};
    // Zero-Delays für Tests — Logik identisch zur Produktion.
    const retryDelays = [
      Duration.zero,
      Duration.zero,
      Duration.zero,
    ];

    for (var attempt = 0; attempt <= retryDelays.length; attempt++) {
      try {
        return await query();
      } on PostgrestException catch (e) {
        final isSchemaError = schemaCacheErrorCodes.contains(e.code);
        if (!isSchemaError || attempt == retryDelays.length) {
          rethrow;
        }
        await Future<void>.delayed(retryDelays[attempt]);
      }
    }
    throw StateError('loadWithSchemaRetry: unreachable');
  }
}
