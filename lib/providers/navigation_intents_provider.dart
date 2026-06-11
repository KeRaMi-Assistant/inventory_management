import 'package:flutter/foundation.dart';

import '../screens/main_tab.dart';

/// Zentrale Navigations-Intents (Paket 3): entkoppelt "irgendwo will jemand
/// zu Tab X springen" von der MainScreen-internen Tab-State-Verwaltung.
///
/// Producer:
///   * [handlePushData] — FCM-Notification-Taps (PushService): Payload-`kind`
///     wird auf ein Ziel gemappt (tracking_status/delivery/payment → Deals,
///     low_stock/mhd → Lager-Hub).
///   * [requestTab] — KPI-Drilldowns im Dashboard u.ä.
///
/// Consumer: `MainScreen` beobachtet den Provider, springt zum Tab, öffnet
/// ggf. den Deal-Dialog und ruft [consume] auf.
class NavigationIntentsProvider extends ChangeNotifier {
  MainTab? _pendingTab;
  int? _pendingDealId;

  MainTab? get pendingTab => _pendingTab;
  int? get pendingDealId => _pendingDealId;

  /// Sprungwunsch zu [tab], optional mit Deal-Detail ([dealId]).
  void requestTab(MainTab tab, {int? dealId}) {
    _pendingTab = tab;
    _pendingDealId = dealId;
    notifyListeners();
  }

  /// Mappt einen FCM-Data-Payload auf ein Navigationsziel. Unbekannte
  /// `kind`-Werte werden ignoriert (kein Sprung ins Nichts).
  void handlePushData(Map<String, dynamic> data) {
    final kind = data['kind'] as String?;
    final dealId = int.tryParse('${data['dealId'] ?? ''}');
    switch (kind) {
      case 'tracking_status':
      case 'delivery':
      case 'payment':
        requestTab(MainTab.deals, dealId: dealId);
      case 'low_stock':
      case 'mhd':
        requestTab(MainTab.warehouse);
      default:
        return;
    }
  }

  /// Vom Consumer (MainScreen) nach Verarbeitung aufgerufen.
  void consume() {
    _pendingTab = null;
    _pendingDealId = null;
  }
}
