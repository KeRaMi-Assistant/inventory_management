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
    // Phase A (T1.4a) — Bug-Fix: vorher `MediaQuery.of(context).size.width`
    // (Viewport-Breite inkl. Sidebar), jetzt `LayoutBuilder` mit
    // `constraints.maxWidth` (Container-Breite des Body ohne Sidebar).
    //
    // Verhaltensänderung (bewusst, Bug-Fix): Bei einem 1300-px-Viewport mit
    // 220-px-Sidebar → 1080-px-Body verschwindet das Summary-Panel jetzt
    // korrekt, weil 1080 < Breakpoints.legacyShellExtended (1100).
    // Vorher erschien es fälschlicherweise, da 1300 >= 1100 (Viewport).
    // Schwelle bleibt identisch (1100 via legacyShellExtended) — Konsolidierung
    // auf Breakpoints.master (1200) erfolgt in Phase B / T1.4b.
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: DealTable(onOpenTicket: onOpenTicket)),
            if (constraints.maxWidth >= Breakpoints.legacyShellExtended)
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
