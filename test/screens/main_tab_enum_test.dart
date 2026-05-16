import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/screens/main_tab.dart';

void main() {
  group('MainTab enum', () {
    test('hat exakt 10 Werte', () {
      expect(MainTab.values.length, 10);
    });

    test('Reihenfolge stimmt mit der historischen Index-Order überein', () {
      // Vor Task #00 waren die Magic-Numbers in main_screen.dart:
      // 0=Dashboard, 1=Deals, 2=Tickets, 3=Inbox, 4=Inventory,
      // 5=Suppliers, 6=Stats, 7=Activity, 8=Settings, 9=Help.
      // Wenn jemand die Enum-Reihenfolge ändert, brechen alle
      // _navIcons[tab.index]-Lookups und der GlobalSearchDialog.
      expect(MainTab.values, [
        MainTab.dashboard,
        MainTab.deals,
        MainTab.tickets,
        MainTab.inbox,
        MainTab.inventory,
        MainTab.suppliers,
        MainTab.stats,
        MainTab.activity,
        MainTab.settings,
        MainTab.help,
      ]);
    });

    test('Round-Trip: Old-Index → Enum → New-Index ist stabil', () {
      for (var i = 0; i < MainTab.values.length; i++) {
        final tab = MainTab.values[i];
        expect(tab.index, i, reason: 'Index-Drift bei ${tab.name}');
      }
    });

    test('name-Property ist als Accessibility-Key tauglich', () {
      for (final tab in MainTab.values) {
        expect(tab.name, isNotEmpty);
        expect(tab.name, matches(RegExp(r'^[a-z]+$')));
      }
    });
  });
}
