import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/buyer_legend.dart';
import '../widgets/deal_table.dart';
import '../widgets/summary_panel.dart';

class DealsScreen extends StatelessWidget {
  final ValueChanged<String>? onOpenTicket;
  const DealsScreen({super.key, this.onOpenTicket});

  @override
  Widget build(BuildContext context) {
    // Phase B (T1.4b): Detail-Panel-Schwelle auf `Breakpoints.master` (1200)
    // konsolidiert. Im Band 1100–1199 px Body-Breite verschwindet das
    // Summary-Panel jetzt — die alte 1100-Schwelle war eng für ein 60/40-Split
    // (660/440); 1200 erlaubt 720/480 und entspricht M3-Window-Size-Class
    // „Large".
    //
    // Bug-Fix aus Phase A (T1.4a) bleibt: `LayoutBuilder.constraints.maxWidth`
    // statt `MediaQuery.of(context).size.width` — sonst würde die Viewport-
    // Breite (inkl. Sidebar) statt der Body-Breite geprüft.
    //
    // Verhaltens-Diff zu T1.4a (Plan §5.2): Body-Breite 1100–1199 zeigte
    // vorher das Panel, jetzt erst ab ≥1200.
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: DealTable(onOpenTicket: onOpenTicket)),
            if (isLarge(constraints.maxWidth))
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
      },
    );
  }
}
