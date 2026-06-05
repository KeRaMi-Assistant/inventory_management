import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_entry.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../services/supabase_repository.dart';

/// Holds the catalog domain state for the signed-in user:
/// [ProductCategory] and [Product] lists. All mutations are routed through
/// [SupabaseRepository]; local lists are caches kept in sync with the server.
///
/// Extracted from [InventoryProvider] as the first provider-split increment.
/// Registers as [ChangeNotifierProxyProvider<SupabaseRepository, CatalogProvider>]
/// in `main.dart`. Workspace lifecycle mirrors [InventoryProvider]:
/// [setActiveWorkspace] is called by the same [_AuthGateState] listener that
/// calls it on [InventoryProvider].
class CatalogProvider extends ChangeNotifier {
  CatalogProvider({required SupabaseRepository repository})
      : _repository = repository;

  final SupabaseRepository _repository;
  final _uuid = const Uuid();

  List<ProductCategory> _productCategories = [];
  List<Product> _products = [];

  bool _loading = false;
  bool _initialLoadAttempted = false;
  Object? _lastError;
  bool _disposed = false;

  /// In-flight load guard — coalesces concurrent [loadData] calls.
  Future<void>? _loadDataInFlight;

  // ── Getters ───────────────────────────────────────────────────────────────

  bool get isLoading => _loading;

  /// True as soon as the first [loadData] call has returned.
  bool get initialLoadAttempted => _initialLoadAttempted;

  Object? get lastError => _lastError;

  List<ProductCategory> get productCategories =>
      List.unmodifiable(_productCategories);

  List<Product> get products => List.unmodifiable(_products);

  // ── Workspace lifecycle ───────────────────────────────────────────────────

  String? _activeWorkspaceId;

  /// Called by [_AuthGateState._onWorkspaceChanged] whenever the active
  /// workspace changes — mirrors the pattern in [InventoryProvider].
  Future<void> setActiveWorkspace(String? workspaceId) async {
    if (_activeWorkspaceId == workspaceId) return;
    _activeWorkspaceId = workspaceId;
    if (workspaceId == null) {
      clearLocalState();
      return;
    }
    await loadData();
  }

  Future<void> loadData() {
    if (_loadDataInFlight != null) return _loadDataInFlight!;
    _loadDataInFlight = _doLoadData();
    return _loadDataInFlight!;
  }

  Future<void> _doLoadData() async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      final snapshot = await _repository.loadAll();
      _productCategories = List.of(snapshot.productCategories)
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _products = List.of(snapshot.products)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      _lastError = e;
      if (kDebugMode) debugPrint('CatalogProvider.loadData failed: $e');
    } finally {
      _loading = false;
      _initialLoadAttempted = true;
      _loadDataInFlight = null;
      if (!_disposed) notifyListeners();
    }
  }

  /// Wipes local caches — used on sign-out so the next user starts clean.
  void clearLocalState() {
    _productCategories = [];
    _products = [];
    _lastError = null;
    _initialLoadAttempted = false;
    _activeWorkspaceId = null;
    notifyListeners();
  }

  // ── Activity helper ───────────────────────────────────────────────────────

  /// Fire-and-forget activity log. Writes directly to the DB via the
  /// repository (no in-memory cache — the activity screen loads from DB).
  /// Errors are swallowed after debug logging so they never block the caller.
  void _log(String message, String type) {
    final entry = ActivityEntry(
      id: _uuid.v4(),
      date: DateTime.now(),
      message: message,
      type: type,
    );
    unawaited(_repository.insertActivity(entry).catchError((Object e) {
      if (kDebugMode) debugPrint('CatalogProvider: activity_log insert failed: $e');
      return entry;
    }));
  }

  // ── PRODUCT CATEGORIES ────────────────────────────────────────────────────

  Future<void> addProductCategory(ProductCategory category) async {
    final saved = await _repository.insertProductCategory(category);
    _productCategories.add(saved);
    _productCategories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _log('Warengruppe hinzugefügt: ${saved.name}', 'category');
    notifyListeners();
  }

  Future<void> updateProductCategory(ProductCategory category) async {
    final saved = await _repository.updateProductCategory(category);
    final idx = _productCategories.indexWhere((c) => c.id == saved.id);
    if (idx == -1) return;
    _productCategories[idx] = saved;
    _productCategories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _log('Warengruppe aktualisiert: ${saved.name}', 'category');
    notifyListeners();
  }

  Future<void> deleteProductCategory(String id) async {
    final category = _productCategories.where((c) => c.id == id).firstOrNull;
    await _repository.deleteProductCategory(id);
    _productCategories.removeWhere((c) => c.id == id);
    if (category != null) {
      _log('Warengruppe gelöscht: ${category.name}', 'category');
    }
    notifyListeners();
  }

  // ── PRODUCTS ──────────────────────────────────────────────────────────────

  Future<void> addProduct(Product product) async {
    final saved = await _repository.insertProduct(product);
    _products.add(saved);
    _products.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _log('Artikel hinzugefügt: ${saved.name}', 'product');
    notifyListeners();
  }

  Future<void> updateProduct(Product product) async {
    final saved = await _repository.updateProduct(product);
    final idx = _products.indexWhere((p) => p.id == saved.id);
    if (idx == -1) return;
    _products[idx] = saved;
    _products.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _log('Artikel aktualisiert: ${saved.name}', 'product');
    notifyListeners();
  }

  Future<void> deleteProduct(String id) async {
    final product = _products.where((p) => p.id == id).firstOrNull;
    await _repository.deleteProduct(id);
    _products.removeWhere((p) => p.id == id);
    if (product != null) {
      _log('Artikel gelöscht: ${product.name}', 'product');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
