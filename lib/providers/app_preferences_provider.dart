import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/inventory_sort_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesProvider extends ChangeNotifier {
  static const _kProfitGoal = 'pref_monthly_profit_goal';
  static const _kLowStock = 'pref_low_stock_threshold';
  static const _kLocale = 'pref_locale';
  static const _kThemeMode = 'pref_theme_mode';
  static const _kColorPalette = 'pref_color_palette';
  static const _kRecentSearches = 'recent_searches';
  static const _kInventorySortMode = 'pref_inventory_sort_mode';
  static const _maxRecentSearches = 5;

  static const supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  double _monthlyProfitGoal = 1000;
  int _lowStockThreshold = 5;
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.system;
  AppColorPalette _colorPalette = AppColorPalette.blue;
  InventorySortMode _inventorySortMode = InventorySortMode.criticalFirst;
  bool _ready = false;
  List<String> _recentSearches = [];

  double get monthlyProfitGoal => _monthlyProfitGoal;
  int get lowStockThreshold => _lowStockThreshold;
  Locale? get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  AppColorPalette get colorPalette => _colorPalette;
  InventorySortMode get inventorySortMode => _inventorySortMode;
  bool get isReady => _ready;

  /// Returns the in-memory cached list of recent searches (max 5, newest first).
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  /// Returns true if [s] looks like PII (e-mail, tracking number, phone).
  static bool isPII(String s) {
    if (s.contains('@')) return true;
    if (RegExp(r'\d{8,}').hasMatch(s)) return true;
    if (RegExp(r'^[A-Z0-9]{10,}$').hasMatch(s)) return true;
    return false;
  }

  /// Adds [query] to recent searches, silently skipping PII.
  /// Deduplicates (moves to front) and enforces max-5 FIFO.
  Future<void> addRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    if (isPII(trimmed)) return;
    // Deduplicate: remove existing occurrence so it moves to front.
    _recentSearches.remove(trimmed);
    _recentSearches.insert(0, trimmed);
    if (_recentSearches.length > _maxRecentSearches) {
      _recentSearches = _recentSearches.take(_maxRecentSearches).toList();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentSearches, _recentSearches);
    notifyListeners();
  }

  /// Clears all recent searches (called on sign-out).
  Future<void> clearRecentSearches() async {
    _recentSearches = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentSearches);
    notifyListeners();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _monthlyProfitGoal = prefs.getDouble(_kProfitGoal) ?? 1000;
    _lowStockThreshold = prefs.getInt(_kLowStock) ?? 5;
    final raw = prefs.getString(_kLocale);
    _locale = (raw == null || raw.isEmpty) ? null : Locale(raw);
    final rawTheme = prefs.getString(_kThemeMode);
    _themeMode = switch (rawTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final rawPalette = prefs.getString(_kColorPalette);
    _colorPalette = switch (rawPalette) {
      'indigo' => AppColorPalette.indigo,
      'violet' => AppColorPalette.violet,
      'teal' => AppColorPalette.teal,
      'rose' => AppColorPalette.rose,
      _ => AppColorPalette.blue,
    };
    AppTheme.setActivePalette(_colorPalette);
    _recentSearches = prefs.getStringList(_kRecentSearches) ?? [];
    final rawSort = prefs.getString(_kInventorySortMode);
    _inventorySortMode = _sortModeFromString(rawSort);
    _ready = true;
    notifyListeners();
  }

  static InventorySortMode _sortModeFromString(String? raw) => switch (raw) {
        'nameAsc' => InventorySortMode.nameAsc,
        'stockDesc' => InventorySortMode.stockDesc,
        'stockAsc' => InventorySortMode.stockAsc,
        'valueDesc' => InventorySortMode.valueDesc,
        'criticalFirst' => InventorySortMode.criticalFirst,
        _ => InventorySortMode.criticalFirst,
      };

  Future<void> setInventorySortMode(InventorySortMode mode) async {
    _inventorySortMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kInventorySortMode, mode.name);
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

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_kLocale);
    } else {
      await prefs.setString(_kLocale, locale.languageCode);
    }
    notifyListeners();
  }

  Future<void> setColorPalette(AppColorPalette palette) async {
    _colorPalette = palette;
    AppTheme.setActivePalette(palette);
    final prefs = await SharedPreferences.getInstance();
    final raw = switch (palette) {
      AppColorPalette.indigo => 'indigo',
      AppColorPalette.violet => 'violet',
      AppColorPalette.teal => 'teal',
      AppColorPalette.rose => 'rose',
      AppColorPalette.blue => 'blue',
    };
    await prefs.setString(_kColorPalette, raw);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_kThemeMode, raw);
    notifyListeners();
  }
}
