import 'package:flutter/material.dart';

/// Versanddienstleister, die der Detector kennt. Fokus liegt auf dem
/// deutschen Markt (DHL, DPD, Hermes, GLS, UPS, Deutsche Post).
enum Carrier {
  dhl,
  dhlExpress,
  ups,
  dpd,
  gls,
  hermes,
  deutschePost,
  amazon,
  unknown;

  String get label => switch (this) {
        Carrier.dhl => 'DHL',
        Carrier.dhlExpress => 'DHL Express',
        Carrier.ups => 'UPS',
        Carrier.dpd => 'DPD',
        Carrier.gls => 'GLS',
        Carrier.hermes => 'Hermes',
        Carrier.deutschePost => 'Deutsche Post',
        Carrier.amazon => 'Amazon',
        Carrier.unknown => 'Unbekannt',
      };

  /// Kurze 3–4-stellige Kennung für kompakte Chip-Darstellungen.
  String get short => switch (this) {
        Carrier.dhl => 'DHL',
        Carrier.dhlExpress => 'DHLX',
        Carrier.ups => 'UPS',
        Carrier.dpd => 'DPD',
        Carrier.gls => 'GLS',
        Carrier.hermes => 'HER',
        Carrier.deutschePost => 'POST',
        Carrier.amazon => 'AMZ',
        Carrier.unknown => '?',
      };

  /// Markenfarbe für die Pille. Bewusst dezent gehalten, damit das Chip nicht
  /// die übrigen Meta-Pillen überstrahlt.
  Color get color => switch (this) {
        Carrier.dhl || Carrier.dhlExpress => const Color(0xFFFFCC00),
        Carrier.ups => const Color(0xFF8B5A2B),
        Carrier.dpd => const Color(0xFF7C2D8C),
        Carrier.gls => const Color(0xFF1A4490),
        Carrier.hermes => const Color(0xFF005CA9),
        Carrier.deutschePost => const Color(0xFFFFCC00),
        Carrier.amazon => const Color(0xFF232F3E),
        Carrier.unknown => const Color(0xFF94A3B8),
      };

  /// Carrier, die in einem Override-Menü angeboten werden (alle außer
  /// `unknown`).
  static List<Carrier> get pickable =>
      Carrier.values.where((c) => c != Carrier.unknown).toList(growable: false);
}

/// Erkennt aus einer Tracking-Nummer den vermutlichen Carrier und baut bei
/// Bedarf die passende Tracking-URL. Komplett offline — die URL wird erst auf
/// Klick gebaut, daher praktisch kostenlos.
class CarrierService {
  CarrierService._();

  // ── Pattern ────────────────────────────────────────────────────────────────

  // UPS: 1Z gefolgt von 16 alphanumerischen Zeichen.
  static final _ups = RegExp(r'^1Z[0-9A-Z]{16}$');
  // Deutsche Post International: zwei Buchstaben + 9 Ziffern + zwei Buchstaben (z. B. RR123456789DE).
  static final _post = RegExp(r'^[A-Z]{2}\d{9}[A-Z]{2}$');
  // Hermes mit 'H'-Prefix (älteres Format).
  static final _hermesH = RegExp(r'^H\d{10,}$');
  // Amazon Logistics nur für 'TBA' + 12 Ziffern. Das ist die einzige
  // Format-ID, die Amazons öffentlicher Tracker (`track.amazon.com`)
  // tatsächlich auflöst. Andere Marketplace-Formate wie 'DE…' sind in
  // Wirklichkeit Carrier-IDs (meistens DHL) — Amazon selbst kann sie
  // weder via track.amazon.com noch via Bestellsuche finden.
  static final _amazon = RegExp(r'^TBA\d{12}$');
  // Amazon Tracking-URLs (Order-Detail / Ship-Track-Seite). Country-TLD wird
  // in Capture-Group 1 gefangen, z. B. `fr` aus `https://www.amazon.fr/...`.
  static final _amazonHostUrl = RegExp(
    r'^https?://(?:[^/]*\.)?amazon\.([a-z]{2,3}(?:\.[a-z]{2,3})?)(?:/|$)',
    caseSensitive: false,
  );
  // Globaler AMZL-Tracker (`track.amazon.com`, kein Country-Account).
  static final _amazonTrackUrl = RegExp(
    r'^https?://(?:[^/]*\.)?track\.amazon\.[a-z.]+(?:/|$)',
    caseSensitive: false,
  );
  // Reine Ziffernfolge.
  static final _digits = RegExp(r'^\d+$');

