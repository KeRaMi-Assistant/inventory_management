import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/statistics_filter_provider.dart';
import '../../../services/statistics_service.dart';
import '../sortable_table.dart';
import '../stat_panel.dart';

class InventorySuppliersTab extends StatelessWidget {
  final StatisticsService stats;
  const InventorySuppliersTab({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final money = NumberFormat.currency(locale: localeTag, symbol: '€');
    final h = stats.inventoryHealth;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatPanel(
          title: l10n.statsHealthHeading,
          icon: Icons.health_and_safety_outlined,
          child: LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth < 480
                  ? 2
                  : c.maxWidth < 800
                      ? 3
                      : 4;
              const gap = 12.0;
              final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
              final cards = <Widget>[
                _HealthCard(
                  label: l10n.statsStockValueEk,
                  value: money.format(h.stockValueEk),
                  icon: Icons.inventory_2_outlined,
                  color: AppTheme.accent,
                ),
                _HealthCard(
                  label: l10n.statsLowStock,
                  value: '${h.lowStock}',
                  icon: Icons.warning_amber_outlined,
                  color: h.lowStock > 0 ? AppTheme.warning : AppTheme.textMuted,
                  hint: '< ${stats.lowStockThreshold}',
                ),
                _HealthCard(
                  label: l10n.statsExpiringSoon,
                  value: '${h.expiringSoon}',
                  icon: Icons.schedule_outlined,
                  color: h.expiringSoon > 0 ? AppTheme.warning : AppTheme.textMuted,
                  hint: l10n.statsExpiringSoonHint,
                ),
                _HealthCard(
                  label: l10n.statsExpired,
                  value: '${h.expired}',
                  icon: Icons.error_outline,
                  color: h.expired > 0 ? AppTheme.danger : AppTheme.textMuted,
                  pulsing: h.expired > 0,
                ),
                _HealthCard(
                  label: l10n.statsDeadStock,
                  value: '${h.deadStock}',
                  icon: Icons.do_not_disturb_alt,
                  color: h.deadStock > 0 ? AppTheme.danger : AppTheme.textMuted,
                  hint: l10n.statsDeadStockHint,
                ),
              ];
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: cards
                    .map((w) => SizedBox(width: cardW, child: w))
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        StatPanel(
          title: l10n.statsSupplierPerformance,
          icon: Icons.local_shipping_outlined,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SortableTable<SupplierStat>(
            rows: stats.supplierStats,
            defaultSortIndex: 3,
            defaultAscending: false,
            onTap: (s) {
              context.read<StatisticsFilterProvider>().setSupplier(s.id);
            },
            columns: [
              SortableColumn(
                label: l10n.inventoryColSupplier,
                builder: (s) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: s.active ? AppTheme.success : AppTheme.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(s.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                valueOf: (s) => s.name.toLowerCase(),
              ),
              SortableColumn(
                label: l10n.statsItems,
                numeric: true,
                builder: (s) => Text('${s.itemCount}'),
                valueOf: (s) => s.itemCount,
              ),
              SortableColumn(
                label: l10n.statsStockValueShort,
                numeric: true,
                builder: (s) => Text(money.format(s.stockValue)),
                valueOf: (s) => s.stockValue,
              ),
              SortableColumn(
                label: l10n.statsAvgEk,
                numeric: true,
                builder: (s) => Text(money.format(s.avgEk)),
                valueOf: (s) => s.avgEk,
              ),
              SortableColumn(
                label: l10n.statsLabelProfit,
                numeric: true,
                builder: (s) => Text(
                  money.format(s.profit),
                  style: TextStyle(
                    color: s.profit >= 0 ? AppTheme.success : AppTheme.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                valueOf: (s) => s.profit,
              ),
              SortableColumn(
                label: l10n.statsLabelMargin,
                numeric: true,
                builder: (s) => Text('${s.marginPct.toStringAsFixed(1)}%'),
                valueOf: (s) => s.marginPct,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HealthCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? hint;
  final bool pulsing;
  const _HealthCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.hint,
    this.pulsing = false,
  });

  @override
  State<_HealthCard> createState() => _HealthCardState();
}

class _HealthCardState extends State<_HealthCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final pulse = widget.pulsing
            ? Tween<double>(begin: 0.65, end: 1.0).evaluate(_ctrl)
            : 1.0;
        return Opacity(opacity: pulse, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgSurfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.color.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(widget.icon, size: 16, color: widget.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMutedOf(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: widget.color,
              ),
            ),
            if (widget.hint != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.hint!,
                style: TextStyle(
                    fontSize: 10, color: AppTheme.textDisabledOf(context)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
