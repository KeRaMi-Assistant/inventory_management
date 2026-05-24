import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/inventory_provider.dart';
import 'add_edit_buyer_dialog.dart';

class BuyerLegend extends StatelessWidget {
  const BuyerLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final buyers = provider.buyers.where((b) => b.active).toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.people_outline,
                        size: 16, color: AppTheme.textMutedOf(context)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.buyerLegendTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const AddEditBuyerDialog(),
                      ),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentLightOf(context),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: AppTheme.accentBorderOf(context)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add,
                                size: 13,
                                color: AppTheme.accentTextOf(context)),
                            const SizedBox(width: 3),
                            Text(
                              l10n.actionAdd,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentTextOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (buyers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      l10n.buyersEmpty,
                      style: TextStyle(
                          color: AppTheme.textMutedOf(context), fontSize: 12),
                    ),
                  )
                else ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: AppTheme.borderOf(context)),
                  const SizedBox(height: 8),
                  ...buyers.map((b) {
                    final count =
                        provider.deals.where((d) => d.buyer == b.name).length;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: b.buyerCellColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              b.name,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryOf(context)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.bgSubtleOf(context),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondaryOf(context)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => AddEditBuyerDialog(buyer: b),
                            ),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(Icons.edit_outlined,
                                  size: 13,
                                  color: AppTheme.textMutedOf(context)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
