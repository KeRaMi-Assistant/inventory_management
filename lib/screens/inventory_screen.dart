import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/deal.dart';
import '../models/inventory_item.dart';
import '../providers/inventory_provider.dart';
import '../utils/status_l10n.dart';
import '../utils/url_helper.dart';
import '../utils/validators.dart';
import '../widgets/attachment_gallery.dart';
import '../widgets/barcode_scanner_sheet.dart';
import '../widgets/inventory_batches_sheet.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  String _search = '';
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static bool _isSold(InventoryItem i) =>
      i.status == 'Verkauft' || i.status == 'Versandt';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            final localeTag =
                Localizations.localeOf(context).toLanguageTag();
            final money =
                NumberFormat.currency(locale: localeTag, symbol: '€');
            final query = _search.trim().toLowerCase();
            List<InventoryItem> applySearch(List<InventoryItem> src) =>
                query.isEmpty
                    ? src
                    : src
                        .where((i) =>
                            i.name.toLowerCase().contains(query) ||
                            (i.sku?.toLowerCase().contains(query) ?? false))
                        .toList();
            final allStock = provider.inventoryItems
                .where((i) => !_isSold(i))
                .toList();
            final allSold =
                provider.inventoryItems.where(_isSold).toList();
            final stockItems = applySearch(allStock);
            final soldItems = applySearch(allSold);

            return Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.inventory_2_outlined, size: 18),
                        text: l10n.inventoryTabStock,
                      ),
                      Tab(
                        icon: const Icon(Icons.sell_outlined, size: 18),
                        text: l10n.inventoryTabSold,
                      ),
                    ],
                  ),
                ),
                _buildSearchBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStockTab(
                        context: context,
                        provider: provider,
                        items: stockItems,
                        allStockEmpty: allStock.isEmpty,
                        isNarrow: isNarrow,
                        money: money,
                        width: constraints.maxWidth,
                        l10n: l10n,
                      ),
                      _buildSoldTab(
                        context: context,
                        provider: provider,
                        items: soldItems,
                        allSoldEmpty: allSold.isEmpty,
                        isNarrow: isNarrow,
                        money: money,
                        width: constraints.maxWidth,
                        l10n: l10n,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStockTab({
    required BuildContext context,
    required InventoryProvider provider,
    required List<InventoryItem> items,
    required bool allStockEmpty,
    required bool isNarrow,
    required NumberFormat money,
    required double width,
    required AppLocalizations l10n,
  }) {
    return Column(
      children: [
        _buildHeader(context, provider, isNarrow, money, width),
        if (provider.criticalStockCount > 0)
          _LowStockBanner(count: provider.criticalStockCount),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: allStockEmpty
                      ? _EmptyInventoryState(provider: provider)
                      : Text(l10n.dealsEmpty),
                )
              : isNarrow
                  ? _buildCardList(context, provider, money, items)
                  : _buildTable(context, provider, money, items),
        ),
      ],
    );
  }

  Widget _buildSoldTab({
    required BuildContext context,
    required InventoryProvider provider,
    required List<InventoryItem> items,
    required bool allSoldEmpty,
    required bool isNarrow,
    required NumberFormat money,
    required double width,
    required AppLocalizations l10n,
  }) {
    return Column(
      children: [
        _buildSoldHeader(context, provider, isNarrow, money, width),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    allSoldEmpty
                        ? l10n.inventorySoldEmpty
                        : l10n.dealsEmpty,
                    style: TextStyle(color: AppTheme.textMutedOf(context)),
                  ),
                )
              : isNarrow
                  ? _buildCardList(context, provider, money, items)
                  : _buildTable(context, provider, money, items),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Builder(builder: (context) {
      final l10n = AppLocalizations.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: l10n.inventorySearchHint,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: l10n.inventoryScanBarcode,
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              onPressed: () => _scanAndLookup(context),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _scanAndLookup(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final code =
        await BarcodeScannerSheet.show(context, title: l10n.inventoryScanBarcode);
    if (code == null || code.isEmpty || !context.mounted) return;
    final provider = context.read<InventoryProvider>();
    final hit = provider.inventoryItems.where((i) => i.ean == code).firstOrNull;
    if (hit != null) {
      setState(() => _search = code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hit.name),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!context.mounted) return;
    final create = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inventoryNoEan),
        content: Text(l10n.inventoryEanCopied(code)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.inventoryCreate),
          ),
        ],
      ),
    );
    if (create == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _InventoryDialog(prefilledEan: code),
      );
    }
  }

  Widget _buildHeader(BuildContext context, InventoryProvider provider, bool isNarrow, NumberFormat money, double width) {
    final l10n = AppLocalizations.of(context);
    final kpis = [
      _kpi(l10n.inventoryKpiTotalItems, '${provider.inventoryItems.length}', Icons.category_outlined, const Color(0xFF2563EB)),
      _kpi(l10n.inventoryKpiTotalStock, '${provider.totalStockQuantity}', Icons.inventory_2_outlined, const Color(0xFF059669)),
      _kpi(l10n.inventoryKpiCriticalItems, '${provider.criticalStockCount}', Icons.warning_amber_rounded, const Color(0xFFDC2626)),
      _kpi(l10n.inventoryKpiStockValue, money.format(provider.totalStockValue), Icons.euro_outlined, const Color(0xFFD97706)),
    ];
    final addButton = ElevatedButton.icon(
      onPressed: () => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _InventoryDialog(),
      ),
      icon: const Icon(Icons.add, size: 16),
      label: Text(l10n.inventoryAddItem),
    );
    if (isNarrow) {
      final cardWidth = (width - 32) / 2;
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kpis.map((k) => SizedBox(width: cardWidth, child: k)).toList(),
            ),
            const SizedBox(height: 8),
            addButton,
            const SizedBox(height: 8),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ...kpis.map((k) => Expanded(child: k)),
          const Spacer(),
          addButton,
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Builder(builder: (ctx) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMutedOf(ctx),
                            fontWeight: FontWeight.w700)),
                    Text(value,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimaryOf(ctx))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSoldHeader(
    BuildContext context,
    InventoryProvider provider,
    bool isNarrow,
    NumberFormat money,
    double width,
  ) {
    final l10n = AppLocalizations.of(context);
    final soldItems =
        provider.inventoryItems.where(_isSold).toList(growable: false);
    final dealsById = {for (final d in provider.deals) d.id: d};

    int totalQuantity = 0;
    double totalProfit = 0;
    final buyerCounts = <String, int>{};

    for (final item in soldItems) {
      totalQuantity += item.quantity;
      final deal = item.dealId != null ? dealsById[item.dealId!] : null;
      if (deal != null) {
        final ek = item.costPrice ?? deal.ekBrutto;
        if (deal.vk != null && ek != null) {
          totalProfit += (deal.vk! - ek) * item.quantity;
        }
        final buyer = deal.buyer?.trim();
        if (buyer != null && buyer.isNotEmpty) {
          buyerCounts.update(buyer, (v) => v + item.quantity,
              ifAbsent: () => item.quantity);
        }
      }
    }

    final topBuyers = buyerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = topBuyers.take(3).toList();

    final countCard = _kpi(
      l10n.inventorySoldKpiCount,
      '$totalQuantity',
      Icons.sell_outlined,
      const Color(0xFF2563EB),
    );
    final profitCard = _kpi(
      l10n.inventorySoldKpiProfit,
      money.format(totalProfit),
      Icons.trending_up,
      totalProfit >= 0
          ? const Color(0xFF059669)
          : const Color(0xFFDC2626),
    );
    final buyersCard = _topBuyersCard(context, top3, l10n);

    final cards = [countCard, profitCard, buyersCard];

    if (isNarrow) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        child: SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => SizedBox(width: 240, child: cards[i]),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: countCard),
          const SizedBox(width: 12),
          Expanded(child: profitCard),
          const SizedBox(width: 12),
          Expanded(child: buyersCard),
        ],
      ),
    );
  }

  Widget _topBuyersCard(
    BuildContext context,
    List<MapEntry<String, int>> top,
    AppLocalizations l10n,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined,
                    color: Color(0xFFD97706), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.inventorySoldKpiTopBuyers,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMutedOf(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (top.isEmpty)
              Text(
                l10n.inventorySoldNoBuyer,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMutedOf(context),
                ),
              )
            else
              ...top.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.inventorySoldBuyerItems(e.value),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMutedOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardList(BuildContext context, InventoryProvider provider, NumberFormat money, List<InventoryItem> items) {
    final l10n = AppLocalizations.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = items[i];
        final color = item.quantity < item.minStock
            ? const Color(0xFFDC2626)
            : item.quantity == item.minStock
                ? const Color(0xFFD97706)
                : const Color(0xFF059669);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                    if (item.ticketUrl != null)
                      IconButton(
                        tooltip: l10n.inventoryDiscordTicketOpen,
                        icon: const Icon(Icons.open_in_new, size: 18, color: Color(0xFF5865F2)),
                        onPressed: () => openUrlWithFallback(context, resolveDiscordUrl(item.ticketUrl!)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.sku ?? "-"} · ${item.location ?? "Kein Lagerort"}',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textMutedOf(context)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: color),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context).inventorySoldBuyerItemsPlural(item.quantity), style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                    const Spacer(),
                    Text(item.costPrice != null ? money.format(item.costPrice) : '-', style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.ticketNumber != null ? 'Ticket: ${item.ticketNumber}' : '-',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textMutedOf(context)),
                      ),
                    ),
                    _statusChip(context, item.status),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Builder(builder: (ctx) {
                      final l10n = AppLocalizations.of(ctx);
                      return Row(children: [
                        TextButton.icon(
                          onPressed: () => _adjust(context, provider, item, true),
                          icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF059669)),
                          label: Text(l10n.inventoryStockIn, style: const TextStyle(color: Color(0xFF059669), fontSize: 12)),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                        ),
                        TextButton.icon(
                          onPressed: () => _adjust(context, provider, item, false),
                          icon: const Icon(Icons.remove_circle_outline, size: 16, color: Color(0xFFD97706)),
                          label: Text(l10n.inventoryStockOut, style: const TextStyle(color: Color(0xFFD97706), fontSize: 12)),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                        ),
                        IconButton(
                          tooltip: l10n.inventoryAddBatch,
                          onPressed: () =>
                              InventoryBatchesSheet.show(context, item),
                          icon: const Icon(Icons.layers_outlined, size: 18),
                        ),
                        IconButton(
                          tooltip: l10n.actionEdit,
                          onPressed: () => showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => _InventoryDialog(item: item),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                        IconButton(
                          tooltip: l10n.actionDelete,
                          onPressed: () => provider.deleteInventoryItem(item.id),
                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                        ),
                      ]);
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accentLightOf(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(localizeInventoryStatus(context, status),
          style: TextStyle(
              fontSize: 11,
              color: AppTheme.accentTextOf(context),
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildTable(BuildContext context, InventoryProvider provider, NumberFormat money, List<InventoryItem> items) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 42,
            columns: [
              DataColumn(label: Text(l10n.inventoryColSku)),
              DataColumn(label: Text(l10n.inventoryColName)),
              DataColumn(label: Text(l10n.inventoryColLocationLong)),
              DataColumn(label: Text(l10n.inventoryColStock)),
              DataColumn(label: Text(l10n.inventoryColMin)),
              const DataColumn(label: Text('Ø EK')),
              DataColumn(label: Text(l10n.inventoryColDealOrTicket)),
              DataColumn(label: Text(l10n.dealColArrival)),
              DataColumn(label: Text(l10n.dealStatus)),
              DataColumn(label: Text(l10n.inventoryColActions)),
            ],
            rows: items
                .map((item) => _row(context, provider, item, money))
                .toList(),
          ),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, InventoryProvider provider, InventoryItem item, NumberFormat money) {
    final l10n = AppLocalizations.of(context);
    final date = DateFormat.yMd(
        Localizations.localeOf(context).toLanguageTag());
    final color = item.quantity < item.minStock
        ? const Color(0xFFDC2626)
        : item.quantity == item.minStock
            ? const Color(0xFFD97706)
            : const Color(0xFF059669);
    return DataRow(
      cells: [
        DataCell(Text(item.sku ?? '-')),
        DataCell(Text(item.name)),
        DataCell(Text(item.location ?? '-')),
        DataCell(Row(children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 6),
          Text('${item.quantity}', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ])),
        DataCell(Text('${item.minStock}')),
        DataCell(Text(item.costPrice != null ? money.format(item.costPrice) : '-')),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text('${item.dealId != null ? "Deal #${item.dealId}" : "-"}${item.ticketNumber != null ? " · ${item.ticketNumber}" : ""}'),
            ),
            if (item.ticketUrl != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: l10n.dealDiscordTicketOpen,
                child: InkWell(
                  onTap: () => openUrlWithFallback(context, resolveDiscordUrl(item.ticketUrl!)),
                  child: const Icon(Icons.open_in_new, size: 14, color: Color(0xFF5865F2)),
                ),
              ),
            ],
          ],
        )),
        DataCell(Text(item.arrivalDate != null ? date.format(item.arrivalDate!) : '-')),
        DataCell(Text(localizeInventoryStatus(context, item.status))),
        DataCell(Row(
          children: [
            IconButton(
              tooltip: l10n.inventoryStockInTooltip,
              onPressed: () => _adjust(context, provider, item, true),
              icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF059669)),
            ),
            IconButton(
              tooltip: l10n.inventoryStockOutTooltip,
              onPressed: () => _adjust(context, provider, item, false),
              icon: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFFD97706)),
            ),
            IconButton(
              tooltip: l10n.actionEdit,
              onPressed: () => showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => _InventoryDialog(item: item),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
            IconButton(
              tooltip: l10n.actionDelete,
              onPressed: () => provider.deleteInventoryItem(item.id),
              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
            ),
          ],
        )),
      ],
    );
  }

  Future<void> _adjust(
    BuildContext context,
    InventoryProvider provider,
    InventoryItem item,
    bool incoming,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: '1');
    final reason = TextEditingController(
        text: incoming
            ? l10n.inventoryReasonStockIn
            : l10n.inventoryReasonSale);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(incoming
            ? l10n.inventoryStockInTitle
            : l10n.inventoryStockOutTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: ctrl,
                decoration: InputDecoration(labelText: l10n.inventoryQuantity),
                keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            TextField(
                controller: reason,
                decoration:
                    InputDecoration(labelText: l10n.inventoryReason)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.actionCancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.actionSave)),
        ],
      ),
    );
    if (ok == true) {
      final qty = int.tryParse(ctrl.text) ?? 0;
      if (qty > 0) await provider.adjustStock(item.id, incoming ? qty : -qty, reason.text);
    }
  }
}

