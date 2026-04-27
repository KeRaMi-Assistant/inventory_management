import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/buyer.dart';
import '../models/deal.dart';
import '../models/shop.dart';
import '../providers/inventory_provider.dart';
import '../utils/url_helper.dart';
import 'add_edit_deal_dialog.dart';

class _ColDef {
  final String label;
  final double width;
  const _ColDef(this.label, this.width);
}

class DealTable extends StatefulWidget {
  const DealTable({super.key});

  @override
  State<DealTable> createState() => _DealTableState();
}

class _DealTableState extends State<DealTable> {
  final _headerScroll = ScrollController();
  final _bodyScroll = ScrollController();
  bool _syncing = false;

  static const _cols = <_ColDef>[
    _ColDef('ID', 52),
    _ColDef('Produkt', 175),
    _ColDef('Anz.', 52),
    _ColDef('Versandtyp', 108),
    _ColDef('Shop', 110),
    _ColDef('Bestelldatum', 110),
    _ColDef('EK Netto', 90),
    _ColDef('EK Brutto', 90),
    _ColDef('VK', 90),
    _ColDef('Käufer', 112),
    _ColDef('Ticket', 90),
    _ColDef('Tracking', 122),
    _ColDef('Ankunft', 100),
    _ColDef('Status', 132),
    _ColDef('Beleg', 68),
    _ColDef('Profit/Stk', 94),
    _ColDef('Ges. Profit', 100),
    _ColDef('Zu bekommen', 106),
    _ColDef('Notiz', 140),
    _ColDef('', 84),
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
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final deals = provider.deals;
        if (deals.isEmpty) return _buildEmpty();

        final dateFmt = DateFormat('dd.MM.yyyy');
        final numFmt = NumberFormat('#,##0.00', 'de_DE');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Sticky header ──────────────────────────────────────────────
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
                  children: _cols
                      .map((c) => _HeaderCell(label: c.label, width: c.width))
                      .toList(),
                ),
              ),
            ),
            // ── Body rows ─────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
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
                          dateFmt: dateFmt,
                          numFmt: numFmt,
                          cols: _cols,
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inbox_outlined,
                size: 48, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Keine Einträge vorhanden',
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Klicke auf „Neuer Eintrag" um einen Deal hinzuzufügen.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Header cell ────────────────────────────────────────────────────────────

