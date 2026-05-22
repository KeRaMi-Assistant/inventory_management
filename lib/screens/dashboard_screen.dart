import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/kpi_card.dart';
import 'purchase_orders_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  /// True only on the very first load (no cached data yet).
  /// Re-loads (isLoading=true but data already present) return false so the
  /// existing content stays visible — no layout jank, no race-condition.
  static bool shouldShowSkeleton({
    required bool isLoading,
    required bool hasData,
  }) =>
      isLoading && !hasData;

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final fmt = NumberFormat.currency(locale: localeTag, symbol: '€');
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final hasData = provider.deals.isNotEmpty ||
            provider.inventoryItems.isNotEmpty ||
            provider.buyers.isNotEmpty;
        final showSkeleton = shouldShowSkeleton(
          isLoading: provider.isLoading,
          hasData: hasData,
        );
        // isEmpty for the empty-state card: only show when not loading and no data
        final isEmpty = !hasData && !provider.isLoading;

        return Skeletonizer(
          key: const Key('skeletonLoader'),
          enabled: showSkeleton,
          containersColor: AppTheme.bgSubtleOf(context),
          effect: const SolidColorEffect(),
          enableSwitchAnimation: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isEmpty) const _EmptyStateCard(),
                if (isEmpty) const SizedBox(height: 24),
                _LowStockAlertBlock(criticalCount: provider.criticalStockCount),
                _KpiGrid(provider: provider, fmt: fmt),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth > 960;
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _BuyerOverview(fmt: fmt)),
                          const SizedBox(width: 16),
                          const Expanded(child: _ActivityFeed()),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _BuyerOverview(fmt: fmt),
                        const SizedBox(height: 16),
                        const _ActivityFeed(),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Low-Stock-Alert-Block (D6) ───────────────────────────────────────────

/// Zeigt einen deutlich sichtbaren Warn-Block, wenn Artikel unter
/// Mindestbestand sind. Bei [criticalCount] == 0 wird der Block
/// komplett ausgeblendet (Committee-Empfehlung D5: kein Empty-/Collapsed-State).
class _LowStockAlertBlock extends StatelessWidget {
  final int criticalCount;
  const _LowStockAlertBlock({required this.criticalCount});

  @override
  Widget build(BuildContext context) {
    if (criticalCount == 0) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.warningBgOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.warningBorderOf(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final phone = constraints.maxWidth < 520;
              final info = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.warningTextOf(context),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.lowStockAlertTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.warningTextOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.lowStockAlertBody(criticalCount),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.warningTextOf(context),
                    ),
                  ),
                ],
              );

              final cta = SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  key: const Key('lowStockReorderButton'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    foregroundColor: AppTheme.bgSurfaceOf(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PurchaseOrdersScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                  label: Text(
                    l10n.lowStockReorderAction,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );

              if (phone) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [info, const SizedBox(height: 12), cta],
                );
              }
              return Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 16),
                  cta,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Empty-State (Erst-Login ohne Daten) ──────────────────────────────────

class _EmptyStateCard extends StatefulWidget {
  const _EmptyStateCard();

  @override
  State<_EmptyStateCard> createState() => _EmptyStateCardState();
}

class _EmptyStateCardState extends State<_EmptyStateCard> {
  bool _loading = false;

  Future<void> _loadDemo() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ob = context.read<OnboardingProvider>();
    final activeWs = context.read<ActiveWorkspaceProvider>();
    final inv = context.read<InventoryProvider>();
    final wsId = activeWs.active?.id;
    if (wsId == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.onboardingErrorNoWorkspace)),
      );
      return;
    }
    setState(() => _loading = true);
    final result = await ob.loadDemoData(wsId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.dashboardDemoLoadError(ob.lastError ?? ''))),
      );
      return;
    }
    await inv.loadData();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.dashboardDemoLoadSuccess(result.total))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final phone = constraints.maxWidth < 520;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: AppTheme.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.dashboardEmptyTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.dashboardEmptySubtitle,
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMutedOf(context)),
              ),
            ],
          );
          final cta = SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _loadDemo,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.dataset_outlined),
              label: Text(l10n.dashboardEmptyLoadDemo),
            ),
          );
          if (phone) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 16), cta],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 16),
              cta,
            ],
          );
        },
      ),
    );
  }
}

