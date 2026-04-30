import 'package:flutter/material.dart';
import '../models/deal.dart';

class FilterProvider extends ChangeNotifier {
  String search = '';
  String? buyer;
  String? status;
  String? shop;
  String? shippingType;
  String? beleg;
  DateTime? fromDate;
  DateTime? toDate;
  String sortKey = 'orderDate';
  bool sortAscending = false;
  final Set<int> selectedDealIds = {};

  void setSearch(String value) {
    search = value;
    notifyListeners();
  }

  void setBuyer(String? value) {
    buyer = _blankToNull(value);
    notifyListeners();
  }

  void setStatus(String? value) {
    status = _blankToNull(value);
    notifyListeners();
  }

  void setShop(String? value) {
    shop = _blankToNull(value);
    notifyListeners();
  }

  void setShippingType(String? value) {
    shippingType = _blankToNull(value);
    notifyListeners();
  }

  void setBeleg(String? value) {
    beleg = _blankToNull(value);
    notifyListeners();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    fromDate = from;
    toDate = to;
    notifyListeners();
  }

  void setSort(String key) {
    if (sortKey == key) {
      sortAscending = !sortAscending;
    } else {
      sortKey = key;
      sortAscending = true;
    }
    notifyListeners();
  }

  void reset() {
    search = '';
    buyer = null;
    status = null;
    shop = null;
    shippingType = null;
    beleg = null;
    fromDate = null;
    toDate = null;
    sortKey = 'orderDate';
    sortAscending = false;
    selectedDealIds.clear();
    notifyListeners();
  }

  void toggleSelected(int id) {
    if (!selectedDealIds.add(id)) selectedDealIds.remove(id);
    notifyListeners();
  }

  void selectAll(Iterable<int> ids) {
    selectedDealIds
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  void clearSelection() {
    selectedDealIds.clear();
    notifyListeners();
  }

  List<Deal> apply(List<Deal> deals) {
    final q = search.trim().toLowerCase();
    final filtered = deals.where((deal) {
      final matchesSearch = q.isEmpty ||
          deal.product.toLowerCase().contains(q) ||
          (deal.ticketNumber ?? '').toLowerCase().contains(q) ||
          (deal.tracking ?? '').toLowerCase().contains(q) ||
          (deal.note ?? '').toLowerCase().contains(q);
      if (!matchesSearch) return false;
      if (buyer != null && deal.buyer != buyer) return false;
      if (status != null && deal.status != status) return false;
      if (shop != null && deal.shop != shop) return false;
      if (shippingType != null && deal.shippingType != shippingType) {
        return false;
      }
      if (beleg != null && deal.beleg != beleg) return false;
      if (fromDate != null && deal.orderDate.isBefore(_dayStart(fromDate!))) {
        return false;
      }
      if (toDate != null && deal.orderDate.isAfter(_dayEnd(toDate!))) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final result = _compare(a, b);
      return sortAscending ? result : -result;
    });
    return filtered;
  }

  int _compare(Deal a, Deal b) {
    int cmp<T extends Comparable<Object>>(T? x, T? y) {
      if (x == null && y == null) return 0;
      if (x == null) return -1;
      if (y == null) return 1;
      return x.compareTo(y);
    }

    return switch (sortKey) {
      'id' => a.id.compareTo(b.id),
      'product' => a.product.toLowerCase().compareTo(b.product.toLowerCase()),
      'quantity' => a.quantity.compareTo(b.quantity),
      'shippingType' => a.shippingType.compareTo(b.shippingType),
      'shop' => a.shop.compareTo(b.shop),
      'ekNetto' => cmp(a.ekNetto, b.ekNetto),
      'ekBrutto' => cmp(a.ekBrutto, b.ekBrutto),
      'vk' => cmp(a.vk, b.vk),
      'buyer' => cmp(a.buyer, b.buyer),
      'ticketNumber' => cmp(a.ticketNumber, b.ticketNumber),
      'tracking' => cmp(a.tracking, b.tracking),
      'arrivalDate' => cmp(a.arrivalDate, b.arrivalDate),
      'status' => a.status.compareTo(b.status),
      'beleg' => a.beleg.compareTo(b.beleg),
      'profitPerUnit' => cmp(a.profitPerUnit, b.profitPerUnit),
      'totalProfit' => cmp(a.totalProfit, b.totalProfit),
      'zuBekommen' => cmp(a.zuBekommen, b.zuBekommen),
      _ => a.orderDate.compareTo(b.orderDate),
    };
  }

  String? _blankToNull(String? value) =>
      value == null || value.isEmpty || value == 'Alle' ? null : value;

  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _dayEnd(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
}
