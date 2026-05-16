import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/carrier_credential.dart';

void main() {
  group('carrier_credential constants', () {
    test('enabledCarrierIds is a subset of supportedCarrierIds', () {
      for (final id in enabledCarrierIds) {
        expect(supportedCarrierIds.contains(id), isTrue,
            reason: 'enabledCarrierIds enthält $id, das nicht in '
                'supportedCarrierIds steht — Backend würde Save ablehnen.');
      }
    });

    test('enabledCarrierIds currently contains only dhl', () {
      // Wenn dieser Test fehlschlägt, war wahrscheinlich ein DPD/UPS-
      // Rollout — bitte Plan-Doku updaten und Test anpassen.
      expect(enabledCarrierIds, equals({'dhl'}));
    });
  });
}
