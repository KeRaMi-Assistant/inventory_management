import '../l10n/app_localizations.dart';

/// Stable identifiers for user-facing auth-flow errors. Provider returns one
/// of these so the UI can render the localized string for the active locale.
enum AuthErrorCode {
  /// Generic network failure during sign-in (catch-all from `signIn`).
  loginNetworkError,

  /// Sign-up succeeded but user must confirm email (no active session).
  /// Also returned when Supabase reports `email not confirmed`.
  confirmEmailFirst,

  /// Generic network failure during sign-up.
  registerNetworkError,

  /// Password-reset mail could not be sent (catch-all).
  resetLinkFailed,

  /// `updatePassword` failed (catch-all).
  passwordChangeFailed,

  /// `resendConfirmation` failed (catch-all).
  resendFailed,

  /// `deleteAccount` Edge-Function returned non-200 / AuthException.
  deleteAccountFailed,

  /// `deleteAccount` failed before reaching the Edge Function (network).
  deleteAccountNetworkError,

  /// Supabase: `invalid login credentials` / `invalid_credentials`.
  emailOrPasswordWrong,

  /// Supabase: `weak password` / `password is too weak`
  /// or `password should be at least N characters` (mapped to "too weak").
  passwordTooWeak,

  /// Supabase: network / failed host lookup.
  noConnection,

  /// Supabase: `user not found`.
  noAccountForEmail,

  /// Supabase: `signups not allowed` / `signup is disabled`.
  registrationDisabled,

  /// Supabase: `provider is not enabled`.
  providerNotEnabled,

  /// OAuth-Provider sign-in failed (catch-all). Carries the provider label
  /// (`Google`, `Apple`, …) in [AuthError.providerLabel].
  providerLoginFailed,
}

/// Result type for `AuthProvider`-Methoden. Either a known [code] or — wenn
/// Supabase einen Fehler liefert, für den noch keine i18n-Übersetzung
/// existiert — ein [rawMessage]-Passthrough.
class AuthError {
  final AuthErrorCode? code;
  final String? rawMessage;
  final String? providerLabel;

  const AuthError.code(AuthErrorCode this.code, {this.providerLabel})
      : rawMessage = null;

  const AuthError.raw(String this.rawMessage)
      : code = null,
        providerLabel = null;

  /// True if this error indicates that the user still has to confirm their
  /// email before continuing. Used by the register screen to route to the
  /// `VerifyEmailScreen` instead of showing a snackbar.
  bool get isConfirmEmail => code == AuthErrorCode.confirmEmailFirst;
}

/// Maps an [AuthError] to a localized, user-facing message.
String localizeAuthError(AppLocalizations l10n, AuthError error) {
  final code = error.code;
  if (code == null) {
    // Unknown Supabase error — pass through the raw message (English from
    // Supabase). Better than a misleading translation.
    return error.rawMessage ?? '';
  }
  switch (code) {
    case AuthErrorCode.loginNetworkError:
      return l10n.authLoginNetworkError;
    case AuthErrorCode.confirmEmailFirst:
      return l10n.authConfirmEmailFirst;
    case AuthErrorCode.registerNetworkError:
      return l10n.authRegisterNetworkError;
    case AuthErrorCode.resetLinkFailed:
      return l10n.authResetLinkFailed;
    case AuthErrorCode.passwordChangeFailed:
      return l10n.authPasswordChangeFailed;
    case AuthErrorCode.resendFailed:
      return l10n.authResendFailed;
    case AuthErrorCode.deleteAccountFailed:
      return l10n.authDeleteAccountFailed;
    case AuthErrorCode.deleteAccountNetworkError:
      return l10n.authDeleteAccountNetworkError;
    case AuthErrorCode.emailOrPasswordWrong:
      return l10n.authEmailOrPasswordWrong;
    case AuthErrorCode.passwordTooWeak:
      return l10n.authPasswordTooWeak;
    case AuthErrorCode.noConnection:
      return l10n.authNoConnection;
    case AuthErrorCode.noAccountForEmail:
      return l10n.authNoAccountForEmail;
    case AuthErrorCode.registrationDisabled:
      return l10n.authRegistrationDisabled;
    case AuthErrorCode.providerNotEnabled:
      return l10n.authProviderNotEnabled;
    case AuthErrorCode.providerLoginFailed:
      return l10n.authProviderLoginFailed(error.providerLabel ?? '');
  }
}
