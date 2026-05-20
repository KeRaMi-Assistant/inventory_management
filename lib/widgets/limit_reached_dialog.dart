import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/billing_provider.dart';
import '../screens/pricing_screen.dart';

/// AlertDialog — informiert den User, dass er sein Plan-Limit an Workspaces
/// erreicht hat, und bietet einen direkten Weg zum Pricing-Screen an.
///
/// Kein Bottom-Sheet, weil es eine kurze Info ohne Input ist (Pflicht-Pattern
/// aus dem Implementierungs-Plan §T13).
class LimitReachedDialog extends StatelessWidget {
  const LimitReachedDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const LimitReachedDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final billing = Provider.of<BillingProvider>(context, listen: false);
    final plan = billing.currentPlan;
    final limit = plan.workspaceLimit;

    return AlertDialog(
      key: const Key('limit-reached-dialog'),
      title: Text(l10n.teamWorkspacesLimitReachedTitle),
      content: Text(
        l10n.teamWorkspacesLimitReachedBody(plan.label, limit),
      ),
      actions: [
        TextButton(
          key: const Key('limit-reached-cancel-btn'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('limit-reached-upgrade-btn'),
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PricingScreen()),
            );
          },
          child: Text(l10n.teamWorkspacesLimitReachedCta),
        ),
      ],
    );
  }
}
