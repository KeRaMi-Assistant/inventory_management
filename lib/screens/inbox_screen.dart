import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/deal.dart';
import '../models/inbox_message.dart';
import '../providers/inbox_provider.dart';
import '../providers/inventory_provider.dart';
import '../widgets/deal_picker_dialog.dart';
import '../widgets/inbox_message_details.dart';

/// Postfach-Inbox: vorgeschlagene Deals (Aktionsmenü mit Annehmen / Tracking
/// übernehmen / Zu Deal zuweisen / Verwerfen), automatisch aktualisierte
/// Deals, unklassifizierte Mails (Aktionsmenü mit Deal anlegen / Tracking
/// übernehmen / Verwerfen / Details).
class InboxScreen extends StatefulWidget {
  final void Function(String ticket)? onOpenTicket;
  const InboxScreen({super.key, this.onOpenTicket});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<InboxProvider>().refresh();
      });
    }
  }

  Future<void> _refresh() => context.read<InboxProvider>().refresh();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Consumer<InboxProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            backgroundColor: const Color(0xFFF1F4F8),
            body: Column(
              children: [
                _InboxHeader(provider: provider, onRefresh: _refresh),
                Material(
                  color: Colors.white,
                  child: TabBar(
                    indicatorColor: const Color(0xFF2563EB),
                    labelColor: const Color(0xFF2563EB),
                    unselectedLabelColor: const Color(0xFF64748B),
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.add_box_outlined, size: 18),
                        text: 'Vorschläge (${provider.pendingSuggestions.length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.sync, size: 18),
                        text: 'Aktualisiert (${provider.matchedRecently.length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.help_outline, size: 18),
                        text: 'Unklassifiziert (${provider.unclassified.length})',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _SuggestionsTab(
                        suggestions: provider.pendingSuggestions,
                        onRefresh: _refresh,
                      ),
                      _MatchedTab(
                        messages: provider.matchedRecently,
                        onRefresh: _refresh,
                        onOpenTicket: widget.onOpenTicket,
                      ),
                      _UnclassifiedTab(
                        messages: provider.unclassified,
                        onRefresh: _refresh,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InboxHeader extends StatelessWidget {
  final InboxProvider provider;
  final Future<void> Function() onRefresh;
  const _InboxHeader({required this.provider, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final hasAccount = provider.accounts.isNotEmpty;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(
            hasAccount ? Icons.mail_outline : Icons.warning_amber_outlined,
            color: hasAccount
                ? const Color(0xFF2563EB)
                : const Color(0xFFD97706),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAccount
                      ? '${provider.accounts.length} Postfach${provider.accounts.length == 1 ? "" : "er"} verbunden'
                      : 'Noch kein Postfach verbunden',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasAccount
                      ? 'Polling alle 5 min — nur Bestellbestätigungen, Versand- und Stornierungs-Mails der konfigurierten Shops landen hier.'
                      : 'Lege unter Einstellungen → Postfach ein IMAP-Konto an.',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Aktualisieren',
            icon: provider.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : onRefresh,
          ),
        ],
      ),
    );
  }
}

// ── Aktion-Helpers (DRY) ───────────────────────────────────────────────

Future<void> _confirmDismissMessage(
  BuildContext context,
  ParsedMessage message,
) async {
  final inbox = context.read<InboxProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Mail verwerfen?'),
      content: Text(
        'Die Mail "${message.subject ?? ""}" wird aus der Inbox '
        'entfernt und nicht mehr angezeigt.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Verwerfen',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await inbox.dismissParsedMessage(message.id);
    messenger.showSnackBar(const SnackBar(
      content: Text('Mail verworfen.'),
      behavior: SnackBarBehavior.floating,
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text('Verwerfen fehlgeschlagen: $e'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

Future<Deal?> _pickDeal(BuildContext context, {required String title, String? hint}) {
  return DealPickerDialog.show(context, title: title, hint: hint);
}

String? _trackingFromMessage(ParsedMessage msg) {
  final p = msg.parsedPayload ?? const {};
  return p['tracking'] as String?;
}

DateTime? _etaFromMessage(ParsedMessage msg) {
  final p = msg.parsedPayload ?? const {};
  final raw = p['eta'] as String?;
  if (raw == null) return null;
  return DateTime.tryParse(raw);
}

String? _carrierFromMessage(ParsedMessage msg) {
  final p = msg.parsedPayload ?? const {};
  return p['carrier'] as String?;
}

// ── Suggestions ────────────────────────────────────────────────────────

class _SuggestionsTab extends StatelessWidget {
  final List<PendingDealSuggestion> suggestions;
  final Future<void> Function() onRefresh;
  const _SuggestionsTab({required this.suggestions, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: suggestions.isEmpty
          ? const _InboxEmpty(
              icon: Icons.check_circle_outline,
              text: 'Keine offenen Vorschläge.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) =>
                  _SuggestionCard(suggestion: suggestions[i]),
            ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final PendingDealSuggestion suggestion;
  const _SuggestionCard({required this.suggestion});

  Future<void> _accept(BuildContext context) async {
    final inventory = context.read<InventoryProvider>();
    final inbox = context.read<InboxProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final shopName = suggestion.shopLabel ?? suggestion.shopKey;
    final orderId = suggestion.orderId;
    final draft = Deal(
      id: Deal.unsavedId,
      product: (suggestion.product ?? '').trim().isEmpty
          ? (orderId != null
              ? 'Bestellung $orderId'
              : 'Erkannter Auftrag ($shopName)')
          : suggestion.product!.trim(),
      quantity: suggestion.quantity,
      isDropship: false,
      shop: shopName,
      orderDate: DateTime.now(),
      ekBrutto: suggestion.total,
      ticketNumber: orderId,
      tracking: suggestion.tracking,
      arrivalDate: suggestion.eta,
      status: suggestion.tracking != null ? 'Unterwegs' : 'Bestellt',
      currency: suggestion.currency,
    );
    try {
      final saved = await inventory.addDeal(draft);
      await inbox.markSuggestionAccepted(suggestion.id, createdDealId: saved.id);
      messenger.showSnackBar(SnackBar(
        content: Text('Deal #${saved.id} aus Vorschlag erstellt.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Annehmen fehlgeschlagen: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _reject(BuildContext context) async {
    final inbox = context.read<InboxProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await inbox.markSuggestionRejected(suggestion.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Ablehnen fehlgeschlagen: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _applyTracking(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final inbox = context.read<InboxProvider>();
    if (suggestion.tracking == null || suggestion.tracking!.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Diese Mail enthält kein Tracking.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final deal = await _pickDeal(
      context,
      title: 'Tracking auf Deal anwenden',
      hint: 'Tracking ${suggestion.tracking} wird auf den ausgewählten Deal '
          'gesetzt, Status → Unterwegs.',
    );
    if (deal == null) return;
    try {
      await inbox.applyTrackingFromSuggestion(
        suggestion: suggestion,
        dealId: deal.id,
      );
      messenger.showSnackBar(SnackBar(
        content: Text('Tracking auf Deal #${deal.id} übernommen.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Tracking-Übernahme fehlgeschlagen: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _linkToDeal(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final inbox = context.read<InboxProvider>();
    final deal = await _pickDeal(
      context,
      title: 'Vorschlag zu Deal zuweisen',
      hint: 'Order-ID, Tracking und ETA werden in den ausgewählten Deal '
          'übernommen, der Vorschlag wird abgehakt.',
    );
    if (deal == null) return;
    try {
      await inbox.linkSuggestionToDeal(suggestion: suggestion, dealId: deal.id);
      messenger.showSnackBar(SnackBar(
        content: Text('Vorschlag mit Deal #${deal.id} verknüpft.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Zuweisung fehlgeschlagen: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    suggestion.shopLabel ?? suggestion.shopKey,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
                const Spacer(),
                if (suggestion.orderId != null)
                  Text(
                    '#${suggestion.orderId}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Color(0xFF64748B),
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  tooltip: 'Aktionen',
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'tracking',
                      child: ListTile(
                        leading: Icon(Icons.local_shipping_outlined),
                        title: Text('Tracking auf Deal anwenden'),
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'link',
                      child: ListTile(
                        leading: Icon(Icons.link),
                        title: Text('Zu bestehendem Deal zuweisen'),
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'reject',
                      child: ListTile(
                        leading:
                            Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
                        title: Text('Verwerfen'),
                        dense: true,
                      ),
                    ),
                  ],
                  onSelected: (v) {
                    switch (v) {
                      case 'tracking':
                        _applyTracking(context);
                        break;
                      case 'link':
                        _linkToDeal(context);
                        break;
                      case 'reject':
                        _reject(context);
                        break;
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              suggestion.product ?? '— ohne Produktnamen —',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _MetaItem(
                  icon: Icons.inventory_2_outlined,
                  label: '${suggestion.quantity} Stk.',
                ),
                if (suggestion.total != null)
                  _MetaItem(
                    icon: Icons.euro_outlined,
                    label: _money(suggestion.total!, suggestion.currency),
                  ),
                if (suggestion.tracking != null)
                  _MetaItem(
                    icon: Icons.local_shipping_outlined,
                    label: suggestion.tracking!,
                  ),
                if (suggestion.eta != null)
                  _MetaItem(
                    icon: Icons.calendar_today_outlined,
                    label: DateFormat.yMMMd('de_DE').format(suggestion.eta!),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.close, size: 16),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                  ),
                  onPressed: () => _reject(context),
                  label: const Text('Verwerfen'),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  onPressed: () => _accept(context),
                  label: const Text('Deal anlegen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _money(double v, String currency) {
    final symbol = switch (currency) {
      'EUR' => '€',
      'USD' => '\$',
      'GBP' => '£',
      'PLN' => 'zł',
      _ => currency,
    };
    return '${v.toStringAsFixed(2).replaceAll('.', ',')} $symbol';
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
        ),
      ],
    );
  }
}

// ── Matched ────────────────────────────────────────────────────────────

class _MatchedTab extends StatelessWidget {
  final List<ParsedMessage> messages;
  final Future<void> Function() onRefresh;
  final void Function(String ticket)? onOpenTicket;
  const _MatchedTab({
    required this.messages,
    required this.onRefresh,
    this.onOpenTicket,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: messages.isEmpty
          ? const _InboxEmpty(
              icon: Icons.inbox_outlined,
              text: 'Noch keine automatisch aktualisierten Deals.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final msg = messages[i];
                final payload = msg.parsedPayload ?? const {};
                final orderId = payload['order_id'] as String?;
                final product = payload['product'] as String?;
                final tracking = payload['tracking'] as String?;
                final shopLabel =
                    payload['shop_label'] as String? ?? msg.shopKey ?? '—';
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    onTap: () => InboxMessageDetails.show(
                      context,
                      message: msg,
                      actions: [
                        if (orderId != null && onOpenTicket != null)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Ticket öffnen'),
                            onPressed: () {
                              Navigator.pop(context);
                              onOpenTicket!(orderId);
                            },
                          ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Verwerfen'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB91C1C),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmDismissMessage(context, msg);
                          },
                        ),
                      ],
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFDCFCE7),
                      child: Icon(Icons.sync,
                          color: Color(0xFF15803D), size: 20),
                    ),
                    title: Text(
                      product ?? msg.subject ?? 'Aktualisierter Deal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          '$shopLabel${orderId != null ? " · #$orderId" : ""}'
                          '${msg.matchDealId != null ? " → Deal #${msg.matchDealId}" : ""}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        if (tracking != null)
                          Text(
                            'Tracking: $tracking',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF334155)),
                          ),
                      ],
                    ),
                    trailing: Text(
                      DateFormat.MMMd('de_DE').add_Hm().format(
                            (msg.processedAt ?? msg.receivedAt).toLocal(),
                          ),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ── Unclassified ───────────────────────────────────────────────────────

class _UnclassifiedTab extends StatelessWidget {
  final List<ParsedMessage> messages;
  final Future<void> Function() onRefresh;
  const _UnclassifiedTab({required this.messages, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: messages.isEmpty
          ? const _InboxEmpty(
              icon: Icons.help_outline,
              text: 'Alles eingeordnet — keine unklaren Mails.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) =>
                  _UnclassifiedRow(message: messages[i]),
            ),
    );
  }
}

class _UnclassifiedRow extends StatelessWidget {
  final ParsedMessage message;
  const _UnclassifiedRow({required this.message});

  Future<void> _createDeal(BuildContext context) async {
    final inventory = context.read<InventoryProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final p = message.parsedPayload ?? const {};
    final shopLabel = (p['shop_label'] as String?) ??
        (message.shopKey ?? 'Sonstige');
    final tracking = _trackingFromMessage(message);
    final draft = Deal(
      id: Deal.unsavedId,
      product: message.subject ?? 'Manueller Eintrag aus Mail',
      quantity: 1,
      isDropship: false,
      shop: shopLabel,
      orderDate: message.receivedAt,
      tracking: tracking,
      status: tracking != null ? 'Unterwegs' : 'Bestellt',
    );
    try {
      final saved = await inventory.addDeal(draft);
      messenger.showSnackBar(SnackBar(
        content: Text('Deal #${saved.id} aus Mail angelegt.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Anlegen fehlgeschlagen: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _applyTracking(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final inbox = context.read<InboxProvider>();
    final tn = _trackingFromMessage(message);
    if (tn == null || tn.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Diese Mail enthält kein Tracking.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final deal = await _pickDeal(
      context,
      title: 'Tracking auf Deal anwenden',
      hint: 'Tracking $tn wird auf den ausgewählten Deal gesetzt.',
    );
    if (deal == null) return;
    try {
      await inbox.applyTrackingFromMessage(
        message: message,
        dealId: deal.id,
        tracking: tn,
        carrier: _carrierFromMessage(message),
        eta: _etaFromMessage(message),
      );
      messenger.showSnackBar(SnackBar(
        content: Text('Tracking auf Deal #${deal.id} übernommen.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Tracking-Übernahme fehlgeschlagen: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showDetails(BuildContext context) {
    InboxMessageDetails.show(
      context,
      message: message,
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Deal anlegen'),
          onPressed: () {
            Navigator.pop(context);
            _createDeal(context);
          },
        ),
        if (_trackingFromMessage(message) != null)
          OutlinedButton.icon(
            icon: const Icon(Icons.local_shipping_outlined, size: 16),
            label: const Text('Tracking → Deal'),
            onPressed: () {
              Navigator.pop(context);
              _applyTracking(context);
            },
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline, size: 16),
          label: const Text('Verwerfen'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB91C1C),
          ),
          onPressed: () {
            Navigator.pop(context);
            _confirmDismissMessage(context, message);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopLabel = (message.parsedPayload?['shop_label'] as String?) ??
        message.shopKey;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () => _showDetails(context),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFEF3C7),
          child: Icon(Icons.help_outline,
              color: Color(0xFFB45309), size: 20),
        ),
        title: Text(
          message.subject ?? '— ohne Betreff —',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${shopLabel ?? "Unbekannt"} · ${message.fromAddress ?? "—"}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            Text(
              DateFormat.yMMMd('de_DE')
                  .add_Hm()
                  .format(message.receivedAt.toLocal()),
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          tooltip: 'Aktionen',
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'create',
              child: ListTile(
                leading: Icon(Icons.add),
                title: Text('Deal anlegen'),
                dense: true,
              ),
            ),
            if (_trackingFromMessage(message) != null)
              const PopupMenuItem(
                value: 'tracking',
                child: ListTile(
                  leading: Icon(Icons.local_shipping_outlined),
                  title: Text('Tracking auf Deal anwenden'),
                  dense: true,
                ),
              ),
            const PopupMenuItem(
              value: 'details',
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Details anzeigen'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'dismiss',
              child: ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Color(0xFFB91C1C)),
                title: Text('Verwerfen'),
                dense: true,
              ),
            ),
          ],
          onSelected: (v) {
            switch (v) {
              case 'create':
                _createDeal(context);
                break;
              case 'tracking':
                _applyTracking(context);
                break;
              case 'details':
                _showDetails(context);
                break;
              case 'dismiss':
                _confirmDismissMessage(context, message);
                break;
            }
          },
        ),
      ),
    );
  }
}

class _InboxEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InboxEmpty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 52, color: const Color(0xFFCBD5E1)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF94A3B8)),
          ),
        ),
      ],
    );
  }
}
