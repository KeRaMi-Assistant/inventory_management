import 'package:flutter/material.dart';

import '../utils/validators.dart';

/// Vier-stufige Stärke-Anzeige für Passwortfelder.
class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final score = Validators.passwordStrength(password);
    final label = switch (score) {
      0 => '',
      1 => 'Schwach',
      2 => 'Mittel',
      3 => 'Stark',
      _ => 'Sehr stark',
    };
    final color = switch (score) {
      0 => const Color(0xFFE2E8F0),
      1 => const Color(0xFFDC2626),
      2 => const Color(0xFFF59E0B),
      3 => const Color(0xFF10B981),
      _ => const Color(0xFF059669),
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
                    color: filled ? color : const Color(0xFFE2E8F0),
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
