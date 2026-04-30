import 'deal.dart';
import 'inventory_item.dart';

class TicketSummary {
  final String ticketNumber;
  final List<Deal> deals;
  final List<InventoryItem> items;

  const TicketSummary({
    required this.ticketNumber,
    required this.deals,
    required this.items,
  });

  bool get hasTicket => ticketNumber != 'Kein Ticket';
  int get dealCount => deals.length;
  int get totalQuantity => deals.fold(0, (sum, d) => sum + d.quantity);
  double get totalEk =>
      deals.fold(0, (sum, d) => sum + (d.ekGesamtBrutto ?? 0));
  double get totalVk => deals.fold(0, (sum, d) => sum + (d.zuBekommen ?? 0));
  double get totalProfit =>
      deals.fold(0, (sum, d) => sum + (d.totalProfit ?? 0));
  String? get buyer => deals.map((d) => d.buyer).whereType<String>().firstOrNull;
  String? get url => deals.map((d) => d.ticketUrl).whereType<String>().firstOrNull;
  DateTime get newestDate => deals
      .map((d) => d.orderDate)
      .reduce((a, b) => a.isAfter(b) ? a : b);

  String get worstStatus {
    const rank = {
      'Bestellt': 0,
      'Unterwegs': 1,
      'Angekommen': 2,
      'Rechnung gestellt': 3,
      'Done': 4,
    };
    return deals.map((d) => d.status).reduce((a, b) {
      return (rank[a] ?? 99) <= (rank[b] ?? 99) ? a : b;
    });
  }

  String get arrivalSummary {
    final arrived = deals.where((d) => d.arrivalDate != null).length;
    if (arrived == 0) return 'Ausstehend';
    if (arrived == deals.length) return 'Alle angekommen';
    return 'Teilweise';
  }
}
