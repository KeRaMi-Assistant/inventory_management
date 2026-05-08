import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/shop.dart';
import '../models/ticket_summary.dart';
import '../providers/inventory_provider.dart';
import '../services/carrier_service.dart';
import '../utils/status_l10n.dart';
import '../utils/url_helper.dart';
import '../widgets/add_edit_deal_dialog.dart';
import '../widgets/tracking_chip.dart';

class TicketsScreen extends StatefulWidget {
  final String? initialTicket;
  const TicketsScreen({super.key, this.initialTicket});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen>
    with SingleTickerProviderStateMixin {
  String _search = '';
  String? _buyer;
  String? _status;
  String _sort = 'Datum';
  String? _selectedTicket;
  late final TabController _archiveTab;

  @override
  void initState() {
    super.initState();
    _selectedTicket = widget.initialTicket;
    _archiveTab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _archiveTab.dispose();
    super.dispose();
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
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final money = NumberFormat.currency(locale: localeTag, symbol: '€');
    final l10n = AppLocalizations.of(context);
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final activeTickets = _filteredActive(provider.ticketSummaries);
        final selected =
            activeTickets.where((t) => t.ticketNumber == _selectedTicket).firstOrNull ??
                activeTickets.firstOrNull;
        return Column(
          children: [
            Material(
              color: AppTheme.bgSurfaceOf(context),
              child: TabBar(
                controller: _archiveTab,
                tabs: [
                  Tab(text: l10n.ticketsTabActive),
                  Tab(text: l10n.ticketsTabArchive),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _archiveTab,
                children: [
                  _ActiveTicketsView(
                    tickets: activeTickets,
                    selected: selected,
                    money: money,
                    provider: provider,
                    search: _search,
                    buyer: _buyer,
                    status: _status,
                    sort: _sort,
                    onSearch: (v) => setState(() => _search = v),
                    onBuyer: (v) => setState(() => _buyer = v),
                    onStatus: (v) => setState(() => _status = v),
                    onSort: (v) => setState(() => _sort = v ?? 'Datum'),
                    onSelectTicket: (t) =>
                        setState(() => _selectedTicket = t),
                  ),
                  _ArchiveTicketsView(
                    tickets: provider.archivedTicketSummaries,
                    money: money,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<TicketSummary> _filteredActive(List<TicketSummary> tickets) {
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

// ─── Active tickets view (was the old TicketsScreen body) ───────────────────
class _ActiveTicketsView extends StatelessWidget {
  final List<TicketSummary> tickets;
  final TicketSummary? selected;
  final NumberFormat money;
  final InventoryProvider provider;
  final String search;
  final String? buyer;
  final String? status;
  final String sort;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onBuyer;
  final ValueChanged<String?> onStatus;
  final ValueChanged<String?> onSort;
  final ValueChanged<String> onSelectTicket;

  const _ActiveTicketsView({
    required this.tickets,
    required this.selected,
    required this.money,
    required this.provider,
    required this.search,
    required this.buyer,
    required this.status,
    required this.sort,
    required this.onSearch,
    required this.onBuyer,
    required this.onStatus,
    required this.onSort,
    required this.onSelectTicket,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 650;
        if (narrow) {
          return _TicketsMobileLayout(
            tickets: tickets,
            selected: selected,
            money: money,
            onSelectTicket: onSelectTicket,
            search: search,
            buyer: buyer,
            status: status,
            sort: sort,
            onSearch: onSearch,
            onBuyer: onBuyer,
            onStatus: onStatus,
            onSort: onSort,
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
                    search: search,
                    buyer: buyer,
                    status: status,
                    sort: sort,
                    onSearch: onSearch,
                    onBuyer: onBuyer,
                    onStatus: onStatus,
                    onSort: onSort,
                  ),
                  Expanded(
                    child: tickets.isEmpty
                        ? Center(
                            child: Text(
                                AppLocalizations.of(context).ticketsEmpty),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: tickets.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final ticket = tickets[i];
                              return _TicketCard(
                                ticket: ticket,
                                money: money,
                                selected: selected?.ticketNumber ==
                                    ticket.ticketNumber,
                                onTap: () => onSelectTicket(ticket.ticketNumber),
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
                  ? Center(
                      child: Text(AppLocalizations.of(context).ticketsSelect),
                    )
                  : _TicketDetail(ticket: selected!, money: money),
            ),
          ],
        );
      },
    );
  }
}

// ─── Archive view: tickets grouped by archived month ────────────────────────
class _ArchiveTicketsView extends StatelessWidget {
  final List<TicketSummary> tickets;
  final NumberFormat money;
  const _ArchiveTicketsView({required this.tickets, required this.money});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (tickets.isEmpty) {
      return Center(child: Text(l10n.ticketsArchiveEmpty));
    }
    final groups = _groupByMonth(tickets);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final monthFmt = DateFormat.yMMMM(localeTag);
    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: groups.length,
        itemBuilder: (context, gIdx) {
          final group = groups[gIdx];
          final monthLabel = monthFmt.format(group.month);
          final profit =
              group.tickets.fold<double>(0, (sum, t) => sum + t.totalProfit);
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MonthHeader(
                  label: monthLabel,
                  profitLabel:
                      l10n.ticketsArchiveMonthProfit(money.format(profit)),
                  profitPositive: profit >= 0,
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < group.tickets.length; i++) ...[
                  _ArchivedTicketCard(
                    ticket: group.tickets[i],
                    money: money,
                  ),
                  if (i < group.tickets.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  List<_MonthGroup> _groupByMonth(List<TicketSummary> source) {
    final byMonth = <DateTime, List<TicketSummary>>{};
    for (final t in source) {
      final at = t.archivedAt;
      if (at == null) continue;
      final month = DateTime(at.year, at.month);
      byMonth.putIfAbsent(month, () => []).add(t);
    }
    final groups = byMonth.entries
        .map((e) => _MonthGroup(month: e.key, tickets: e.value))
        .toList();
    groups.sort((a, b) => b.month.compareTo(a.month));
    return groups;
  }
}

class _MonthGroup {
  final DateTime month;
  final List<TicketSummary> tickets;
  _MonthGroup({required this.month, required this.tickets});
}

class _MonthHeader extends StatelessWidget {
  final String label;
  final String profitLabel;
  final bool profitPositive;
  const _MonthHeader({
    required this.label,
    required this.profitLabel,
    required this.profitPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
          Text(
            profitLabel,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: profitPositive
                  ? AppTheme.successTextOf(context)
                  : AppTheme.dangerTextOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedTicketCard extends StatelessWidget {
  final TicketSummary ticket;
  final NumberFormat money;
  const _ArchivedTicketCard({required this.ticket, required this.money});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onLongPress: () => _onLongPress(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.bgSurfaceOf(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.ticketNumber,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Icon(Icons.archive_outlined,
                    size: 16, color: AppTheme.textMutedOf(context)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ticket.buyer ?? l10n.ticketsNoBuyer,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMutedOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'EK ${money.format(ticket.totalEk)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    'VK ${money.format(ticket.totalVk)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    money.format(ticket.totalProfit),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ticket.totalProfit >= 0
                          ? AppTheme.successTextOf(context)
                          : AppTheme.dangerTextOf(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.ticketsArchiveLongPressHint,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textMutedOf(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onLongPress(BuildContext context) async {
    final ticketId = ticket.ticketId;
    if (ticketId == null) return;
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.borderOf(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                ticket.ticketNumber,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.ticketsArchiveReopenConfirm,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppTheme.textMutedOf(context), fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.unarchive_outlined),
                  label: Text(l10n.ticketsArchiveReopen),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.actionCancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<InventoryProvider>();
    try {
      await provider.reopenTicket(ticketId);
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(
          content: Text('${l10n.ticketsArchiveReopen} · ${ticket.ticketNumber}')));
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorPrefix('$e'))));
    }
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
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        TabBar(
          controller: _tab,
          tabs: [
            Tab(text: l10n.ticketsTabList),
            Tab(text: l10n.ticketsTabDetail),
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
                        ? Center(child: Text(l10n.ticketsEmpty))
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
                  ? Center(child: Text(l10n.ticketsSelect))
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
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppTheme.bgSurfaceOf(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: l10n.ticketsSearchHintShort),
              onChanged: onSearch,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _dd(
                        context,
                        l10n.dealBuyer,
                        buyer,
                        provider.buyers.map((b) => b.name).toList(),
                        provider.buyers.map((b) => b.name).toList(),
                        onBuyer)),
                const SizedBox(width: 8),
                Expanded(
                    child: _dd(
                        context,
                        l10n.dealStatus,
                        status,
                        InventoryProvider.statusOptions,
                        InventoryProvider.statusOptions
                            .map((s) => localizeDealStatus(context, s))
                            .toList(),
                        onStatus)),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: sort,
              decoration:
                  InputDecoration(labelText: l10n.ticketsSortLabel),
              items: [
                DropdownMenuItem(
                    value: 'Datum', child: Text(l10n.ticketsSortDate)),
                DropdownMenuItem(
                    value: 'Profit', child: Text(l10n.ticketsSortProfit)),
                DropdownMenuItem(
                    value: 'Anzahl Deals',
                    child: Text(l10n.ticketsSortDealCount)),
              ],
              onChanged: onSort,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dd(BuildContext context, String label, String? value,
      List<String> values, List<String> labels, ValueChanged<String?> onChanged) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.commonAll)),
        for (int i = 0; i < values.length; i++)
          DropdownMenuItem(value: values[i], child: Text(labels[i])),
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
          color: selected ? AppTheme.accentSelectedBgOf(context) : AppTheme.bgSurfaceOf(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppTheme.accent.withAlpha(153) : AppTheme.borderOf(context)),
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
                    tooltip: AppLocalizations.of(context).ticketsOpenTooltip,
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
                _badge(
                    ticket.buyer ??
                        AppLocalizations.of(context).ticketsNoBuyer,
                    AppTheme.textMutedOf(context)),
                _badge(
                    '${ticket.totalQuantity} · ${ticket.dealCount}',
                    AppTheme.accentTextOf(context)),
                _badge(localizeDealStatus(context, ticket.worstStatus),
                    status),
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
                      color: ticket.totalProfit >= 0
                          ? AppTheme.successTextOf(context)
                          : AppTheme.dangerTextOf(context),
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
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMd(localeTag);
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
                      tooltip: l10n.ticketsOpenTooltip,
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
                      label: Text(l10n.actionEdit),
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
                    label: Text(l10n.ticketsAddDealTooltip),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(ticket.buyer ?? l10n.ticketsNoBuyerAssigned,
                  style: TextStyle(color: AppTheme.textMutedOf(context))),
              const SizedBox(height: 16),
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 38,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 48,
                    columns: [
                      DataColumn(label: Text(l10n.ticketsColProduct)),
                      DataColumn(label: Text(l10n.ticketsColQuantity)),
                      const DataColumn(label: Text('EK')),
                      const DataColumn(label: Text('VK')),
                      DataColumn(label: Text(l10n.ticketsBoxProfit)),
                      DataColumn(label: Text(l10n.dealStatus)),
                      DataColumn(label: Text(l10n.dealColArrival)),
                      DataColumn(label: Text(l10n.ticketsColTracking)),
                      const DataColumn(label: Text('')),
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
                                .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(localizeDealStatus(
                                        context, s))))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) provider.updateDeal(deal.copyWith(status: v));
                            },
                          ),
                        ),
                        DataCell(Text(deal.arrivalDate != null ? date.format(deal.arrivalDate!) : '-')),
                        DataCell(_TrackingCell(
                          tracking: deal.tracking,
                          shop: provider.shops
                              .where((s) => s.name == deal.shop)
                              .firstOrNull,
                        )),
                        DataCell(
                          IconButton(
                            tooltip: l10n.dealEdit,
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
                      Text(l10n.ticketsRelatedItems,
                          style:
                              const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (ticket.items.isEmpty)
                        Text(l10n.dealCommentEmpty,
                            style:
                                TextStyle(color: AppTheme.textMutedOf(context)))
                      else
                        ...ticket.items.map((item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.name),
                              subtitle: Text(
                                  '${item.quantity} · ${item.location ?? l10n.inventoryNoLocation}'),
                              trailing: Text(localizeInventoryStatus(
                                  context, item.status)),
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
                  color: AppTheme.accentLightOf(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit_outlined,
                    color: AppTheme.accentTextOf(context), size: 20),
              ),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context).ticketsEditTitle),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                TextField(
                  controller: numberCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).ticketsTicketNumber,
                    prefixIcon: const Icon(
                        Icons.confirmation_number_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).dealTicketUrl,
                    hintText: 'https://discord.com/...',
                    prefixIcon: const Icon(Icons.link, size: 18),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: bulkStatus,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).dealStatus,
                    prefixIcon: const Icon(Icons.flag_outlined, size: 18),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child:
                          Text(AppLocalizations.of(context).commonAll),
                    ),
                    ...InventoryProvider.statusOptions.map(
                      (s) => DropdownMenuItem<String?>(
                        value: s,
                        child: Text(localizeDealStatus(context, s)),
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
              child: Text(AppLocalizations.of(context).actionCancel),
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
              child: Text(AppLocalizations.of(context).actionSave),
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
    final l10n = AppLocalizations.of(context);
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
      messenger.showSnackBar(SnackBar(
          content: Text('${l10n.actionSave} · ${ticket.ticketNumber}')));
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorPrefix('$e'))));
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
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        _box(context, l10n.ticketsBoxEkTotal, money.format(ticket.totalEk)),
        const SizedBox(width: 10),
        _box(context, l10n.ticketsBoxVkTotal, money.format(ticket.totalVk)),
        const SizedBox(width: 10),
        _box(context, l10n.ticketsBoxProfit, money.format(ticket.totalProfit),
            good: ticket.totalProfit >= 0),
        const SizedBox(width: 10),
        _box(context, l10n.ticketsBoxQuantity, '${ticket.totalQuantity}'),
      ],
    );
  }

  Widget _box(BuildContext context, String label, String value, {bool? good}) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context), fontWeight: FontWeight.w700)),
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
                        ? AppTheme.textPrimaryOf(context)
                        : good
                            ? AppTheme.successTextOf(context)
                            : AppTheme.dangerTextOf(context),
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

/// Tracking-Cell innerhalb der DataTable. Wir kapseln das in einem eigenen
/// Widget, damit der Chip in einer SizedBox mit fester Maximalbreite sitzt
/// — `DataTable` rechnet sonst Intrinsic-Widths über die Children, was mit
/// einem unbegrenzten Chip in einem ScrollView-DataCell zu Layout-Fehlern
/// führt (sichtbare Regression nach dem letzten Edit).
class _TrackingCell extends StatelessWidget {
  const _TrackingCell({required this.tracking, required this.shop});

  final String? tracking;
  final Shop? shop;

  @override
  Widget build(BuildContext context) {
    if (tracking == null) {
      return const Text('-');
    }
    return SizedBox(
      width: 180,
      child: TrackingChip(
        tracking: tracking!,
        compact: true,
        shopAmazonCountry: amazonCountryFromShop(
          shopName: shop?.name,
          region: shop?.region,
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
