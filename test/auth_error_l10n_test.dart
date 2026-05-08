import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inventory_management/l10n/app_localizations.dart';
import 'package:inventory_management/utils/auth_error_l10n.dart';

void main() {
  Future<AppLocalizations> load(Locale locale) =>
      AppLocalizations.delegate.load(locale);

  group('localizeAuthError', () {
    for (final locale in [const Locale('de'), const Locale('en')]) {
      for (final code in AuthErrorCode.values) {
        test('${locale.languageCode} / ${code.name} returns non-empty', () async {
          final l10n = await load(locale);
          final err = code == AuthErrorCode.providerLoginFailed
              ? const AuthError.code(AuthErrorCode.providerLoginFailed,
                  providerLabel: 'Google')
              : AuthError.code(code);
          final msg = localizeAuthError(l10n, err);
          expect(msg, isNotEmpty);
        });
      }
    }

    test('providerLoginFailed includes provider label', () async {
      final en = await load(const Locale('en'));
      final de = await load(const Locale('de'));
      const apple = AuthError.code(AuthErrorCode.providerLoginFailed,
          providerLabel: 'Apple');
      expect(localizeAuthError(en, apple), contains('Apple'));
      expect(localizeAuthError(de, apple), contains('Apple'));
    });

    test('raw passthrough returns the message', () async {
      final en = await load(const Locale('en'));
      const raw = 'Too many requests';
      const err = AuthError.raw(raw);
      expect(localizeAuthError(en, err), raw);
    });

    test('isConfirmEmail flag is true only for confirmEmailFirst', () {
      expect(const AuthError.code(AuthErrorCode.confirmEmailFirst).isConfirmEmail,
          isTrue);
      expect(const AuthError.code(AuthErrorCode.loginNetworkError).isConfirmEmail,
          isFalse);
      expect(const AuthError.raw('foo').isConfirmEmail, isFalse);
    });
  });
}
