import 'dart:convert';
import 'package:http/http.dart' as http;

class DiscordService {
  static const _base = 'https://discord.com/api/v10';

  /// Builds the Discord OAuth2 authorization URL.
  /// [redirectUri] must be registered in the Discord Developer Portal.
  static String buildOAuthUrl({
    required String clientId,
    required String redirectUri,
  }) {
    final uri = Uri.https('discord.com', '/oauth2/authorize', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'token',
      'scope': 'identify guilds',
      'state': 'popup',
    });
    return uri.toString();
  }

  /// Parses the URL fragment returned by Discord after OAuth2 login.
  /// Returns a map with 'access_token', 'expires_in', etc. or null.
  static Map<String, String>? parseOAuthFragment(String fragment) {
    final clean = fragment.startsWith('#') ? fragment.substring(1) : fragment;
    if (clean.isEmpty) return null;
    final params = Uri.splitQueryString(clean);
    if (!params.containsKey('access_token')) return null;
    return params;
  }

  /// Fetches the Discord username for the logged-in user.
  static Future<String?> getUserName(String accessToken) async {
    try {
      final resp = await http.get(
        Uri.parse('$_base/users/@me'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['global_name'] as String?)?.isNotEmpty == true
            ? data['global_name'] as String
            : data['username'] as String? ?? '';
      }
    } catch (_) {}
    return null;
  }

  /// Searches [guildIds] for a ticket channel matching [ticketNumber].
  /// Runs all guild requests in parallel for speed.
  /// Returns the discord.com channel URL or null if not found.
  static Future<String?> findTicketUrl({
    required String accessToken,
    required List<String> guildIds,
    required String ticketNumber,
  }) async {
    if (accessToken.trim().isEmpty) return null;

    final clean = ticketNumber.trim().toLowerCase();
    if (clean.isEmpty) return null;

    // ignore: avoid_print
    print('[Discord] findTicketUrl ticket="$clean" guilds=$guildIds');

    // Extract trailing digits (e.g. "drittserver-14502" → 14502)
    final digits = RegExp(r'\d+').allMatches(clean).lastOrNull?.group(0);
    final num = digits != null ? int.tryParse(digits) : null;
    // ignore: avoid_print
    print('[Discord] extracted digits=$digits, num=$num');

    // Search all guilds in parallel
    final futures = guildIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .map((guildId) => _searchGuild(accessToken, guildId, clean, num))
        .toList();

    if (futures.isEmpty) return null;

    // Return first non-null result (hard cap: 5 s total)
    final results = await Future.wait(futures, eagerError: false)
        .timeout(const Duration(seconds: 5), onTimeout: () => List.filled(futures.length, null));
    for (final r in results) {
      if (r != null) return r;
    }
    return null;
  }

  static Future<String?> _searchGuild(
    String accessToken,
    String guildId,
    String ticketText,
    int? ticketNum,
  ) async {
    try {
      final uri = Uri.parse('$_base/guilds/$guildId/channels');
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $accessToken',
      }).timeout(const Duration(seconds: 4));

      // ignore: avoid_print
      print('[Discord] guild $guildId → HTTP ${resp.statusCode}');

      if (resp.statusCode != 200) {
        // ignore: avoid_print
        print('[Discord] guild $guildId Fehler: ${resp.body}');
        return null;
      }

      final channels = jsonDecode(resp.body) as List<dynamic>;
      // ignore: avoid_print
      print('[Discord] guild $guildId → ${channels.length} channels gefunden:');
      for (final ch in channels) {
        final name = (ch['name'] as String? ?? '');
        // ignore: avoid_print
        print('  - "$name" (id=${ch['id']}, type=${ch['type']})');
        if (_matchesTicket(name.toLowerCase(), ticketText, ticketNum)) {
          final channelId = ch['id'] as String;
          final url = 'https://discord.com/channels/$guildId/$channelId';
          // ignore: avoid_print
          print('[Discord] ✓ MATCH: "$name" → $url');
          return url;
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[Discord] guild $guildId error: $e');
    }
    return null;
  }

  /// Returns true if [channelName] matches the ticket.
  /// Matches:
  ///   - exact/contains full ticket text ("drittserver-14502" in name)
  ///   - channel starts with "ticket" and contains the trailing number
  static bool _matchesTicket(String channelName, String ticketText, int? ticketNum) {
    // Full text match (e.g. channel "drittserver-14502" for ticket "drittserver-14502")
    if (channelName.contains(ticketText)) return true;

    // Number-only match for "ticket-…" channels (e.g. "ticket-14502" for ticket "14502" or "drittserver-14502")
    if (ticketNum != null && channelName.startsWith('ticket')) {
      final matches = RegExp(r'\d+').allMatches(channelName);
      for (final m in matches) {
        if (int.tryParse(m.group(0)!) == ticketNum) return true;
      }
    }
    return false;
  }
}
