import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/deal.dart';
import '../models/inbox_message.dart';
import '../models/mailbox_account.dart';
import '../providers/inbox_provider.dart';
import '../utils/mail_link.dart';
import '../utils/url_helper.dart';
import '../widgets/add_edit_deal_dialog.dart';
import '../widgets/deal_picker_dialog.dart';
import '../widgets/inbox_message_details.dart';

/// Postfach-Inbox: Vorschläge → vorausgefüllter Edit-Dialog beim Annehmen,
/// Aktualisiert → Quick-View inkl. Mail-Link, Unklassifiziert → manueller
/// Workflow. Alle Listen unterstützen Verwerfen, Tracking-Übernahme,
/// Zu-Deal-zuweisen und das Öffnen der Original-Mail im Web-Mailer.
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
                        text:
                            'Vorschläge (${provider.pendingSuggestions.length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.sync, size: 18),
                        text:
                            'Aktualisiert (${provider.matchedRecently.length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.help_outline, size: 18),
                        text:
                            'Unklassifiziert (${provider.unclassified.length})',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _SuggestionsTab(
                        suggestions: provider.pendingSuggestions,
                        accounts: provider.accounts,
                        onRefresh: _refresh,
                      ),
                      _MatchedTab(
                        messages: provider.matchedRecently,
                        accounts: provider.accounts,
                        onRefresh: _refresh,
                        onOpenTicket: widget.onOpenTicket,
                      ),
                      _UnclassifiedTab(
                        messages: provider.unclassified,
                        accounts: provider.accounts,
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
                      ? '${provider.accounts.length} Postfach'
                          '${provider.accounts.length == 1 ? "" : "er"} verbunden'
                      : 'Noch kein Postfach verbunden',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasAccount
                      ? 'Polling alle 5 min — nur Bestellbestätigungen, '
                          'Versand- und Stornierungs-Mails der konfigurierten '
                          'Shops landen hier.'
                      : 'Lege unter Einstellungen → Postfach ein IMAP-Konto an.',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: provider.dismissalCount == 0
                ? 'Verworfen-Filter (0)'
                : 'Verworfen-Filter zurücksetzen '
                    '(${provider.dismissalCount} '
                    '${provider.dismissalCount == 1 ? "Eintrag" : "Einträge"})',
            icon: Icon(
              provider.dismissalCount == 0
                  ? Icons.filter_alt_outlined
                  : Icons.filter_alt_off_outlined,
              color: provider.dismissalCount == 0
                  ? const Color(0xFF94A3B8)
                  : null,
            ),
            onPressed: provider.dismissalCount == 0 || provider.isLoading
                ? null
                : () => _confirmClearDismissals(context, provider),
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

Future<void> _confirmClearDismissals(
  BuildContext context,
  InboxProvider provider,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Filter zurücksetzen?'),
      content: Text(
        '${provider.dismissalCount} verworfene Einträge werden wieder '
        'angezeigt. Bestellbestätigungen, die zwischenzeitlich erneut '
        'gekommen sind, erscheinen ebenfalls wieder im Inbox-Tab.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Zurücksetzen'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await provider.clearDismissals();
    messenger.showSnackBar(const SnackBar(
      content: Text('Verworfen-Filter geleert.'),
      behavior: SnackBarBehavior.floating,
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text('Zurücksetzen fehlgeschlagen: $e'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ── Helpers ────────────────────────────────────────────────────────────

String? _imapHostFor(List<MailboxAccount> accounts, {String? accountId}) {
  if (accounts.isEmpty) return null;
  if (accountId != null) {
    final match =
        accounts.where((a) => a.id == accountId).firstOrNull;
    if (match != null) return match.imapHost;
  }
  return accounts.first.imapHost;
}

Future<void> _openMail(
  BuildContext context, {
  required String? messageId,
  required String? imapHost,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final url = buildMailDeepLink(messageId: messageId, imapHost: imapHost);
  if (url == null) {
    if (messageId != null && messageId.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: messageId));
      messenger.showSnackBar(const SnackBar(
        content: Text('Message-ID in die Zwischenablage kopiert.'),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text('Kein Mail-Link verfügbar.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
    return;
  }
  if (!context.mounted) return;
  await openUrlWithFallback(context, url);
}

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
        'Die Mail "${message.subject ?? ""}" wird aus der Inbox entfernt '
        'und nicht mehr angezeigt.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Verwerfen', style: TextStyle(color: Colors.white)),
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

String _moneyFmt(double v, String currency) {
  final symbol = switch (currency) {
    'EUR' => '€',
    'USD' => '\$',
    'GBP' => '£',
    'PLN' => 'zł',
    _ => currency,
  };
  return '${v.toStringAsFixed(2).replaceAll('.', ',')} $symbol';
}

// ── Suggestions Tab ────────────────────────────────────────────────────

class _SuggestionsTab extends StatelessWidget {
  final List<PendingDealSuggestion> suggestions;
  final List<MailboxAccount> accounts;
  final Future<void> Function() onRefresh;
  const _SuggestionsTab({
    required this.suggestions,
    required this.accounts,
    required this.onRefresh,
  });

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
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _SuggestionCard(
                suggestion: suggestions[i],
                imapHost: _imapHostFor(accounts),
              ),
            ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final PendingDealSuggestion suggestion;
  final String? imapHost;
  const _SuggestionCard({required this.suggestion, this.imapHost});

  Deal _toDraftDeal() {
    final shopName = suggestion.shopLabel ?? suggestion.shopKey;
    final orderId = suggestion.orderId;
    final dealStatus = suggestion.status?.toDealStatus() ??
        (suggestion.tracking != null ? 'Unterwegs' : 'Bestellt');
    return Deal(
      id: Deal.unsavedId,
      product: (suggestion.product ?? '').trim().isEmpty
          ? (orderId != null
              ? 'Bestellung $orderId'
              : 'Erkannter Auftrag ($shopName)')
          : suggestion.product!.trim(),
      quantity: suggestion.quantity,
      isDropship: false,
      shop: shopName,
      orderDate: suggestion.createdAt,
      ekBrutto: suggestion.total,
      ticketNumber: orderId,
      tracking: suggestion.tracking,
      arrivalDate: suggestion.eta,
      status: dealStatus,
      currency: suggestion.currency,
    );
  }

  Future<void> _accept(BuildContext context) async {
    final inbox = context.read<InboxProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<Deal>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditDealDialog(prefill: _toDraftDeal()),
    );
    // saved.id == unsavedId → User hat den Dialog ohne Speichern verlassen.
    if (saved == null || saved.id == Deal.unsavedId) return;
    try {
      await inbox.markSuggestionAccepted(suggestion.id, createdDealId: saved.id);
      messenger.showSnackBar(SnackBar(
        content: Text('Deal #${saved.id} aus Vorschlag erstellt.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Konnte Vorschlag nicht abschließen: $e'),
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
    final deal = await DealPickerDialog.show(
      context,
      title: 'Tracking auf Deal anwenden',
      hint: 'Tracking ${suggestion.tracking} → Deal-Tracking, '
          'Status wird auf "Unterwegs" gesetzt.',
    );
    if (deal == null) return;
    try {
      await inbox.applyTrackingFromSuggestion(
          suggestion: suggestion, dealId: deal.id);
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
    final deal = await DealPickerDialog.show(
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
    final dfDate = DateFormat('dd.MM.yyyy', 'de_DE');
    final dfDateTime = DateFormat('dd.MM.yyyy · HH:mm', 'de_DE');
    final hasMailLink = buildMailDeepLink(
          messageId: suggestion.messageId,
          imapHost: imapHost,
        ) !=
        null;
    final shopName = suggestion.shopLabel ?? suggestion.shopKey;
    final productTitle =
        (suggestion.product ?? '').trim().isEmpty ? null : suggestion.product;
    final inbox = context.read<InboxProvider>();
    final referenceNow = inbox.lastRefreshedAt;
    final visDays = inbox.visibilityDays;
    final daysLeft =
        visDays - referenceNow.difference(suggestion.receivedAt).inDays;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ShopBadge(label: shopName),
                const SizedBox(width: 8),
                if (suggestion.status != null)
                  _ShipStatusBadge(status: suggestion.status!),
                const SizedBox(width: 6),
                _CountdownPill(daysLeft: daysLeft, totalDays: visDays),
                const Spacer(),
                Text(
                  dfDateTime.format(suggestion.receivedAt.toLocal()),
                  style: const TextStyle(
                    fontSize: 11,
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
                    if (hasMailLink || suggestion.messageId != null)
                      const PopupMenuItem(
                        value: 'mail',
                        child: ListTile(
                          leading: Icon(Icons.open_in_new),
                          title: Text('Mail im Browser öffnen'),
                          dense: true,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'reject',
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
                      case 'tracking':
                        _applyTracking(context);
                        break;
                      case 'link':
                        _linkToDeal(context);
                        break;
                      case 'mail':
                        _openMail(
                          context,
                          messageId: suggestion.messageId,
                          imapHost: imapHost,
                        );
                        break;
                      case 'reject':
                        _reject(context);
                        break;
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              productTitle ?? '— ohne Produktnamen —',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: productTitle != null
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF94A3B8),
                fontStyle: productTitle == null ? FontStyle.italic : null,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                if (suggestion.orderId != null)
                  _MetaItem(
                    icon: Icons.tag,
                    label: suggestion.orderId!,
                    monospace: true,
                  ),
                _MetaItem(
                  icon: Icons.inventory_2_outlined,
                  label: '${suggestion.quantity} Stk.',
                ),
                if (suggestion.total != null)
                  _MetaItem(
                    icon: Icons.euro_outlined,
                    label: _moneyFmt(suggestion.total!, suggestion.currency),
                  ),
                if (suggestion.eta != null)
                  _MetaItem(
                    icon: Icons.event_outlined,
                    label: 'ETA ${dfDate.format(suggestion.eta!)}',
                  ),
              ],
            ),
            if (suggestion.trackings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tn in suggestion.trackings)
                    _TrackingPill(tracking: tn, carrier: suggestion.carrier),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.close, size: 16),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFB91C1C)),
                  onPressed: () => _reject(context),
                  label: const Text('Verwerfen'),
                ),
                const Spacer(),
                if (hasMailLink)
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    onPressed: () => _openMail(
                      context,
                      messageId: suggestion.messageId,
                      imapHost: imapHost,
                    ),
                    label: const Text('Mail öffnen'),
                  ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  onPressed: () => _accept(context),
                  label: const Text('Annehmen & bearbeiten'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Matched Tab ────────────────────────────────────────────────────────

class _MatchedTab extends StatelessWidget {
  final List<ParsedMessage> messages;
  final List<MailboxAccount> accounts;
  final Future<void> Function() onRefresh;
  final void Function(String ticket)? onOpenTicket;
  const _MatchedTab({
    required this.messages,
    required this.accounts,
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
                      actions: _detailActionsFor(context, msg, orderId),
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

  List<Widget> _detailActionsFor(
    BuildContext context,
    ParsedMessage msg,
    String? orderId,
  ) {
    final imapHost = _imapHostFor(accounts, accountId: msg.accountId);
    final canOpenMail = buildMailDeepLink(
          messageId: msg.messageId,
          imapHost: imapHost,
        ) !=
        null;
    return [
      if (orderId != null && onOpenTicket != null)
        ElevatedButton.icon(
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Ticket öffnen'),
          onPressed: () {
            Navigator.pop(context);
            onOpenTicket!(orderId);
          },
        ),
      if (canOpenMail)
        OutlinedButton.icon(
          icon: const Icon(Icons.mail_outline, size: 16),
          label: const Text('Mail öffnen'),
          onPressed: () {
            Navigator.pop(context);
            _openMail(context, messageId: msg.messageId, imapHost: imapHost);
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
    ];
  }
}

// ── Unclassified Tab ───────────────────────────────────────────────────

class _UnclassifiedTab extends StatelessWidget {
  final List<ParsedMessage> messages;
  final List<MailboxAccount> accounts;
  final Future<void> Function() onRefresh;
  const _UnclassifiedTab({
    required this.messages,
    required this.accounts,
    required this.onRefresh,
  });

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
              itemBuilder: (context, i) => _UnclassifiedRow(
                message: messages[i],
                imapHost: _imapHostFor(accounts, accountId: messages[i].accountId),
              ),
            ),
    );
  }
}

class _UnclassifiedRow extends StatelessWidget {
  final ParsedMessage message;
  final String? imapHost;
  const _UnclassifiedRow({required this.message, this.imapHost});

  String? _trackingFromMessage() =>
      message.parsedPayload?['tracking'] as String?;
  String? _carrierFromMessage() =>
      message.parsedPayload?['carrier'] as String?;
  DateTime? _etaFromMessage() {
    final raw = message.parsedPayload?['eta'] as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> _createDeal(BuildContext context) async {
    final p = message.parsedPayload ?? const {};
    final shopLabel =
        (p['shop_label'] as String?) ?? (message.shopKey ?? 'Sonstige');
    final tracking = _trackingFromMessage();
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
    final saved = await showDialog<Deal>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditDealDialog(prefill: draft),
    );
    if (saved == null || saved.id == Deal.unsavedId) return;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Deal #${saved.id} aus Mail angelegt.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _applyTracking(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final inbox = context.read<InboxProvider>();
    final tn = _trackingFromMessage();
    if (tn == null || tn.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Diese Mail enthält kein Tracking.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final deal = await DealPickerDialog.show(
      context,
      title: 'Tracking auf Deal anwenden',
      hint: 'Tracking $tn → Deal-Tracking.',
    );
    if (deal == null) return;
    try {
      await inbox.applyTrackingFromMessage(
        message: message,
        dealId: deal.id,
        tracking: tn,
        carrier: _carrierFromMessage(),
        eta: _etaFromMessage(),
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
    final hasMailLink = buildMailDeepLink(
          messageId: message.messageId,
          imapHost: imapHost,
        ) !=
        null;
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
        if (_trackingFromMessage() != null)
          OutlinedButton.icon(
            icon: const Icon(Icons.local_shipping_outlined, size: 16),
            label: const Text('Tracking → Deal'),
            onPressed: () {
              Navigator.pop(context);
              _applyTracking(context);
            },
          ),
        if (hasMailLink)
          OutlinedButton.icon(
            icon: const Icon(Icons.mail_outline, size: 16),
            label: const Text('Mail öffnen'),
            onPressed: () {
              Navigator.pop(context);
              _openMail(
                context,
                messageId: message.messageId,
                imapHost: imapHost,
              );
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
    final hasMailLink = buildMailDeepLink(
          messageId: message.messageId,
          imapHost: imapHost,
        ) !=
        null;
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
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
            if (_trackingFromMessage() != null)
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
            if (hasMailLink)
              const PopupMenuItem(
                value: 'mail',
                child: ListTile(
                  leading: Icon(Icons.mail_outline),
                  title: Text('Mail öffnen'),
                  dense: true,
                ),
              ),
            const PopupMenuItem(
              value: 'dismiss',
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
              case 'create':
                _createDeal(context);
                break;
              case 'tracking':
                _applyTracking(context);
                break;
              case 'details':
                _showDetails(context);
                break;
              case 'mail':
                _openMail(
                  context,
                  messageId: message.messageId,
                  imapHost: imapHost,
                );
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

// ── Building blocks ────────────────────────────────────────────────────

class _CountdownPill extends StatelessWidget {
  /// Anzahl Tage, die diese Suggestion noch in der Inbox sichtbar bleibt.
  /// Referenz ist [InboxProvider.lastRefreshedAt], damit der Countdown
  /// bis zum nächsten Pull stabil bleibt — nicht jede Sekunde tickt.
  final int daysLeft;

  /// Volles Sichtbarkeitsfenster nach aktuellem Plan (Free=0, Starter=7,
  /// Pro=30, Business=90, Ultimate=365). Wird für Clamping + Tooltip
  /// genutzt, damit die Pill nicht oberhalb des Plan-Maximums anzeigt.
  final int totalDays;
  const _CountdownPill({required this.daysLeft, required this.totalDays});

  @override
  Widget build(BuildContext context) {
    final clamped = daysLeft.clamp(0, totalDays);
    final (bg, fg) = clamped <= 3
        ? (const Color(0xFFFEE2E2), const Color(0xFFB91C1C))
        : clamped <= 7
            ? (const Color(0xFFFEF3C7), const Color(0xFFB45309))
            : (const Color(0xFFE0F2FE), const Color(0xFF0369A1));
    final label = clamped == 0
        ? 'Heute weg'
        : clamped == 1
            ? 'Noch 1 Tag'
            : 'Noch $clamped Tage';
    return Tooltip(
      message:
          'Inbox-Sichtbarkeit $totalDays Tage. '
          'Aktualisiert sich beim nächsten Refresh.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 11, color: fg),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopBadge extends StatelessWidget {
  final String label;
  const _ShopBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2563EB),
        ),
      ),
    );
  }
}

class _ShipStatusBadge extends StatelessWidget {
  final SuggestionShipStatus status;
  const _ShipStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      SuggestionShipStatus.ordered =>
        (const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
      SuggestionShipStatus.shipped =>
        (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      SuggestionShipStatus.delivered =>
        (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      SuggestionShipStatus.cancelled =>
        (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      SuggestionShipStatus.refunded =>
        (const Color(0xFFEDE9FE), const Color(0xFF6D28D9)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool monospace;
  const _MetaItem({
    required this.icon,
    required this.label,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: const Color(0xFF334155),
            fontFamily: monospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}

class _TrackingPill extends StatelessWidget {
  final String tracking;
  final String? carrier;
  const _TrackingPill({required this.tracking, this.carrier});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: tracking));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Tracking-Nummer kopiert.'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_shipping_outlined,
                size: 14, color: Color(0xFF334155)),
            const SizedBox(width: 6),
            Text(
              tracking,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            if (carrier != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  carrier!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.copy_outlined,
                size: 12, color: Color(0xFF94A3B8)),
          ],
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
