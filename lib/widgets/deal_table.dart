import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/buyer.dart';
import '../models/deal.dart';
import '../providers/inventory_provider.dart';
import 'add_edit_deal_dialog.dart';

class DealTable extends StatelessWidget {
  const DealTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final deals = provider.deals;
        if (deals.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 56, color: Color(0xFFCBD5E1)),
                SizedBox(height: 12),
                Text(
                  'Keine Einträge vorhanden',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 6),
                Text(
                  'Klicke auf „Neuer Eintrag" um einen Deal hinzuzufügen.',
                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                ),
              ],
            ),
          );
        }
        final dateFmt = DateFormat('dd.MM.yyyy');
        final numFmt = NumberFormat('#,##0.00', 'de_DE');

        Buyer? findBuyer(String? name) {
          if (name == null) return null;
          try {
            return provider.buyers.firstWhere((b) => b.name == name);
          } catch (_) {
            return null;
          }
        }

        Color statusColor(String s) {
          switch (s) {
            case 'Bestellt':
              return Colors.blue;
            case 'Unterwegs':
              return Colors.orange;
            case 'Rechnung gestellt':
              return Colors.purple;
            case 'Done':
              return Colors.green;
            default:
              return Colors.grey;
          }
        }

        String fmtNum(double? v) => v != null ? '€ ${numFmt.format(v)}' : '';
        String fmtDate(DateTime? d) => d != null ? dateFmt.format(d) : '';

        DataRow buildRow(Deal deal) {
          final buyer = findBuyer(deal.buyer);
          final rowColor = buyer?.rowFillColor;
          final buyerCellColor = buyer?.buyerCellColor;
          final fontColor = buyer?.fontColor ?? Colors.black;

          return DataRow(
            color: rowColor != null
                ? WidgetStateProperty.all(rowColor)
                : null,
            cells: [
              DataCell(Text('${deal.id}')),
              DataCell(SizedBox(
                  width: 150,
                  child: Text(deal.product,
                      overflow: TextOverflow.ellipsis))),
              DataCell(Text('${deal.quantity}')),
              DataCell(Text(deal.shippingType)),
              DataCell(Text(deal.shop)),
              DataCell(Text(dateFmt.format(deal.orderDate))),
              DataCell(Text(fmtNum(deal.ekNetto))),
              DataCell(Text(fmtNum(deal.ekBrutto))),
              DataCell(Text(fmtNum(deal.vk))),
              DataCell(deal.buyer != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: buyerCellColor ?? Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(deal.buyer!,
                          style: TextStyle(
                              color: fontColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    )
                  : const Text('')),
              DataCell(Text(deal.ticketNumber ?? '')),
              DataCell(Text(deal.tracking ?? '')),
              DataCell(Text(fmtDate(deal.arrivalDate))),
              DataCell(
                Chip(
                  label: Text(deal.status,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11)),
                  backgroundColor: statusColor(deal.status),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              DataCell(Text(deal.beleg)),
              DataCell(Text(fmtNum(deal.profitPerUnit))),
              DataCell(Text(fmtNum(deal.totalProfit))),
              DataCell(Text(fmtNum(deal.zuBekommen))),
              DataCell(SizedBox(
                  width: 120,
                  child: Text(deal.note ?? '',
                      overflow: TextOverflow.ellipsis))),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AddEditDealDialog(deal: deal),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18,
                        color: Colors.red),
                    onPressed: () => _confirmDelete(context, provider, deal),
                  ),
                ],
              )),
            ],
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(Colors.grey[100]),
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Produkt')),
                DataColumn(label: Text('Anz.')),
                DataColumn(label: Text('Versandtyp')),
                DataColumn(label: Text('Shop')),
                DataColumn(label: Text('Bestelldatum')),
                DataColumn(label: Text('EK Netto')),
                DataColumn(label: Text('EK Brutto')),
                DataColumn(label: Text('VK')),
                DataColumn(label: Text('Käufer')),
                DataColumn(label: Text('Ticket')),
                DataColumn(label: Text('Tracking')),
                DataColumn(label: Text('Ankunft')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Beleg')),
                DataColumn(label: Text('Profit/Stk')),
                DataColumn(label: Text('Total Profit')),
                DataColumn(label: Text('Zu bekommen')),
                DataColumn(label: Text('Notiz')),
                DataColumn(label: Text('Aktionen')),
              ],
              rows: deals.map(buildRow).toList(),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(
      BuildContext context, InventoryProvider provider, Deal deal) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deal löschen'),
        content: Text(
            'Deal "${deal.product}" (ID: ${deal.id}) wirklich löschen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              provider.deleteDeal(deal.id);
              Navigator.pop(context);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
