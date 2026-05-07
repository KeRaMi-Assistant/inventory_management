import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistiert den gewaehlten ThemeMode (hell / dunkel / system) via SharedPreferences.
class ThemeProvider extends ChangeNotifier {
  static const _kThemeMode = 'pref_theme_mode';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_kThemeMode);
    _mode = raw != null ? ThemeMode.values[raw] : ThemeMode.system;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }
}
