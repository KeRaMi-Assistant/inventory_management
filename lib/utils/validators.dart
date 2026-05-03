/// Zentrale Eingabe-Validatoren für alle Formulare.
///
/// Konvention:
///  - validate*-Methoden geben `null` bei OK zurück, sonst eine
///    deutschsprachige Fehlermeldung, die direkt im UI angezeigt werden kann.
///  - sanitize*-Methoden geben den bereinigten String zurück (nie null).
///
/// Diese Helfer werden VOR jedem Insert/Update aufgerufen — sowohl als
/// FormFieldValidator im UI als auch defensiv im Repository.
library;

class Validators {
  Validators._();

  // ── Allgemeine Limits ───────────────────────────────────────────────────
  static const int maxProductName = 200;
  static const int maxBuyerName = 100;
  static const int maxShopName = 100;
  static const int maxSku = 50;
  static const int maxTicket = 100;
  static const int maxNote = 2000;
  static const int maxUrl = 2048;

  static final RegExp _email = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
  );
  static final RegExp _control = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
  static final RegExp _digits = RegExp(r'^\d+$');
  static final RegExp _skuChars = RegExp(r'^[A-Za-z0-9._\-]+$');

  // ── Sanitization ────────────────────────────────────────────────────────

  /// Trimmt Whitespace, entfernt NUL/Steuerzeichen.
  static String sanitize(String? value) {
    if (value == null) return '';
    return value.replaceAll(_control, '').trim();
  }

  /// Wie [sanitize], gibt aber `null` zurück, wenn das Ergebnis leer ist.
  static String? sanitizeOrNull(String? value) {
    final s = sanitize(value);
    return s.isEmpty ? null : s;
  }

  // ── Email ───────────────────────────────────────────────────────────────

  static String? validateEmail(String? value) {
    final v = sanitize(value);
    if (v.isEmpty) return 'E-Mail erforderlich';
    if (v.length > 254) return 'E-Mail ist zu lang';
    if (!_email.hasMatch(v)) return 'Ungültige E-Mail';
    return null;
  }

  // ── Passwort ────────────────────────────────────────────────────────────

  /// Strenge Regeln: min. 8 Zeichen, je 1 Groß-, Kleinbuchstabe, Zahl,
  /// Sonderzeichen.
  static String? validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Passwort erforderlich';
    if (v.length < 8) return 'Mindestens 8 Zeichen';
    if (v.length > 128) return 'Maximal 128 Zeichen';
    if (!RegExp(r'[A-Z]').hasMatch(v)) {
      return 'Mindestens 1 Großbuchstabe';
    }
    if (!RegExp(r'[a-z]').hasMatch(v)) {
      return 'Mindestens 1 Kleinbuchstabe';
    }
    if (!RegExp(r'\d').hasMatch(v)) return 'Mindestens 1 Zahl';
    if (!RegExp(r'[!@#$%^&*()_+\-=\[\]{};:,.<>?/\\|~`"' "'" r']').hasMatch(v)) {
      return 'Mindestens 1 Sonderzeichen';
    }
    return null;
  }

  /// 0 = leer, 1 = schwach, 2 = mittel, 3 = stark, 4 = sehr stark.
  static int passwordStrength(String value) {
    if (value.isEmpty) return 0;
    int score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[a-z]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(value) &&
        RegExp(r'[!@#$%^&*()_+\-=\[\]{};:,.<>?/\\|~`"' "'" r']')
            .hasMatch(value)) {
      score++;
    }
    return score.clamp(0, 4);
  }

  // ── Pflichtfelder ───────────────────────────────────────────────────────

  static String? validateRequired(String? value, {String label = 'Feld'}) {
    final v = sanitize(value);
    if (v.isEmpty) return '$label erforderlich';
    return null;
  }

  // ── Geschäftsfelder ─────────────────────────────────────────────────────

  static String? validateProductName(String? value, {bool required = true}) {
    final v = sanitize(value);
    if (v.isEmpty) {
      return required ? 'Produktname erforderlich' : null;
    }
    if (v.length > maxProductName) {
      return 'Maximal $maxProductName Zeichen';
    }
    return null;
  }

  static String? validateBuyerName(String? value, {bool required = true}) {
    final v = sanitize(value);
    if (v.isEmpty) return required ? 'Käufername erforderlich' : null;
    if (v.length > maxBuyerName) return 'Maximal $maxBuyerName Zeichen';
    return null;
  }

  static String? validateShopName(String? value, {bool required = true}) {
    final v = sanitize(value);
    if (v.isEmpty) return required ? 'Shop-Name erforderlich' : null;
    if (v.length > maxShopName) return 'Maximal $maxShopName Zeichen';
    return null;
  }

  static String? validateSku(String? value, {bool required = false}) {
    final v = sanitize(value);
    if (v.isEmpty) return required ? 'SKU erforderlich' : null;
    if (v.length > maxSku) return 'Maximal $maxSku Zeichen';
    if (!_skuChars.hasMatch(v)) {
      return 'Nur Buchstaben, Ziffern, „-_.“';
    }
    return null;
  }

  static String? validateTicket(String? value, {bool required = false}) {
    final v = sanitize(value);
    if (v.isEmpty) return required ? 'Ticketnummer erforderlich' : null;
    if (v.length > maxTicket) return 'Maximal $maxTicket Zeichen';
    return null;
  }

  static String? validateNote(String? value) {
    final v = value ?? '';
    if (v.length > maxNote) return 'Maximal $maxNote Zeichen';
    return null;
  }

  // ── Zahlen ──────────────────────────────────────────────────────────────

  static String? validateInt(String? value, {
    bool required = true,
    int? min,
    int? max,
  }) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return required ? 'Pflichtfeld' : null;
    final n = int.tryParse(v);
    if (n == null) return 'Ungültige Ganzzahl';
    if (min != null && n < min) return 'Muss ≥ $min sein';
    if (max != null && n > max) return 'Muss ≤ $max sein';
    return null;
  }

  static String? validatePositiveInt(String? value) =>
      validateInt(value, required: true, min: 1);

  static String? validateNonNegativeInt(String? value) =>
      validateInt(value, required: true, min: 0);

  /// Geldbetrag mit max. 2 Nachkommastellen, '.' oder ',' als Dezimaltrenner.
  static String? validateMoney(String? value, {bool required = false}) {
    final v = (value ?? '').trim().replaceAll(',', '.');
    if (v.isEmpty) return required ? 'Betrag erforderlich' : null;
    final n = double.tryParse(v);
    if (n == null) return 'Ungültige Zahl';
    if (n < 0) return 'Betrag darf nicht negativ sein';
    if (n > 99999999.99) return 'Betrag zu hoch';
    final dotIdx = v.indexOf('.');
    if (dotIdx >= 0 && v.length - dotIdx - 1 > 2) {
      return 'Maximal 2 Nachkommastellen';
    }
    return null;
  }

  // ── EAN / GTIN / Barcode ────────────────────────────────────────────────

  /// Prüft EAN-13/UPC-12/GTIN-8/14 inkl. Prüfziffer (Modulo-10).
  static String? validateGtin(String? value, {bool required = false}) {
    final v = sanitize(value);
    if (v.isEmpty) return required ? 'GTIN/EAN erforderlich' : null;
    if (![8, 12, 13, 14].contains(v.length)) {
      return 'Muss 8/12/13/14 Ziffern haben';
    }
    if (!_digits.hasMatch(v)) return 'Nur Ziffern erlaubt';
    if (!_isValidGtinChecksum(v)) return 'Ungültige Prüfziffer';
    return null;
  }

  static bool _isValidGtinChecksum(String s) {
    int sum = 0;
    for (int i = 0; i < s.length - 1; i++) {
      final digit = int.parse(s[i]);
      // Von rechts gesehen wechseln 3/1 — daher Position relativ zur Prüfziffer.
      final fromRight = s.length - 1 - i;
      sum += digit * (fromRight.isOdd ? 3 : 1);
    }
    final check = (10 - (sum % 10)) % 10;
    return check == int.parse(s[s.length - 1]);
  }

  // ── URL ─────────────────────────────────────────────────────────────────

  static String? validateUrl(String? value, {bool required = false}) {
    final v = sanitize(value);
    if (v.isEmpty) return required ? 'URL erforderlich' : null;
    if (v.length > maxUrl) return 'URL zu lang';
    final candidate = v.startsWith('http') ? v : 'https://$v';
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasAuthority) return 'Ungültige URL';
    if (!(uri.scheme == 'http' || uri.scheme == 'https')) {
      return 'Nur http/https erlaubt';
    }
    return null;
  }

  // ── Discord-Server-IDs (Snowflake) ──────────────────────────────────────

  static String? validateDiscordSnowflake(String? value,
      {bool required = false}) {
    final v = sanitize(value);
    if (v.isEmpty) return required ? 'Server-ID erforderlich' : null;
    if (!_digits.hasMatch(v)) return 'Nur Ziffern';
    if (v.length < 15 || v.length > 21) return '15–21 Ziffern';
    return null;
  }
}