  /// Normalisiert die Eingabe (Trim, alle Whitespaces raus, Uppercase) damit
  /// die Pattern auch bei kopiertem Text greifen.
  static String _normalize(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();

  /// Versucht den Carrier zu bestimmen. Bei Mehrdeutigkeit (typisch
  /// 14-stellig in DE) wird DHL gewählt — der Nutzer kann via Long-Press
  /// einen anderen Carrier setzen.
  static Carrier detect(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return Carrier.unknown;
    // URL-Tracking: erst Amazon-Hosts prüfen, bevor wir die Eingabe in
    // Uppercase normalisieren — Hostname-Matching ist case-insensitive
    // via Regex-Flag.
    if (_amazonHostUrl.hasMatch(trimmed) ||
        _amazonTrackUrl.hasMatch(trimmed)) {
      return Carrier.amazon;
    }
    final v = _normalize(trimmed);
    if (_amazon.hasMatch(v)) return Carrier.amazon;
    if (_ups.hasMatch(v)) return Carrier.ups;
    if (_post.hasMatch(v)) return Carrier.deutschePost;
    if (_hermesH.hasMatch(v)) return Carrier.hermes;
    if (!_digits.hasMatch(v)) return Carrier.unknown;
    switch (v.length) {
      case 10:
        // 10-stellige reine Ziffernfolge ist in DE typisch DHL Express AWB.
        return Carrier.dhlExpress;
      case 11:
        return Carrier.gls;
      case 12:
      case 13:
      case 14:
      case 15:
      case 16:
      case 17:
      case 18:
      case 19:
      case 20:
      case 22:
        // Mehrdeutige Längen (vor allem 14/16 Ziffern). DHL dominiert den DE-
        // Markt, daher Default DHL; Long-Press öffnet den Carrier-Picker.
        return Carrier.dhl;
      default:
        return Carrier.unknown;
    }
  }

  /// Baut die Carrier-URL. Wenn die Tracking-Nummer schon eine vollständige
  /// URL ist (z. B. weil der Nutzer den Link direkt kopiert hat), wird die
  /// unverändert zurückgegeben.
  ///
  /// `amazonCountry` (z. B. 'de', 'fr', 'it', 'es', 'co.uk', 'com') wirkt nur
  /// für `Carrier.amazon` und steuert, in welchem Amazon-Account die
  /// Bestellsuche geöffnet wird. Ohne Override wird .de genutzt.
  static String urlFor(
    Carrier carrier,
    String tracking, {
    String? amazonCountry,
  }) {
    final raw = tracking.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final n = Uri.encodeQueryComponent(raw);
    return switch (carrier) {
      Carrier.dhl =>
        'https://www.dhl.de/de/privatkunden/pakete-empfangen/verfolgen.html?piececode=$n',
      Carrier.dhlExpress =>
        'https://www.dhl.com/de-de/home/tracking/tracking-express.html?submit=1&tracking-id=$n',
      Carrier.ups => 'https://www.ups.com/track?loc=de_DE&tracknum=$n',
      Carrier.dpd =>
        'https://tracking.dpd.de/parcelstatus?query=$n&locale=de_DE',
      Carrier.gls => 'https://gls-group.com/DE/de/paketverfolgung?match=$n',
      Carrier.hermes =>
        'https://www.myhermes.de/empfangen/sendungsverfolgung/sendungsinformation?sendungsnummer=$n',
      Carrier.deutschePost =>
        'https://www.deutschepost.de/sendung/simpleQueryResult.html?form.sendungsnummer=$n',
      Carrier.amazon => _amazonUrl(raw, n, amazonCountry),
      Carrier.unknown => 'https://www.google.com/search?q=$n',
    };
  }

  /// Convenience: erkennt und baut die URL in einem Schritt. Wird typischer
  /// Weise erst on-tap aufgerufen.
  static String resolveUrl(String tracking) =>
      urlFor(detect(tracking), tracking);

  /// Routet Amazon-Sendungen je nach ID-Format und gewähltem Country auf
  /// das beste Endziel.
  ///
  /// Wichtig: Amazons öffentliche Bestellsuche (`?search=`) ist **nicht**
  /// nach Tracking-ID indexiert — sie sucht nur Produkttitel,
  /// Bestellnummer, Adresse oder Empfänger. Wir öffnen daher nur die
  /// Bestellhistorie-Wurzel im jeweiligen Country-Account und kopieren die
  /// Tracking-ID als Hilfestellung in die Zwischenablage (siehe Chip).
  ///
  /// • TBA-Format ohne Country → `track.amazon.com/tracking/{id}` (globaler
  ///   AMZL-Tracker, kein Login nötig, zeigt echte Sendungsverfolgung).
  /// • Country gesetzt → `amazon.{tld}/your-orders` (Bestellhistorie des
  ///   gewählten Accounts; Nutzer findet die Bestellung per Datum/Produkt).
  /// • Default ohne Country & ohne TBA → amazon.de Bestellhistorie.
  static String _amazonUrl(String raw, String encoded, String? country) {
    if (country == null && _amazon.hasMatch(_normalize(raw))) {
      return 'https://track.amazon.com/tracking/$encoded';
    }
    final tld = country ?? 'de';
    return 'https://www.amazon.$tld/gp/your-account/order-history';
  }
}

/// Bekannte Amazon-Country-Domains für den Long-Press-Picker. Schlüssel ist
/// das TLD-Fragment (`de`, `fr`, `co.uk`, …), Wert ein menschlicher Label.
const amazonCountryOptions = <String, String>{
  'de': 'Deutschland',
  'com': 'International (.com)',
  'fr': 'France',
  'it': 'Italia',
  'es': 'España',
  'co.uk': 'United Kingdom',
  'nl': 'Nederland',
  'pl': 'Polska',
  'se': 'Sverige',
};

/// Gibt das Amazon-Country-TLD (`'de'`, `'fr'`, `'co.uk'` …) zurück, wenn der
/// übergebene Shop als Amazon-Variante identifizierbar ist. Bevorzugt wird
/// der Suffix nach dem letzten `-` im Shop-Namen (`Amazon-FR` → `fr`,
/// `Amazon-CO.UK` → `co.uk`); fällt sonst auf das `region`-Feld zurück, damit
/// alte Shops ohne Suffix weiter funktionieren. Sonst `null`.
///
/// Genutzt vom TrackingChip, um den Country-Picker zu überspringen, wenn
/// der Deal einem Amazon-Shop mit eindeutigem Land zugeordnet ist.
String? amazonCountryFromShop({
  required String? shopName,
  required String? region,
}) {
  if (shopName == null) return null;
  final name = shopName.trim();
  if (!name.toLowerCase().startsWith('amazon')) return null;
  // Suffix nach dem letzten '-' priorisieren (Amazon-FR, Amazon-CO.UK).
  final dashIdx = name.lastIndexOf('-');
  if (dashIdx > 0 && dashIdx < name.length - 1) {
    final suffix = name.substring(dashIdx + 1).trim().toLowerCase();
    if (amazonCountryOptions.containsKey(suffix)) return suffix;
  }
  // Region-Fallback für Bestandsshops, die per Dropdown gepflegt wurden.
  final r = region?.trim().toLowerCase();
  if (r == null || r.isEmpty) return null;
  return amazonCountryOptions.containsKey(r) ? r : null;
}

/// Liest das Amazon-Country-TLD aus einer Tracking-URL aus, z. B.
/// `https://www.amazon.fr/-/en/gp/your-account/ship-track?...` → `'fr'`.
/// Liefert `null`, wenn das Tracking keine Amazon-Country-URL ist (z. B.
/// `track.amazon.com` ohne Country oder gar keine URL).
String? amazonCountryFromTracking(String tracking) {
  final raw = tracking.trim();
  // `track.amazon.{tld}` ist der globale AMZL-Tracker (kein Country-
  // Account). Ohne diese Vorabprüfung würde die folgende Regex aus
  // `track.amazon.com` fälschlich `com` als Country zurückliefern.
  if (CarrierService._amazonTrackUrl.hasMatch(raw)) return null;
  final m = CarrierService._amazonHostUrl.firstMatch(raw);
  if (m == null) return null;
  final tld = m.group(1)?.toLowerCase();
  return amazonCountryOptions.containsKey(tld) ? tld : null;
}

/// Vordefinierte Versanddienst-Suppliers, die per Knopfdruck in die
/// Lieferanten-Liste eingefügt werden können (siehe `SuppliersScreen`).
/// Name ist eindeutig — beim Seeden überspringen wir Duplikate (case-
/// insensitive nach Name).
class CarrierSupplierSeed {
  const CarrierSupplierSeed({required this.name, required this.website});
  final String name;
  final String website;
}

/// Vordefinierte Amazon-Country-Shops, die per Knopfdruck idempotent in die
/// Shop-Liste eingefügt werden können (siehe Settings → Shops). Name folgt
/// dem Schema `Amazon-<TLD-uppercase>`; das `region`-Feld bekommt das TLD in
/// Lowercase, damit alte Code-Pfade, die noch über die Region routen, weiter
/// funktionieren.
class AmazonShopSeed {
  const AmazonShopSeed({required this.name, required this.region});
  final String name;
  final String region;
}

const amazonShopSeeds = <AmazonShopSeed>[
  AmazonShopSeed(name: 'Amazon-DE', region: 'de'),
  AmazonShopSeed(name: 'Amazon-COM', region: 'com'),
  AmazonShopSeed(name: 'Amazon-FR', region: 'fr'),
  AmazonShopSeed(name: 'Amazon-IT', region: 'it'),
  AmazonShopSeed(name: 'Amazon-ES', region: 'es'),
  AmazonShopSeed(name: 'Amazon-CO.UK', region: 'co.uk'),
  AmazonShopSeed(name: 'Amazon-NL', region: 'nl'),
  AmazonShopSeed(name: 'Amazon-PL', region: 'pl'),
  AmazonShopSeed(name: 'Amazon-SE', region: 'se'),
];

const carrierSupplierSeeds = <CarrierSupplierSeed>[
  CarrierSupplierSeed(name: 'DHL', website: 'https://www.dhl.de'),
  CarrierSupplierSeed(
      name: 'DHL Express', website: 'https://www.dhl.com/de-de/home.html'),
  CarrierSupplierSeed(name: 'UPS', website: 'https://www.ups.com/de'),
  CarrierSupplierSeed(name: 'DPD', website: 'https://www.dpd.com/de/de/'),
  CarrierSupplierSeed(name: 'GLS', website: 'https://gls-group.com/DE/de/'),
  CarrierSupplierSeed(name: 'Hermes', website: 'https://www.myhermes.de'),
  CarrierSupplierSeed(
      name: 'Deutsche Post', website: 'https://www.deutschepost.de'),
  CarrierSupplierSeed(name: 'Amazon', website: 'https://www.amazon.de'),
];
