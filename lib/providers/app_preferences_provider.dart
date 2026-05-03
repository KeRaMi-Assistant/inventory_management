import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-Präferenzen die nichts mit der Cloud-DB zu tun haben:
/// - monatliches Profit-Ziel (für die Statistik)
/// - Schwellwert für "niedriger Bestand"-Warnungen
class AppPreferencesProvider extends ChangeNotifier {
  static const _kProfitGoal = 'pref_monthly_profit_goal';
  static const _kLowStock = 'pref_low_stock_threshold';

  double _monthlyProfitGoal = 1000;
  int _lowStockThreshold = 5;
  bool _ready = false;

  double get monthlyProfitGoal => _monthlyProfitGoal;
  int get lowStockThreshold => _lowStockThreshold;
  bool get isReady => _ready;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _monthlyProfitGoal = prefs.getDouble(_kProfitGoal) ?? 1000;
    _lowStockThreshold = prefs.getInt(_kLowStock) ?? 5;
    _ready = true;
    notifyListeners();
  }

  Future<void> setMonthlyProfitGoal(double value) async {
    _monthlyProfitGoal = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kProfitGoal, value);
    notifyListeners();
  }

  Future<void> setLowStockThreshold(int value) async {
    _lowStockThreshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLowStock, value);
    notifyListeners();
  }
}
