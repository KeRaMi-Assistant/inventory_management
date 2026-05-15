// Platform-adaptive URL opener.
// On web: uses dart:js_interop / package:web window.open (guaranteed to work).
// On native: uses url_launcher.
export 'url_helper_stub.dart'
    if (dart.library.html) 'url_helper_web.dart'
    if (dart.library.io) 'url_helper_native.dart';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'url_helper_stub.dart'
    if (dart.library.html) 'url_helper_web.dart'
    if (dart.library.io) 'url_helper_native.dart';

/// Attempts to resolve a proper Discord channel URL from a raw or malformed value.
///
/// Handles:
/// - Already proper `https://discord.com/channels/{server}/{channel}` → returned as-is.
/// - Malformed `https://{digits}` or bare `{digits}` → builds proper URL using [serverIds].
/// - Everything else → returned as-is.
String resolveDiscordUrl(String url, {List<String> serverIds = const []}) {
  if (url.contains('discord.com/channels/')) return url;
  final channelId = RegExp(r'\b(\d{15,21})\b').firstMatch(url)?.group(1);
  final serverId = serverIds.firstOrNull;
  if (channelId != null && serverId != null) {
    return 'https://discord.com/channels/$serverId/$channelId';
  }
  return url;
}

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
        content: Text(AppLocalizations.of(context).urlHelperLinkOpenError),
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

