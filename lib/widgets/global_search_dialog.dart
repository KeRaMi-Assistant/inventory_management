import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/buyer.dart';
import '../models/deal.dart';
import '../models/inventory_item.dart';
import '../models/supplier.dart';
import '../models/ticket_summary.dart';
import '../providers/filter_provider.dart';
import '../providers/inventory_provider.dart';

/// Command-palette-style global search across deals, items, tickets, buyers,
/// suppliers. The dialog reads from [InventoryProvider] and dispatches the
/// chosen result via [selectTab] / [openTicket] callbacks supplied by the
/// host (MainScreen) so navigation stays under the host's control.
class GlobalSearchDialog extends StatefulWidget {
  const GlobalSearchDialog({
    super.key,
    required this.selectTab,
    required this.openTicket,
  });

  final ValueChanged<int> selectTab;
  final ValueChanged<String> openTicket;

  static const int dealsTab = 1;
  static const int ticketsTab = 2;
  static const int inboxTab = 3;
  static const int inventoryTab = 4;
  static const int suppliersTab = 5;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<int> selectTab,
    required ValueChanged<String> openTicket,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => GlobalSearchDialog(
        selectTab: selectTab,
        openTicket: openTicket,
      ),
    );
  }

  @override
  State<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<GlobalSearchDialog> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  int _highlight = 0;

  static const _maxPerGroup = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final results = _buildResults(provider);
    final flat = results.expand((g) => g.items).toList();
    if (_highlight >= flat.length) _highlight = flat.length - 1;
    if (_highlight < 0) _highlight = 0;

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
        child: Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.arrowDown):
                const _MoveIntent(1),
            LogicalKeySet(LogicalKeyboardKey.arrowUp):
                const _MoveIntent(-1),
            LogicalKeySet(LogicalKeyboardKey.escape):
                const _CloseIntent(),
            LogicalKeySet(LogicalKeyboardKey.enter):
                const _ActivateIntent(),
            LogicalKeySet(LogicalKeyboardKey.numpadEnter):
                const _ActivateIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _MoveIntent: CallbackAction<_MoveIntent>(
                onInvoke: (intent) {
                  if (flat.isEmpty) return null;
                  setState(() {
                    _highlight =
                        (_highlight + intent.delta).clamp(0, flat.length - 1);
                  });
                  return null;
                },
              ),
              _CloseIntent: CallbackAction<_CloseIntent>(
                onInvoke: (_) {
                  Navigator.of(context).maybePop();
                  return null;
                },
              ),
              _ActivateIntent: CallbackAction<_ActivateIntent>(
                onInvoke: (_) {
                  if (flat.isNotEmpty) flat[_highlight].onTap();
                  return null;
                },
              ),
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SearchField(
                  controller: _controller,
                  focusNode: _focus,
                  onChanged: (v) => setState(() {
                    _query = v;
                    _highlight = 0;
                  }),
                ),
                Divider(height: 1, color: AppTheme.borderOf(context)),
                Flexible(
                  child: _query.trim().isEmpty
                      ? const _PlaceholderHint()
                      : results.isEmpty
                          ? const _NoResults()
                          : _Results(
                              groups: results,
                              highlight: _highlight,
                              flatLength: flat.length,
                            ),
                ),
                Divider(height: 1, color: AppTheme.borderOf(context)),
                const _Footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_ResultGroup> _buildResults(InventoryProvider provider) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final dealHits = provider.deals.where((d) => _dealMatches(d, q)).take(_maxPerGroup).toList();
    final itemHits = provider.inventoryItems.where((i) => _itemMatches(i, q)).take(_maxPerGroup).toList();
    final ticketHits = provider.ticketSummaries
        .where((t) => t.hasTicket && t.ticketNumber.toLowerCase().contains(q))
        .take(_maxPerGroup)
        .toList();
    final buyerHits = provider.buyers
        .where((b) => b.name.toLowerCase().contains(q))
        .take(_maxPerGroup)
        .toList();
    final supplierHits = provider.suppliers
        .where((s) => s.name.toLowerCase().contains(q))
        .take(_maxPerGroup)
        .toList();

    final l10n = AppLocalizations.of(context);
    return [
      if (dealHits.isNotEmpty)
        _ResultGroup(
          l10n.navDeals,
          [for (final d in dealHits) _resultForDeal(d)],
        ),
      if (itemHits.isNotEmpty)
        _ResultGroup(
          l10n.navInventory,
          [for (final i in itemHits) _resultForItem(i)],
        ),
      if (ticketHits.isNotEmpty)
        _ResultGroup(
          l10n.navTickets,
          [for (final t in ticketHits) _resultForTicket(t)],
        ),
      if (buyerHits.isNotEmpty)
        _ResultGroup(
          l10n.dealBuyer,
          [for (final b in buyerHits) _resultForBuyer(b)],
        ),
      if (supplierHits.isNotEmpty)
        _ResultGroup(
          l10n.navSuppliers,
          [for (final s in supplierHits) _resultForSupplier(s)],
        ),
    ];
  }

  bool _dealMatches(Deal d, String q) {
    if (d.product.toLowerCase().contains(q)) return true;
    if ((d.ticketNumber ?? '').toLowerCase().contains(q)) return true;
    if ((d.tracking ?? '').toLowerCase().contains(q)) return true;
    if ((d.buyer ?? '').toLowerCase().contains(q)) return true;
    if ((d.note ?? '').toLowerCase().contains(q)) return true;
    if (d.id.toString() == q) return true;
    return false;
  }

  bool _itemMatches(InventoryItem i, String q) {
    if (i.name.toLowerCase().contains(q)) return true;
    if ((i.sku ?? '').toLowerCase().contains(q)) return true;
    if ((i.ean ?? '').toLowerCase().contains(q)) return true;
    if ((i.location ?? '').toLowerCase().contains(q)) return true;
    return false;
  }

  _Result _resultForDeal(Deal d) {
    return _Result(
      icon: Icons.list_alt_rounded,
      iconColor: AppTheme.accent,
      title: d.product,
      subtitle: '#${d.id} · ${d.shop} · ${d.status}'
          '${d.buyer != null ? " · ${d.buyer}" : ""}',
      onTap: () {
        final filters = context.read<FilterProvider>();
        filters
          ..reset()
          ..setSearch(d.product);
        widget.selectTab(GlobalSearchDialog.dealsTab);
        Navigator.of(context).pop();
      },
    );
  }

  _Result _resultForItem(InventoryItem i) {
    final eanLabel = (i.ean != null && i.ean!.isNotEmpty) ? ' · EAN ${i.ean}' : '';
    return _Result(
      icon: Icons.inventory_2_rounded,
      iconColor: AppTheme.success,
      title: i.name,
      subtitle:
          '${i.quantity} Stk.${i.location != null ? " · ${i.location}" : ""}'
          '${i.sku != null ? " · ${i.sku}" : ""}$eanLabel',
      onTap: () {
        widget.selectTab(GlobalSearchDialog.inventoryTab);
        Navigator.of(context).pop();
      },
    );
  }

  _Result _resultForTicket(TicketSummary t) {
    return _Result(
      icon: Icons.confirmation_number_rounded,
      iconColor: AppTheme.warning,
      title: t.ticketNumber,
      subtitle: '${t.dealCount} Deal(s) · ${t.worstStatus} · ${t.arrivalSummary}',
      onTap: () {
        widget.openTicket(t.ticketNumber);
        Navigator.of(context).pop();
      },
    );
  }

  _Result _resultForBuyer(Buyer b) {
    return _Result(
      icon: Icons.person_outline_rounded,
      iconColor: AppTheme.info,
      title: b.name,
      subtitle: 'Käufer · Deals filtern',
      onTap: () {
        final filters = context.read<FilterProvider>();
        filters
          ..reset()
          ..setBuyer(b.name);
        widget.selectTab(GlobalSearchDialog.dealsTab);
        Navigator.of(context).pop();
      },
    );
  }

  _Result _resultForSupplier(Supplier s) {
    return _Result(
      icon: Icons.local_shipping_rounded,
      iconColor: AppTheme.accentDark,
      title: s.name,
      subtitle: 'Lieferant${s.contactName != null ? " · ${s.contactName}" : ""}',
      onTap: () {
        widget.selectTab(GlobalSearchDialog.suppliersTab);
        Navigator.of(context).pop();
      },
    );
  }
}

