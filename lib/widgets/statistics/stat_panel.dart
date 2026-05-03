import 'package:flutter/material.dart';

/// Wiederverwendbarer Panel-Container für die Statistik-Tabs.
/// Weißer Hintergrund, dezenter Border, optionaler Titel + Icon + Action.
class StatPanel extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  const StatPanel({
    super.key,
    this.title,
    this.icon,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || icon != null || trailing != null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E6EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeader) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: const Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                  ],
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  ?trailing,
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E6EF)),
          ],
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
