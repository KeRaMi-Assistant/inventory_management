import 'package:flutter/foundation.dart';

import '../services/demo_data_service.dart';
import '../services/workspace_service.dart';
import '../utils/error_messages.dart';
import 'active_workspace_provider.dart';

/// Trägt den lokalen State des Onboarding-Flows: gewählte Shops, Lieferanten,
/// optionales erstes Ticket. Persistiert beim Abschluss `onboarded_at` auf dem
/// Workspace und legt — falls gewünscht — Demo-Daten an.
///
/// Bewusst dünn: kein eigenes Repository-Cache, keine Listener auf andere
/// Provider. Der OnboardingScreen liest direkt aus diesem Provider und ruft
/// am Ende [completeOnboarding] auf, das den AuthGate via
/// [ActiveWorkspaceProvider.applyUpdate] in den MainScreen routet.
class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider({
    required WorkspaceService workspaceService,
    required DemoDataService demoDataService,
  })  : _workspaceService = workspaceService,
        _demoDataService = demoDataService;

  final WorkspaceService _workspaceService;
  final DemoDataService _demoDataService;

  // ── Step 3: shops ───────────────────────────────────────────────────────
  final Set<String> _selectedShops = <String>{};
  Set<String> get selectedShops => Set.unmodifiable(_selectedShops);

  void toggleShop(String shop) {
    if (!_selectedShops.add(shop)) _selectedShops.remove(shop);
    notifyListeners();
  }

  // ── Step 4: suppliers ───────────────────────────────────────────────────
  final List<String> _suppliers = <String>[];
  List<String> get suppliers => List.unmodifiable(_suppliers);

  void addSupplier(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    if (_suppliers.any((s) => s.toLowerCase() == clean.toLowerCase())) return;
    _suppliers.add(clean);
    notifyListeners();
  }

  void removeSupplier(String name) {
    _suppliers.removeWhere((s) => s == name);
    notifyListeners();
  }

  // ── Step 5: first ticket ────────────────────────────────────────────────
  String _firstTicketProduct = '';
  int _firstTicketQuantity = 1;
  String _firstTicketShop = '';

  String get firstTicketProduct => _firstTicketProduct;
  int get firstTicketQuantity => _firstTicketQuantity;
  String get firstTicketShop => _firstTicketShop;

  void setFirstTicket({String? product, int? quantity, String? shop}) {
    if (product != null) _firstTicketProduct = product;
    if (quantity != null) _firstTicketQuantity = quantity.clamp(1, 999);
    if (shop != null) _firstTicketShop = shop;
    notifyListeners();
  }

  bool get hasFirstTicket =>
      _firstTicketProduct.trim().isNotEmpty &&
      _firstTicketShop.trim().isNotEmpty;

  // ── Status ──────────────────────────────────────────────────────────────
  bool _busy = false;
  bool get busy => _busy;

  String? _lastError;
  String? get lastError => _lastError;

  /// Persistiert die gewählten Shops/Suppliers, optional das erste Ticket,
  /// und markiert den Workspace als `onboarded`. Aktualisiert den
  /// [ActiveWorkspaceProvider] live, damit der AuthGate sofort weiterroutet.
  Future<bool> completeOnboarding({
    required ActiveWorkspaceProvider activeWs,
    required String workspaceId,
    required Future<void> Function(String name) onAddShop,
    required Future<void> Function(String name) onAddSupplier,
    required Future<void> Function(
      String product,
      int quantity,
      String shop,
    ) onAddFirstDeal,
  }) async {
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      for (final shop in _selectedShops) {
        await onAddShop(shop);
      }
      for (final s in _suppliers) {
        await onAddSupplier(s);
      }
      if (hasFirstTicket) {
        await onAddFirstDeal(
          _firstTicketProduct.trim(),
          _firstTicketQuantity,
          _firstTicketShop.trim(),
        );
      }
      final updated = await _workspaceService.markOnboarded(workspaceId);
      activeWs.applyUpdate(updated);
      return true;
    } catch (e) {
      _lastError = sanitizeError(e);
      if (kDebugMode) debugPrint('OnboardingProvider.complete failed: $e');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// "Skip Onboarding" — markiert den Workspace nur als onboarded, ohne
  /// Shops/Suppliers/Tickets anzulegen.
  Future<bool> skipOnboarding({
    required ActiveWorkspaceProvider activeWs,
    required String workspaceId,
  }) async {
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      final updated = await _workspaceService.markOnboarded(workspaceId);
      activeWs.applyUpdate(updated);
      return true;
    } catch (e) {
      _lastError = sanitizeError(e);
      if (kDebugMode) debugPrint('OnboardingProvider.skip failed: $e');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // ── Demo-Daten (auch außerhalb Onboarding aufrufbar) ─────────────────────

  Future<DemoSeedResult?> loadDemoData(String workspaceId) async {
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      return await _demoDataService.loadDemoData(workspaceId: workspaceId);
    } catch (e) {
      _lastError = sanitizeError(e);
      if (kDebugMode) debugPrint('OnboardingProvider.loadDemo failed: $e');
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<DemoWipeResult?> wipeDemoData(String workspaceId) async {
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      return await _demoDataService.wipeDemoData(workspaceId: workspaceId);
    } catch (e) {
      _lastError = sanitizeError(e);
      if (kDebugMode) debugPrint('OnboardingProvider.wipeDemo failed: $e');
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> hasDemoData(String workspaceId) async {
    try {
      return await _demoDataService.hasDemoData(workspaceId: workspaceId);
    } catch (_) {
      return false;
    }
  }

  void resetLocalState() {
    _selectedShops.clear();
    _suppliers.clear();
    _firstTicketProduct = '';
    _firstTicketQuantity = 1;
    _firstTicketShop = '';
    _lastError = null;
    notifyListeners();
  }
}