// ─── Responsive KPI Grid ───────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  final InventoryProvider provider;
  final NumberFormat fmt;
  const _KpiGrid({required this.provider, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kpis = [
      (Icons.shopping_cart_outlined, l10n.dashboardKpiOpenOrders, '${provider.openOrdersCount}', AppTheme.accent),
      (Icons.local_shipping_outlined, l10n.dashboardKpiShipping, '${provider.openDeliveriesCount}', AppTheme.warning),
      (Icons.today_outlined, l10n.dashboardKpiArrivedToday, '${provider.arrivedTodayCount}', AppTheme.info),
      (Icons.trending_up_rounded, l10n.dashboardKpiTotalProfit, fmt.format(provider.totalProfit), AppTheme.success),
      (Icons.account_balance_wallet_outlined, l10n.dashboardKpiOpenAmount, fmt.format(provider.openAmount), AppTheme.warning),
      (Icons.warning_amber_rounded, l10n.dashboardKpiCriticalStock, '${provider.criticalStockCount}', AppTheme.danger),
      (Icons.receipt_long_outlined, l10n.dashboardKpiMissingInvoice, '${provider.missingInvoiceCount}', AppTheme.purple),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width < 500 ? 2 : width < 900 ? 3 : width < 1200 ? 4 : 7;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: kpis.map((k) {
            final itemWidth = (width - (cols - 1) * 12) / cols;
            return SizedBox(
              width: itemWidth,
              child: KpiCard(icon: k.$1, title: k.$2, value: k.$3, color: k.$4),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─── Panels ────────────────────────────────────────────────────────────────────

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = DateFormat('dd.MM. HH:mm');
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final activities = provider.activities.take(10).toList();
        return _Panel(
          title: l10n.dashboardActivityFeed,
          icon: Icons.bolt_outlined,
          child: activities.isEmpty
              ? _MutedText(l10n.dashboardActivityEmpty)
              : Column(
                  children: activities
                      .map((a) => _ActivityItem(
                            message: a.message,
                            date: fmt.format(a.date),
                          ))
                      .toList(),
                ),
        );
      },
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String message;
  final String date;
  const _ActivityItem({required this.message, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondaryOf(context))),
                const SizedBox(height: 2),
                Text(date,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyerOverview extends StatelessWidget {
  final NumberFormat fmt;
  const _BuyerOverview({required this.fmt});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final rows = provider.buyers.map((buyer) {
          final deals = provider.deals.where((d) => d.buyer == buyer.name).toList();
          deals.sort((a, b) => b.orderDate.compareTo(a.orderDate));
          final open = deals
              .where((d) => d.status != 'Done')
              .fold(0.0, (sum, d) => sum + (d.zuBekommen ?? 0));
          return (buyer: buyer, count: deals.length, open: open, last: deals.firstOrNull);
        }).toList();

        return _Panel(
          title: l10n.dashboardBuyerOverview,
          icon: Icons.people_outline,
          child: rows.isEmpty
              ? _MutedText(l10n.dashboardBuyerEmpty)
              : Column(
                  children: [
                    // Header row
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 20),
                          Expanded(
                            child: Text(l10n.dashboardColBuyer,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMutedOf(context),
                                    letterSpacing: 0.5)),
                          ),
                          SizedBox(
                            width: 70,
                            child: Text(l10n.dashboardColDeals,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMutedOf(context),
                                    letterSpacing: 0.5)),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text(l10n.dashboardColOpen,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMutedOf(context),
                                    letterSpacing: 0.5)),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(l10n.dashboardColLastDeal,
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMutedOf(context),
                                    letterSpacing: 0.5)),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: AppTheme.borderStrongOf(context)),
                    ...rows.map(
                      (row) => Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppTheme.borderOf(context))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: row.buyer.buyerCellColor,
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(row.buyer.name,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppTheme.textPrimaryOf(context)),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text('${row.count}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      fontSize: 13, color: AppTheme.textSecondaryOf(context))),
                            ),
                            SizedBox(
                              width: 110,
                              child: Text(fmt.format(row.open),
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppTheme.warning,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(row.last?.product ?? '-',
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      fontSize: 12, color: AppTheme.textMutedOf(context))),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// ─── Shared Panel Widget ───────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Panel({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.textMutedOf(context)),
                const SizedBox(width: 8),
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context))),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.borderOf(context)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  final String text;
  const _MutedText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(color: AppTheme.textMutedOf(context), fontSize: 13));
  }
}

