import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../utils/validators.dart';

/// Vier-stufige Stärke-Anzeige für Passwortfelder.
class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final score = Validators.passwordStrength(password);
    final label = switch (score) {
      0 => '',
      1 => l10n.passwordStrengthWeak,
      2 => l10n.passwordStrengthMedium,
      3 => l10n.passwordStrengthStrong,
      _ => l10n.passwordStrengthVeryStrong,
    };
    final emptyTrackColor = AppTheme.borderOf(context);
    final color = switch (score) {
      0 => emptyTrackColor,
      1 => AppTheme.dangerTextOf(context),
      2 => AppTheme.warningTextOf(context),
      3 => AppTheme.successTextOf(context),
      _ => AppTheme.successTextOf(context),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: List.generate(4, (i) {
              final filled = i < score;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: filled ? color : emptyTrackColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
