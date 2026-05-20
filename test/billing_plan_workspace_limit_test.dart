import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/billing_profile.dart';

void main() {
  group('BillingPlan.workspaceLimit', () {
    test('free = 1', () => expect(BillingPlan.free.workspaceLimit, 1));
    test('solo = 1', () => expect(BillingPlan.solo.workspaceLimit, 1));
    test('soloPro = 2', () => expect(BillingPlan.soloPro.workspaceLimit, 2));
    test('team = 5', () => expect(BillingPlan.team.workspaceLimit, 5));
    test('business = 20', () => expect(BillingPlan.business.workspaceLimit, 20));
    test('enterprise = -1 (unlimited)',
        () => expect(BillingPlan.enterprise.workspaceLimit, -1));

    test('rank ordering matches workspace-limit ordering for finite tiers', () {
      // Higher rank → at least as many workspaces (except enterprise = -1 sentinel).
      for (final a in [
        BillingPlan.free,
        BillingPlan.solo,
        BillingPlan.soloPro,
        BillingPlan.team,
        BillingPlan.business,
      ]) {
        for (final b in [
          BillingPlan.free,
          BillingPlan.solo,
          BillingPlan.soloPro,
          BillingPlan.team,
          BillingPlan.business,
        ]) {
          if (a.rank < b.rank) {
            expect(a.workspaceLimit <= b.workspaceLimit, isTrue,
                reason: 'lower rank ${a.name} should have ≤ limit than ${b.name}');
          }
        }
      }
    });
  });
}
