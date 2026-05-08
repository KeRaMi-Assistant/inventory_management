import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inventory_management/l10n/app_localizations.dart';
import 'package:inventory_management/models/billing_profile.dart';
import 'package:inventory_management/utils/pricing_plan_l10n.dart';

Future<AppLocalizations> _loadLocalizations(Locale locale) async {
  return AppLocalizations.delegate.load(locale);
}

void main() {
  group('localizePricingTagline', () {
    for (final locale in [const Locale('de'), const Locale('en')]) {
      for (final plan in BillingPlan.values) {
        test('${locale.languageCode} / ${plan.name} returns non-empty', () async {
          final l10n = await _loadLocalizations(locale);
          final value = localizePricingTagline(l10n, plan);
          expect(value, isNotEmpty);
        });
      }
    }
  });

  group('localizePricingHighlights', () {
    for (final locale in [const Locale('de'), const Locale('en')]) {
      for (final plan in BillingPlan.values) {
        test('${locale.languageCode} / ${plan.name} has at least 5 highlights',
            () async {
          final l10n = await _loadLocalizations(locale);
          final highlights = localizePricingHighlights(l10n, plan);
          expect(highlights.length, greaterThanOrEqualTo(5));
          expect(highlights.every((h) => h.isNotEmpty), isTrue);
        });
      }
    }
  });

  test('Free plan EN highlights do not contain umlauts', () async {
    final l10n = await _loadLocalizations(const Locale('en'));
    final highlights = localizePricingHighlights(l10n, BillingPlan.free);
    final umlautRe = RegExp(r'[äöüÄÖÜß]');
    for (final h in highlights) {
      expect(umlautRe.hasMatch(h), isFalse,
          reason: 'EN highlight contains umlaut: $h');
    }
  });

  test('DE and EN return different (translated) taglines', () async {
    final de = await _loadLocalizations(const Locale('de'));
    final en = await _loadLocalizations(const Locale('en'));
    for (final plan in BillingPlan.values) {
      final deTag = localizePricingTagline(de, plan);
      final enTag = localizePricingTagline(en, plan);
      expect(deTag, isNot(equals(enTag)),
          reason: 'Tagline for ${plan.name} is identical in DE and EN');
    }
  });
}
