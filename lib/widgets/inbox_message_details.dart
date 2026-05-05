import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/inbox_message.dart';

/// Vollbild-fähiges Bottom-Sheet, das Header + extrahierte Felder einer
/// geparsten Mail anzeigt. Zeigt KEINE Rohinhalte (die werden ohnehin nach
/// Parse aus der DB entfernt). Aktionen (Verwerfen, Tracking, Deal anlegen)
/// werden über die Buttons unten ausgelöst.
class InboxMessageDetails extends StatelessWidget {
  final ParsedMessage message;
  final List<Widget> actions;

  const InboxMessageDetails({
    super.key,
    required this.message,
    this.actions = const [],
  });

  static Future<void> show(
    BuildContext context, {
    required ParsedMessage message,
    List<Widget> actions = const [],
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => InboxMessageDetails(message: message, actions: actions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = message.parsedPayload ?? const {};
    final orderId = p['order_id'] as String?;
    final shopLabel = p['shop_label'] as String? ?? message.shopKey;
    final product = p['product'] as String?;
    final tracking = p['tracking'] as String?;
    final carrier = p['carrier'] as String?;
    final total = (p['total'] as num?)?.toDouble();
    final currency = p['currency'] as String? ?? 'EUR';
    final eta = p['eta'] as String?;
    final df = DateFormat.yMMMd('de_DE').add_Hm();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatusBadge(status: message.status),
                if (shopLabel != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      shopLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message.subject ?? '— ohne Betreff —',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Von: ${message.fromAddress ?? "—"}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
            Text(
              'Empfangen: ${df.format(message.receivedAt.toLocal())}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
            if (message.processedAt != null)
              Text(
                'Verarbeitet: ${df.format(message.processedAt!.toLocal())}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
            const SizedBox(height: 20),
            if (orderId != null || product != null || total != null) ...[
              const _SectionTitle('Bestellung'),
              if (orderId != null)
                _DetailRow(
                  label: 'Order-ID',
                  value: orderId,
                  copyable: true,
                ),
              if (product != null)
                _DetailRow(label: 'Produkt', value: product),
              if (total != null)
                _DetailRow(
                  label: 'Betrag',
                  value: '${total.toStringAsFixed(2).replaceAll(".", ",")} '
                      '${_currencySymbol(currency)}',
                ),
              const SizedBox(height: 16),
            ],
            if (tracking != null) ...[
              const _SectionTitle('Versand'),
              _DetailRow(
                label: 'Tracking',
                value: tracking,
                copyable: true,
              ),
              if (carrier != null)
                _DetailRow(label: 'Carrier', value: carrier),
              if (eta != null)
                _DetailRow(label: 'ETA', value: eta),
              const SizedBox(height: 16),
            ],
            if (message.matchDealId != null) ...[
              const _SectionTitle('Verknüpft mit'),
              _DetailRow(
                label: 'Deal',
                value: '#${message.matchDealId}',
              ),
              const SizedBox(height: 16),
            ],
            if (actions.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }

  static String _currencySymbol(String c) {
    switch (c) {
      case 'EUR':
        return '€';
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'PLN':
        return 'zł';
      default:
        return c;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final ParsedMessageStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ParsedMessageStatus.matched =>
        ('Aktualisiert', const Color(0xFF15803D)),
      ParsedMessageStatus.suggested =>
        ('Vorschlag', const Color(0xFF2563EB)),
      ParsedMessageStatus.unclassified =>
        ('Unklassifiziert', const Color(0xFFB45309)),
      ParsedMessageStatus.failed =>
        ('Fehler', const Color(0xFFB91C1C)),
      ParsedMessageStatus.dismissed =>
        ('Verworfen', const Color(0xFF94A3B8)),
      ParsedMessageStatus.pending =>
        ('In Arbeit', const Color(0xFF64748B)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  const _DetailRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          if (copyable)
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 14),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints.tightFor(width: 28, height: 28),
              tooltip: 'Kopieren',
              onPressed: () => Clipboard.setData(ClipboardData(text: value)),
            ),
        ],
      ),
    );
  }
}
