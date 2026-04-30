import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

Future<bool> openUrl(String url) async {
  final result = web.window.open(url, '_blank', '');
  return result != null;
}

Future<void> copyToClipboard(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}
