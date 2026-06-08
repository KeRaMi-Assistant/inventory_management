import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'activity_screen.dart';
import 'main_tab.dart';
import 'statistics_screen.dart';

/// Auswertung-Sektion (Tier-2b, T2.6).
///
/// Bündelt [MainTab.stats] (Statistik, Default) und [MainTab.activity]
/// (Aktivität) unter einem `SegmentedButton`. `StatisticsScreen` bleibt
/// bewusst nicht-embeddable (Plan §5 Scope-Grenze, Tier 3) — es wird hier
/// als Vollbild-Body gerendert.
///
/// State (aktiver Sub-Tab) lebt im Owner (`main_screen.dart`).
class AnalyticsSectionScreen extends StatelessWidget {
  /// Aktiver Sub-Tab — stats oder activity.
  final MainTab activeTab;

  /// Callback bei Sub-Tab-Wechsel (liefert stats/activity).
  final ValueChanged<MainTab> onSelectSubTab;

  const AnalyticsSectionScreen({
    super.key,
    required this.activeTab,
    required this.onSelectSubTab,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Defensiver Fallback: alles außer activity → stats.
    final effective =
        activeTab == MainTab.activity ? MainTab.activity : MainTab.stats;

    final body = effective == MainTab.activity
        ? const ActivityScreen()
        : const StatisticsScreen();

    return Column(
      key: const Key('analyticsSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SegmentedButton<MainTab>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                expandedInsets: constraints.maxWidth < 600
                    ? EdgeInsets.zero
                    : null,
                showSelectedIcon: false,
                segments: [
                  ButtonSegment<MainTab>(
                    value: MainTab.stats,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const KeyedSubtree(
                          key: Key('analyticsSeg-stats'),
                          child: Icon(Icons.bar_chart_outlined, size: 16),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l10n.navStatistics,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ButtonSegment<MainTab>(
                    value: MainTab.activity,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const KeyedSubtree(
                          key: Key('analyticsSeg-activity'),
                          child: Icon(Icons.history_outlined, size: 16),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l10n.navActivity,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                selected: {effective},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) onSelectSubTab(selection.first);
                },
              );
            },
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
