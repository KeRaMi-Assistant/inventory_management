import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/buyer.dart';
import '../models/deal.dart';
import '../models/shop.dart';
import '../providers/filter_provider.dart';
import '../providers/inventory_provider.dart';
import '../services/carrier_service.dart';
import '../utils/status_l10n.dart';
import '../utils/url_helper.dart';
import 'add_edit_deal_dialog.dart';
import 'deal_card.dart';
import 'tracking_chip.dart';

class _ColDef {
  final String labelKey;
  final String sortKey;
  final double width;
  const _ColDef(this.labelKey, this.sortKey, this.width);
}

String _colLabel(AppLocalizations l10n, String key) => switch (key) {
      'id' => l10n.dealColId,
      'product' => l10n.dealProduct,
      'quantity' => l10n.dealQuantityShort,
      'isDropship' => l10n.dealShippingType,
      'shop' => l10n.dealShop,
      'orderDate' => l10n.dealOrderDate,
      'ekNetto' => l10n.dealColEkNet,
      'ekBrutto' => l10n.dealColEkGross,
      'vk' => l10n.dealColVk,
      'buyer' => l10n.dealBuyer,
      'ticketNumber' => l10n.dealColTicket,
      'tracking' => l10n.dealTracking,
      'arrivalDate' => l10n.dealColArrival,
      'status' => l10n.dealStatus,
      'hasReceipt' => l10n.dealReceipt,
      'profitPerUnit' => l10n.dealColProfitUnit,
      'totalProfit' => l10n.dealColProfitTotal,
      'zuBekommen' => l10n.dealColReceivable,
      'note' => l10n.dealNote,
      _ => '',
    };

class DealTable extends StatefulWidget {
  final ValueChanged<String>? onOpenTicket;
  const DealTable({super.key, this.onOpenTicket});

  @override
  State<DealTable> createState() => _DealTableState();
}

class _DealTableState extends State<DealTable> {
  final _headerScroll = ScrollController();
  final _bodyScroll = ScrollController();
  bool _syncing = false;

  static const _cols = <_ColDef>[
    _ColDef('', 'selected', 44),
    _ColDef('id', 'id', 58),
    _ColDef('product', 'product', 190),
    _ColDef('quantity', 'quantity', 58),
    _ColDef('isDropship', 'isDropship', 110),
    _ColDef('shop', 'shop', 120),
    _ColDef('orderDate', 'orderDate', 118),
    _ColDef('ekNetto', 'ekNetto', 96),
    _ColDef('ekBrutto', 'ekBrutto', 96),
    _ColDef('vk', 'vk', 90),
    _ColDef('buyer', 'buyer', 126),
    _ColDef('ticketNumber', 'ticketNumber', 130),
    _ColDef('tracking', 'tracking', 130),
    _ColDef('arrivalDate', 'arrivalDate', 108),
    _ColDef('status', 'status', 148),
    _ColDef('hasReceipt', 'hasReceipt', 74),
    _ColDef('profitPerUnit', 'profitPerUnit', 98),
    _ColDef('totalProfit', 'totalProfit', 104),
    _ColDef('zuBekommen', 'zuBekommen', 112),
    _ColDef('note', 'note', 150),
    _ColDef('', 'actions', 88),
  ];

  @override
  void initState() {
    super.initState();
    _headerScroll.addListener(_syncFromHeader);
    _bodyScroll.addListener(_syncFromBody);
  }

  void _syncFromHeader() {
    if (_syncing) return;
    _syncing = true;
    if (_bodyScroll.hasClients) _bodyScroll.jumpTo(_headerScroll.offset);
    _syncing = false;
  }

  void _syncFromBody() {
    if (_syncing) return;
    _syncing = true;
    if (_headerScroll.hasClients) _headerScroll.jumpTo(_bodyScroll.offset);
    _syncing = false;
  }

