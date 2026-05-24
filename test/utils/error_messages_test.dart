import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, AuthException;

import 'package:inventory_management/utils/error_messages.dart';

// ---------------------------------------------------------------------------
// error_messages_test.dart
//
// Testet alle 6 Branches der sanitizeError()-Funktion in
// lib/utils/error_messages.dart.
//
// Alle Tests laufen ohne l10n-Kontext (kein BuildContext nötig). Die
// Fallback-Strings (_k*-Konstanten) werden verifiziert. In echter UI wird
// l10n übergeben, das ist ein separater Integrationstest-Scope.
//
// Siehe Plan plans/2026-05-24_ui-ux-value-uplift.md Task C4.
// ---------------------------------------------------------------------------

void main() {
  group('sanitizeError', () {
    // ── Branch 1: PostgrestException ────────────────────────────────────────

    test('PostgrestException mit nicht-leerem message gibt message zurück',
        () {
      final e = PostgrestException(message: 'duplicate key value violates unique constraint');
      final result = sanitizeError(e);
      expect(result, 'duplicate key value violates unique constraint');
    });

    test('PostgrestException mit leerem message gibt errorUnknown zurück', () {
      final e = PostgrestException(message: '');
      final result = sanitizeError(e);
      expect(result, 'Ein unbekannter Fehler ist aufgetreten.');
    });

    test('PostgrestException mit leerem message gibt fallback zurück wenn angegeben',
        () {
      final e = PostgrestException(message: '');
      final result = sanitizeError(e, fallback: 'Mein Kontext-Fehler');
      expect(result, 'Mein Kontext-Fehler');
    });

    test('PostgrestException enthält keinen Stack-Trace im Rückgabewert', () {
      // Simuliert eine Exception mit hint/details die nie an den User soll.
      final e = PostgrestException(
        message: 'row-level security violation',
        hint: 'Table: deals; RLS policy "workspace_isolation"',
        details: 'Internal stack trace...',
        code: '42501',
      );
      final result = sanitizeError(e);
      expect(result, 'row-level security violation');
      // hint, details und code dürfen NICHT im Output auftauchen
      expect(result, isNot(contains('42501')));
      expect(result, isNot(contains('stack trace')));
      expect(result, isNot(contains('workspace_isolation')));
    });

    // ── Branch 2: SocketException ────────────────────────────────────────────

    test('SocketException gibt Offline-Meldung zurück', () {
      final e = SocketException('Connection refused');
      final result = sanitizeError(e);
      expect(result, 'Keine Internetverbindung. Bitte prüfe deine Verbindung.');
    });

    test('SocketException ignoriert fallback (Offline-Meldung hat Vorrang)',
        () {
      final e = SocketException('Network unreachable');
      final result = sanitizeError(e, fallback: 'Anderer Fehler');
      // Offline-Meldung hat Vorrang vor fallback
      expect(result, 'Keine Internetverbindung. Bitte prüfe deine Verbindung.');
    });

    // ── Branch 3: TimeoutException ───────────────────────────────────────────

    test('TimeoutException gibt Timeout-Meldung zurück', () {
      final e = TimeoutException('Connection timed out');
      final result = sanitizeError(e);
      expect(result, 'Zeitüberschreitung. Bitte erneut versuchen.');
    });

    // ── Branch 4: AuthException ──────────────────────────────────────────────

    test('AuthException gibt Anmeldung-abgelaufen-Meldung zurück', () {
      final e = AuthException('JWT expired');
      final result = sanitizeError(e);
      expect(result, 'Anmeldung abgelaufen. Bitte erneut anmelden.');
    });

    // ── Branch 5: FormatException ────────────────────────────────────────────

    test('FormatException gibt Datenformat-Meldung zurück', () {
      final e = FormatException('Unexpected token <, "<HTML>..." is not valid JSON');
      final result = sanitizeError(e);
      expect(result, 'Ungültiges Datenformat.');
    });

    test('FormatException enthält keine rohe Exception-Message im Output', () {
      final e = FormatException('Internal parser trace...');
      final result = sanitizeError(e);
      expect(result, isNot(contains('Internal parser trace')));
    });

    // ── Branch 6: Unbekannte Exception ───────────────────────────────────────

    test('Unbekannte Exception gibt errorUnknown zurück', () {
      final e = Exception('Something unexpected');
      final result = sanitizeError(e);
      expect(result, 'Ein unbekannter Fehler ist aufgetreten.');
    });

    test('Unbekannte Exception gibt fallback zurück wenn angegeben', () {
      final e = Exception('Something unexpected');
      final result = sanitizeError(e, fallback: 'Kontext-spezifischer Fehler');
      expect(result, 'Kontext-spezifischer Fehler');
    });

    test('StateError (unbekannter Typ) gibt errorUnknown zurück', () {
      final e = StateError('Bad state: no element');
      final result = sanitizeError(e);
      expect(result, 'Ein unbekannter Fehler ist aufgetreten.');
    });

    test('Unbekannte Exception enthält keinen rohen toString()-Output', () {
      final e = Exception('RLS policy violation at line 42 of auth.sql');
      final result = sanitizeError(e);
      expect(result, isNot(contains('RLS policy')));
      expect(result, isNot(contains('auth.sql')));
    });

    // ── fallback-Parameter ────────────────────────────────────────────────────

    test('fallback wird bei null-ähnlichen Fällen verwendet', () {
      final result = sanitizeError(
        Exception('unknown'),
        fallback: 'Bitte erneut versuchen',
      );
      expect(result, 'Bitte erneut versuchen');
    });

    // ── PostgrestException message-Trim ─────────────────────────────────────

    test('PostgrestException message wird getrimmt', () {
      final e = PostgrestException(message: '  Fehler mit Whitespace  ');
      final result = sanitizeError(e);
      expect(result, 'Fehler mit Whitespace');
    });
  });
}
