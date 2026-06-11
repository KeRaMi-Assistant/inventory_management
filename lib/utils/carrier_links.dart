/// Carrier-Deep-Links + Anzeige-Namen (Paket 1).
///
/// Eine Quelle für "öffne die Sendung auf der Carrier-Webseite" — bewusst
/// ohne Netz-Calls: reine URL-Templates. Amazon Logistics hat keine
/// öffentliche Tracking-Seite → null.
library;

/// Liefert die öffentliche Tracking-URL für [carrier] + [tracking],
/// oder `null` wenn der Carrier keine öffentliche Seite hat / unbekannt ist.
String? carrierTrackingUrl(String? carrier, String? tracking) {
  final t = tracking?.trim();
  if (t == null || t.isEmpty) return null;
  final encoded = Uri.encodeComponent(t);
  return switch (carrier?.toLowerCase()) {
    'dhl' =>
      'https://www.dhl.de/de/privatkunden/dhl-sendungsverfolgung.html?piececode=$encoded',
    'dpd' => 'https://tracking.dpd.de/status/de_DE/parcel/$encoded',
    'ups' => 'https://www.ups.com/track?tracknum=$encoded',
    'gls' => 'https://gls-group.eu/DE/de/paketverfolgung?match=$encoded',
    'hermes' =>
      'https://www.myhermes.de/empfangen/sendungsverfolgung/sendungsinformation#$encoded',
    // Amazon Logistics: Status nur in der Bestellübersicht des Käufers —
    // keine öffentliche Tracking-Seite.
    'amazon' => null,
    _ => null,
  };
}

/// Anzeige-Name für eine Carrier-Id (`'dhl'` → `'DHL'`).
String? carrierDisplayName(String? carrier) => switch (carrier?.toLowerCase()) {
      'dhl' => 'DHL',
      'dpd' => 'DPD',
      'ups' => 'UPS',
      'gls' => 'GLS',
      'hermes' => 'Hermes',
      'amazon' => 'Amazon Logistics',
      null => null,
      _ => carrier!.toUpperCase(),
    };
