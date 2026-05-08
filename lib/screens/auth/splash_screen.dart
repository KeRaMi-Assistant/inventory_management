import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.bgAppOf(context),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentLightOf(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.inventory_2_rounded,
                  color: AppTheme.accentTextOf(context), size: 32),
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 14),
            Text(
              message ?? l10n.splashSyncing,
              style: TextStyle(color: AppTheme.textMutedOf(context)),
            ),
          ],
        ),
      ),
    );
  }
}
