import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_file_stub.dart'
    if (dart.library.io) 'storage_file_native.dart';

/// Legacy local-only persistence. Kept around solely so that pre-Supabase
/// users can be migrated into their cloud account on first login. New
/// writes go to [SupabaseRepository].
class StorageService {
  static const _key = 'lagerverwaltung_data';

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

  /// Removes the legacy blob — called after a successful cloud migration so
  /// we don't re-import on every login.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
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
