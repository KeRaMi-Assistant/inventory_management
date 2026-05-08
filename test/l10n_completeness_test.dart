import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ARB symmetry', () {
    final deArb =
        jsonDecode(File('lib/l10n/app_de.arb').readAsStringSync()) as Map;
    final enArb =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;

    Set<String> nonMetaKeys(Map m) =>
        m.keys.cast<String>().where((k) => !k.startsWith('@')).toSet();

    test('DE and EN ARB files have identical key sets', () {
      final de = nonMetaKeys(deArb);
      final en = nonMetaKeys(enArb);
      expect(en.difference(de), isEmpty,
          reason: 'Keys present in EN but missing in DE');
      expect(de.difference(en), isEmpty,
          reason: 'Keys present in DE but missing in EN');
    });

    test('No EN value contains German umlauts (likely untranslated)', () {
      final umlautRe = RegExp(r'[äöüÄÖÜß]');
      final hits = <String, String>{};
      for (final entry in enArb.entries) {
        final k = entry.key as String;
        if (k.startsWith('@')) continue;
        final v = entry.value;
        if (v is! String) continue;
        if (umlautRe.hasMatch(v)) hits[k] = v;
      }
      expect(hits, isEmpty,
          reason: 'EN values still contain umlauts: $hits');
    });

    test('At least 5 ICU plural keys exist', () {
      int pluralCount(Map m) => m.values
          .whereType<String>()
          .where((v) => v.contains('plural'))
          .length;
      expect(pluralCount(enArb), greaterThanOrEqualTo(5));
      expect(pluralCount(deArb), greaterThanOrEqualTo(5));
    });

    test('Placeholders metadata is symmetric for keyed values', () {
      // For every @key entry in EN, DE must have the same.
      for (final k in enArb.keys.cast<String>().where((k) => k.startsWith('@'))) {
        if (k == '@@locale') continue;
        expect(deArb.containsKey(k), isTrue,
            reason: 'Missing metadata key $k in DE');
      }
      for (final k in deArb.keys.cast<String>().where((k) => k.startsWith('@'))) {
        if (k == '@@locale') continue;
        expect(enArb.containsKey(k), isTrue,
            reason: 'Missing metadata key $k in EN');
      }
    });
  });

  group('Generated AppLocalizations sources exist', () {
    test('app_localizations_de.dart and app_localizations_en.dart present', () {
      expect(File('lib/l10n/app_localizations_de.dart').existsSync(), isTrue);
      expect(File('lib/l10n/app_localizations_en.dart').existsSync(), isTrue);
    });

    test('AppLocalizations.dart contains both locale supportedLocales', () {
      final src =
          File('lib/l10n/app_localizations.dart').readAsStringSync();
      expect(src.contains("Locale('de')"), isTrue);
      expect(src.contains("Locale('en')"), isTrue);
    });
  });
}
