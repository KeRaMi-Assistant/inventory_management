import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/services/carrier_service.dart';

/// Validiert die Amazon-HTML-Fixtures, die der Deno-Adapter
/// (`supabase/functions/_shared/inbox_adapters.ts`) konsumiert.
///
/// Die eigentliche Tracking-Extraktion läuft in Deno — diese Tests
/// stellen sicher, dass:
///   1. Alle Fixtures existieren und nicht leer sind.
///   2. Jede Versand-Fixture enthält die erwartete Tracking-Nr (in Body
///      oder href) — sonst kann der Adapter nichts extrahieren.
///   3. Die Tracking-Nrn werden vom Carrier-Service korrekt klassifiziert
///      (Sanity-Check, dass die Fixture-Werte realistisch sind).
///
/// Deno-Test-Datei: `supabase/functions/_shared/amazon_html_test.ts`
/// (deckt die eigentliche Adapter-Logik ab).
void main() {
  group('Amazon HTML Fixtures', () {
    late Directory fixturesDir;

    setUpAll(() {
      fixturesDir = Directory('test/fixtures');
      expect(fixturesDir.existsSync(), isTrue,
          reason: 'test/fixtures/ muss existieren');
    });

    File fixture(String name) => File('${fixturesDir.path}/$name');

    test('alle 9 Pflicht-Fixtures sind vorhanden', () {
      const required = [
        'amazon_de_shipped_dhl.html',
        'amazon_de_shipped_amazon_logistics.html',
        'amazon_de_shipped_amazon_progress_only.html',
        'amazon_com_shipped_ups.html',
        'amazon_fr_shipped_chronopost.html',
        'amazon_it_shipped_amazon_logistics.html',
        'amazon_es_shipped_seur.html',
        'amazon_uk_shipped_dpd.html',
        'amazon_de_order_confirmation.html',
      ];
      for (final name in required) {
        final f = fixture(name);
        expect(f.existsSync(), isTrue,
            reason: 'Fixture fehlt: $name');
        expect(f.lengthSync(), greaterThan(200),
            reason: 'Fixture zu klein/leer: $name');
      }
    });

    test('DHL-Fixture enthält 20-stellige DHL-Tracking-Nr', () {
      final body = fixture('amazon_de_shipped_dhl.html').readAsStringSync();
      const expected = '00340434202012345678';
      expect(body.contains(expected), isTrue);
      // Carrier-Service sollte diese 20-stellige Nr als DHL klassifizieren
      // (über reine Ziffernlänge greift Pattern für 20-22 Digits).
      // _digits-Length-Branch: 20 → DHL/Allgemein.
      expect(CarrierService.detect(expected), isNot(equals(Carrier.unknown)));
    });

    test('Amazon-Logistics-Fixture enthält TBA + track.amazon.de', () {
      final body =
          fixture('amazon_de_shipped_amazon_logistics.html').readAsStringSync();
      expect(body.contains('TBA987654321098'), isTrue);
      expect(body.contains('track.amazon.de'), isTrue);
      expect(CarrierService.detect('TBA987654321098'), Carrier.amazon);
    });

    test('UPS-Fixture: 1Z-Tracking + ups.com tracknum-Param', () {
      final body = fixture('amazon_com_shipped_ups.html').readAsStringSync();
      expect(body.contains('1Z999AA10123456784'), isTrue);
      expect(body.contains('tracknum=1Z999AA10123456784'), isTrue);
      expect(CarrierService.detect('1Z999AA10123456784'), Carrier.ups);
    });

    test('Chronopost-Fixture: FR-Label "Numéro de suivi" + chronopost.fr URL',
        () {
      final body =
          fixture('amazon_fr_shipped_chronopost.html').readAsStringSync();
      expect(body.contains('Numéro de suivi'), isTrue);
      expect(body.contains('XJ123456789FR'), isTrue);
      expect(body.contains('chronopost.fr'), isTrue);
      expect(body.contains('listeNumerosLT='), isTrue);
    });

    test('IT-Fixture: TBA + Numero di tracciamento Label', () {
      final body = fixture('amazon_it_shipped_amazon_logistics.html')
          .readAsStringSync();
      expect(body.contains('TBA456789012345'), isTrue);
      expect(body.contains('Numero di tracciamento'), isTrue);
      expect(body.contains('track.amazon.it'), isTrue);
    });

    test('SEUR-Fixture: ES-Label + segOnLine Param', () {
      final body = fixture('amazon_es_shipped_seur.html').readAsStringSync();
      expect(body.contains('Número de seguimiento'), isTrue);
      expect(body.contains('14001122334455'), isTrue);
      expect(body.contains('segOnLine='), isTrue);
    });

    test('DPD-UK-Fixture: track.dpd.co.uk/parcels Pfad', () {
      final body = fixture('amazon_uk_shipped_dpd.html').readAsStringSync();
      expect(body.contains('15501234567890'), isTrue);
      expect(body.contains('track.dpd.co.uk/parcels/'), isTrue);
    });

    String stripComments(String html) =>
        html.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

    test('Progress-Only-Fixture: KEIN Carrier-Link, nur Amazon-Tracker', () {
      final body = stripComments(
          fixture('amazon_de_shipped_amazon_progress_only.html')
              .readAsStringSync());
      // Hat orderId + shipmentId in der URL, aber KEINE bekannte Carrier-URL.
      expect(body.contains('progress-tracker/package'), isTrue);
      expect(body.contains('shipmentId='), isTrue);
      expect(body.contains('dhl.de'), isFalse);
      expect(body.contains('track.amazon.de/tracking/'), isFalse);
      expect(body.contains('1Z'), isFalse);
      expect(body.contains('TBA'), isFalse);
    });

    test('Order-Confirmation-Fixture: nur Order-ID, kein Tracking-Pattern',
        () {
      final body = stripComments(
          fixture('amazon_de_order_confirmation.html').readAsStringSync());
      expect(body.contains('303-7766554-4332211'), isTrue);
      expect(body.contains('TBA'), isFalse);
      expect(body.contains('1Z'), isFalse);
      expect(body.contains('Sendungsnummer'), isFalse);
      expect(body.contains('Tracking'), isFalse);
    });

    test('Distinct Carrier-Coverage: Fixtures decken mind. 5 Carrier ab', () {
      final shippingFixtures = [
        ('amazon_de_shipped_dhl.html', 'DHL'),
        ('amazon_de_shipped_amazon_logistics.html', 'Amazon Logistics'),
        ('amazon_com_shipped_ups.html', 'UPS'),
        ('amazon_fr_shipped_chronopost.html', 'Chronopost'),
        ('amazon_it_shipped_amazon_logistics.html', 'Amazon Logistics'),
        ('amazon_es_shipped_seur.html', 'SEUR'),
        ('amazon_uk_shipped_dpd.html', 'DPD'),
      ];
      final distinctCarriers = shippingFixtures.map((e) => e.$2).toSet();
      expect(distinctCarriers.length, greaterThanOrEqualTo(5),
          reason:
              'Fixtures müssen >= 5 distinct Carrier abdecken (war: $distinctCarriers)');
    });
  });
}
