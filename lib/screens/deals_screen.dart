import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../widgets/buyer_legend.dart';
import '../widgets/deal_table.dart';
import '../widgets/summary_panel.dart';

class DealsScreen extends StatelessWidget {
  final ValueChanged<String>? onOpenTicket;
  const DealsScreen({super.key, this.onOpenTicket});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: DealTable(onOpenTicket: onOpenTicket)),
        if (MediaQuery.of(context).size.width >= 1100)
          Container(
            width: 292,
            decoration: BoxDecoration(
              color: AppTheme.bgSubtleOf(context),
              border: Border(
                left: BorderSide(color: AppTheme.borderOf(context)),
              ),
            ),
            child: const SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(14, 14, 14, 100),
              child: Column(
                children: [
                  BuyerLegend(),
                  SizedBox(height: 12),
                  SummaryPanel(),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
