import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
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
import 'tracking_chip.dart';

class DealCard extends StatelessWidget {
  final Deal deal;
  final InventoryProvider provider;
  final FilterProvider filters;
  final ValueChanged<String>? onOpenTicket;

  const DealCard({
    super.key,
    required this.deal,
    required this.provider,
    required this.filters,
    this.onOpenTicket,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dateFmt = DateFormat.yMd(localeTag);
    final money = NumberFormat.currency(locale: localeTag, symbol: '€');
    final status = _statusStyle(deal.status);
    final selected = filters.selectedDealIds.contains(deal.id);

    Buyer? buyer;
    try {
      buyer = provider.buyers.firstWhere((b) => b.name == deal.buyer);
    } catch (_) {}

    Shop? shop;
    try {
      shop = provider.shops.firstWhere((s) => s.name == deal.shop);
    } catch (_) {}

    final profit = deal.totalProfit;
    final profitColor = profit == null
        ? AppTheme.textMuted
        : (profit >= 0 ? AppTheme.success : AppTheme.danger);

    return Material(
      color: selected ? AppTheme.accentLight : AppTheme.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? AppTheme.accent : AppTheme.border,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AddEditDealDialog(deal: deal),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top: checkbox + product + status ───────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: selected,
                      onChanged: (_) => filters.toggleSelected(deal.id),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deal.product,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '#${deal.id} · ${deal.quantity} Stk.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '·',
                              style: TextStyle(color: AppTheme.textDisabled),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: shop?.url != null
                                  ? InkWell(
                                      onTap: () => openUrlWithFallback(
                                          context, shop!.url!),
                                      child: Text(
                                        deal.shop,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : Text(
                                      deal.shop,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _StatusPill(
                      label: localizeDealStatus(context, deal.status),
                      style: status),
                ],
              ),
              const SizedBox(height: 10),
              // ── Middle: numbers ────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _NumberCell(
                      label: 'EK',
                      value: deal.ekBrutto != null
                          ? money.format(deal.ekBrutto)
                          : '-',
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: _NumberCell(
                      label: 'VK',
                      value: deal.vk != null ? money.format(deal.vk) : '-',
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: _NumberCell(
                      label: 'Profit',
                      value:
                          profit != null ? money.format(profit) : '-',
                      color: profitColor,
                      bold: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ── Bottom: buyer + dates + ticket + tracking ──────────────
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (deal.buyer != null) _buyerBadge(deal.buyer!, buyer),
                  _MetaChip(
                    icon: Icons.event_outlined,
                    label: dateFmt.format(deal.orderDate),
                  ),
                  if (deal.arrivalDate != null)
                    _MetaChip(
                      icon: Icons.local_shipping_outlined,
                      label: dateFmt.format(deal.arrivalDate!),
                      color: AppTheme.success,
                    ),
                  if (deal.ticketNumber != null)
                    _MetaChip(
                      icon: Icons.confirmation_number_outlined,
                      label: deal.ticketNumber!,
                      color: AppTheme.accent,
                      onTap: () {
                        if (onOpenTicket != null) {
                          onOpenTicket!(deal.ticketNumber!);
                        } else if (deal.ticketUrl != null) {
                          final prov = context.read<InventoryProvider>();
                          final b = prov.buyers
                              .where((x) => x.name == deal.buyer)
                              .firstOrNull;
                          openUrlWithFallback(
                            context,
                            resolveDiscordUrl(deal.ticketUrl!,
                                serverIds: b?.discordServerIds ?? []),
                          );
                        }
                      },
                    ),
                  if (deal.tracking != null)
                    TrackingChip(
                      tracking: deal.tracking!,
                      shopAmazonCountry: amazonCountryFromShop(
                        shopName: shop?.name,
                        region: shop?.region,
                      ),
                    ),
                  if (deal.hasReceipt)
                    _MetaChip(
                      icon: Icons.receipt_long_outlined,
                      label: l10n.dealReceipt,
                      color: AppTheme.success,
                    ),
                ],
              ),
              if (deal.note != null && deal.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    deal.note!,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              // ── Actions ────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: l10n.actionEdit,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => AddEditDealDialog(deal: deal),
                    ),
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: AppTheme.accent),
                  ),
                  IconButton(
                    tooltip: l10n.actionDelete,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppTheme.danger),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buyerBadge(String name, Buyer? buyer) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: buyer?.buyerCellColor ?? AppTheme.textMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_outline, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              color: buyer?.fontColor ?? Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
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
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: Text(l10n.actionDelete,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  ({Color bg, Color border, Color text}) _statusStyle(String s) =>
      switch (s) {
        'Bestellt' => (
            bg: AppTheme.accentLight,
            border: const Color(0xFFBFDBFE),
            text: AppTheme.accentDark
          ),
        'Unterwegs' => (
            bg: AppTheme.warningBg,
            border: const Color(0xFFFDE68A),
            text: AppTheme.warning
          ),
        'Angekommen' => (
            bg: const Color(0xFFF0FDFA),
            border: const Color(0xFF99F6E4),
            text: const Color(0xFF0F766E)
          ),
        'Rechnung gestellt' => (
            bg: const Color(0xFFF5F3FF),
            border: const Color(0xFFDDD6FE),
            text: const Color(0xFF6D28D9)
          ),
        'Done' => (
            bg: AppTheme.successBg,
            border: const Color(0xFFBBF7D0),
            text: AppTheme.success
          ),
        _ => (
            bg: AppTheme.bgSubtle,
            border: AppTheme.border,
            text: AppTheme.textMuted
          ),
      };
}

// ─── small parts ─────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String label;
  final ({Color bg, Color border, Color text}) style;
  const _StatusPill({required this.label, required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: style.text,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NumberCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _NumberCell({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  const _MetaChip({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textMuted;
    final widget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: c,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return widget;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: widget,
    );
  }
}
