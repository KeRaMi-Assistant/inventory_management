import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_file_stub.dart'
    if (dart.library.io) 'storage_file_native.dart';

class StorageService {
  static const _key = 'lagerverwaltung_data';

  Future<void> saveData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }

  Future<Map<String, dynamic>?> loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final content = prefs.getString(_key);
      if (content == null) {
        final legacyContent = await loadLegacyDataFile();
        if (legacyContent == null || legacyContent.isEmpty) return null;
        final data = jsonDecode(legacyContent) as Map<String, dynamic>;
        await prefs.setString(_key, jsonEncode(data));
        return data;
      }
      if (content.isEmpty) return null;
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String> exportJson(Map<String, dynamic> data) async {
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Map<String, dynamic>? parseJsonBackup(String content) {
    try {
      final data = jsonDecode(content);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }
}
