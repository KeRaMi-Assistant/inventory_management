import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/ticket_summary.dart';
import '../providers/inventory_provider.dart';
import '../utils/url_helper.dart';
import '../widgets/add_edit_deal_dialog.dart';

class TicketsScreen extends StatefulWidget {
  final String? initialTicket;
  const TicketsScreen({super.key, this.initialTicket});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  String _search = '';
  String? _buyer;
  String? _status;
  String _sort = 'Datum';
  String? _selectedTicket;

  @override
  void initState() {
    super.initState();
    _selectedTicket = widget.initialTicket;
  }

  @override
  void didUpdateWidget(covariant TicketsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTicket != oldWidget.initialTicket && widget.initialTicket != null) {
      _selectedTicket = widget.initialTicket;
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final tickets = _filtered(provider.ticketSummaries);
        final selected = tickets.where((t) => t.ticketNumber == _selectedTicket).firstOrNull ??
            tickets.firstOrNull;
        return LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 650;
            if (narrow) {
              return _TicketsMobileLayout(
                tickets: tickets,
                selected: selected,
                money: money,
                onSelectTicket: (t) => setState(() => _selectedTicket = t),
                search: _search,
                buyer: _buyer,
                status: _status,
                sort: _sort,
                onSearch: (v) => setState(() => _search = v),
                onBuyer: (v) => setState(() => _buyer = v),
                onStatus: (v) => setState(() => _status = v),
                onSort: (v) => setState(() => _sort = v ?? 'Datum'),
                provider: provider,
              );
            }
            return Row(
              children: [
                SizedBox(
                  width: constraints.maxWidth > 1100 ? 440 : 360,
                  child: Column(
                    children: [
                      _TicketFilters(
                        provider: provider,
                        search: _search,
                        buyer: _buyer,
                        status: _status,
                        sort: _sort,
                        onSearch: (v) => setState(() => _search = v),
                        onBuyer: (v) => setState(() => _buyer = v),
                        onStatus: (v) => setState(() => _status = v),
                        onSort: (v) => setState(() => _sort = v ?? 'Datum'),
                      ),
                      Expanded(
                        child: tickets.isEmpty
                            ? const Center(child: Text('Keine Tickets gefunden.'))
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: tickets.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final ticket = tickets[i];
                                  return _TicketCard(
                                    ticket: ticket,
                                    money: money,
                                    selected: selected?.ticketNumber == ticket.ticketNumber,
                                    onTap: () => setState(() => _selectedTicket = ticket.ticketNumber),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: selected == null
                      ? const Center(child: Text('Ticket auswählen'))
                      : _TicketDetail(ticket: selected, money: money),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<TicketSummary> _filtered(List<TicketSummary> tickets) {
    final query = _search.trim().toLowerCase();
    final filtered = tickets.where((ticket) {
      if (query.isNotEmpty && !ticket.ticketNumber.toLowerCase().contains(query)) {
        return false;
      }
      if (_buyer != null && ticket.buyer != _buyer) return false;
      if (_status != null && ticket.worstStatus != _status) return false;
      return true;
    }).toList();
    filtered.sort((a, b) {
      return switch (_sort) {
        'Profit' => b.totalProfit.compareTo(a.totalProfit),
        'Anzahl Deals' => b.dealCount.compareTo(a.dealCount),
        _ => b.newestDate.compareTo(a.newestDate),
      };
    });
    return filtered;
  }
}

// ─── Mobile tab layout for tickets ───────────────────────────────────────────
class _TicketsMobileLayout extends StatefulWidget {
  final List<TicketSummary> tickets;
  final TicketSummary? selected;
  final NumberFormat money;
  final ValueChanged<String> onSelectTicket;
  final InventoryProvider provider;
  final String search;
  final String? buyer;
  final String? status;
  final String sort;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onBuyer;
  final ValueChanged<String?> onStatus;
  final ValueChanged<String?> onSort;

  const _TicketsMobileLayout({
    required this.tickets,
    required this.selected,
    required this.money,
    required this.onSelectTicket,
    required this.provider,
    required this.search,
    required this.buyer,
    required this.status,
    required this.sort,
    required this.onSearch,
    required this.onBuyer,
    required this.onStatus,
    required this.onSort,
  });

  @override
  State<_TicketsMobileLayout> createState() => _TicketsMobileLayoutState();
}

class _TicketsMobileLayoutState extends State<_TicketsMobileLayout>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Tickets'),
            Tab(text: 'Detail'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              // ── Tab 0: ticket list ──────────────────────────────────────
              Column(
                children: [
                  _TicketFilters(
                    provider: widget.provider,
                    search: widget.search,
                    buyer: widget.buyer,
                    status: widget.status,
                    sort: widget.sort,
                    onSearch: widget.onSearch,
                    onBuyer: widget.onBuyer,
                    onStatus: widget.onStatus,
                    onSort: widget.onSort,
                  ),
                  Expanded(
                    child: widget.tickets.isEmpty
                        ? const Center(child: Text('Keine Tickets gefunden.'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: widget.tickets.length,
                            separatorBuilder: (context, i) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final ticket = widget.tickets[i];
                              return _TicketCard(
                                ticket: ticket,
                                money: widget.money,
                                selected: widget.selected?.ticketNumber == ticket.ticketNumber,
                                onTap: () {
                                  widget.onSelectTicket(ticket.ticketNumber);
                                  _tab.animateTo(1);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
              // ── Tab 1: detail ────────────────────────────────────────────
              widget.selected == null
                  ? const Center(child: Text('Ticket auswählen'))
                  : _TicketDetail(ticket: widget.selected!, money: widget.money),
            ],
          ),
        ),
      ],
    );
  }
}

class _TicketFilters extends StatelessWidget {
  final InventoryProvider provider;
  final String search;
  final String? buyer;
  final String? status;
  final String sort;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onBuyer;
  final ValueChanged<String?> onStatus;
  final ValueChanged<String?> onSort;

  const _TicketFilters({
    required this.provider,
    required this.search,
    required this.buyer,
    required this.status,
    required this.sort,
    required this.onSearch,
    required this.onBuyer,
    required this.onStatus,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: 'Ticket suchen'),
              onChanged: onSearch,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _dd('Käufer', buyer, provider.buyers.map((b) => b.name), onBuyer)),
                const SizedBox(width: 8),
                Expanded(child: _dd('Status', status, InventoryProvider.statusOptions, onStatus)),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: sort,
              decoration: const InputDecoration(labelText: 'Sortierung'),
              items: ['Datum', 'Profit', 'Anzahl Deals']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: onSort,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dd(String label, String? value, Iterable<String> values, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: null, child: Text('Alle')),
        ...values.map((v) => DropdownMenuItem(value: v, child: Text(v))),
      ],
      onChanged: onChanged,
    );
  }
}

class _TicketCard extends StatelessWidget {
  final TicketSummary ticket;
  final NumberFormat money;
  final bool selected;
  final VoidCallback onTap;
  const _TicketCard({
    required this.ticket,
    required this.money,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = _statusColor(ticket.worstStatus);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(ticket.ticketNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                if (ticket.url != null)
                  IconButton(
                    tooltip: 'Ticket öffnen',
                    icon: const Icon(Icons.open_in_new, size: 16),
                    onPressed: () {
                      final prov = context.read<InventoryProvider>();
                      final buyer = prov.buyers.where((b) => b.name == ticket.buyer).firstOrNull;
                      final serverIds = buyer?.discordServerIds ?? [];
                      openUrlWithFallback(context, resolveDiscordUrl(ticket.url!, serverIds: serverIds));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _badge(ticket.buyer ?? 'Kein Käufer', const Color(0xFF64748B)),
                _badge('${ticket.totalQuantity} Produkte · ${ticket.dealCount} Deals', const Color(0xFF2563EB)),
                _badge(ticket.worstStatus, status),
                _badge(ticket.arrivalSummary, const Color(0xFF0D9488)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('EK ${money.format(ticket.totalEk)}', style: const TextStyle(fontSize: 12))),
                Expanded(child: Text('VK ${money.format(ticket.totalVk)}', style: const TextStyle(fontSize: 12))),
                Expanded(
                  child: Text(
                    money.format(ticket.totalProfit),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ticket.totalProfit >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _TicketDetail extends StatelessWidget {
  final TicketSummary ticket;
  final NumberFormat money;
  const _TicketDetail({required this.ticket, required this.money});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd.MM.yyyy');
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(ticket.ticketNumber, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                  if (ticket.url != null)
                    IconButton(
                      tooltip: 'Ticket öffnen',
                      onPressed: () {
                        final buyer = provider.buyers.where((b) => b.name == ticket.buyer).firstOrNull;
                        final serverIds = buyer?.discordServerIds ?? [];
                        openUrlWithFallback(context, resolveDiscordUrl(ticket.url!, serverIds: serverIds));
                      },
                      icon: const Icon(Icons.open_in_new),
                    ),
                  if (ticket.hasTicket) ...[
                    OutlinedButton.icon(
                      onPressed: () => _editTicket(context, provider, ticket),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Bearbeiten'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => AddEditDealDialog(initialTicketNumber: ticket.hasTicket ? ticket.ticketNumber : null),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Deal hinzufügen'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(ticket.buyer ?? 'Kein Käufer zugeordnet', style: const TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 38,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 48,
                    columns: const [
                      DataColumn(label: Text('Produkt')),
                      DataColumn(label: Text('Anzahl')),
                      DataColumn(label: Text('EK')),
                      DataColumn(label: Text('VK')),
                      DataColumn(label: Text('Profit')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Ankunft')),
                      DataColumn(label: Text('Tracking')),
                      DataColumn(label: Text('')),
                    ],
                    rows: ticket.deals.map((deal) {
                      return DataRow(cells: [
                        DataCell(Text(deal.product)),
                        DataCell(Text('${deal.quantity}')),
                        DataCell(Text(money.format(deal.ekGesamtBrutto ?? 0))),
                        DataCell(Text(money.format(deal.zuBekommen ?? 0))),
                        DataCell(Text(money.format(deal.totalProfit ?? 0))),
                        DataCell(
                          DropdownButton<String>(
                            value: deal.status,
                            underline: const SizedBox.shrink(),
                            items: InventoryProvider.statusOptions
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) provider.updateDeal(deal.copyWith(status: v));
                            },
                          ),
                        ),
                        DataCell(Text(deal.arrivalDate != null ? date.format(deal.arrivalDate!) : '-')),
                        DataCell(Text(deal.tracking ?? '-')),
                        DataCell(
                          IconButton(
                            tooltip: 'Deal bearbeiten',
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => AddEditDealDialog(deal: deal),
                            ),
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Totals(ticket: ticket, money: money),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Zugehörige Lagerartikel', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (ticket.items.isEmpty)
                        const Text('Keine Lagerartikel verknüpft.', style: TextStyle(color: Color(0xFF94A3B8)))
                      else
                        ...ticket.items.map((item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.name),
                              subtitle: Text('${item.quantity} Stück · ${item.location ?? "Kein Lagerort"}'),
                              trailing: Text(item.status),
                            )),
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

  Future<void> _editTicket(
    BuildContext context,
    InventoryProvider provider,
    TicketSummary ticket,
  ) async {
    final numberCtrl = TextEditingController(text: ticket.ticketNumber);
    final urlCtrl = TextEditingController(text: ticket.url ?? '');
    String? bulkStatus;
    final result = await showDialog<_TicketEditResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined,
                    color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Ticket bearbeiten'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Änderungen werden auf alle ${ticket.deals.length} Deals dieses Tickets angewendet.',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: numberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ticketnummer',
                    prefixIcon:
                        Icon(Icons.confirmation_number_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Discord-Ticket Link',
                    hintText: 'https://discord.com/...',
                    prefixIcon: Icon(Icons.link, size: 18),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: bulkStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status für alle Deals (optional)',
                    prefixIcon: Icon(Icons.flag_outlined, size: 18),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— Status nicht ändern —'),
                    ),
                    ...InventoryProvider.statusOptions.map(
                      (s) => DropdownMenuItem<String?>(
                        value: s,
                        child: Text(s),
                      ),
                    ),
                  ],
                  onChanged: (v) => setS(() => bulkStatus = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                ctx,
                _TicketEditResult(
                  ticketNumber: numberCtrl.text,
                  ticketUrl: urlCtrl.text,
                  status: bulkStatus,
                ),
              ),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
    numberCtrl.dispose();
    urlCtrl.dispose();
    if (result == null || !context.mounted) return;

    final ids = ticket.deals.map((d) => d.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.updateDealsTicket(
        ids,
        ticketNumber: result.ticketNumber.trim() == ticket.ticketNumber
            ? null
            : result.ticketNumber,
        ticketUrl: result.ticketUrl.trim() == (ticket.url ?? '')
            ? null
            : result.ticketUrl,
      );
      if (result.status != null) {
        await provider.updateDealsStatus(ids, result.status!);
      }
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Ticket aktualisiert.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }
}

class _TicketEditResult {
  final String ticketNumber;
  final String ticketUrl;
  final String? status;
  _TicketEditResult({
    required this.ticketNumber,
    required this.ticketUrl,
    required this.status,
  });
}

class _Totals extends StatelessWidget {
  final TicketSummary ticket;
  final NumberFormat money;
  const _Totals({required this.ticket, required this.money});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _box('EK gesamt', money.format(ticket.totalEk)),
        const SizedBox(width: 10),
        _box('VK gesamt', money.format(ticket.totalVk)),
        const SizedBox(width: 10),
        _box('Profit', money.format(ticket.totalProfit), good: ticket.totalProfit >= 0),
        const SizedBox(width: 10),
        _box('Stückzahl', '${ticket.totalQuantity}'),
      ],
    );
  }

  Widget _box(String label, String value, {bool? good}) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: good == null
                        ? const Color(0xFF0F172A)
                        : good
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _statusColor(String status) => switch (status) {
      'Bestellt' => const Color(0xFF3B82F6),
      'Unterwegs' => const Color(0xFFF59E0B),
      'Angekommen' => const Color(0xFF0D9488),
      'Rechnung gestellt' => const Color(0xFF8B5CF6),
      'Done' => const Color(0xFF10B981),
      _ => const Color(0xFF64748B),
    };
