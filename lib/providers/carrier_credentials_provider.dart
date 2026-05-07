import 'package:flutter/foundation.dart';

import '../models/carrier_credential.dart';
import '../services/supabase_repository.dart';

/// Hält die im Settings → Versand-Tab gepflegten Carrier-API-Keys (maskiert).
/// Nur Owner/Admin sehen Daten; bei fehlender Berechtigung liefert die
/// Server-RPC einen Fehler — den fangen wir hier ab und zeigen `[]`.
class CarrierCredentialsProvider extends ChangeNotifier {
  CarrierCredentialsProvider({required SupabaseRepository repository})
      : _repository = repository;

  final SupabaseRepository _repository;

  List<CarrierCredential> _credentials = const [];
  bool _loading = false;
  Object? _lastError;

  List<CarrierCredential> get credentials => List.unmodifiable(_credentials);
  bool get isLoading => _loading;
  Object? get lastError => _lastError;

  /// Existiert für [carrierId] bereits ein Eintrag?
  CarrierCredential? credentialFor(String carrierId) {
    for (final c in _credentials) {
      if (c.carrierId == carrierId) return c;
    }
    return null;
  }

  /// Liest die aktuelle Liste der Credentials. Setzt [_lastError] bei
  /// fehlender Berechtigung, ohne zu werfen — die UI rendert dann ein
  /// "Kein Zugriff"-Hint.
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      _credentials = await _repository.loadCarrierCredentials();
    } catch (e) {
      _lastError = e;
      _credentials = const [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Speichert einen API-Key. Bei Erfolg wird die Liste neu geladen, damit
  /// die maskierte Anzeige (`••••<last4>`) sofort aktualisiert ist.
  Future<void> setApiKey({
    required String carrierId,
    required String apiKey,
  }) async {
    await _repository.setCarrierApiKey(carrierId: carrierId, apiKey: apiKey);
    await refresh();
  }

  Future<void> deleteApiKey(String carrierId) async {
    await _repository.deleteCarrierApiKey(carrierId);
    await refresh();
  }

  /// Wirft den lokalen State weg (z.B. beim Logout / Workspace-Wechsel).
  void clear() {
    if (_credentials.isEmpty && !_loading && _lastError == null) return;
    _credentials = const [];
    _loading = false;
    _lastError = null;
    notifyListeners();
  }
}
