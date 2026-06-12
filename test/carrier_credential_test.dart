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
      // DPD zurückgestuft auf Coming Feature (2026-06-11): Pull ist durch
      // DPDs TLS-Bot-Schutz unmöglich, der offizielle Push Service braucht
      // ein DPD-Geschäftskonto (nicht vorhanden). Webhook dpd-push liegt
      // bereit. Wenn dieser Test fehlschlägt, war wahrscheinlich ein
      // DPD-/UPS-Rollout — Registry (carriers.ts) + Test anpassen.
      expect(enabledCarrierIds, equals({'dhl'}));
    });
  });
}
