import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/utils/carrier_links.dart';

void main() {
  group('carrierTrackingUrl', () {
    test('DHL/DPD/UPS/GLS liefern URL mit encodeter Tracking-Nr', () {
      expect(
        carrierTrackingUrl('dhl', 'JJD0123456789012345'),
        contains('piececode=JJD0123456789012345'),
      );
      expect(
        carrierTrackingUrl('dpd', '05001234567890'),
        contains('/parcel/05001234567890'),
      );
      expect(
        carrierTrackingUrl('ups', '1Z999AA10123456784'),
        contains('tracknum=1Z999AA10123456784'),
      );
      expect(
        carrierTrackingUrl('gls', '11766771249246689455'),
        contains('match=11766771249246689455'),
      );
    });

    test('Amazon Logistics + unbekannte Carrier → null', () {
      expect(carrierTrackingUrl('amazon', 'TBA123456789012'), isNull);
      expect(carrierTrackingUrl('foo', '123'), isNull);
      expect(carrierTrackingUrl(null, '123'), isNull);
    });

    test('leeres/null Tracking → null', () {
      expect(carrierTrackingUrl('dhl', ''), isNull);
      expect(carrierTrackingUrl('dhl', '   '), isNull);
      expect(carrierTrackingUrl('dhl', null), isNull);
    });

    test('Sonderzeichen werden URL-encoded', () {
      expect(
        carrierTrackingUrl('dhl', 'A B&C'),
        contains('piececode=A%20B%26C'),
      );
    });
  });

  group('carrierDisplayName', () {
    test('bekannte Carrier → kuratierte Labels', () {
      expect(carrierDisplayName('dhl'), 'DHL');
      expect(carrierDisplayName('amazon'), 'Amazon Logistics');
      expect(carrierDisplayName('gls'), 'GLS');
    });

    test('null → null, unbekannt → uppercase Fallback', () {
      expect(carrierDisplayName(null), isNull);
      expect(carrierDisplayName('xyz'), 'XYZ');
    });
  });
}
