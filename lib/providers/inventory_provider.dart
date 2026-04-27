import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/buyer.dart';
import '../models/deal.dart';
import '../models/shop.dart';
import '../services/discord_service.dart';
import '../services/storage_service.dart';

class InventoryProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final _uuid = const Uuid();

  List<Deal> _deals = [];
  List<Buyer> _buyers = [];
  List<Shop> _shops = [];
  String _discordClientId = '';
  String _discordAccessToken = '';
  String _discordUsername = '';
  DateTime? _discordTokenExpiry;

  List<Deal> get deals => List.unmodifiable(
        List.from(_deals)..sort((a, b) => b.id.compareTo(a.id)),
      );
  List<Buyer> get buyers => List.unmodifiable(
        List.from(_buyers)..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      );
  List<Shop> get shops => List.unmodifiable(_shops);

  String get discordClientId => _discordClientId;
  String get discordAccessToken => _discordAccessToken;
  String get discordUsername => _discordUsername;
  bool get isDiscordConnected =>
      _discordAccessToken.isNotEmpty &&
      (_discordTokenExpiry == null ||
          _discordTokenExpiry!.isAfter(DateTime.now()));

  static const List<String> statusOptions = [
    'Bestellt',
    'Unterwegs',
    'Rechnung gestellt',
    'Done',
  ];
  static const List<String> shippingTypes = ['Reship', 'Dropship'];
  static const List<String> belegOptions = ['Ja', 'Nein'];

  int get openOrdersCount =>
      _deals.where((d) => d.status == 'Bestellt').length;

  double get totalProfit => _deals.fold(
        0,
        (sum, d) => sum + (d.totalProfit ?? 0),
      );

  double get openAmount => _deals
      .where((d) => d.status != 'Done')
      .fold(0, (sum, d) => sum + (d.zuBekommen ?? 0));

  int get openDeliveriesCount =>
      _deals.where((d) => d.status == 'Unterwegs').length;

  int get nextDealId =>
      _deals.isEmpty ? 1 : (_deals.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1);

  /// All non-null ticketNumbers used as Amazon order IDs.
  Set<String> get existingAmazonOrderIds =>
      _deals.where((d) => d.ticketNumber != null && d.ticketNumber!.isNotEmpty).map((d) => d.ticketNumber!).toSet();

  Future<void> loadData() async {
    final data = await _storage.loadData();
    if (data != null) {
      _deals = (data['deals'] as List<dynamic>? ?? [])
          .map((e) => Deal.fromJson(e as Map<String, dynamic>))
          .toList();
      _buyers = (data['buyers'] as List<dynamic>? ?? [])
          .map((e) => Buyer.fromJson(e as Map<String, dynamic>))
          .toList();
      _shops = (data['shops'] as List<dynamic>? ?? [])
          .map((e) => Shop.fromJson(e as Map<String, dynamic>))
          .toList();
      _discordClientId = data['discordClientId'] as String? ?? '';
      _discordAccessToken = data['discordAccessToken'] as String? ?? '';
      _discordUsername = data['discordUsername'] as String? ?? '';
      final expiryMs = data['discordTokenExpiry'] as int?;
      _discordTokenExpiry = expiryMs != null
          ? DateTime.fromMillisecondsSinceEpoch(expiryMs)
          : null;
    } else {
      _initDefaults();
    }
    notifyListeners();
  }

  void _initDefaults() {
    _buyers = [
      Buyer(
        id: _uuid.v4(),
        name: 'Tibor',
        rowFillColor: const Color(0xFFE3F0FF),
        buyerCellColor: const Color(0xFF1565C0),
        fontColor: Colors.white,
        sortOrder: 0,
      ),
      Buyer(
        id: _uuid.v4(),
        name: 'Bountyhunter',
        rowFillColor: const Color(0xFFFFF3E0),
        buyerCellColor: const Color(0xFFE65100),
        fontColor: Colors.white,
        sortOrder: 1,
      ),
      Buyer(
        id: _uuid.v4(),
        name: 'Mahando',
        rowFillColor: const Color(0xFFE8F5E9),
        buyerCellColor: const Color(0xFF2E7D32),
        fontColor: Colors.white,
        sortOrder: 2,
      ),
      Buyer(
        id: _uuid.v4(),
        name: 'Christian Leimer',
        rowFillColor: const Color(0xFFF3E5F5),
        buyerCellColor: const Color(0xFF6A1B9A),
        fontColor: Colors.white,
        sortOrder: 3,
      ),
      Buyer(
        id: _uuid.v4(),
        name: 'GrinBuy',
        rowFillColor: const Color(0xFFFFFDE7),
        buyerCellColor: const Color(0xFFF9A825),
        fontColor: Colors.black,
        sortOrder: 4,
      ),
    ];
    _shops = [
      Shop(id: _uuid.v4(), name: 'Amazon-ES', region: 'ES', channel: 'Amazon'),
      Shop(id: _uuid.v4(), name: 'Amazon-DE', region: 'DE', channel: 'Amazon'),
      Shop(id: _uuid.v4(), name: 'Amazon-FR', region: 'FR', channel: 'Amazon'),
      Shop(id: _uuid.v4(), name: 'eBay', region: 'DE', channel: 'eBay'),
      Shop(id: _uuid.v4(), name: 'Alibaba', region: 'CN', channel: 'Alibaba'),
    ];
    _deals = [];
  }

  Future<void> _save() async {
    await _storage.saveData({
      'deals': _deals.map((d) => d.toJson()).toList(),
      'buyers': _buyers.map((b) => b.toJson()).toList(),
      'shops': _shops.map((s) => s.toJson()).toList(),
      'discordClientId': _discordClientId,
      'discordAccessToken': _discordAccessToken,
      'discordUsername': _discordUsername,
      'discordTokenExpiry': _discordTokenExpiry?.millisecondsSinceEpoch,
    });
  }

  Future<void> updateDiscordClientId(String id) async {
    _discordClientId = id.trim();
    notifyListeners();
    await _save();
  }

  /// Called after Discord OAuth2 redirect — parses the URL fragment,
  /// extracts the access token, fetches the username, and persists.
  Future<void> handleDiscordOAuthCallback(String fragment) async {
    final params = DiscordService.parseOAuthFragment(fragment);
    if (params == null) return;
    final token = params['access_token'] ?? '';
    if (token.isEmpty) return;
    final expiresIn = int.tryParse(params['expires_in'] ?? '') ?? 604800;
    _discordAccessToken = token;
    _discordTokenExpiry =
        DateTime.now().add(Duration(seconds: expiresIn));
    _discordUsername =
        await DiscordService.getUserName(token) ?? '';
    notifyListeners();
    await _save();
  }

  Future<void> disconnectDiscord() async {
    _discordAccessToken = '';
    _discordUsername = '';
    _discordTokenExpiry = null;
    notifyListeners();
    await _save();
  }

  // DEALS
  Future<void> addDeal(Deal deal) async {
    _deals.add(deal.copyWith(id: nextDealId));
    notifyListeners();
    await _save();
  }

  Future<void> updateDeal(Deal deal) async {
    final idx = _deals.indexWhere((d) => d.id == deal.id);
    if (idx != -1) {
      _deals[idx] = deal;
      notifyListeners();
      await _save();
    }
  }

  Future<void> deleteDeal(int id) async {
    _deals.removeWhere((d) => d.id == id);
    notifyListeners();
    await _save();
  }

  /// Merges imported deals (new IDs assigned sequentially).
  Future<void> importDeals(List<Deal> imported) async {
    int id = nextDealId;
    for (final d in imported) {
      _deals.add(d.copyWith(id: id++));
    }
    notifyListeners();
    await _save();
  }

  // BUYERS
  Future<void> addBuyer(Buyer buyer) async {
    _buyers.add(buyer.copyWith(id: _uuid.v4()));
    notifyListeners();
    await _save();
  }

  Future<void> updateBuyer(Buyer buyer) async {
    final idx = _buyers.indexWhere((b) => b.id == buyer.id);
    if (idx != -1) {
      _buyers[idx] = buyer;
      notifyListeners();
      await _save();
    }
  }

  Future<void> deleteBuyer(String id) async {
    _buyers.removeWhere((b) => b.id == id);
    notifyListeners();
    await _save();
  }

  // SHOPS
  Future<void> addShop(Shop shop) async {
    _shops.add(shop.copyWith(id: _uuid.v4()));
    notifyListeners();
    await _save();
  }

  Future<void> updateShop(Shop shop) async {
    final idx = _shops.indexWhere((s) => s.id == shop.id);
    if (idx != -1) {
      _shops[idx] = shop;
      notifyListeners();
      await _save();
    }
  }

  Future<void> deleteShop(String id) async {
    _shops.removeWhere((s) => s.id == id);
    notifyListeners();
    await _save();
  }
}