// ─── Inner models ────────────────────────────────────────────────────────────

class _Result {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Result({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _ResultGroup {
  final String label;
  final List<_Result> items;
  const _ResultGroup(this.label, this.items);
}

// ─── Intents ─────────────────────────────────────────────────────────────────

class _MoveIntent extends Intent {
  final int delta;
  const _MoveIntent(this.delta);
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}

class _ActivateIntent extends Intent {
  const _ActivateIntent();
}

// ─── UI parts ────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, size: 20),
          hintText: 'Suchen über Deals, Lager, Tickets, Käufer, Lieferanten…',
          hintStyle: const TextStyle(fontSize: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: false,
        ),
        style: GoogleFonts.inter(fontSize: 15),
        onChanged: onChanged,
      ),
    );
  }
}

class _Results extends StatelessWidget {
  final List<_ResultGroup> groups;
  final int highlight;
  final int flatLength;

  const _Results({
    required this.groups,
    required this.highlight,
    required this.flatLength,
  });

  @override
  Widget build(BuildContext context) {
    int idx = 0;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              group.label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMutedOf(context),
                letterSpacing: 0.6,
              ),
            ),
          ),
          for (final item in group.items)
            _ResultTile(
              result: item,
              highlighted: idx++ == highlight,
            ),
        ],
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final _Result result;
  final bool highlighted;
  const _ResultTile({required this.result, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? AppTheme.accentLight : Colors.transparent,
      child: InkWell(
        onTap: result.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: result.iconColor.withAlpha(28),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(result.icon, color: result.iconColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMutedOf(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (highlighted)
                Icon(Icons.subdirectory_arrow_left,
                    size: 14, color: AppTheme.textMutedOf(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderHint extends StatelessWidget {
  const _PlaceholderHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipp:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMutedOf(context),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          _hint('Produktname, EAN, SKU, Ticket-Nummer, Käufer-Name…', context),
          _hint('↑ ↓ navigieren · ↵ öffnen · esc schließt.', context),
        ],
      ),
    );
  }

  Widget _hint(String text, BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          text,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
        ),
      );
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: AppTheme.textDisabledOf(context), size: 36),
            SizedBox(height: 8),
            Text(
              'Keine Treffer.',
              style: TextStyle(
                  color: AppTheme.textMutedOf(context), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AppTheme.bgSubtleOf(context),
      child: Row(
        children: [
          const _Kbd('↑↓'),
          const SizedBox(width: 6),
          Text(l10n.globalSearchKeyNav, style: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context))),
          const SizedBox(width: 14),
          const _Kbd('↵'),
          const SizedBox(width: 6),
          Text(l10n.globalSearchKeyOpen, style: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context))),
          const SizedBox(width: 14),
          const _Kbd('esc'),
          const SizedBox(width: 6),
          Text(l10n.globalSearchKeyClose, style: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context))),
        ],
      ),
    );
  }
}

class _Kbd extends StatelessWidget {
  final String label;
  const _Kbd(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        border: Border.all(color: AppTheme.borderOf(context)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondaryOf(context),
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
