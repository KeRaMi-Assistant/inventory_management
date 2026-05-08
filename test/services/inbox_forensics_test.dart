import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Validiert die Forensik-Fixtures unter `test/fixtures/forensics/`.
///
/// Die eigentliche HTML-Pattern-Extraktion läuft in Deno
/// (`supabase/functions/_shared/inbox_forensics_test.ts`); diese Tests
/// stellen nur sicher, dass:
///   1. Pro Shop ≥ 1 Fixture vorhanden ist.
///   2. Jede Fixture nicht-leer (≥ 100 bytes) ist.
///   3. Keine PII-Smells (echte Email-Adressen, Telefonnummern,
///      Nicht-redacted Vor-/Nachnamen) im File stecken.
void main() {
  group('Inbox Forensics Fixtures', () {
    late Directory baseDir;

    setUpAll(() {
      baseDir = Directory('test/fixtures/forensics');
      expect(baseDir.existsSync(), isTrue,
          reason: 'test/fixtures/forensics/ muss existieren');
    });

    test('Alle 15 Forensik-Shops haben mind. 1 .html-Fixture', () {
      const shops = [
        'amazon', 'mediamarkt', 'saturn', 'pccomponentes', 'kaufland',
        'xkom', 'lego', 'tink', 'anker', 'euronics',
        'dell', 'galaxus', 'alza', 'ebay', 'xxxlutz',
      ];
      for (final shop in shops) {
        final shopDir = Directory('${baseDir.path}/$shop');
        expect(shopDir.existsSync(), isTrue,
            reason: 'Shop-Dir fehlt: $shop');
        final htmls = shopDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.html'))
            .toList();
        expect(htmls.isNotEmpty, isTrue,
            reason: 'Shop $shop hat keine .html-Fixtures');
      }
    });

    test('Keine Fixture ist leer (≥ 100 bytes)', () {
      final files = Directory(baseDir.path)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.html'))
          .toList();
      expect(files.length, greaterThanOrEqualTo(30),
          reason: 'Erwartet ≥ 30 Fixtures, gefunden ${files.length}');
      for (final f in files) {
        expect(f.lengthSync(), greaterThanOrEqualTo(100),
            reason: '${f.path}: zu klein/leer');
      }
    });

    test('Keine PII-Smells in Fixtures (echte Mail-Adressen, Telefon-Nrn)', () {
      // Whitelisted-Test-Markers — wenn die im File stehen, ist Redaction
      // korrekt erfolgt. Echte Mail-Adressen, Telefon-Nrn oder echte
      // Vor-/Nachnamen würden hier als PII-Smell flaggen.
      final files = Directory(baseDir.path)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.html'));
      final patternsForbidden = <RegExp>[
        // Telefon-Nummern (10+ Ziffern in Folge oder mit Trennern).
        RegExp(r'\bTel\.?\s*:?\s*[\d/\-\s+()]{8,18}\d'),
        // Email-Adressen außerhalb example.test/example.com-Whitelist.
        RegExp(r'[\w.+-]+@(?!example\.(?:test|com)\b)[\w-]+\.[a-z]{2,}',
            caseSensitive: false),
        // Hilgenkamp ist die echte Adresse aus den DB-Samples — darf
        // NICHT in Fixtures landen.
        RegExp(r'Hilgenkamp', caseSensitive: false),
        // Wolfsburg darf nur in der placebo-Adresse vorkommen, nicht
        // pur als Stadt.
        RegExp(r'\b38442\s+Wolfsburg\b', caseSensitive: false),
      ];
      for (final f in files) {
        final content = f.readAsStringSync();
        for (final p in patternsForbidden) {
          expect(p.hasMatch(content), isFalse,
              reason: '${f.path}: PII-Smell durch Pattern $p');
        }
      }
    });

    test('Mindestens 12 Forensik-Memos in docs/inbox-forensics/', () {
      final memoDir = Directory('docs/inbox-forensics');
      expect(memoDir.existsSync(), isTrue);
      final memos = memoDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md') && !f.path.endsWith('README.md'))
          .toList();
      expect(memos.length, greaterThanOrEqualTo(12),
          reason: 'Erwartet ≥ 12 Memos, gefunden ${memos.length}');
    });

    test('Jede Memo hat ≥ 60 Zeilen Content', () {
      final memos = Directory('docs/inbox-forensics')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md') && !f.path.endsWith('README.md'));
      for (final m in memos) {
        final lines = m.readAsLinesSync();
        expect(lines.length, greaterThanOrEqualTo(60),
            reason: '${m.path}: nur ${lines.length} Zeilen');
      }
    });
  });
}