class _HeaderCell extends StatelessWidget {
  final String label;
  final double width;
  const _HeaderCell({required this.label, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 38,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ─── Data row ────────────────────────────────────────────────────────────────

class _DealRow extends StatefulWidget {
  final Deal deal;
  final bool isEven;
  final InventoryProvider provider;
  final DateFormat dateFmt;
  final NumberFormat numFmt;
  final List<_ColDef> cols;

  const _DealRow({
    required this.deal,
    required this.isEven,
    required this.provider,
    required this.dateFmt,
    required this.numFmt,
    required this.cols,
  });

  @override
  State<_DealRow> createState() => _DealRowState();
}

class _DealRowState extends State<_DealRow> {
  bool _hovered = false;

  Color get _rowColor {
    Buyer? buyer;
    try {
      buyer = widget.provider.buyers
          .firstWhere((b) => b.name == widget.deal.buyer);
    } catch (_) {}

    final base = buyer?.rowFillColor;
    final hasBase = base != null && base.a > 0;

    if (_hovered) {
      return hasBase
          ? Color.alphaBlend(const Color(0x22000000), base)
          : const Color(0xFFEFF3FC);
    }
    if (hasBase) return base;
    return widget.isEven ? Colors.white : const Color(0xFFFAFBFD);
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final provider = widget.provider;

    Buyer? buyer;
    try {
      buyer = provider.buyers.firstWhere((b) => b.name == deal.buyer);
    } catch (_) {}

    Shop? shop;
    try {
      shop = provider.shops.firstWhere((s) => s.name == deal.shop);
    } catch (_) {}

    final shopUrl = shop?.url;

    String fmtN(double? v) => v != null ? '€\u202F${widget.numFmt.format(v)}' : '–';
    String fmtD(DateTime? d) =>
        d != null ? widget.dateFmt.format(d) : '–';

    final status = _statusStyle(deal.status);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 46,
        decoration: BoxDecoration(
          color: _rowColor,
          border: const Border(
            bottom: BorderSide(color: Color(0xFFECF0F6), width: 1),
          ),
        ),
        child: Row(
          children: [
            _c(Text('${deal.id}',
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500)),
                widget.cols[0]),
            _c(
              Text(deal.product,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis),
              widget.cols[1],
            ),
            _c(
              Text('${deal.quantity}',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF334155))),
              widget.cols[2],
            ),
            _c(
              _tag(deal.shippingType, const Color(0xFFF1F5F9),
                  const Color(0xFF64748B)),
              widget.cols[3],
            ),
            _c(
              shopUrl != null
                  ? _LinkCell(text: deal.shop, url: shopUrl)
                  : Text(deal.shop,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF334155)),
                      overflow: TextOverflow.ellipsis),
              widget.cols[4],
            ),
            _c(
              Text(widget.dateFmt.format(deal.orderDate),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF475569))),
              widget.cols[5],
            ),
            _c(_mono(fmtN(deal.ekNetto)), widget.cols[6]),
            _c(_mono(fmtN(deal.ekBrutto)), widget.cols[7]),
            _c(_mono(fmtN(deal.vk)), widget.cols[8]),
            // Buyer badge
            _c(
              deal.buyer != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
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
                    )
                  : const Text('–',
                      style: TextStyle(
                          color: Color(0xFFCBD5E1), fontSize: 12)),
              widget.cols[9],
            ),
            _c(
              deal.ticketNumber != null
                  ? (deal.ticketUrl != null
                      ? _LinkCell(text: deal.ticketNumber!, url: deal.ticketUrl!)
                      : Text(deal.ticketNumber!,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis))
                  : const Text('–',
                      style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
              widget.cols[10],
            ),
            _c(
              Text(deal.tracking ?? '–',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis),
              widget.cols[11],
            ),
            _c(
              Text(fmtD(deal.arrivalDate),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF475569))),
              widget.cols[12],
            ),
            // Status badge
            _c(
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: status.border),
                ),
                child: Text(
                  deal.status,
                  style: TextStyle(
                    fontSize: 11,
                    color: status.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              widget.cols[13],
            ),
            // Beleg badge
            _c(
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: deal.beleg == 'Ja'
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: deal.beleg == 'Ja'
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  deal.beleg,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: deal.beleg == 'Ja'
                        ? const Color(0xFF15803D)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
              widget.cols[14],
            ),
            _c(_profitText(fmtN(deal.profitPerUnit), deal.profitPerUnit),
                widget.cols[15]),
            _c(_profitText(fmtN(deal.totalProfit), deal.totalProfit),
                widget.cols[16]),
            _c(
              Text(
                fmtN(deal.zuBekommen),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: (deal.zuBekommen ?? 0) > 0
                      ? const Color(0xFFD97706)
                      : const Color(0xFF94A3B8),
                ),
              ),
              widget.cols[17],
            ),
            _c(
              Text(deal.note ?? '',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis),
              widget.cols[18],
            ),
            // Actions
            SizedBox(
              width: widget.cols[19].width,
              height: 46,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ActionBtn(
                      icon: Icons.edit_outlined,
                      color: const Color(0xFF2563EB),
                      tooltip: 'Bearbeiten',
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => AddEditDealDialog(deal: deal),
                      ),
                    ),
                    const SizedBox(width: 2),
                    _ActionBtn(
                      icon: Icons.delete_outline,
                      color: const Color(0xFFDC2626),
                      tooltip: 'Löschen',
                      onTap: () => _confirmDelete(context, provider, deal),
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

  Widget _c(Widget child, _ColDef col) => SizedBox(
        width: col.width,
        height: 46,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      );

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
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: fg,
                fontWeight: FontWeight.w500)),
      );

  Widget _profitText(String text, double? value) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: value == null
              ? const Color(0xFF94A3B8)
              : (value >= 0
                  ? const Color(0xFF059669)
                  : const Color(0xFFDC2626)),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );

  ({Color bg, Color border, Color text}) _statusStyle(String s) => switch (s) {
        'Bestellt' => (
            bg: const Color(0xFFEFF6FF),
            border: const Color(0xFFBFDBFE),
            text: const Color(0xFF1D4ED8)
          ),
        'Unterwegs' => (
            bg: const Color(0xFFFFFBEB),
            border: const Color(0xFFFDE68A),
            text: const Color(0xFFB45309)
          ),
        'Rechnung gestellt' => (
            bg: const Color(0xFFF5F3FF),
            border: const Color(0xFFDDD6FE),
            text: const Color(0xFF6D28D9)
          ),
        'Done' => (
            bg: const Color(0xFFF0FDF4),
            border: const Color(0xFFBBF7D0),
            text: const Color(0xFF15803D)
          ),
        _ => (
            bg: const Color(0xFFF8FAFC),
            border: const Color(0xFFE2E8F0),
            text: const Color(0xFF64748B)
          ),
      };

  void _confirmDelete(
      BuildContext context, InventoryProvider provider, Deal deal) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eintrag löschen'),
        content: Text(
            '„${deal.product}" (ID: ${deal.id}) wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteDeal(deal.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Löschen',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Action button with hover ────────────────────────────────────────────────

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

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
              color: _hovered
                  ? widget.color.withAlpha(22)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: _hovered
                  ? widget.color
                  : const Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tappable link cell that opens a URL in the browser.
/// Uses dart:html on web (guaranteed), url_launcher on native.
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: const Color(0xFF2563EB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: Color(0xFFBFD7FF)),
          ),
          backgroundColor: const Color(0xFFEFF6FF),
        ),
        icon: const Icon(Icons.open_in_new, size: 12),
        label: Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: () => openUrl(url),
      ),
    );
  }
}

