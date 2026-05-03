import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/deal.dart';
import '../models/inventory_item.dart';
import '../providers/inventory_provider.dart';
import '../utils/url_helper.dart';
import '../utils/validators.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            final money = NumberFormat.currency(locale: 'de_DE', symbol: '€');
            final query = _search.trim().toLowerCase();
            final items = query.isEmpty
                ? provider.inventoryItems
                : provider.inventoryItems
                    .where((i) =>
                        i.name.toLowerCase().contains(query) ||
                        (i.sku?.toLowerCase().contains(query) ?? false))
                    .toList();
            return Column(
              children: [
                _buildHeader(context, provider, isNarrow, money, constraints.maxWidth),
                if (provider.criticalStockCount > 0)
                  _LowStockBanner(count: provider.criticalStockCount),
                _buildSearchBar(),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: provider.inventoryItems.isEmpty
                              ? _EmptyInventoryState(provider: provider)
                              : const Text('Keine Artikel gefunden.'),
                        )
                      : isNarrow
                          ? _buildCardList(context, provider, money, items)
                          : _buildTable(context, provider, money, items),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search, size: 18),
          hintText: 'Artikel suchen (Name oder SKU)…',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (v) => setState(() => _search = v),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, InventoryProvider provider, bool isNarrow, NumberFormat money, double width) {
    final kpis = [
      _kpi('Gesamtartikel', '${provider.inventoryItems.length}', Icons.category_outlined, const Color(0xFF2563EB)),
      _kpi('Gesamtbestand', '${provider.totalStockQuantity}', Icons.inventory_2_outlined, const Color(0xFF059669)),
      _kpi('Kritische Artikel', '${provider.criticalStockCount}', Icons.warning_amber_rounded, const Color(0xFFDC2626)),
      _kpi('Lagerwert', money.format(provider.totalStockValue), Icons.euro_outlined, const Color(0xFFD97706)),
    ];
    final addButton = ElevatedButton.icon(
      onPressed: () => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _InventoryDialog(),
      ),
      icon: const Icon(Icons.add, size: 16),
      label: const Text('Artikel hinzufügen'),
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
                  Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                  Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardList(BuildContext context, InventoryProvider provider, NumberFormat money, List<InventoryItem> items) {
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
                        tooltip: 'Discord-Ticket öffnen',
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
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: color),
                    const SizedBox(width: 4),
                    Text('${item.quantity} Stück', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
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
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                    _statusChip(item.status),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _adjust(context, provider, item, true),
                      icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF059669)),
                      label: const Text('Ein', style: TextStyle(color: Color(0xFF059669), fontSize: 12)),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                    ),
                    TextButton.icon(
                      onPressed: () => _adjust(context, provider, item, false),
                      icon: const Icon(Icons.remove_circle_outline, size: 16, color: Color(0xFFD97706)),
                      label: const Text('Aus', style: TextStyle(color: Color(0xFFD97706), fontSize: 12)),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                    ),
                    IconButton(
                      tooltip: 'Bearbeiten',
                      onPressed: () => showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => _InventoryDialog(item: item),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Löschen',
                      onPressed: () => provider.deleteInventoryItem(item.id),
                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status, style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildTable(BuildContext context, InventoryProvider provider, NumberFormat money, List<InventoryItem> items) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 42,
            columns: const [
              DataColumn(label: Text('SKU')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Lagerort')),
              DataColumn(label: Text('Bestand')),
              DataColumn(label: Text('Mindestbestand')),
              DataColumn(label: Text('Ø EK-Preis')),
              DataColumn(label: Text('Deal/Ticket')),
              DataColumn(label: Text('Ankunft')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Aktionen')),
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
    final date = DateFormat('dd.MM.yyyy');
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
                message: 'Discord-Ticket öffnen',
                child: InkWell(
                  onTap: () => openUrlWithFallback(context, resolveDiscordUrl(item.ticketUrl!)),
                  child: const Icon(Icons.open_in_new, size: 14, color: Color(0xFF5865F2)),
                ),
              ),
            ],
          ],
        )),
        DataCell(Text(item.arrivalDate != null ? date.format(item.arrivalDate!) : '-')),
        DataCell(Text(item.status)),
        DataCell(Row(
          children: [
            IconButton(
              tooltip: 'Einbuchen',
              onPressed: () => _adjust(context, provider, item, true),
              icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF059669)),
            ),
            IconButton(
              tooltip: 'Ausbuchen',
              onPressed: () => _adjust(context, provider, item, false),
              icon: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFFD97706)),
            ),
            IconButton(
              tooltip: 'Bearbeiten',
              onPressed: () => showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => _InventoryDialog(item: item),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
            IconButton(
              tooltip: 'Löschen',
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
    final ctrl = TextEditingController(text: '1');
    final reason = TextEditingController(text: incoming ? 'Einbuchung' : 'Verkauf');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(incoming ? 'Einbuchen' : 'Ausbuchen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Menge'), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Grund')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Speichern')),
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
  const _InventoryDialog({this.item});

  @override
  State<_InventoryDialog> createState() => _InventoryDialogState();
}

