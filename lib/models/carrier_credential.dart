/// Maskierte Repräsentation eines Carrier-API-Keys, wie er via
/// `list_carrier_credentials`-RPC zurückkommt. Klartext wird NIE im Modell
/// transportiert — Setzen läuft separat über `set_carrier_api_key`.
class CarrierCredential {
  final String carrierId;
  final String apiKeyLast4;
  final bool enabled;
  final DateTime? lastPolledAt;
  final String? lastError;
  final DateTime updatedAt;

  const CarrierCredential({
    required this.carrierId,
    required this.apiKeyLast4,
    required this.enabled,
    required this.updatedAt,
    this.lastPolledAt,
    this.lastError,
  });

  factory CarrierCredential.fromSupabase(Map<String, dynamic> row) =>
      CarrierCredential(
        carrierId: row['carrier_id'] as String,
        apiKeyLast4: row['api_key_last4'] as String? ?? '',
        enabled: row['enabled'] as bool? ?? true,
        lastPolledAt: row['last_polled_at'] != null
            ? DateTime.parse(row['last_polled_at'] as String)
            : null,
        lastError: row['last_error'] as String?,
        updatedAt: row['updated_at'] != null
            ? DateTime.parse(row['updated_at'] as String)
            : DateTime.now().toUtc(),
      );

  /// Anzeige-Maskierung `••••••••<last4>`. Nutzt fixe Punktanzahl, damit
  /// die Länge nicht auf den Original-Key schließen lässt.
  String get masked => '••••••••${apiKeyLast4.padLeft(4, '·')}';
}

/// Set der Carrier-IDs, die der `tracking-poll`-Edge-Function bekannt sind.
/// Spiegelt die `CHECK`-Constraint der Migration wider.
const supportedCarrierIds = <String>{'dhl', 'dpd', 'ups'};

/// Carrier-IDs, die in der UI aktuell konfigurierbar sind. DPD und UPS
/// bleiben backend-seitig unterstützt (siehe `supportedCarrierIds` und die
/// CHECK-Constraint in `workspace_carrier_credentials.carrier_id`),
/// werden im Settings-Screen aber als „Bald verfügbar" gerendert, bis
/// die produktive Anbindung steht. Reaktivierung = Eintrag hier ergänzen.
const enabledCarrierIds = <String>{'dhl'};

/// Anzeigelabel pro Carrier-ID. Wird in den Settings-Screens genutzt.
String labelForCarrierId(String id) => switch (id) {
      'dhl' => 'DHL',
      'dpd' => 'DPD',
      'ups' => 'UPS',
      _ => id.toUpperCase(),
    };
