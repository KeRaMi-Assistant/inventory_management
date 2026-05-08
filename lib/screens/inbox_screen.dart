import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
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
            backgroundColor: AppTheme.bgAppOf(context),
            body: Column(
              children: [
                _InboxHeader(provider: provider, onRefresh: _refresh),
                _InboxFilterBar(provider: provider),
                Material(
                  color: AppTheme.bgSurfaceOf(context),
                  child: TabBar(
                    indicatorColor: AppTheme.accentTextOf(context),
                    labelColor: AppTheme.accentTextOf(context),
                    unselectedLabelColor: AppTheme.textMutedOf(context),
                    dividerColor: AppTheme.borderOf(context),
                    tabs: [
                      Tab(
                        icon: Badge.count(
                          count: provider.unreadSuggestionsCount,
                          isLabelVisible:
                              provider.unreadSuggestionsCount > 0,
                          child: const Icon(
                              Icons.add_box_outlined,
                              size: 18),
                        ),
                        text:
                            'Vorschläge (${provider.pendingSuggestions.length})',
                      ),
                      Tab(
                        icon: Badge.count(
                          count: provider.unreadMatchedCount,
                          isLabelVisible:
                              provider.unreadMatchedCount > 0,
                          child: const Icon(Icons.sync, size: 18),
                        ),
                        text:
                            'Aktualisiert (${provider.matchedRecently.length})',
                      ),
                      Tab(
                        icon: Badge.count(
                          count: provider.unreadUnclassifiedCount,
                          isLabelVisible:
                              provider.unreadUnclassifiedCount > 0,
                          child: const Icon(
                              Icons.help_outline,
                              size: 18),
                        ),
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
      color: AppTheme.bgSurfaceOf(context),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(
            hasAccount ? Icons.mail_outline : Icons.warning_amber_outlined,
            color: hasAccount
                ? AppTheme.accentTextOf(context)
                : AppTheme.warningTextOf(context),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasAccount
                      ? 'Polling alle 5 min — nur Bestellbestätigungen, '
                          'Versand- und Stornierungs-Mails der konfigurierten '
                          'Shops landen hier.'
                      : 'Lege unter Einstellungen → Postfach ein IMAP-Konto an.',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondaryOf(context)),
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
                  ? AppTheme.textMutedOf(context)
                  : null,
            ),
            onPressed: provider.dismissalCount == 0 || provider.isLoading
                ? null
                : () => _confirmClearDismissals(context, provider),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context)
                .inboxMarkAllReadTooltip(provider.unreadCount),
            icon: const Icon(Icons.mark_email_read_outlined),
            color: provider.unreadCount == 0
                ? AppTheme.textMutedOf(context)
                : null,
            onPressed: provider.unreadCount == 0 || provider.isLoading
                ? null
                : () => _confirmMarkAllRead(context, provider),
          ),
          IconButton(
            tooltip: hasAccount
                ? 'Jetzt pollen (statt 5 min warten)'
                : 'Erst Postfach in den Einstellungen verbinden',
            icon: const Icon(Icons.cloud_download_outlined),
            color: hasAccount && !provider.isLoading
                ? null
                : AppTheme.textMutedOf(context),
            onPressed: !hasAccount || provider.isLoading
                ? null
                : () => _triggerPoll(context, provider),
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

/// Filter-Leiste über den Tabs. Zwei Pill-Dropdowns: Shop und Status.
/// Versteckt sich, wenn weder Shops bekannt noch Suggestions vorhanden
/// sind (z.B. Free-Plan, leere Inbox) — in dem Fall hat der User nichts
/// zu filtern und die Pills wären nur Lärm.
class _InboxFilterBar extends StatelessWidget {
  final InboxProvider provider;
  const _InboxFilterBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final shopKeys = provider.availableShopKeys;
    if (shopKeys.isEmpty && !provider.hasActiveFilter) {
      return const SizedBox.shrink();
    }
    return Container(
      color: AppTheme.bgSurfaceOf(context),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          _FilterPill(
            icon: Icons.store_outlined,
            label: provider.shopFilter == null
                ? 'Alle Shops'
                : provider.shopLabelFor(provider.shopFilter!),
            active: provider.shopFilter != null,
            onTap: () => _pickShop(context, provider, shopKeys),
            onClear: provider.shopFilter == null
                ? null
                : () => provider.setShopFilter(null),
          ),
          const SizedBox(width: 8),
          _FilterPill(
            icon: Icons.local_shipping_outlined,
            label: provider.statusFilter == null
                ? 'Alle Status'
                : provider.statusFilter!.label(),
            active: provider.statusFilter != null,
            onTap: () => _pickStatus(context, provider),
            onClear: provider.statusFilter == null
                ? null
                : () => provider.setStatusFilter(null),
          ),
          if (provider.hasActiveFilter) ...[
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Filter zurücksetzen'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentTextOf(context),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: provider.clearFilters,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickShop(
    BuildContext context,
    InboxProvider provider,
    List<String> shopKeys,
  ) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inbox),
              title: const Text('Alle Shops'),
              trailing: provider.shopFilter == null
                  ? const Icon(Icons.check, color: Color(0xFF2563EB))
                  : null,
              onTap: () => Navigator.pop(context, _kAllShops),
            ),
            const Divider(height: 1),
            for (final key in shopKeys)
              ListTile(
                leading: const Icon(Icons.store_outlined),
                title: Text(provider.shopLabelFor(key)),
                trailing: provider.shopFilter == key
                    ? const Icon(Icons.check, color: Color(0xFF2563EB))
                    : null,
                onTap: () => Navigator.pop(context, key),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    provider.setShopFilter(picked == _kAllShops ? null : picked);
  }

  Future<void> _pickStatus(
    BuildContext context,
    InboxProvider provider,
  ) async {
    // Wrapper, damit wir "Alle Status" vom echten "Bestellt"-Pick und vom
    // Cancel (null) sauber unterscheiden können.
    final picked = await showModalBottomSheet<Object?>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inbox),
              title: const Text('Alle Status'),
              trailing: provider.statusFilter == null
                  ? const Icon(Icons.check, color: Color(0xFF2563EB))
                  : null,
              onTap: () => Navigator.pop(context, _kAllStatusesSentinel),
            ),
            const Divider(height: 1),
            for (final s in SuggestionShipStatus.values)
              ListTile(
                leading: Icon(_statusIcon(s)),
                title: Text(s.label()),
                trailing: provider.statusFilter == s
                    ? const Icon(Icons.check, color: Color(0xFF2563EB))
                    : null,
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    if (picked is SuggestionShipStatus) {
      provider.setStatusFilter(picked);
    } else {
      provider.setStatusFilter(null);
    }
  }

  // Sentinel-Wert für die Shop-Sheet ("Alle Shops"). String reicht, weil
  // echte Shop-Keys nie diesen Wert haben.
  static const String _kAllShops = '__all__';
  // Eigene Sentinel-Instanz für die Status-Sheet — type-distinct von
  // SuggestionShipStatus, damit `is SuggestionShipStatus` zuverlässig
  // greift.
  static const Object _kAllStatusesSentinel = Object();

  static IconData _statusIcon(SuggestionShipStatus s) {
    switch (s) {
      case SuggestionShipStatus.ordered:
        return Icons.shopping_cart_outlined;
      case SuggestionShipStatus.shipped:
        return Icons.local_shipping_outlined;
      case SuggestionShipStatus.delivered:
        return Icons.check_circle_outline;
      case SuggestionShipStatus.cancelled:
        return Icons.cancel_outlined;
      case SuggestionShipStatus.refunded:
        return Icons.undo_outlined;
    }
  }
}

class _FilterPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? AppTheme.accentLightOf(context)
        : AppTheme.bgSubtleOf(context);
    final fg = active
        ? AppTheme.accentTextOf(context)
        : AppTheme.textSecondaryOf(context);
    final border = active
        ? AppTheme.accentBorderOf(context)
        : AppTheme.borderOf(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              onClear == null ? Icons.expand_more : Icons.close,
              size: 14,
              color: fg,
            ),
          ],
        ),
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