  @override
  void dispose() {
    _headerScroll.dispose();
    _bodyScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<InventoryProvider, FilterProvider>(
      builder: (context, provider, filters, _) {
        final deals = filters.apply(provider.deals);
        final dateFmt = DateFormat('dd.MM.yyyy');
        final numFmt = NumberFormat('#,##0.00', 'de_DE');
        final allVisibleSelected = deals.isNotEmpty &&
            deals.every((d) => filters.selectedDealIds.contains(d.id));

        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FilterBar(provider: provider, filters: filters),
                if (filters.selectedDealIds.isNotEmpty)
                  _BulkActionBar(provider: provider, filters: filters),
                if (isNarrow)
                  Expanded(
                    child: deals.isEmpty
                        ? const _EmptyState()
                        : ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(12, 8, 12, 100),
                            itemCount: deals.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) => DealCard(
                              deal: deals[i],
                              provider: provider,
                              filters: filters,
                              onOpenTicket: widget.onOpenTicket,
                            ),
                          ),
                  )
                else ...[
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      border: Border(
                        bottom: BorderSide(
                            color: Color(0xFFDDE3ED), width: 1.5),
                      ),
                    ),
                    child: SingleChildScrollView(
                      controller: _headerScroll,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: Row(
                        children: [
                          SizedBox(
                            width: _cols.first.width,
                            height: 40,
                            child: Center(
                              child: Checkbox(
                                value: allVisibleSelected,
                                tristate: true,
                                onChanged: deals.isEmpty
                                    ? null
                                    : (_) {
                                        if (allVisibleSelected) {
                                          filters.clearSelection();
                                        } else {
                                          filters.selectAll(
                                              deals.map((d) => d.id));
                                        }
                                      },
                              ),
                            ),
                          ),
                          ..._cols.skip(1).map(
                                (c) => _HeaderCell(
                                  label: _colLabel(
                                      AppLocalizations.of(context),
                                      c.labelKey),
                                  sortKey: c.sortKey,
                                  width: c.width,
                                  filters: filters,
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: deals.isEmpty
                        ? const _EmptyState()
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              controller: _bodyScroll,
                              scrollDirection: Axis.horizontal,
                              physics: const ClampingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (int i = 0; i < deals.length; i++)
                                    _DealRow(
                                      deal: deals[i],
                                      isEven: i.isEven,
                                      provider: provider,
                                      filters: filters,
                                      dateFmt: dateFmt,
                                      numFmt: numFmt,
                                      cols: _cols,
                                      onOpenTicket: widget.onOpenTicket,
                                    ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  final InventoryProvider provider;
  final FilterProvider filters;
  const _FilterBar({required this.provider, required this.filters});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 240,
              child: TextField(
                decoration: InputDecoration(
                  hintText: l10n.dealsSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
                onChanged: filters.setSearch,
              ),
            ),
            _dropdown(
              width: 140,
              label: l10n.dealBuyer,
              value: filters.buyer,
              values: provider.buyers.map((b) => b.name).toList(),
              labels: provider.buyers.map((b) => b.name).toList(),
              onChanged: filters.setBuyer,
            ),
            _dropdown(
              width: 150,
              label: l10n.dealStatus,
              value: filters.status,
              values: InventoryProvider.statusOptions,
              labels: InventoryProvider.statusOptions
                  .map((s) => localizeDealStatus(context, s))
                  .toList(),
              onChanged: filters.setStatus,
            ),
            _dropdown(
              width: 140,
              label: l10n.dealShop,
              value: filters.shop,
              values: provider.shops.map((s) => s.name).toList(),
              labels: provider.shops.map((s) => s.name).toList(),
              onChanged: filters.setShop,
            ),
            _boolDropdown(
              width: 130,
              label: l10n.dealShippingType,
              value: filters.isDropship,
              trueLabel: l10n.dealDropship,
              falseLabel: l10n.dealReship,
              onChanged: filters.setIsDropship,
            ),
            _boolDropdown(
              width: 100,
              label: l10n.dealReceipt,
              value: filters.hasReceipt,
              trueLabel: l10n.dealReceiptYes,
              falseLabel: l10n.dealReceiptNo,
              onChanged: filters.setHasReceipt,
            ),
            OutlinedButton.icon(
              onPressed: () => _pickRange(context),
              icon: const Icon(Icons.date_range_outlined, size: 16),
              label: Text(_dateLabel(l10n)),
            ),
            IconButton(
              tooltip: l10n.dealsFilterReset,
              onPressed: filters.reset,
              icon: const Icon(Icons.refresh, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown({
    required double width,
    required String label,
    required String? value,
    required List<String> values,
    required List<String> labels,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: Builder(builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.commonAll)),
            for (int i = 0; i < values.length; i++)
              DropdownMenuItem(
                  value: values[i], child: Text(labels[i])),
          ],
          onChanged: onChanged,
        );
      }),
    );
  }

  Widget _boolDropdown({
    required double width,
    required String label,
    required bool? value,
    required String trueLabel,
    required String falseLabel,
    required ValueChanged<bool?> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: Builder(builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return DropdownButtonFormField<bool?>(
          isExpanded: true,
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: [
            DropdownMenuItem<bool?>(
                value: null, child: Text(l10n.commonAll)),
            DropdownMenuItem<bool?>(value: true, child: Text(trueLabel)),
            DropdownMenuItem<bool?>(value: false, child: Text(falseLabel)),
          ],
          onChanged: onChanged,
        );
      }),
    );
  }

  String _dateLabel(AppLocalizations l10n) {
    final fmt = DateFormat('dd.MM.yy');
    if (filters.fromDate == null && filters.toDate == null) {
      return l10n.dealsFilterDate;
    }
    final from =
        filters.fromDate != null ? fmt.format(filters.fromDate!) : '...';
    final to = filters.toDate != null ? fmt.format(filters.toDate!) : '...';
    return '$from - $to';
  }

  Future<void> _pickRange(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: filters.fromDate != null && filters.toDate != null
          ? DateTimeRange(start: filters.fromDate!, end: filters.toDate!)
          : null,
    );
    if (range != null) filters.setDateRange(range.start, range.end);
  }
}

class _BulkActionBar extends StatelessWidget {
  final InventoryProvider provider;
  final FilterProvider filters;
  const _BulkActionBar({required this.provider, required this.filters});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ids = filters.selectedDealIds.toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFFEFF6FF),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            l10n.commonSelected(ids.length),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D4ED8),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: l10n.bulkChangeStatusTooltip,
            onSelected: (status) async {
              await provider.updateDealsStatus(ids, status);
              filters.clearSelection();
            },
            itemBuilder: (_) => InventoryProvider.statusOptions
                .map((s) => PopupMenuItem(
                    value: s,
                    child: Text(localizeDealStatus(context, s))))
                .toList(),
            child: _BulkButton(
                icon: Icons.flag_outlined, label: l10n.bulkStatus),
          ),
          PopupMenuButton<String?>(
            tooltip: l10n.bulkAssignBuyerTooltip,
            onSelected: (buyer) async {
              await provider.assignDealsBuyer(ids, buyer);
              filters.clearSelection();
            },
            itemBuilder: (_) => [
              PopupMenuItem<String?>(
                  value: null, child: Text(l10n.bulkBuyerNone)),
              ...provider.buyers.map((b) =>
                  PopupMenuItem<String?>(value: b.name, child: Text(b.name))),
            ],
            child: _BulkButton(
                icon: Icons.person_outline, label: l10n.bulkBuyer),
          ),
          TextButton.icon(
            onPressed: () async {
              await provider.deleteDeals(ids);
              filters.clearSelection();
            },
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text(l10n.actionDelete),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
          ),
          IconButton(
            tooltip: l10n.actionDeselect,
            onPressed: filters.clearSelection,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _BulkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _BulkButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: null,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final String sortKey;
  final double width;
  final FilterProvider filters;
  const _HeaderCell({
    required this.label,
    required this.sortKey,
    required this.width,
    required this.filters,
  });

  @override
  Widget build(BuildContext context) {
    final sortable = label.isNotEmpty && sortKey != 'actions';
    final active = filters.sortKey == sortKey;
    return InkWell(
      onTap: sortable ? () => filters.setSort(sortKey) : null,
      child: SizedBox(
        width: width,
        height: 40,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (sortable)
                Icon(
                  active
                      ? (filters.sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                      : Icons.unfold_more,
                  size: 13,
                  color: active ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DealRow extends StatefulWidget {
  final Deal deal;
  final bool isEven;
  final InventoryProvider provider;
  final FilterProvider filters;
  final DateFormat dateFmt;
  final NumberFormat numFmt;
  final List<_ColDef> cols;
  final ValueChanged<String>? onOpenTicket;

  const _DealRow({
    required this.deal,
    required this.isEven,
    required this.provider,
    required this.filters,
    required this.dateFmt,
    required this.numFmt,
    required this.cols,
    this.onOpenTicket,
  });

  @override
  State<_DealRow> createState() => _DealRowState();
}

class _DealRowState extends State<_DealRow> {
  bool _hovered = false;

  Color get _rowColor {
    Buyer? buyer;
    try {
      buyer = widget.provider.buyers.firstWhere((b) => b.name == widget.deal.buyer);
    } catch (_) {}

    final needsAttention =
        widget.deal.status == 'Unterwegs' && widget.deal.arrivalDate == null;
    final base = buyer?.rowFillColor;
    if (_hovered) return const Color(0xFFEFF3FC);
    if (needsAttention) return const Color(0xFFFFFBEB);
    if (base != null && base.a > 0) return base;
    return widget.isEven ? Colors.white : const Color(0xFFFAFBFD);
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final provider = widget.provider;
    final filters = widget.filters;
    final selected = filters.selectedDealIds.contains(deal.id);

    Buyer? buyer;
    try {
      buyer = provider.buyers.firstWhere((b) => b.name == deal.buyer);
    } catch (_) {}

    Shop? shop;
    try {
      shop = provider.shops.firstWhere((s) => s.name == deal.shop);
    } catch (_) {}

    String fmtN(double? v) => v != null ? '€ ${widget.numFmt.format(v)}' : '-';
    String fmtD(DateTime? d) => d != null ? widget.dateFmt.format(d) : '-';
    final status = _statusStyle(deal.status);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 46,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDDEBFF) : _rowColor,
          border: const Border(bottom: BorderSide(color: Color(0xFFECF0F6))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: widget.cols[0].width,
              height: 46,
              child: Center(
                child: Checkbox(
                  value: selected,
                  onChanged: (_) => filters.toggleSelected(deal.id),
                ),
              ),
            ),
            _c(Text('${deal.id}', style: _muted()), widget.cols[1]),
            _c(Text(deal.product, style: _strong(), overflow: TextOverflow.ellipsis), widget.cols[2]),
            _c(Text('${deal.quantity}', style: _normal()), widget.cols[3]),
            _c(
                _tag(
                    deal.isDropship
                        ? AppLocalizations.of(context).dealDropship
                        : AppLocalizations.of(context).dealReship,
                    const Color(0xFFF1F5F9),
                    const Color(0xFF64748B)),
                widget.cols[4]),
            _c(shop?.url != null ? _LinkCell(text: deal.shop, url: shop!.url!) : Text(deal.shop, style: _normal(), overflow: TextOverflow.ellipsis), widget.cols[5]),
            _c(Text(widget.dateFmt.format(deal.orderDate), style: _normal()), widget.cols[6]),
            _c(_mono(fmtN(deal.ekNetto)), widget.cols[7]),
            _c(_mono(fmtN(deal.ekBrutto)), widget.cols[8]),
            _c(_mono(fmtN(deal.vk)), widget.cols[9]),
            _c(_buyerBadge(deal, buyer), widget.cols[10]),
            _c(_ticketCell(deal), widget.cols[11]),
            SizedBox(
              width: widget.cols[12].width,
              height: 46,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: deal.tracking != null
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: widget.cols[12].width - 24,
                          child: TrackingChip(
                            tracking: deal.tracking!,
                            compact: true,
                            shopAmazonCountry: amazonCountryFromShop(
                              shopName: shop?.name,
                              region: shop?.region,
                            ),
                          ),
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Text('-', style: _muted()),
                      ),
              ),
            ),
            GestureDetector(
              onDoubleTap: () => _editArrivalDate(context, provider, deal),
              child: _c(Text(fmtD(deal.arrivalDate), style: _normal()), widget.cols[13]),
            ),
            GestureDetector(
              onDoubleTapDown: (details) => _editStatus(context, provider, deal, details.globalPosition),
              child: _c(
                  _statusBadge(localizeDealStatus(context, deal.status),
                      status),
                  widget.cols[14]),
            ),
            _c(_belegBadge(deal.hasReceipt), widget.cols[15]),
            _c(_profitText(fmtN(deal.profitPerUnit), deal.profitPerUnit), widget.cols[16]),
            _c(_profitText(fmtN(deal.totalProfit), deal.totalProfit), widget.cols[17]),
            _c(Text(fmtN(deal.zuBekommen), style: _money()), widget.cols[18]),
            _c(Text(deal.note ?? '', style: _normal(), overflow: TextOverflow.ellipsis), widget.cols[19]),
            SizedBox(
              width: widget.cols[20].width,
              height: 46,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionBtn(
                    icon: Icons.edit_outlined,
                    color: const Color(0xFF2563EB),
                    tooltip: 'Bearbeiten',
                    onTap: () => showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => AddEditDealDialog(deal: deal),
                    ),
                  ),
                  _ActionBtn(
                    icon: Icons.delete_outline,
                    color: const Color(0xFFDC2626),
                    tooltip: 'Löschen',
                    onTap: () => _confirmDelete(context, provider, deal),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ticketCell(Deal deal) {
    if (deal.ticketNumber == null) return Text('-', style: _muted());
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () {
        if (widget.onOpenTicket != null) {
          widget.onOpenTicket!(deal.ticketNumber!);
        } else if (deal.ticketUrl != null) {
          final prov = context.read<InventoryProvider>();
          final buyer = prov.buyers.where((b) => b.name == deal.buyer).firstOrNull;
          final serverIds = buyer?.discordServerIds ?? [];
          openUrlWithFallback(context, resolveDiscordUrl(deal.ticketUrl!, serverIds: serverIds));
        }
      },
      child: Text(
        deal.ticketNumber!,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buyerBadge(Deal deal, Buyer? buyer) {
    if (deal.buyer == null) return Text('-', style: _muted());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: buyer?.buyerCellColor ?? const Color(0xFF64748B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        deal.buyer!,
        style: TextStyle(
          color: buyer?.fontColor ?? Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _c(Widget child, _ColDef col) => SizedBox(
        width: col.width,
        height: 46,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      );

  TextStyle _normal() => const TextStyle(fontSize: 12, color: Color(0xFF475569));
  TextStyle _muted() => const TextStyle(fontSize: 12, color: Color(0xFF94A3B8));
  TextStyle _strong() => const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A));

  Widget _mono(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF334155),
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      );

  Widget _tag(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
      );

  Widget _statusBadge(String label, ({Color bg, Color border, Color text}) style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.border),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: style.text, fontWeight: FontWeight.w700)),
    );
  }

  Widget _belegBadge(bool ok) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ok ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
      ),
      child: Text(
        ok ? l10n.dealReceiptYes : l10n.dealReceiptNo,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ok ? const Color(0xFF15803D) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _profitText(String text, double? value) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: value == null
              ? const Color(0xFF94A3B8)
              : (value >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626)),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );

  TextStyle _money() => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFFD97706),
        fontFeatures: [FontFeature.tabularFigures()],
      );

  ({Color bg, Color border, Color text}) _statusStyle(String s) => switch (s) {
        'Bestellt' => (bg: const Color(0xFFEFF6FF), border: const Color(0xFFBFDBFE), text: const Color(0xFF1D4ED8)),
        'Unterwegs' => (bg: const Color(0xFFFFFBEB), border: const Color(0xFFFDE68A), text: const Color(0xFFB45309)),
        'Angekommen' => (bg: const Color(0xFFF0FDFA), border: const Color(0xFF99F6E4), text: const Color(0xFF0F766E)),
        'Rechnung gestellt' => (bg: const Color(0xFFF5F3FF), border: const Color(0xFFDDD6FE), text: const Color(0xFF6D28D9)),
        'Done' => (bg: const Color(0xFFF0FDF4), border: const Color(0xFFBBF7D0), text: const Color(0xFF15803D)),
        _ => (bg: const Color(0xFFF8FAFC), border: const Color(0xFFE2E8F0), text: const Color(0xFF64748B)),
      };

  Future<void> _editArrivalDate(BuildContext context,
      InventoryProvider provider, Deal deal) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: deal.arrivalDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    await provider.updateDeal(deal.copyWith(
        arrivalDate: picked,
        status: deal.status == 'Unterwegs' ? 'Angekommen' : deal.status));
    if (!context.mounted) return;
    final shouldCheckIn = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.checkInDealTitle),
        content:
            Text(l10n.checkInDealText(deal.quantity, deal.product)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.checkInNo)),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.checkInButton)),
        ],
      ),
    );
    if (shouldCheckIn == true) {
      await provider.checkInDeal(deal.copyWith(arrivalDate: picked));
    }
  }

  Future<void> _editStatus(
    BuildContext context,
    InventoryProvider provider,
    Deal deal,
    Offset position,
  ) async {
    final status = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: InventoryProvider.statusOptions
          .map((s) => PopupMenuItem(
              value: s, child: Text(localizeDealStatus(context, s))))
          .toList(),
    );
    if (status != null) {
      await provider.updateDeal(deal.copyWith(status: status));
    }
  }

  void _confirmDelete(
      BuildContext context, InventoryProvider provider, Deal deal) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.dealDeleteTitle),
        content: Text(l10n.dealDeleteConfirm(deal.product, deal.id)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.actionCancel)),
          ElevatedButton(
            onPressed: () {
              provider.deleteDeal(deal.id);
              Navigator.pop(context);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: Text(l10n.actionDelete,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hovered ? widget.color.withAlpha(22) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: _hovered ? widget.color : const Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkCell extends StatelessWidget {
  final String text;
  final String url;
  const _LinkCell({required this.text, required this.url});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: url,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: const Color(0xFF2563EB),
        ),
        icon: const Icon(Icons.open_in_new, size: 12),
        label: Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: () => openUrlWithFallback(context, url),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined,
              size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 16),
          Text(
            l10n.dealsEmpty,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.dealsEmptyHint,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
