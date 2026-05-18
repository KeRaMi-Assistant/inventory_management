import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../brand.dart';

/// CanLogistics Brand-Mark als CustomPainter — geometrisches "C" mit
/// nach rechts zeigendem Chevron (Andeutung von outbound-Logistik-Fluss).
///
/// Verwendung:
///   * `BrandMark(size: 56)` — auf hellem Hintergrund (Indigo-Fill).
///   * `BrandMark(size: 56, onDark: true)` — auf dunklem Hintergrund (Weiß-Fill).
///   * `BrandMark(size: 80, withBackground: true)` — eingebettet in Indigo-Gradient-Rounded-Square
///     (so wie das Launcher-Icon, aber vektorisiert).
///
/// Wird überall in der App verwendet, wo eine konsistente Logo-Marke
/// auftaucht (Splash, Login-Header, Onboarding-Welcome, App-Bar, Settings-
/// About). PNG-Assets bleiben für Launcher-Icons/Favicon zuständig.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 64,
    this.onDark = false,
    this.withBackground = false,
    this.color,
  });

  /// Logische Pixelgröße (Quadrat, size × size).
  final double size;

  /// `true` rendert die Marke in Weiß (für dunkle Hintergründe).
  final bool onDark;

  /// `true` umgibt die Marke mit dem Indigo-Gradient-Rounded-Square —
  /// die App-Icon-Variante. `false` zeichnet nur die nackte Marke.
  final bool withBackground;

  /// Optionaler Override für die Marken-Farbe. Wenn `null`, wird
  /// Indigo (Light) bzw. Weiß (Dark) basierend auf [onDark] gewählt.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final markColor = color ?? (onDark ? Brand.onPrimary : Brand.primary);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BrandMarkPainter(
          markColor: markColor,
          withBackground: withBackground,
        ),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  _BrandMarkPainter({required this.markColor, required this.withBackground});

  final Color markColor;
  final bool withBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);

    if (withBackground) {
      // Indigo-Gradient-Rounded-Square (matches PIL render).
      final rect = Offset.zero & size;
      final radius = Radius.circular(s * 0.22);
      final bgPaint = Paint()
        ..shader = Brand.gradient.createShader(rect);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), bgPaint);
    }

    // Geometry constants — match generate_logo.py for visual parity.
    const paddingRatio = 0.20;
    const strokeRatio = 0.16;
    const mouthRatio = 0.32;

    // When embedded in withBackground, the mark gets 62% of canvas (PIL parity).
    // Standalone, it fills the canvas.
    final markScale = withBackground ? 0.62 : 1.0;
    final markSize = s * markScale;
    final markOffset = Offset(
      (size.width - markSize) / 2,
      (size.height - markSize) / 2,
    );

    final pad = markSize * paddingRatio;
    final stroke = markSize * strokeRatio;

    final outerRect = Rect.fromLTWH(
      markOffset.dx + pad,
      markOffset.dy + pad,
      markSize - 2 * pad,
      markSize - 2 * pad,
    );
    final innerRect = outerRect.deflate(stroke);

    // Draw the "C" as a filled ring with a right-side mouth cut, using a Path
    // (rather than even-odd composite, so anti-aliasing stays crisp).
    final ringPath = Path()
      ..addOval(outerRect)
      ..addOval(innerRect)
      ..fillType = PathFillType.evenOdd;

    // Mouth: rectangular cut on the right that turns "O" → "C".
    final mouthH = (markSize - 2 * pad) * mouthRatio;
    final mouthW = (markSize - 2 * pad) * 0.60;
    final mouthRect = Rect.fromLTWH(
      outerRect.right - mouthW,
      center.dy - mouthH / 2,
      mouthW + s, // overshoot to avoid sub-pixel seam at right edge
      mouthH,
    );
    final mouthPath = Path()..addRect(mouthRect);

    final cPath = Path.combine(PathOperation.difference, ringPath, mouthPath);
    final paint = Paint()
      ..color = markColor
      ..isAntiAlias = true;
    canvas.drawPath(cPath, paint);

    // Logistics-flow chevron (>) inside the mouth.
    final chevronCx = outerRect.right - stroke * 0.4;
    final chevronCy = center.dy;
    final arm = stroke * 0.95;
    final thickness = (stroke * 0.32).clamp(2.0, double.infinity);
    final chevronPaint = Paint()
      ..color = markColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final chevron = Path()
      ..moveTo(chevronCx - arm, chevronCy - arm)
      ..lineTo(chevronCx, chevronCy)
      ..lineTo(chevronCx - arm, chevronCy + arm);
    canvas.drawPath(chevron, chevronPaint);
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter old) =>
      old.markColor != markColor || old.withBackground != withBackground;
}

/// Wordmark "CanLogistics" — "Can" bold in Brand-Indigo,
/// "Logistics" medium in slate. Inter font (über google_fonts, schon im Stack).
///
/// `fontSize` ist die Höhe der Großbuchstaben in logischen Pixeln.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.fontSize = 22,
    this.onDark,
    this.canColor,
    this.logisticsColor,
  });

  final double fontSize;

  /// Wenn null, wird `Theme.of(context).brightness` ausgewertet.
  final bool? onDark;

  final Color? canColor;
  final Color? logisticsColor;

  @override
  Widget build(BuildContext context) {
    final dark =
        onDark ?? Theme.of(context).brightness == Brightness.dark;
    final can = canColor ?? (dark ? Brand.primaryLight : Brand.primary);
    final logistics = logisticsColor ??
        (dark ? AppTheme.textSecondaryDark : AppTheme.textSecondary);

    return RichText(
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: fontSize,
          height: 1.0,
          letterSpacing: -0.2,
        ),
        children: [
          TextSpan(
            text: 'Can',
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: can,
              letterSpacing: -0.4,
            ),
          ),
          TextSpan(
            text: 'Logistics',
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: logistics,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kombi-Lockup: Brand-Mark + Wordmark horizontal — der häufigste Anker.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.markSize = 36,
    this.fontSize = 20,
    this.withBackground = true,
    this.onDark,
    this.spacing = 10,
  });

  final double markSize;
  final double fontSize;
  final bool withBackground;
  final bool? onDark;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final dark =
        onDark ?? Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BrandMark(
          size: markSize,
          onDark: !withBackground && dark,
          withBackground: withBackground,
        ),
        SizedBox(width: spacing),
        BrandWordmark(fontSize: fontSize, onDark: dark),
      ],
    );
  }
}
