import 'package:flutter/foundation.dart';

import '../models/billing_profile.dart';
import '../services/billing_service.dart';

/// Hält das aktuelle [BillingProfile] und vermittelt Lade-/Speicher-
/// Operationen. Wird von der Pricing- und Billing-Form-Screen verwendet
/// und kann später als Plan-Gate für Quotas dienen.
class BillingProvider extends ChangeNotifier {
  BillingProvider(this._service);

  final BillingService _service;

  BillingProfile? _profile;
  bool _loading = false;
  String? _error;

  BillingProfile? get profile => _profile;
  bool get isLoading => _loading;
  String? get error => _error;

  /// Aktueller Plan — Default Free, wenn noch kein Profil geladen wurde.
  BillingPlan get currentPlan => _profile?.plan ?? BillingPlan.free;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _service.loadCurrent();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> save(BillingProfile updated) async {
    _profile = await _service.upsert(updated);
    notifyListeners();
  }

  Future<void> activatePlan({
    required BillingPlan plan,
    BillingCycle? cycle,
  }) async {
    _profile = await _service.setPlan(plan: plan, cycle: cycle);
    notifyListeners();
  }

  void clear() {
    _profile = null;
    _loading = false;
    _error = null;
    notifyListeners();
  }
}
