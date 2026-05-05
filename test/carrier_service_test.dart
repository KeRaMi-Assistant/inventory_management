import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/services/carrier_service.dart';

void main() {
  group('CarrierService.detect', () {
    test('UPS 1Z…', () {
      expect(CarrierService.detect('1Z999AA10123456784'), Carrier.ups);
      expect(CarrierService.detect('1z999aa10123456784'), Carrier.ups);
    });
    test('Deutsche Post LL+9+LL', () {
      expect(CarrierService.detect('RR123456789DE'), Carrier.deutschePost);
    });
    test('Hermes mit H-Prefix', () {
      expect(CarrierService.detect('H1003123456789012'), Carrier.hermes);
    });
    test('Amazon AMZL TBA+12 → Carrier.amazon', () {
      expect(CarrierService.detect('TBA123456789012'), Carrier.amazon);
      expect(CarrierService.detect('tba123456789012'), Carrier.amazon);
    });
    test('DE+Ziffern → DHL (echter Carrier; Amazons Tracker findet das nicht)', () {
      expect(CarrierService.detect('DE5435294918'), Carrier.dhl);
      expect(CarrierService.detect('DE12345678'), Carrier.dhl);
    });
    test('Deutsche Post LL+9+LL bleibt erkannt (kollidiert nicht mit DE-DHL)', () {
      // Das DHL-DE-Pattern verlangt Ziffern bis zum Ende; Deutsche Post hat
      // zwei Buchstaben am Ende und matcht deshalb nicht.
      expect(CarrierService.detect('DE123456789DE'), Carrier.deutschePost);
    });
    test('DHL Express = 10 Ziffern', () {
      expect(CarrierService.detect('1234567890'), Carrier.dhlExpress);
    });
    test('GLS = 11 Ziffern', () {
      expect(CarrierService.detect('12345678901'), Carrier.gls);
    });
    test('DHL national = 12 Ziffern', () {
      expect(CarrierService.detect('123456789012'), Carrier.dhl);
    });
    test('14 Ziffern → DHL Default (mehrdeutig)', () {
      expect(CarrierService.detect('12345678901234'), Carrier.dhl);
    });
    test('20 Ziffern (DHL modern)', () {
      expect(CarrierService.detect('00340434161094019748'), Carrier.dhl);
    });
    test('Müll → unknown', () {
      expect(CarrierService.detect('asdf'), Carrier.unknown);
      expect(CarrierService.detect(''), Carrier.unknown);
    });
    test('Whitespace tolerant', () {
      expect(CarrierService.detect(' 1Z 999 AA1 0123 456 784 '), Carrier.ups);
    });
  });

  group('CarrierService.urlFor', () {
    test('Pass-through bei vollständiger URL', () {
      const u = 'https://example.com/track/X';
      expect(CarrierService.urlFor(Carrier.dhl, u), u);
    });
    test('DHL piececode-Param', () {
      final url = CarrierService.urlFor(Carrier.dhl, '00340434161094019748');
      expect(url, contains('dhl.de'));
      expect(url, contains('piececode=00340434161094019748'));
    });
    test('UPS de_DE locale', () {
      final url = CarrierService.urlFor(Carrier.ups, '1Z999AA10123456784');
      expect(url, contains('ups.com'));
      expect(url, contains('loc=de_DE'));
    });
    test('Amazon TBA-Format → globaler AMZL-Tracker (.com)', () {
      final url = CarrierService.urlFor(Carrier.amazon, 'TBA123456789012');
      expect(url, 'https://track.amazon.com/tracking/TBA123456789012');
    });
    test('Amazon ohne Country-Override + Nicht-TBA → amazon.de Bestellhistorie-Wurzel', () {
      // Amazons Bestellsuche akzeptiert keine Tracking-IDs (nur
      // Produkttitel/Bestellnr./Adresse); deshalb öffnen wir die Order-
      // History-Wurzel statt einer leeren Suchergebnisseite.
      final url = CarrierService.urlFor(Carrier.amazon, 'DE5435294918');
      expect(url, 'https://www.amazon.de/gp/your-account/order-history');
    });
    test('Amazon Country-Override (FR) → amazon.fr Bestellhistorie', () {
      final url = CarrierService.urlFor(
        Carrier.amazon,
        'DE5435294918',
        amazonCountry: 'fr',
      );
      expect(url, 'https://www.amazon.fr/gp/your-account/order-history');
    });
    test('Amazon Country-Override schlägt TBA-Default (UK)', () {
      final url = CarrierService.urlFor(
        Carrier.amazon,
        'TBA123456789012',
        amazonCountry: 'co.uk',
      );
      expect(url, contains('amazon.co.uk/gp/your-account/order-history'));
      expect(url, isNot(contains('track.amazon.com')));
    });
    test('DHL DE-Prefix Tracker-URL', () {
      final url = CarrierService.urlFor(Carrier.dhl, 'DE5435294918');
      expect(url, contains('dhl.de'));
      expect(url, contains('piececode=DE5435294918'));
    });
    test('Amazon-URL → Carrier.amazon (Detection)', () {
      expect(
        CarrierService.detect(
            'https://www.amazon.it/-/de/gp/your-account/ship-track?itemId=abc'),
        Carrier.amazon,
      );
      expect(
        CarrierService.detect(
            'https://www.amazon.fr/-/en/gp/your-account/ship-track?itemId=abc'),
        Carrier.amazon,
      );
      expect(
        CarrierService.detect('https://track.amazon.com/tracking/TBA123'),
        Carrier.amazon,
      );
    });
    test('Amazon-URL → urlFor liefert Original-URL pass-through', () {
      const u =
          'https://www.amazon.fr/-/en/gp/your-account/ship-track?itemId=xyz';
      expect(CarrierService.urlFor(Carrier.amazon, u), u);
    });
  });

  group('amazonCountryFromShop suffix parsing', () {
    test('Suffix "Amazon-FR" → "fr"', () {
      expect(
        amazonCountryFromShop(shopName: 'Amazon-FR', region: ''),
        'fr',
      );
    });
    test('Suffix "Amazon-CO.UK" → "co.uk"', () {
      expect(
        amazonCountryFromShop(shopName: 'Amazon-CO.UK', region: ''),
        'co.uk',
      );
    });
    test('Suffix bevorzugt Region (Suffix gewinnt bei Konflikt)', () {
      expect(
        amazonCountryFromShop(shopName: 'Amazon-IT', region: 'de'),
        'it',
      );
    });
    test('Region-Fallback ohne Suffix (Bestandsshops)', () {
      expect(
        amazonCountryFromShop(shopName: 'Amazon', region: 'de'),
        'de',
      );
    });
    test('Unbekanntes Suffix fällt auf Region zurück', () {
      expect(
        amazonCountryFromShop(shopName: 'Amazon-XX', region: 'fr'),
        'fr',
      );
    });
    test('Nicht-Amazon-Shop liefert null', () {
      expect(
        amazonCountryFromShop(shopName: 'Balenciaga-FR', region: 'fr'),
        null,
      );
    });
  });

  group('amazonCountryFromTracking', () {
    test('Country-Host-URL → TLD', () {
      expect(
        amazonCountryFromTracking(
            'https://www.amazon.fr/-/en/gp/your-account/ship-track?x=1'),
        'fr',
      );
      expect(
        amazonCountryFromTracking('https://www.amazon.co.uk/orders'),
        'co.uk',
      );
    });
    test('track.amazon.com (kein Country) → null', () {
      expect(
        amazonCountryFromTracking('https://track.amazon.com/tracking/TBA1'),
        null,
      );
    });
    test('Nicht-URL liefert null', () {
      expect(amazonCountryFromTracking('TBA123456789012'), null);
      expect(amazonCountryFromTracking('DE5435294918'), null);
    });
  });
}
