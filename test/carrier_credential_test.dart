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

    test('enabledCarrierIds currently contains dhl + dpd', () {
      // DPD-Rollout Paket 2 (plans/2026-06-10_state_of_the_art_tracking_
      // roadmap.md): Poll-Adapter existierte schon, UI ist jetzt frei.
      // Wenn dieser Test fehlschlägt, war wahrscheinlich ein UPS-Rollout —
      // bitte Registry (supabase/functions/_shared/carriers.ts) + Test
      // anpassen.
      expect(enabledCarrierIds, equals({'dhl', 'dpd'}));
    });
  });
}
