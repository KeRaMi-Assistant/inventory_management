import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/carrier_credential.dart';
import 'package:inventory_management/providers/carrier_credentials_provider.dart';
import 'package:inventory_management/services/supabase_repository.dart';

class _FakeRepo extends SupabaseRepository {
  _FakeRepo() : super.forTesting();

  List<CarrierCredential> stored = [];
  Object? loadError;
  String? lastSetCarrier;
  String? lastSetKey;
  String? lastDeleted;

  @override
  Future<List<CarrierCredential>> loadCarrierCredentials() async {
    if (loadError != null) throw loadError!;
    return List.of(stored);
  }

  @override
  Future<void> setCarrierApiKey({
    required String carrierId,
    required String apiKey,
  }) async {
    lastSetCarrier = carrierId;
    lastSetKey = apiKey;
    final updatedAt = DateTime.utc(2026, 5, 7, 10);
    stored = [
      ...stored.where((c) => c.carrierId != carrierId),
      CarrierCredential(
        carrierId: carrierId,
        apiKeyLast4: apiKey.substring(apiKey.length - 4),
        enabled: true,
        updatedAt: updatedAt,
      ),
    ];
  }

  @override
  Future<void> deleteCarrierApiKey(String carrierId) async {
    lastDeleted = carrierId;
    stored.removeWhere((c) => c.carrierId == carrierId);
  }
}

void main() {
  group('CarrierCredential', () {
    test('fromSupabase parst typische Zeile', () {
      final c = CarrierCredential.fromSupabase({
        'carrier_id': 'dhl',
        'api_key_last4': 'abcd',
        'enabled': true,
        'last_polled_at': '2026-05-07T08:30:00.000Z',
        'last_error': null,
        'updated_at': '2026-05-07T08:30:00.000Z',
      });
      expect(c.carrierId, 'dhl');
      expect(c.apiKeyLast4, 'abcd');
      expect(c.enabled, isTrue);
      expect(c.lastPolledAt?.toUtc().hour, 8);
      expect(c.masked, '••••••••abcd');
    });

    test('masked füllt kürzere last4 mit Punkten auf', () {
      final c = CarrierCredential.fromSupabase({
        'carrier_id': 'ups',
        'api_key_last4': 'XY',
        'enabled': true,
        'updated_at': '2026-05-07T00:00:00.000Z',
      });
      expect(c.masked.endsWith('··XY'), isTrue);
    });
  });

  group('labelForCarrierId', () {
    test('liefert Label für bekannte Carrier', () {
      expect(labelForCarrierId('dhl'), 'DHL');
      expect(labelForCarrierId('dpd'), 'DPD');
      expect(labelForCarrierId('ups'), 'UPS');
    });
    test('Fallback uppercased', () {
      expect(labelForCarrierId('foo'), 'FOO');
    });
  });

  group('CarrierCredentialsProvider', () {
    test('refresh lädt Liste aus Repository', () async {
      final repo = _FakeRepo()
        ..stored = [
          CarrierCredential(
            carrierId: 'dhl',
            apiKeyLast4: '1234',
            enabled: true,
            updatedAt: DateTime.utc(2026, 5, 7),
          ),
        ];
      final p = CarrierCredentialsProvider(repository: repo);
      expect(p.credentials, isEmpty);
      await p.refresh();
      expect(p.credentials, hasLength(1));
      expect(p.credentialFor('dhl'), isNotNull);
      expect(p.credentialFor('ups'), isNull);
      expect(p.lastError, isNull);
    });

    test('refresh fängt Fehler ab und setzt lastError', () async {
      final repo = _FakeRepo()..loadError = StateError('keine Berechtigung');
      final p = CarrierCredentialsProvider(repository: repo);
      await p.refresh();
      expect(p.credentials, isEmpty);
      expect(p.lastError, isA<StateError>());
    });

    test('setApiKey delegiert an Repo und lädt neu', () async {
      final repo = _FakeRepo();
      final p = CarrierCredentialsProvider(repository: repo);
      await p.setApiKey(carrierId: 'ups', apiKey: 'super-secret-key');
      expect(repo.lastSetCarrier, 'ups');
      expect(repo.lastSetKey, 'super-secret-key');
      expect(p.credentialFor('ups')?.apiKeyLast4, '-key');
    });

    test('deleteApiKey entfernt Eintrag', () async {
      final repo = _FakeRepo()
        ..stored = [
          CarrierCredential(
            carrierId: 'dpd',
            apiKeyLast4: 'zzzz',
            enabled: true,
            updatedAt: DateTime.utc(2026, 5, 7),
          ),
        ];
      final p = CarrierCredentialsProvider(repository: repo);
      await p.refresh();
      expect(p.credentialFor('dpd'), isNotNull);
      await p.deleteApiKey('dpd');
      expect(repo.lastDeleted, 'dpd');
      expect(p.credentialFor('dpd'), isNull);
    });

    test('clear leert lokalen State', () async {
      final repo = _FakeRepo()
        ..stored = [
          CarrierCredential(
            carrierId: 'dhl',
            apiKeyLast4: '0000',
            enabled: true,
            updatedAt: DateTime.utc(2026, 5, 7),
          ),
        ];
      final p = CarrierCredentialsProvider(repository: repo);
      await p.refresh();
      expect(p.credentials, hasLength(1));
      p.clear();
      expect(p.credentials, isEmpty);
    });
  });
}