class _InventoryDialogState extends State<_InventoryDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _min = TextEditingController(text: '0');
  final _location = TextEditingController();
  final _cost = TextEditingController();
  final _ticketUrl = TextEditingController();
  final _note = TextEditingController();
  String _status = 'Im Lager';
  String _selectedTicketNumber = '';

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _name.text = item.name;
      _sku.text = item.sku ?? '';
      _quantity.text = '${item.quantity}';
      _min.text = '${item.minStock}';
      _location.text = item.location ?? '';
      _cost.text = item.costPrice?.toStringAsFixed(2) ?? '';
      _selectedTicketNumber = item.ticketNumber ?? '';
      _ticketUrl.text = item.ticketUrl ?? '';
      _note.text = item.note ?? '';
      _status = item.status;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
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
            decoration: const InputDecoration(
              labelText: 'Produkt *',
              suffixIcon: Icon(Icons.arrow_drop_down, size: 20),
              helperText: 'Aus Ticket auswählen oder frei eingeben',
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
      decoration: const InputDecoration(labelText: 'Produkt *'),
      maxLength: Validators.maxProductName,
      validator: Validators.validateProductName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<InventoryProvider>();
    final ticketNumbers = provider.ticketSummaries
        .map((t) => t.ticketNumber)
        .where((t) => t != 'Kein Ticket')
        .toList();

    return AlertDialog(
      title: Text(widget.item == null ? 'Artikel hinzufügen' : 'Artikel bearbeiten'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                            decoration: const InputDecoration(
                              labelText: 'Ticket',
                              suffixIcon: Icon(Icons.arrow_drop_down, size: 20),
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
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: InventoryProvider.inventoryStatusOptions
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // ── 2. Product – dropdown if ticket has deals ─────────────────
                _buildProductField(provider),
                const SizedBox(height: 10),
                // ── 3. Quantity + SKU ─────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      decoration: const InputDecoration(labelText: 'Angekommen (Stk.)'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          Validators.validateNonNegativeInt(v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _sku,
                      decoration: const InputDecoration(labelText: 'Produktnummer (optional)'),
                      maxLength: Validators.maxSku,
                      validator: (v) => Validators.validateSku(v),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                // ── 4. Min stock + cost + location ────────────────────────────
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _min,
                      decoration: const InputDecoration(labelText: 'Mindestbestand'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          Validators.validateNonNegativeInt(v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _cost,
                      decoration: const InputDecoration(labelText: 'Ø EK-Preis'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => Validators.validateMoney(v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _location,
                      decoration: const InputDecoration(labelText: 'Lagerort'),
                      maxLength: 100,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _ticketUrl,
                  decoration: const InputDecoration(
                    labelText: 'Discord-Ticket Link',
                    hintText: 'https://discord.com/...',
                    prefixIcon: Icon(Icons.link, size: 18),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (v) => Validators.validateUrl(v),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _note,
                  decoration: const InputDecoration(labelText: 'Notiz'),
                  maxLines: 2,
                  maxLength: Validators.maxNote,
                  validator: Validators.validateNote,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        ElevatedButton(
          onPressed: () async {
            if (!_form.currentState!.validate()) return;
            final prov = context.read<InventoryProvider>();
            final item = InventoryItem(
              id: widget.item?.id ?? '',
              name: _name.text.trim(),
              sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
              quantity: int.tryParse(_quantity.text) ?? 0,
              minStock: int.tryParse(_min.text) ?? 0,
              location: _location.text.trim().isEmpty ? null : _location.text.trim(),
              costPrice: double.tryParse(_cost.text.replaceAll(',', '.')),
              arrivalDate: widget.item?.arrivalDate ?? DateTime.now(),
              dealId: widget.item?.dealId,
              ticketNumber: _selectedTicketNumber.trim().isEmpty ? null : _selectedTicketNumber.trim(),
              ticketUrl: _ticketUrl.text.trim().isEmpty ? null : _ticketUrl.text.trim(),
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              status: _status,
            );
            if (widget.item == null) {
              await prov.addInventoryItem(item);
            } else {
              await prov.updateInventoryItem(item);
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

// ─── Low-stock warning banner ─────────────────────────────────────────────────
class _LowStockBanner extends StatefulWidget {
  final int count;
  const _LowStockBanner({required this.count});

  @override
  State<_LowStockBanner> createState() => _LowStockBannerState();
}

class _EmptyInventoryState extends StatefulWidget {
  const _EmptyInventoryState({required this.provider});
  final InventoryProvider provider;

  @override
  State<_EmptyInventoryState> createState() => _EmptyInventoryStateState();
}

class _EmptyInventoryStateState extends State<_EmptyInventoryState> {
  bool _loading = false;

  Future<void> _seed() async {
    setState(() => _loading = true);
    final added = await widget.provider.seedDemoInventory();
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$added Demo-Artikel angelegt.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
        const SizedBox(height: 12),
        const Text('Noch keine Lagerartikel angelegt.'),
        const SizedBox(height: 16),
        _loading
            ? const CircularProgressIndicator()
            : OutlinedButton.icon(
                onPressed: _seed,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Demo-Daten laden'),
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
    return MaterialBanner(
      backgroundColor: const Color(0xFFFEF2F2),
      leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
      content: Text(
        '${widget.count} Artikel ${widget.count == 1 ? "hat" : "haben"} Bestand unter dem Mindestbestand!',
        style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _dismissed = true),
          child: const Text('Schließen', style: TextStyle(color: Color(0xFFDC2626))),
        ),
      ],
    );
  }
}
