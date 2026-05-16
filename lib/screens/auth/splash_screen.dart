import 'package:flutter/material.dart';

import '../../brand.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/brand_logo.dart';

/// Brand-Splash, der nach erfolgreichem Login angezeigt wird, während die
/// Provider hydratisieren. Ersetzt den alten generischen Inventory-Splash.
///
/// Design-Pattern:
///   * Vertikaler Indigo-Gradient als Fullscreen-Background.
///   * Animierte Marke (fade-in + leichte upward-translation) → Wiedererkennung.
///   * Wordmark in Weiß, darunter Tagline + kleiner Spinner.
///
/// Auf kleinen Phones (360x640) bleibt alles im Viewport, weil maxWidth 320
/// und mainAxisSize.min greift. Weil der Screen nur kurz sichtbar ist,
/// brauchen wir kein SafeArea-Padding — der Brand-Background soll bis an die
/// Bildschirmränder reichen (Notch + Home-Indicator inklusive).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.message});

  final String? message;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Brand.primaryDeep,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Brand.gradient),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Marken-Logo (vektorisierter CustomPainter).
                    const BrandMark(size: 96, onDark: true),
                    const SizedBox(height: 22),
                    // Wordmark in Weiß / hell.
                    const BrandWordmark(
                      fontSize: 28,
                      onDark: true,
                      canColor: Colors.white,
                      logisticsColor: Color(0xCCFFFFFF),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.appTagline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 13,
                        height: 1.35,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.message ?? l10n.splashSyncing,
                      style: const TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
