import 'package:flutter/widgets.dart';

/// Gibt eine menschenlesbare relative Zeitangabe zurück.
///
/// Sprache richtet sich nach der aktuellen Locale:
/// - `de` (und alles andere): "jetzt", "vor X min", "vor X h", "vor X d"
/// - `en`: "just now", "X min ago", "X h ago", "X d ago"
///
/// Für ältere Zeitpunkte (≥ 7 Tage) wird das ISO-Datum `YYYY-MM-DD` ausgegeben.
String formatRelativeTime(BuildContext context, DateTime when) {
  final locale = Localizations.localeOf(context).languageCode;
  final delta = DateTime.now().difference(when);

  if (locale == 'en') {
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
    if (delta.inHours < 24) return '${delta.inHours} h ago';
    if (delta.inDays < 7) return '${delta.inDays} d ago';
  } else {
    if (delta.inMinutes < 1) return 'jetzt';
    if (delta.inMinutes < 60) return 'vor ${delta.inMinutes} min';
    if (delta.inHours < 24) return 'vor ${delta.inHours} h';
    if (delta.inDays < 7) return 'vor ${delta.inDays} d';
  }

  // Datum für ältere Einträge
  return '${when.year}-'
      '${when.month.toString().padLeft(2, '0')}-'
      '${when.day.toString().padLeft(2, '0')}';
}
