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
      return e.message;
    } catch (e) {
      return 'Anmeldung fehlgeschlagen: $e';
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
      return e.message;
    } catch (e) {
      return 'Registrierung fehlgeschlagen: $e';
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Reset-Link konnte nicht gesendet werden: $e';
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