Future<void> _confirmMarkAllRead(
  BuildContext context,
  InboxProvider provider,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final unreadCount = provider.unreadCount;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.inboxMarkAllReadConfirmTitle),
      content: Text(l10n.inboxMarkAllReadConfirmBody(unreadCount)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.actionCancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.inboxMarkAllRead),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await provider.markAllRead();
    final markedCount = unreadCount - provider.unreadCount;
    messenger.showSnackBar(SnackBar(
      content: Text(l10n.inboxMarkAllReadSuccess(
          markedCount > 0 ? markedCount : unreadCount)),
      behavior: SnackBarBehavior.floating,
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text(l10n.inboxMarkAllReadFailure(e.toString())),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

Future<void> _triggerPoll(BuildContext context, InboxProvider provider) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(
    content: Text('Pollt das Postfach…'),
    behavior: SnackBarBehavior.floating,
    duration: Duration(seconds: 2),
  ));
  final result = await provider.pollNow();
  if (result != null) {
    final parts = <String>[];
    if (result.fetched > 0) {
      parts.add('${result.fetched} Mail${result.fetched == 1 ? "" : "s"} geholt');
    }
    if (result.stored > 0) {
      parts.add('${result.stored} aufgenommen');
    }
    final s = result.suggested ?? 0;
    final m = result.matched ?? 0;
    if (s > 0 || m > 0) {
      parts.add('$s Vorschl. / $m gemerged');
    }
    final msg = parts.isEmpty
        ? 'Keine neuen passenden Mails. Postfach ist aktuell.'
        : '${parts.join(", ")}.';
    messenger.showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
  } else if (provider.lastError != null) {
    messenger.showSnackBar(SnackBar(
      content: Text('Polling fehlgeschlagen: ${provider.lastError}'),
      backgroundColor: AppTheme.danger,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 8),
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
    final inbox = context.watch<InboxProvider>();
    final referenceNow = inbox.lastRefreshedAt;
    final visDays = inbox.visibilityDays;
    final daysLeft =
        visDays - referenceNow.difference(suggestion.receivedAt).inDays;
    final unread = inbox.isUnread(suggestion.parsedMessageId);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
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
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMutedOf(context),
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
                fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                color: productTitle != null
                    ? AppTheme.textPrimaryOf(context)
                    : AppTheme.textMutedOf(context),
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
                      foregroundColor: AppTheme.dangerTextOf(context)),
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
                final unread = context
                    .watch<InboxProvider>()
                    .isUnread(msg.id);
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppTheme.borderOf(context)),
                  ),
                  child: ListTile(
                    onTap: () => InboxMessageDetails.show(
                      context,
                      message: msg,
                      actions: _detailActionsFor(context, msg, orderId),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.successBgOf(context),
                      child: Icon(Icons.sync,
                          color: AppTheme.successTextOf(context), size: 20),
                    ),
                    title: Text(
                      product ?? msg.subject ?? 'Aktualisierter Deal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            unread ? FontWeight.w800 : FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          '$shopLabel${orderId != null ? " · #$orderId" : ""}'
                          '${msg.matchDealId != null ? " → Deal #${msg.matchDealId}" : ""}',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryOf(context)),
                        ),
                        if (tracking != null)
                          Text(
                            'Tracking: $tracking',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondaryOf(context)),
                          ),
                      ],
                    ),
                    trailing: Text(
                      DateFormat.MMMd('de_DE').add_Hm().format(
                            (msg.processedAt ?? msg.receivedAt).toLocal(),
                          ),
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textMutedOf(context)),
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
          foregroundColor: AppTheme.dangerTextOf(context),
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
            foregroundColor: AppTheme.dangerTextOf(context),
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
    final unread =
        context.watch<InboxProvider>().isUnread(message.id);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () => _showDetails(context),
        leading: CircleAvatar(
          backgroundColor: AppTheme.warningBgOf(context),
          child: Icon(Icons.help_outline,
              color: AppTheme.warningTextOf(context), size: 20),
        ),
        title: Text(
          message.subject ?? '— ohne Betreff —',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${shopLabel ?? "Unbekannt"} · ${message.fromAddress ?? "—"}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondaryOf(context)),
            ),
            Text(
              DateFormat.yMMMd('de_DE')
                  .add_Hm()
                  .format(message.receivedAt.toLocal()),
              style: TextStyle(
                  fontSize: 11, color: AppTheme.textMutedOf(context)),
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
        ? (AppTheme.dangerBgOf(context), AppTheme.dangerTextOf(context))
        : clamped <= 7
            ? (AppTheme.warningBgOf(context), AppTheme.warningTextOf(context))
            : (AppTheme.infoBgOf(context), AppTheme.infoTextOf(context));
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
        color: AppTheme.accentLightOf(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.accentTextOf(context),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg) = switch (status) {
      SuggestionShipStatus.ordered => (
          AppTheme.infoBgOf(context),
          AppTheme.infoTextOf(context)
        ),
      SuggestionShipStatus.shipped => (
          AppTheme.warningBgOf(context),
          AppTheme.warningTextOf(context)
        ),
      SuggestionShipStatus.delivered => (
          AppTheme.successBgOf(context),
          AppTheme.successTextOf(context)
        ),
      SuggestionShipStatus.cancelled => (
          AppTheme.dangerBgOf(context),
          AppTheme.dangerTextOf(context)
        ),
      SuggestionShipStatus.refunded => dark
          ? (const Color(0xFF2E1065), const Color(0xFFC4B5FD))
          : (const Color(0xFFEDE9FE), const Color(0xFF6D28D9)),
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
        Icon(icon, size: 13, color: AppTheme.textMutedOf(context)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryOf(context),
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
          color: AppTheme.bgSubtleOf(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 14, color: AppTheme.textSecondaryOf(context)),
            const SizedBox(width: 6),
            Text(
              tracking,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            if (carrier != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurfaceOf(context),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.borderStrongOf(context)),
                ),
                child: Text(
                  carrier!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.copy_outlined,
                size: 12, color: AppTheme.textMutedOf(context)),
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
        Icon(icon, size: 52, color: AppTheme.textDisabledOf(context)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            text,
            style: TextStyle(color: AppTheme.textMutedOf(context)),
          ),
        ),
      ],
    );
  }
}
