import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/auth_error_l10n.dart';

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

  /// Returns `null` on success or a structured [AuthError] otherwise.
  /// The UI maps the error to a localized string via `localizeAuthError`.
  Future<AuthError?> signIn({
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
    } catch (_) {
      return const AuthError.code(AuthErrorCode.loginNetworkError);
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

  Future<AuthError?> signUp({
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
        return const AuthError.code(AuthErrorCode.confirmEmailFirst);
      }
      return null;
    } on AuthException catch (e) {
      return _humanizeAuthError(e);
    } catch (_) {
      return const AuthError.code(AuthErrorCode.registerNetworkError);
    }
  }

  Future<AuthError?> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: _resetRedirectUrl,
      );
      return null;
    } on AuthException catch (e) {
      return _humanizeAuthError(e);
    } catch (_) {
      return const AuthError.code(AuthErrorCode.resetLinkFailed);
    }
  }

  /// Setzt das Passwort des aktuell eingeloggten Users (i.d.R. nach
  /// passwordRecovery-Deep-Link).
  Future<AuthError?> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      return _humanizeAuthError(e);
    } catch (_) {
      return const AuthError.code(AuthErrorCode.passwordChangeFailed);
    }
  }

  /// Schickt die Bestätigungsmail erneut.
  Future<AuthError?> resendConfirmation(String email) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
      return null;
    } on AuthException catch (e) {
      return _humanizeAuthError(e);
    } catch (_) {
      return const AuthError.code(AuthErrorCode.resendFailed);
    }
  }

  // ── OAuth ────────────────────────────────────────────────────────────────

  Future<AuthError?> signInWithGoogle() async {
    return _oauth(OAuthProvider.google);
  }

  Future<AuthError?> signInWithApple() async {
    return _oauth(OAuthProvider.apple);
  }

  Future<AuthError?> _oauth(OAuthProvider provider) async {
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
    } catch (_) {
      return AuthError.code(
        AuthErrorCode.providerLoginFailed,
        providerLabel: _providerLabel(provider),
      );
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
  /// Gibt `null` bei Erfolg zurück, sonst eine [AuthError]-Beschreibung.
  Future<AuthError?> deleteAccount() async {
    try {
      final response = await _client.functions.invoke('delete-account');
      if (response.status != 200) {
        return const AuthError.code(AuthErrorCode.deleteAccountFailed);
      }
      await _client.auth.signOut();
      return null;
    } on AuthException catch (e) {
      return _humanizeAuthError(e);
    } catch (_) {
      return const AuthError.code(AuthErrorCode.deleteAccountNetworkError);
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

  /// Mappt Supabase-`AuthException`s auf strukturierte [AuthError]-Codes.
  /// Für Fehler ohne dedizierten i18n-Schlüssel (z.B. Rate-Limit,
  /// "already registered") wird die rohe `AuthException.message` (englisch)
  /// als Passthrough zurückgegeben — besser als eine irreführende
  /// Übersetzung.
  static AuthError _humanizeAuthError(AuthException e) {
    final raw = e.message.toLowerCase();
    final code = e.statusCode;

    if (code == '429' ||
        raw.contains('rate limit') ||
        raw.contains('too many')) {
      // No dedicated l10n key for rate-limit yet — pass through.
      return AuthError.raw(e.message);
    }
    if (raw.contains('invalid login credentials') ||
        raw.contains('invalid_credentials')) {
      return const AuthError.code(AuthErrorCode.emailOrPasswordWrong);
    }
    if (raw.contains('email not confirmed')) {
      return const AuthError.code(AuthErrorCode.confirmEmailFirst);
    }
    if (raw.contains('user already registered') ||
        raw.contains('already been registered')) {
      // No dedicated l10n key yet — pass through Supabase message.
      return AuthError.raw(e.message);
    }
    if (raw.contains('password should be at least')) {
      // No dedicated "too short" key — fall back to "too weak", which is
      // semantically the closest existing message.
      return const AuthError.code(AuthErrorCode.passwordTooWeak);
    }
    if (raw.contains('weak password') ||
        raw.contains('password is too weak')) {
      return const AuthError.code(AuthErrorCode.passwordTooWeak);
    }
    if (raw.contains('network') || raw.contains('failed host lookup')) {
      return const AuthError.code(AuthErrorCode.noConnection);
    }
    if (raw.contains('user not found')) {
      return const AuthError.code(AuthErrorCode.noAccountForEmail);
    }
    if (raw.contains('signups not allowed') ||
        raw.contains('signup is disabled')) {
      return const AuthError.code(AuthErrorCode.registrationDisabled);
    }
    if (raw.contains('provider is not enabled')) {
      return const AuthError.code(AuthErrorCode.providerNotEnabled);
    }
    return AuthError.raw(e.message);
  }

  @override
  void dispose() {
    _authSub.cancel();
    _passwordRecoveryController.close();
    super.dispose();
  }
}
