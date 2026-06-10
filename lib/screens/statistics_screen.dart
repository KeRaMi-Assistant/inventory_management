import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/inventory_batch.dart';
import '../providers/app_preferences_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/purchasing_provider.dart';
import '../providers/stock_provider.dart';
import '../providers/statistics_filter_provider.dart';
import '../services/statistics_export_service.dart';
import '../services/statistics_service.dart';
import '../widgets/app_feedback.dart';
import '../widgets/statistics/filter_bar.dart';
import '../widgets/statistics/tabs/buyers_tab.dart';
import '../widgets/statistics/tabs/finance_tab.dart';
import '../widgets/statistics/tabs/inventory_suppliers_tab.dart';
import '../widgets/statistics/tabs/overview_tab.dart';
import '../widgets/statistics/tabs/products_shops_tab.dart';

class StatisticsScreen extends StatefulWidget {
  /// When `true`, the top-level background [Container] is omitted so the
  /// screen can be embedded inside a detail pane (e.g. [SectionHubScreen])
  /// without doubling the background colour. The [TabController], [TabBar]
  /// and [TabBarView] are unaffected — they do not depend on a [Scaffold].
  ///
  /// Default `false` preserves the existing full-screen behaviour used by
  /// [AnalyticsSectionScreen] and any [Navigator.push] call-sites.
  final bool embedded;

  const StatisticsScreen({super.key, this.embedded = false});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 5, vsync: this);
  Future<List<InventoryBatch>>? _batchFuture;

  @override
  void initState() {
    super.initState();
    final inv = context.read<StockProvider>();
    _batchFuture = inv.loadAllBatches().catchError((Object e) {
      if (kDebugMode) debugPrint('loadAllBatches: $e');
      return <InventoryBatch>[];
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _onExport(StatisticsService stats) async {
    final l10n = AppLocalizations.of(context);
    final svc = StatisticsExportService(stats);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined,
                  color: Color(0xFFDC2626)),
              title: Text(l10n.statsExportPdfTitle),
              subtitle: Text(l10n.statsExportPdfDesc),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined,
                  color: Color(0xFF059669)),
              title: Text(l10n.statsExportXlsxTitle),
              subtitle: Text(l10n.statsExportXlsxDesc),
              onTap: () => Navigator.pop(context, 'xlsx'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined,
                  color: Color(0xFF2563EB)),
              title: Text(l10n.statsExportCsvTitle),
              subtitle: Text(l10n.statsExportCsvDesc),
              onTap: () => Navigator.pop(context, 'csv'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.print_outlined, color: Color(0xFF6B7280)),
              title: Text(l10n.statsExportPrintTitle),
              onTap: () => Navigator.pop(context, 'print'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    try {
      switch (choice) {
        case 'pdf':
          final bytes = await svc.buildOverviewPdf();
          await svc.savePdf(bytes);
          break;
        case 'xlsx':
          await svc.saveExcel();
          break;
        case 'csv':
          await svc.saveDealsCsv();
          break;
        case 'print':
          final bytes = await svc.buildOverviewPdf();
          await Printing.layoutPdf(onLayout: (_) async => bytes);
          break;
      }
      if (mounted) {
        AppFeedback.success(context, l10n.statsReportExported);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, l10n.appFeedbackErrorDefault);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InventoryBatch>>(
      future: _batchFuture,
      builder: (context, snap) {
        return Consumer3<InventoryProvider, StatisticsFilterProvider,
            AppPreferencesProvider>(
          builder: (context, inv, filter, prefs, _) {
            if (inv.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            // Suppliers now live in PurchasingProvider — watch it so the supplier
            // filter/breakdown rebuilds when the supplier list changes.
            final suppliers = context.watch<PurchasingProvider>().suppliers;
            final stock = context.watch<StockProvider>();
            final batches = snap.data ?? const <InventoryBatch>[];
            final stats = StatisticsService(
              allDeals: inv.deals,
              allItems: stock.inventoryItems,
              suppliers: suppliers,
              batches: batches,
              allMovements: stock.movements,
              filter: filter,
              monthlyProfitGoal: prefs.monthlyProfitGoal,
              lowStockThreshold: prefs.lowStockThreshold,
            );

            // Build the shared tab body (TabBar + TabBarView).
            // StatisticsScreen never owns a Scaffold or AppBar — the tab
            // controller lives in State via SingleTickerProviderStateMixin
            // and is independent of any Scaffold.
            //
            // embedded == true  → bare Column, host detail pane provides bg.
            // embedded == false → original Container(bgApp) wrapper intact
            //                     (AnalyticsSectionScreen / full-screen path).
            final tabBody = Column(
              children: [
                StatisticsFilterBar(onExport: () => _onExport(stats)),
                Material(
                  color: AppTheme.bgSurfaceOf(context),
                  elevation: 0,
                  child: TabBar(
                    controller: _tab,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: AppTheme.accentTextOf(context),
                    indicatorWeight: 2,
                    labelColor: AppTheme.accentTextOf(context),
                    unselectedLabelColor: AppTheme.textMutedOf(context),
                    dividerColor: AppTheme.borderOf(context),
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    tabs: [
                      Tab(icon: const Icon(Icons.dashboard_outlined, size: 16), text: AppLocalizations.of(context).statsTabOverview),
                      Tab(icon: const Icon(Icons.people_outline, size: 16), text: AppLocalizations.of(context).statsTabBuyers),
                      Tab(icon: const Icon(Icons.shopping_bag_outlined, size: 16), text: AppLocalizations.of(context).statsTabProductsShops),
                      Tab(icon: const Icon(Icons.inventory_2_outlined, size: 16), text: AppLocalizations.of(context).statsTabInventorySuppliers),
                      Tab(icon: const Icon(Icons.account_balance_outlined, size: 16), text: AppLocalizations.of(context).statsTabFinance),
                    ],
                  ),
                ),
                Expanded(
                  // ExcludeSemantics prevents accessibility_tools from
                  // emitting false-positive "missing semantic label" warnings
                  // on individual fl_chart canvas elements in debug builds.
                  // Real a11y for charts is provided by Semantics-wrapper
                  // labels on the tab headings and KPI summaries (Epic D §5.5).
                  child: ExcludeSemantics(
                    excluding: kDebugMode,
                    child: TabBarView(
                      controller: _tab,
                      children: [
                        OverviewTab(stats: stats),
                        BuyersTab(stats: stats),
                        ProductsShopsTab(stats: stats),
                        InventorySuppliersTab(stats: stats),
                        FinanceTab(
                          stats: stats,
                          onExportTax: () async {
                            final svc = StatisticsExportService(stats);
                            final l10n = AppLocalizations.of(context);
                            try {
                              await svc.saveTaxCsv();
                              if (!context.mounted) return;
                              AppFeedback.success(
                                context,
                                l10n.statsTaxExportSaved,
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              AppFeedback.error(
                                context,
                                l10n.appFeedbackErrorDefault,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );

            if (widget.embedded) return tabBody;
            return Container(
              color: AppTheme.bgAppOf(context),
              child: tabBody,
            );
          },
        );
      },
    );
  }
}
