import 'package:flutter/material.dart';

/// Marken-Konstanten für CanLogistics.
///
/// Diese Werte sind die **Single-Source-of-Truth** für alles Brand-Bezogene:
/// Name, Tagline-Keys, Brand-Farbe, Asset-Pfade. Sie sind bewusst **unabhängig**
/// von der user-wählbaren Accent-Palette (`AppTheme.activePalette`) — User darf
/// die UI nach Geschmack einfärben; die Marke bleibt aber stabil Indigo.
///
/// Wer in der App eine Brand-Touch-Stelle baut (Splash, Login-Header,
/// Onboarding-Welcome, App-Bar-Logo, Settings-About) zieht sich Werte hier
/// raus statt sie zu kopieren.
class Brand {
  Brand._();

  /// Marken-Name. Wird in About-Bildschirmen / hardcoded-fallbacks genutzt.
  /// User-sichtbare Texte bleiben über ARB (`appTitle`) lokalisiert.
  static const String name = 'CanLogistics';

  /// Primary Brand Color — Indigo 700.
  static const Color primary = Color(0xFF4338CA);

  /// Helle Variante für Gradienten — Indigo 500.
  static const Color primaryLight = Color(0xFF6366F1);

  /// Tiefe Variante für Gradienten — Indigo 900.
  static const Color primaryDeep = Color(0xFF312E81);

  /// Kontrast-Farbe für Text/Icons auf Brand-Backgrounds.
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Vertikaler Brand-Gradient — für Splash, Onboarding-Header, Promo-Cards.
  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryLight, primaryDeep],
  );

  /// Asset-Pfade (für `Image.asset(...)` an Stellen, die das Raster-PNG brauchen
  /// — z. B. Platform-Channels, externe Embeds). Für In-App-UI bevorzugt
  /// [BrandMark]/[BrandWordmark] aus `widgets/brand_logo.dart`.
  static const String logoAsset = 'assets/branding/logo_1024.png';
  static const String logoMaskWhiteAsset =
      'assets/branding/logo_mark_white_1024.png';
  static const String logoMaskIndigoAsset =
      'assets/branding/logo_mark_indigo_1024.png';
  static const String wordmarkLightAsset =
      'assets/branding/wordmark_light.png';
  static const String wordmarkDarkAsset =
      'assets/branding/wordmark_dark.png';
}
