import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';

/// Über-/Copyright-Seite: App-Name, Version, Copyright-Hinweis (Kerem Özkan)
/// und „Alle Rechte vorbehalten". Erreichbar aus Einstellungen → Allgemein.
///
/// Bewusst statisch und ohne Provider — reine Anzeige. Die Version wird
/// asynchron via `package_info_plus` geladen (nice-to-have; bleibt bei
/// Fehler einfach leer).
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = '${info.version} (${info.buildNumber})');
    } catch (_) {
      // Version ist nur Beiwerk — bei Fehler bleibt die Zeile aus.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = AppTheme.accentTextOf(context);
    return Scaffold(
      backgroundColor: AppTheme.bgAppOf(context),
      appBar: AppBar(title: Text(l10n.aboutScreenTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.inventory_2_outlined,
                        size: 44, color: accent),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.aboutAppName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.aboutTagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMutedOf(context),
                    ),
                  ),
                  if (_version.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurfaceOf(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderOf(context)),
                      ),
                      child: Text(
                        '${l10n.aboutVersionLabel} $_version',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Divider(color: AppTheme.borderOf(context)),
                  const SizedBox(height: 24),
                  Text(
                    l10n.aboutCopyright,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.aboutAllRightsReserved,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMutedOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
