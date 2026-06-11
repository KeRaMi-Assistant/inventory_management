import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/deals_provider.dart';
import '../providers/navigation_intents_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/stock_provider.dart';
import '../utils/responsive.dart';
import '../widgets/app_feedback.dart';
import '../widgets/empty_state.dart';
import '../widgets/statistics/kpi_card.dart';
import 'main_tab.dart';
import 'purchase_orders_screen.dart';

/// Maximale Inhaltsbreite des Dashboards auf großen Viewports (Desktop,
/// Ultrawide). Stellt sicher, dass KPI-Karten und Panels nicht übermäßig
/// breit werden. Auf Phone/Tablet ist der Viewport schmaler als dieser Wert,
/// sodass `Center + ConstrainedBox` dort keine visuelle Wirkung hat.
const double _kDashboardMaxWidth = 1400;

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
    return Consumer2<StockProvider, DealsProvider>(
      builder: (context, stock, provider, _) {
        final hasData = provider.deals.isNotEmpty ||
            stock.inventoryItems.isNotEmpty ||
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
            padding: const EdgeInsets.all(AppTheme.space24),
            child: Center(
              child: ConstrainedBox(
                // Begrenzt den Dashboard-Inhalt auf Desktop auf _kDashboardMaxWidth —
                // auf Phone/Tablet kein visueller Unterschied (Viewport < MaxWidth).
                constraints: const BoxConstraints(maxWidth: _kDashboardMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isEmpty) const _EmptyStateCard(),
                    if (isEmpty) const SizedBox(height: 24),
                    _LowStockAlertBlock(criticalCount: stock.criticalStockCount),
                    _KpiGrid(provider: provider, stock: stock, fmt: fmt),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth > Breakpoints.legacyDashboardWide;
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
      padding: const EdgeInsets.only(bottom: AppTheme.space24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.warningBgOf(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.warningBorderOf(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final phone = constraints.maxWidth < Breakpoints.legacyDashboardCompact;
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
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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

/// Onboarding-Panel, das auf dem Dashboard erscheint, wenn noch keine Daten
/// vorhanden sind. Nutzt [EmptyState] mit `cardStyle: true` für die
/// Card-Optik und übergibt den Demo-Daten-Button als `action`-Slot.
///
/// Stateful nur wegen des `_loading`-Zustands während des async [_loadDemo]-
/// Calls — das UI-Skeleton kommt von [EmptyState].
class _EmptyStateCard extends StatefulWidget {
  const _EmptyStateCard();

  @override
  State<_EmptyStateCard> createState() => _EmptyStateCardState();
}

class _EmptyStateCardState extends State<_EmptyStateCard> {
  bool _loading = false;

  Future<void> _loadDemo() async {
    final l10n = AppLocalizations.of(context);
    final ob = context.read<OnboardingProvider>();
    final activeWs = context.read<ActiveWorkspaceProvider>();
    final inv = context.read<DealsProvider>();
    final wsId = activeWs.active?.id;
    if (wsId == null) {
      // Workspace nicht vorhanden — synchron, context ist garantiert gültig.
      AppFeedback.error(context, l10n.onboardingErrorNoWorkspace);
      return;
    }
    setState(() => _loading = true);
    final result = await ob.loadDemoData(wsId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result == null) {
      // Demo-Load fehlgeschlagen. Rohe Exception-Strings werden nicht
      // durchgereicht (ob.lastError wäre ein interner Provider-Fehler).
      // Stattdessen generischer Fehler-Key — für Details muss der User
      // die Fehler-Logs prüfen (Pre-Launch, kein Support-Chat nötig).
      AppFeedback.error(context, l10n.appFeedbackErrorDefault);
      return;
    }
    await inv.loadData();
    if (!mounted) return;
    // Demo-Reload ist idempotent → kein Undo erforderlich.
    AppFeedback.info(context, l10n.dashboardDemoLoadSuccess(result.total));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.lightbulb_outline,
      title: l10n.dashboardEmptyTitle,
      subtitle: l10n.dashboardEmptySubtitle,
      keySlug: 'dashboardEmpty',
      cardStyle: true,
      action: SizedBox(
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
      ),
    );
  }
}

// ─── Responsive KPI Grid ───────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  final DealsProvider provider;
  final StockProvider stock;
  final NumberFormat fmt;
  const _KpiGrid({required this.provider, required this.stock, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Drilldown-Ziele (Paket 3): KPI-Tap springt zum passenden Tab via
    // NavigationIntentsProvider (MainScreen konsumiert den Intent).
    final kpis = [
      (Icons.shopping_cart_outlined, l10n.dashboardKpiOpenOrders, '${provider.openOrdersCount}', AppTheme.accent, MainTab.deals),
      (Icons.local_shipping_outlined, l10n.dashboardKpiShipping, '${provider.openDeliveriesCount}', AppTheme.warning, MainTab.deals),
      (Icons.today_outlined, l10n.dashboardKpiArrivedToday, '${provider.arrivedTodayCount}', AppTheme.info, MainTab.deals),
      (Icons.trending_up_rounded, l10n.dashboardKpiTotalProfit, fmt.format(provider.totalProfit), AppTheme.success, MainTab.stats),
      (Icons.account_balance_wallet_outlined, l10n.dashboardKpiOpenAmount, fmt.format(provider.openAmount), AppTheme.warning, MainTab.stats),
      (Icons.warning_amber_rounded, l10n.dashboardKpiCriticalStock, '${stock.criticalStockCount}', AppTheme.danger, MainTab.warehouse),
      (Icons.receipt_long_outlined, l10n.dashboardKpiMissingInvoice, '${provider.missingInvoiceCount}', AppTheme.purple, MainTab.deals),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Spaltenanzahl: Ziel-Kartenbreite ~320 px, maximal 4 Spalten (auch
        // auf Ultrawide), mindestens 2 Spalten (auch auf kleinen Phones).
        // Formel: (availableWidth / 320).floor().clamp(2, 4)
        // Beispiele:  360 px → 1,12 → clamp → 2
        //             640 px → 2,00 → clamp → 2
        //             900 px → 2,81 → clamp → 2 … (floor=2)
        //             960 px → 3,00 → clamp → 3
        //            1280 px → 4,00 → clamp → 4
        //            2560 px → 8,00 → clamp → 4  ← Ultrawide-Begrenzung
        final cols = (width / 320).floor().clamp(2, 4);
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: kpis.map((k) {
            final itemWidth = (width - (cols - 1) * 12) / cols;
            return SizedBox(
              width: itemWidth,
              child: KpiCard(
                icon: k.$1,
                label: k.$2,
                value: k.$3,
                accent: k.$4,
                onTap: () => context
                    .read<NavigationIntentsProvider>()
                    .requestTab(k.$5),
              ),
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
    return Consumer<DealsProvider>(
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
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5), // off-grid: baseline-align bullet with first text line
            child: Container(
              width: 6,  // off-grid: bullet dot size (visual, not layout spacing)
              height: 6, // off-grid: bullet dot size (visual, not layout spacing)
              decoration: BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space10),
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
    return Consumer<DealsProvider>(
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
                      padding: const EdgeInsets.only(bottom: AppTheme.space8),
                      child: Row(
                        children: [
                          const SizedBox(width: AppTheme.space20),
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
                        padding: const EdgeInsets.symmetric(vertical: AppTheme.space10),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppTheme.borderOf(context))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,  // off-grid: buyer dot indicator size (visual, not layout spacing)
                              height: 10, // off-grid: buyer dot indicator size (visual, not layout spacing)
                              decoration: BoxDecoration(
                                  color: row.buyer.buyerCellColor,
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: AppTheme.space10),
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
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.space16, AppTheme.space14, AppTheme.space16, AppTheme.space14),
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
            padding: const EdgeInsets.all(AppTheme.space16),
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

