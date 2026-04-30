import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/buyer.dart';
import '../models/deal.dart';
import '../models/shop.dart';
import '../providers/filter_provider.dart';
import '../providers/inventory_provider.dart';
import '../utils/url_helper.dart';
import 'add_edit_deal_dialog.dart';

class _ColDef {
  final String label;
  final String sortKey;
  final double width;
  const _ColDef(this.label, this.sortKey, this.width);
}

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
    _ColDef('ID', 'id', 58),
    _ColDef('Produkt', 'product', 190),
    _ColDef('Anz.', 'quantity', 58),
    _ColDef('Versandtyp', 'shippingType', 110),
    _ColDef('Shop', 'shop', 120),
    _ColDef('Bestelldatum', 'orderDate', 118),
    _ColDef('EK Netto', 'ekNetto', 96),
    _ColDef('EK Brutto', 'ekBrutto', 96),
    _ColDef('VK', 'vk', 90),
    _ColDef('Käufer', 'buyer', 126),
    _ColDef('Ticket', 'ticketNumber', 130),
    _ColDef('Tracking', 'tracking', 130),
    _ColDef('Ankunft', 'arrivalDate', 108),
    _ColDef('Status', 'status', 148),
    _ColDef('Beleg', 'beleg', 74),
    _ColDef('Profit/Stk', 'profitPerUnit', 98),
    _ColDef('Ges. Profit', 'totalProfit', 104),
    _ColDef('Zu bekommen', 'zuBekommen', 112),
    _ColDef('Notiz', 'note', 150),
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterBar(provider: provider, filters: filters),
            if (filters.selectedDealIds.isNotEmpty)
              _BulkActionBar(provider: provider, filters: filters),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFDDE3ED), width: 1.5),
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
                                    filters.selectAll(deals.map((d) => d.id));
                                  }
                                },
                        ),
                      ),
                    ),
                    ..._cols.skip(1).map(
                          (c) => _HeaderCell(
                            label: c.label,
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
                decoration: const InputDecoration(
                  hintText: 'Produkt, Ticket, Tracking, Notiz',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
                onChanged: filters.setSearch,
              ),
            ),
            _dropdown(
              width: 140,
              label: 'Käufer',
              value: filters.buyer,
              values: provider.buyers.map((b) => b.name).toList(),
              onChanged: filters.setBuyer,
            ),
            _dropdown(
              width: 150,
              label: 'Status',
              value: filters.status,
              values: InventoryProvider.statusOptions,
              onChanged: filters.setStatus,
            ),
            _dropdown(
              width: 140,
              label: 'Shop',
              value: filters.shop,
              values: provider.shops.map((s) => s.name).toList(),
              onChanged: filters.setShop,
            ),
            _dropdown(
              width: 130,
              label: 'Versand',
              value: filters.shippingType,
              values: InventoryProvider.shippingTypes,
              onChanged: filters.setShippingType,
            ),
            _dropdown(
              width: 100,
              label: 'Beleg',
              value: filters.beleg,
              values: InventoryProvider.belegOptions,
              onChanged: filters.setBeleg,
            ),
            OutlinedButton.icon(
              onPressed: () => _pickRange(context),
              icon: const Icon(Icons.date_range_outlined, size: 16),
              label: Text(_dateLabel()),
            ),
            IconButton(
              tooltip: 'Filter zurücksetzen',
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
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem(value: null, child: Text('Alle')),
          ...values.map((v) => DropdownMenuItem(value: v, child: Text(v))),
        ],
        onChanged: onChanged,
      ),
    );
  }

  String _dateLabel() {
    final fmt = DateFormat('dd.MM.yy');
    if (filters.fromDate == null && filters.toDate == null) return 'Datum';
    final from = filters.fromDate != null ? fmt.format(filters.fromDate!) : '...';
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
            '${ids.length} ausgewählt',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D4ED8),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Status ändern',
            onSelected: (status) async {
              await provider.updateDealsStatus(ids, status);
              filters.clearSelection();
            },
            itemBuilder: (_) => InventoryProvider.statusOptions
                .map((s) => PopupMenuItem(value: s, child: Text(s)))
                .toList(),
            child: const _BulkButton(icon: Icons.flag_outlined, label: 'Status'),
          ),
          PopupMenuButton<String?>(
            tooltip: 'Käufer zuweisen',
            onSelected: (buyer) async {
              await provider.assignDealsBuyer(ids, buyer);
              filters.clearSelection();
            },
            itemBuilder: (_) => [
              const PopupMenuItem<String?>(value: null, child: Text('Kein Käufer')),
              ...provider.buyers
                  .map((b) => PopupMenuItem<String?>(value: b.name, child: Text(b.name))),
            ],
            child: const _BulkButton(icon: Icons.person_outline, label: 'Käufer'),
          ),
          TextButton.icon(
            onPressed: () async {
              await provider.deleteDeals(ids);
              filters.clearSelection();
            },
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Löschen'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
          ),
          IconButton(
            tooltip: 'Auswahl aufheben',
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
            _c(_tag(deal.shippingType, const Color(0xFFF1F5F9), const Color(0xFF64748B)), widget.cols[4]),
            _c(shop?.url != null ? _LinkCell(text: deal.shop, url: shop!.url!) : Text(deal.shop, style: _normal(), overflow: TextOverflow.ellipsis), widget.cols[5]),
            _c(Text(widget.dateFmt.format(deal.orderDate), style: _normal()), widget.cols[6]),
            _c(_mono(fmtN(deal.ekNetto)), widget.cols[7]),
            _c(_mono(fmtN(deal.ekBrutto)), widget.cols[8]),
            _c(_mono(fmtN(deal.vk)), widget.cols[9]),
            _c(_buyerBadge(deal, buyer), widget.cols[10]),
            _c(_ticketCell(deal), widget.cols[11]),
            _c(deal.tracking != null ? _LinkCell(text: deal.tracking!, url: _trackingUrl(deal.tracking!)) : Text('-', style: _muted()), widget.cols[12]),
            GestureDetector(
              onDoubleTap: () => _editArrivalDate(context, provider, deal),
              child: _c(Text(fmtD(deal.arrivalDate), style: _normal()), widget.cols[13]),
            ),
            GestureDetector(
              onDoubleTapDown: (details) => _editStatus(context, provider, deal, details.globalPosition),
              child: _c(_statusBadge(deal.status, status), widget.cols[14]),
            ),
            _c(_belegBadge(deal.beleg), widget.cols[15]),
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
          openUrlWithFallback(context, deal.ticketUrl!);
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

  Widget _belegBadge(String beleg) {
    final ok = beleg == 'Ja';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ok ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
      ),
      child: Text(
        beleg,
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

  String _trackingUrl(String tracking) {
    final value = tracking.trim();
    if (value.startsWith('http')) return value;
    return 'https://www.google.com/search?q=${Uri.encodeComponent(value)}';
  }

  Future<void> _editArrivalDate(BuildContext context, InventoryProvider provider, Deal deal) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: deal.arrivalDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    await provider.updateDeal(deal.copyWith(arrivalDate: picked, status: deal.status == 'Unterwegs' ? 'Angekommen' : deal.status));
    if (!context.mounted) return;
    final shouldCheckIn = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Artikel ins Lager einbuchen?'),
        content: Text('${deal.quantity}x ${deal.product} als Lagerartikel anlegen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nein')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Einbuchen')),
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
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: InventoryProvider.statusOptions
          .map((s) => PopupMenuItem(value: s, child: Text(s)))
          .toList(),
    );
    if (status != null) await provider.updateDeal(deal.copyWith(status: status));
  }

  void _confirmDelete(BuildContext context, InventoryProvider provider, Deal deal) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eintrag löschen'),
        content: Text('"${deal.product}" (ID: ${deal.id}) wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              provider.deleteDeal(deal.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Löschen', style: TextStyle(color: Colors.white)),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF94A3B8)),
          SizedBox(height: 16),
          Text(
            'Keine Deals gefunden',
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Filter anpassen oder einen neuen Deal anlegen.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
