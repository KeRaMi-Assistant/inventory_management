import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openUrl(String url) async {
  // Try discord:// deep link first for URLs pointing to discord.com
  if (url.contains('discord.com/channels/')) {
    final discordUri = Uri.tryParse(url.replaceFirst('https://discord.com', 'discord:/'));
    if (discordUri != null && await canLaunchUrl(discordUri)) {
      return launchUrl(discordUri, mode: LaunchMode.externalApplication);
    }
  }
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> copyToClipboard(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}
