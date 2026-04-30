// Platform-adaptive URL opener.
// On web: uses dart:js_interop / package:web window.open (guaranteed to work).
// On native: uses url_launcher.
export 'url_helper_stub.dart'
    if (dart.library.html) 'url_helper_web.dart'
    if (dart.library.io) 'url_helper_native.dart';

import 'package:flutter/material.dart';
import 'url_helper_stub.dart'
    if (dart.library.html) 'url_helper_web.dart'
    if (dart.library.io) 'url_helper_native.dart';

/// Opens [url] and shows a snackbar with a copy-link fallback if opening fails.
Future<void> openUrlWithFallback(BuildContext context, String url) async {
  bool success = false;
  try {
    success = await openUrl(url);
  } catch (_) {
    success = false;
  }
  if (!success && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Link konnte nicht geöffnet werden.'),
        action: SnackBarAction(
          label: 'Link kopieren',
          onPressed: () => copyToClipboard(url),
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

