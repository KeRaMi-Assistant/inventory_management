import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String?> loadLegacyDataFile() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/inventory_data.json');
    if (!await file.exists()) return null;
    return file.readAsString();
  } catch (_) {
    return null;
  }
}
