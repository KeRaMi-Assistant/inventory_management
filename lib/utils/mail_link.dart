/// Baut aus einer RFC822 Message-ID + IMAP-Host einen Deep-Link, mit dem
/// der User die Mail in seinem Web-Mail-Client direkt öffnen kann.
///
/// Aktuell unterstützt: Gmail (alle Subdomains von gmail.com / googlemail.com,
/// inkl. Workspace-Konten). Andere Provider liefern null — der Caller fällt
/// dann auf "Message-ID in die Zwischenablage" zurück.
String? buildMailDeepLink({
  required String? messageId,
  required String? imapHost,
}) {
  if (messageId == null || messageId.isEmpty) return null;
  final id = messageId.replaceAll(RegExp(r'^<|>$'), '').trim();
  if (id.isEmpty) return null;
  final encoded = Uri.encodeComponent(id);

  final host = (imapHost ?? '').toLowerCase();
  if (host.contains('gmail.com') ||
      host.contains('googlemail.com') ||
      host.contains('google.com')) {
    return 'https://mail.google.com/mail/u/0/#search/rfc822msgid:$encoded';
  }
  return null;
}