class _InventoryDialog extends StatefulWidget {
  final InventoryItem? item;
  final String? prefilledEan;
  const _InventoryDialog({this.item, this.prefilledEan});

  @override
  State<_InventoryDialog> createState() => _InventoryDialogState();
}

class _InventoryDialogState extends State<_InventoryDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _ean = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _min = TextEditingController(text: '0');
  final _location = TextEditingController();
  final _cost = TextEditingController();
  final _ticketUrl = TextEditingController();
  final _note = TextEditingController();
  String _status = 'Im Lager';
  String _selectedTicketNumber = '';
  String? _supplierId;
  List<String> _attachmentPaths = const [];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _name.text = item.name;
      _sku.text = item.sku ?? '';
      _ean.text = item.ean ?? '';
      _supplierId = item.supplierId;
      _quantity.text = '${item.quantity}';
      _min.text = '${item.minStock}';
      _location.text = item.location ?? '';
      _cost.text = item.costPrice?.toStringAsFixed(2) ?? '';
      _selectedTicketNumber = item.ticketNumber ?? '';
      _ticketUrl.text = item.ticketUrl ?? '';
      _note.text = item.note ?? '';
      _status = item.status;
      _attachmentPaths = List.of(item.attachmentPaths);
    }
    if (widget.prefilledEan != null && widget.prefilledEan!.isNotEmpty) {
      _ean.text = widget.prefilledEan!;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _ean.dispose();
    _quantity.dispose();
    _min.dispose();
    _location.dispose();
    _cost.dispose();
    _ticketUrl.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Returns the product name field: Autocomplete when a ticket with deals is
  /// selected, plain TextFormField otherwise.
  Widget _buildProductField(InventoryProvider provider) {
    final l10n = AppLocalizations.of(context);
    final ticketDeals = _selectedTicketNumber.isNotEmpty
        ? (provider.ticketSummaries
                .where((t) => t.ticketNumber == _selectedTicketNumber)
                .firstOrNull
                ?.deals ??
            [])
        : <Deal>[];

    if (ticketDeals.isNotEmpty) {
      return Autocomplete<Deal>(
        initialValue: TextEditingValue(text: _name.text),
        displayStringForOption: (deal) => deal.product,
        optionsBuilder: (value) {
          if (value.text.isEmpty) return ticketDeals;
          final q = value.text.toLowerCase();
          return ticketDeals.where((d) => d.product.toLowerCase().contains(q));
        },
        onSelected: (deal) {
          setState(() {
            _name.text = deal.product;
            if (_quantity.text == '1' || _quantity.text.isEmpty) {
              _quantity.text = '${deal.quantity}';
            }
            if (_cost.text.isEmpty && deal.ekBrutto != null) {
              _cost.text = deal.ekBrutto!.toStringAsFixed(2);
            }
            if (_ticketUrl.text.isEmpty && deal.ticketUrl != null) {
              _ticketUrl.text = deal.ticketUrl!;
            }
          });
        },
        fieldViewBuilder: (ctx, ctrl, focusNode, _) {
          return TextFormField(
            controller: ctrl,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: l10n.inventoryProductRequiredLabel,
              suffixIcon: const Icon(Icons.arrow_drop_down, size: 20),
              helperText: l10n.inventoryProductHint,
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Pflichtfeld' : null,
            onChanged: (v) => _name.text = v,
          );
        },
        optionsViewBuilder: (ctx, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final deal = options.elementAt(i);
                    final ekText = deal.ekBrutto != null
                        ? '€ ${deal.ekBrutto!.toStringAsFixed(2)}'
                        : '-';
                    return ListTile(
                      dense: true,
                      title: Text(deal.product),
                      subtitle: Text('${deal.quantity} Stk. · EK $ekText'),
                      onTap: () => onSelected(deal),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    }

    return TextFormField(
      controller: _name,
      decoration: InputDecoration(
          labelText: '${AppLocalizations.of(context).dealProduct} *'),
      maxLength: Validators.maxProductName,
      validator: Validators.validateProductName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<InventoryProvider>();
    final ticketNumbers = provider.ticketSummaries
        .map((t) => t.ticketNumber)
        .where((t) => t != 'Kein Ticket')
        .toList();

    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppTheme.borderOf(context))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentLightOf(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.inventory_2_outlined,
                        color: AppTheme.accentTextOf(context), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item == null
                          ? l10n.inventoryAddItemTitle
                          : l10n.inventoryEditItemTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 20, color: AppTheme.textMutedOf(context)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // ── Form (scrollable) ─────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                _sectionLabel(l10n.inventorySectionGeneral),
                const SizedBox(height: 12),
                // ── 1. Ticket first so product dropdown can populate ──────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Autocomplete<String>(
                        initialValue: TextEditingValue(text: _selectedTicketNumber),
                        optionsBuilder: (TextEditingValue value) {
                          if (value.text.isEmpty) return ticketNumbers;
                          final q = value.text.toLowerCase();
                          return ticketNumbers.where((t) => t.toLowerCase().contains(q));
                        },
                        onSelected: (String selection) {
                          setState(() {
                            _selectedTicketNumber = selection;
                            // Clear product name so the new dropdown is unambiguous
                            _name.text = '';
                            if (_ticketUrl.text.isEmpty) {
                              final match = provider.ticketSummaries
                                  .where((t) => t.ticketNumber == selection)
                                  .firstOrNull;
                              if (match?.url != null) _ticketUrl.text = match!.url!;
                            }
                          });
                        },
                        fieldViewBuilder: (ctx, controller, focusNode, onSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(ctx).dealColTicket,
                              suffixIcon: const Icon(Icons.arrow_drop_down,
                                  size: 20),
                            ),
                            onChanged: (v) => setState(() {
                              _selectedTicketNumber = v;
                            }),
                          );
                        },
                        optionsViewBuilder: (ctx, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(8),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 200, maxWidth: 280),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (_, index) {
                                    final option = options.elementAt(index);
                                    return ListTile(
                                      dense: true,
                                      title: Text(option),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration:
                            InputDecoration(labelText: l10n.dealStatus),
                        items: InventoryProvider.inventoryStatusOptions
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(localizeInventoryStatus(
                                    context, s))))
                            .toList(),
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildProductField(provider),
                const SizedBox(height: 20),
                _sectionLabel(l10n.inventoryColStock),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      decoration: InputDecoration(
                          labelText: l10n.inventoryColQuantity),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          Validators.validateNonNegativeInt(v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _min,
                      decoration:
                          InputDecoration(labelText: l10n.inventoryColMin),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          Validators.validateNonNegativeInt(v),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cost,
                      decoration: InputDecoration(
                        labelText: l10n.inventoryColCost,
                        prefixText: '€ ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => Validators.validateMoney(v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _location,
                      decoration: InputDecoration(
                        labelText: l10n.inventoryColLocationLong,
                        prefixIcon:
                            const Icon(Icons.place_outlined, size: 18),
                      ),
                      maxLength: 100,
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                _sectionLabel(l10n.inventorySectionId),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sku,
                      decoration: InputDecoration(labelText: l10n.inventoryColSku),
                      maxLength: Validators.maxSku,
                      validator: (v) => Validators.validateSku(v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ean,
                      decoration: InputDecoration(
                        labelText: l10n.inventoryColEanGtin,
                        prefixIcon: const Icon(Icons.qr_code_2, size: 18),
                        suffixIcon: IconButton(
                          tooltip: l10n.inventoryScanBarcode,
                          icon: const Icon(Icons.qr_code_scanner, size: 18),
                          onPressed: () async {
                            final code = await BarcodeScannerSheet.show(
                              context,
                              title: l10n.inventoryScanBarcode,
                            );
                            if (code != null && code.isNotEmpty) {
                              setState(() => _ean.text = code);
                            }
                          },
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 14,
                      validator: (v) => Validators.validateGtin(v),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _supplierId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.inventoryColSupplier,
                    prefixIcon:
                        const Icon(Icons.local_shipping_outlined, size: 18),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.inventoryNoSupplier),
                    ),
                    ...provider.activeSuppliers.map(
                      (s) => DropdownMenuItem<String?>(
                        value: s.id,
                        child:
                            Text(s.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _supplierId = v),
                ),
                const SizedBox(height: 20),
                _sectionLabel(l10n.inventorySectionAttachments),
                const SizedBox(height: 12),
                AttachmentGallery(
                  paths: _attachmentPaths,
                  entityKind: 'item',
                  entityId: widget.item?.id ?? '',
                  onChanged: (next) =>
                      setState(() => _attachmentPaths = next),
                ),
                const SizedBox(height: 20),
                _sectionLabel(l10n.dealNote),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ticketUrl,
                  decoration: InputDecoration(
                    labelText: l10n.dealTicketUrl,
                    hintText: 'https://discord.com/...',
                    prefixIcon: const Icon(Icons.link, size: 18),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (v) => Validators.validateUrl(v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  decoration:
                      InputDecoration(labelText: l10n.dealNote),
                  maxLines: 2,
                  maxLength: Validators.maxNote,
                  validator: Validators.validateNote,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
            // ── Actions ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppTheme.borderOf(context))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.actionCancel),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () async {
                      if (!_form.currentState!.validate()) return;
                      final prov = context.read<InventoryProvider>();
                      final item = InventoryItem(
                        id: widget.item?.id ?? '',
                        name: _name.text.trim(),
                        sku: _sku.text.trim().isEmpty
                            ? null
                            : _sku.text.trim(),
                        ean: _ean.text.trim().isEmpty
                            ? null
                            : _ean.text.trim(),
                        quantity: int.tryParse(_quantity.text) ?? 0,
                        minStock: int.tryParse(_min.text) ?? 0,
                        location: _location.text.trim().isEmpty
                            ? null
                            : _location.text.trim(),
                        costPrice: double.tryParse(
                            _cost.text.replaceAll(',', '.')),
                        arrivalDate:
                            widget.item?.arrivalDate ?? DateTime.now(),
                        dealId: widget.item?.dealId,
                        supplierId: _supplierId,
                        ticketNumber: _selectedTicketNumber.trim().isEmpty
                            ? null
                            : _selectedTicketNumber.trim(),
                        ticketUrl: _ticketUrl.text.trim().isEmpty
                            ? null
                            : _ticketUrl.text.trim(),
                        note: _note.text.trim().isEmpty
                            ? null
                            : _note.text.trim(),
                        status: _status,
                        attachmentPaths: _attachmentPaths,
                      );
                      if (widget.item == null) {
                        await prov.addInventoryItem(item);
                      } else {
                        await prov.updateInventoryItem(item);
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(l10n.actionSave),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Builder(builder: (ctx) {
      return Row(
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMutedOf(ctx),
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(height: 1, color: AppTheme.borderOf(ctx)),
          ),
        ],
      );
    });
  }
}

// ─── Low-stock warning banner ─────────────────────────────────────────────────
class _LowStockBanner extends StatefulWidget {
  final int count;
  const _LowStockBanner({required this.count});

  @override
  State<_LowStockBanner> createState() => _LowStockBannerState();
}

class _EmptyInventoryState extends StatelessWidget {
  const _EmptyInventoryState({required this.provider});
  final InventoryProvider provider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inventory_2_outlined,
            size: 48, color: AppTheme.textDisabledOf(context)),
        const SizedBox(height: 12),
        Text(
          l10n.inventoryEmpty,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryOf(context)),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.suppliersEmptyHint,
          style: TextStyle(
              color: AppTheme.textMutedOf(context), fontSize: 12),
        ),
      ],
    );
  }
}

class _LowStockBannerState extends State<_LowStockBanner> {
  bool _dismissed = false;

  @override
  void didUpdateWidget(covariant _LowStockBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count) _dismissed = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return MaterialBanner(
      backgroundColor: AppTheme.dangerBgOf(context),
      leading: Icon(Icons.warning_amber_rounded,
          color: AppTheme.dangerTextOf(context)),
      content: Text(
        '${widget.count} Artikel ${widget.count == 1 ? "hat" : "haben"} Bestand unter dem Mindestbestand!',
        style: TextStyle(
            color: AppTheme.dangerTextOf(context),
            fontWeight: FontWeight.w700),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _dismissed = true),
          child: Text(l10n.actionClose,
              style: TextStyle(color: AppTheme.dangerTextOf(context))),
        ),
      ],
    );
  }
}
