import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/deal.dart';
import '../providers/inventory_provider.dart';

/// Reusable Picker für "Wähle einen bestehenden Deal aus". Wird vom Inbox-Tab
/// genutzt, um Tracking/Mail-Inhalte einem Deal zuzuweisen. Filtert Live nach
/// Produkt, Ticketnummer, Shop und Käufer.
class DealPickerDialog extends StatefulWidget {
  final String title;
  final String? hint;

  const DealPickerDialog({
    super.key,
    required this.title,
    this.hint,
  });

  static Future<Deal?> show(
    BuildContext context, {
    required String title,
    String? hint,
  }) {
    return showDialog<Deal>(
      context: context,
      builder: (_) => DealPickerDialog(title: title, hint: hint),
    );
  }

  @override
  State<DealPickerDialog> createState() => _DealPickerDialogState();
}

class _DealPickerDialogState extends State<DealPickerDialog> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Deal> _filter(List<Deal> deals) {
    final q = _query.trim().toLowerCase();
    final open = deals.where((d) => d.status != 'Done').toList();
    if (q.isEmpty) return open.take(60).toList();
    return open.where((d) {
      final hay = '${d.product} ${d.ticketNumber ?? ''} ${d.shop} ${d.buyer ?? ''}'
          .toLowerCase();
      return hay.contains(q);
    }).take(60).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, inventory, _) {
        final results = _filter(inventory.deals);
        return AlertDialog(
          title: Text(widget.title),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          content: SizedBox(
            width: 520,
            height: 460,
            child: Column(
              children: [
                if (widget.hint != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.hint!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMutedOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Suche nach Produkt, Ticket, Shop oder Käufer …',
                    prefixIcon: Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: results.isEmpty
                      ? Center(
                          child: Text(
                            'Kein passender Deal gefunden.',
                            style: TextStyle(color: AppTheme.textDisabledOf(context)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: results.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) =>
                              _DealRow(deal: results[i]),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).actionCancel),
            ),
          ],
        );
      },
    );
  }
}

class _DealRow extends StatelessWidget {
  final Deal deal;
  const _DealRow({required this.deal});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMd('de_DE');
    return InkWell(
      onTap: () => Navigator.pop(context, deal),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.bgSubtleOf(context),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '#${deal.id}',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deal.product,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      deal.shop,
                      if ((deal.ticketNumber ?? '').isNotEmpty)
                        '#${deal.ticketNumber}',
                      if (deal.buyer != null) deal.buyer!,
                      df.format(deal.orderDate),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMutedOf(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(deal.status).withAlpha(30),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                deal.status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _statusColor(deal.status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Bestellt':
        return AppTheme.info;
      case 'Unterwegs':
        return AppTheme.warning;
      case 'Angekommen':
        return AppTheme.success;
      case 'Rechnung gestellt':
        return AppTheme.purple;
      case 'Done':
        return AppTheme.textMuted;
      default:
        return AppTheme.textMuted;
    }
  }
}
