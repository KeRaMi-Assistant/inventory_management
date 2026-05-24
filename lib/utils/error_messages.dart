/// Zentrale Sanitisierungs-Hilfsfunktion für Fehlermeldungen.
///
/// Wandelt rohe Exception-Objekte in User-freundliche, lokalisierte Strings
/// um. Postgres-Stack-Traces und interne Supabase-Fehlercodes werden niemals
/// direkt an den User durchgereicht.
///
/// Verwendung:
/// ```dart
/// } catch (e) {
///   AppFeedback.error(context, sanitizeError(e, l10n: l10n));
/// }
/// ```
library;

import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, AuthException;

import '../l10n/app_localizations.dart';

/// Wandelt [error] in eine User-freundliche Fehlermeldung um.
///
/// Reihenfolge der Prüfungen:
/// 1. [PostgrestException] → nur `message`-Field des Fehlers, nie Code/Hint
/// 2. [SocketException] → Offline-Meldung
/// 3. [TimeoutException] → Timeout-Meldung
/// 4. [AuthException] → Anmeldung abgelaufen
/// 5. [FormatException] → Ungültiges Datenformat
/// 6. Sonst → [fallback] ?? `l10n.errorUnknown`
///
/// [l10n] ist optional. Wenn nicht übergeben, werden fest kodierte
/// Strings als Fallback verwendet (z. B. bei Provider-Layer-Aufruf ohne
/// BuildContext). In UI-Layern immer [l10n] übergeben.
///
/// [fallback] überschreibt den generischen „Unbekannter Fehler"-String
/// für Stellen, die einen kontextspezifischen Fehlertext benötigen.
String sanitizeError(
  Object error, {
  AppLocalizations? l10n,
  String? fallback,
}) {
  if (error is PostgrestException) {
    // message-Field enthält die DB-seitige Fehlermeldung (oft bereits
    // englisch und verständlich), aber nie Postgres-Stack-Traces.
    final msg = error.message.trim();
    if (msg.isNotEmpty) return msg;
    return fallback ?? l10n?.errorUnknown ?? _kErrorUnknown;
  }

  if (error is SocketException) {
    return l10n?.errorNetworkOffline ?? _kErrorNetworkOffline;
  }

  if (error is TimeoutException) {
    return l10n?.errorTimeout ?? _kErrorTimeout;
  }

  if (error is AuthException) {
    return l10n?.errorAuthExpired ?? _kErrorAuthExpired;
  }

  if (error is FormatException) {
    return l10n?.errorFormatInvalid ?? _kErrorFormatInvalid;
  }

  return fallback ?? l10n?.errorUnknown ?? _kErrorUnknown;
}

// ── Fallback-Strings (ohne l10n-Kontext, z. B. im Provider-Layer) ────────────
// Diese werden nur verwendet wenn kein [l10n]-Objekt übergeben wird.
// Sie sind bewusst auf Deutsch, da das die App-Standardsprache ist.

const String _kErrorNetworkOffline =
    'Keine Internetverbindung. Bitte prüfe deine Verbindung.';
const String _kErrorTimeout = 'Zeitüberschreitung. Bitte erneut versuchen.';
const String _kErrorAuthExpired =
    'Anmeldung abgelaufen. Bitte erneut anmelden.';
const String _kErrorFormatInvalid = 'Ungültiges Datenformat.';
const String _kErrorUnknown = 'Ein unbekannter Fehler ist aufgetreten.';
