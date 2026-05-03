import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps `Supabase.instance.client.auth` in a ChangeNotifier so the rest of
/// the app can react to sign-in / sign-out without depending on the SDK
/// directly.
class AuthProvider extends ChangeNotifier {
  AuthProvider({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client {
    _authSub = _client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _authSub;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  bool get isLoggedIn => currentUser != null;
  String? get userEmail => currentUser?.email;

  /// Returns `null` on success or a human-readable error otherwise.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return _humanizeAuthError(e);
    } catch (e) {
      return 'Anmeldung fehlgeschlagen. Bitte Internetverbindung prüfen.';
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      // If "Confirm email" is enabled in Supabase, signUp returns a user
      // without an active session. Surface that as a hint, not an error.
      if (res.session == null && res.user != null) {
        return 'Bitte bestätige zuerst deine E-Mail-Adresse.';
      }
      return null;
    } on AuthException catch (e) {
      return _humanizeAuthError(e);
    } catch (e) {
      return 'Registrierung fehlgeschlagen. Bitte Internetverbindung prüfen.';
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
      return null;
    } on AuthException catch (e) {
      return _humanizeAuthError(e);
    } catch (e) {
      return 'Reset-Link konnte nicht gesendet werden.';
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Aktualisiert das aktuelle Session-Token. Wird vom SessionManager
  /// genutzt, um Ablauf-Banner-Aktion und proaktives Refreshing zu ermöglichen.
  Future<bool> refreshSession() async {
    try {
      await _client.auth.refreshSession();
      return _client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  /// Wandelt Supabase-Fehler in deutschsprachige, benutzerfreundliche Texte.
  static String _humanizeAuthError(AuthException e) {
    final raw = e.message.toLowerCase();
    final code = e.statusCode;

    if (code == '429' ||
        raw.contains('rate limit') ||
        raw.contains('too many')) {
      return 'Zu viele Versuche. Bitte in 15 Minuten erneut probieren.';
    }
    if (raw.contains('invalid login credentials') ||
        raw.contains('invalid_credentials')) {
      return 'E-Mail oder Passwort ist falsch.';
    }
    if (raw.contains('email not confirmed')) {
      return 'Bitte bestätige zuerst deine E-Mail-Adresse.';
    }
    if (raw.contains('user already registered') ||
        raw.contains('already been registered')) {
      return 'Es existiert bereits ein Konto mit dieser E-Mail.';
    }
    if (raw.contains('password should be at least')) {
      return 'Passwort ist zu kurz.';
    }
    if (raw.contains('weak password') ||
        raw.contains('password is too weak')) {
      return 'Passwort ist zu schwach. Bitte stärkeres Passwort wählen.';
    }
    if (raw.contains('network') || raw.contains('failed host lookup')) {
      return 'Keine Verbindung. Internetverbindung prüfen.';
    }
    if (raw.contains('user not found')) {
      return 'Kein Konto mit dieser E-Mail gefunden.';
    }
    if (raw.contains('signups not allowed') ||
        raw.contains('signup is disabled')) {
      return 'Registrierung ist derzeit deaktiviert.';
    }
    // Fallback: Originaltext, falls nicht gemappt.
    return e.message;
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
