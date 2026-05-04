import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps `Supabase.instance.client.auth` in a ChangeNotifier so the rest of
/// the app can react to sign-in / sign-out without depending on the SDK
/// directly.
class AuthProvider extends ChangeNotifier {
  AuthProvider({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client {
    _authSub = _client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _passwordRecoveryController.add(true);
      }
      notifyListeners();
    });
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _authSub;

  /// Emit `true` whenever Supabase signals an `AuthChangeEvent.passwordRecovery`
  /// (Deep-Link nach Passwort-Reset-E-Mail). Die App routet dann zum
  /// ResetPasswordScreen.
  final StreamController<bool> _passwordRecoveryController =
      StreamController<bool>.broadcast();
  Stream<bool> get passwordRecoveryStream =>
      _passwordRecoveryController.stream;

  bool _busy = false;
  bool get isBusy => _busy;

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

  /// Prüft, ob der aktuell eingeloggte User Mitglied im angegebenen
  /// Workspace ist. Liefert `true` falls ja. Wird vom Team-Login-Flow
  /// nach dem normalen `signIn` aufgerufen.
  Future<bool> isMemberOfWorkspace(String workspaceId) async {
    final uid = currentUser?.id;
    if (uid == null) return false;
    try {
      final rows = await _client
          .from('workspace_members')
          .select('user_id')
          .eq('workspace_id', workspaceId)
          .eq('user_id', uid)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
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
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: _resetRedirectUrl,
      );
      return null;
    } on AuthException catch (e) {
      return _humanizeAuthError(e);
    } catch (e) {
      return 'Reset-Link konnte nicht gesendet werden.';
    }
  }

  /// Setzt das Passwort des aktuell eingeloggten Users (i.d.R. nach
  /// passwordRecovery-Deep-Link).
  Future<String?> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      return _humanizeAuthError(e);
    } catch (_) {
      return 'Passwort konnte nicht geändert werden.';
    }
  }

  /// Schickt die Bestätigungsmail erneut.
  Future<String?> resendConfirmation(String email) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
      return null;
    } on AuthException catch (e) {
      return _humanizeAuthError(e);
    } catch (_) {
      return 'E-Mail konnte nicht erneut gesendet werden.';
    }
  }

  // ── OAuth ────────────────────────────────────────────────────────────────

  Future<String?> signInWithGoogle() async {
    return _oauth(OAuthProvider.google);
  }

  Future<String?> signInWithApple() async {
    return _oauth(OAuthProvider.apple);
  }

  Future<String?> _oauth(OAuthProvider provider) async {
    _busy = true;
    notifyListeners();
    try {
      await _client.auth.signInWithOAuth(
        provider,
        redirectTo: _oauthRedirectUrl,
      );
      return null;
    } on AuthException catch (e) {
      return _humanizeAuthError(e);
    } catch (e) {
      return 'Anmeldung mit ${_providerLabel(provider)} fehlgeschlagen.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  static String _providerLabel(OAuthProvider p) {
    switch (p) {
      case OAuthProvider.google:
        return 'Google';
      case OAuthProvider.apple:
        return 'Apple';
      default:
        return p.name;
    }
  }

  /// Web nutzt den tatsächlichen Browser-Origin als Callback (egal welcher
  /// Port `flutter run` zufällig vergibt), Mobile den registrierten Deep-Link.
  /// **Wichtig:** Im Supabase-Dashboard muss unter
  /// `Authentication → URL Configuration → Redirect URLs` ein Eintrag wie
  /// `http://localhost:*` (oder konkrete Ports) auf der Allow-List stehen,
  /// sonst lehnt Supabase den dynamischen Redirect ab.
  String? get _oauthRedirectUrl {
    if (kIsWeb) return Uri.base.origin;
    return 'inventorymanagement://auth/callback';
  }

  String? get _resetRedirectUrl {
    if (kIsWeb) return Uri.base.origin;
    return 'inventorymanagement://auth/reset';
  }

  /// True, wenn die Plattform Apple-Sign-In sinnvoll anzeigen kann.
  bool get appleSignInAvailable {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Löscht den Account vollständig via Edge Function (nutzt service_role intern).
  /// Gibt `null` bei Erfolg zurück, sonst eine Fehlermeldung.
  Future<String?> deleteAccount() async {
    try {
      final response = await _client.functions.invoke('delete-account');
      if (response.status != 200) {
        return 'Konto konnte nicht gelöscht werden.';
      }
      await _client.auth.signOut();
      return null;
    } on AuthException catch (e) {
      return _humanizeAuthError(e);
    } catch (_) {
      return 'Konto konnte nicht gelöscht werden. Bitte Internetverbindung prüfen.';
    }
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
    if (raw.contains('provider is not enabled')) {
      return 'Dieser Anmeldeweg ist im Backend nicht aktiviert.';
    }
    return e.message;
  }

  @override
  void dispose() {
    _authSub.cancel();
    _passwordRecoveryController.close();
    super.dispose();
  }
}
