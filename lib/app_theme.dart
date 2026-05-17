import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppColorPalette { blue, indigo, violet, teal, rose }

class _PaletteConfig {
  final Color accent;
  final Color accentLight;
  final Color accentDark;
  final Color accentLightDark;
  final Color accentBorderLight;
  final Color accentBorderDark;
  final Color accentSelectedDark;
  final Color accentTextDark;
  const _PaletteConfig({
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.accentLightDark,
    required this.accentBorderLight,
    required this.accentBorderDark,
    required this.accentSelectedDark,
    required this.accentTextDark,
  });
}

class AppTheme {
  // -- Neutral Base (Light) --
  static const Color bgApp = Color(0xFFF5F7FA);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color bgSubtle = Color(0xFFEEF2F7);
  static const Color border = Color(0xFFE0E6EF);
  static const Color borderStrong = Color(0xFFC8D3E0);

  // -- Text (Light) --
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF374151);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF9CA3AF);

  // -- Neutral Base (Dark) --
  static const Color bgAppDark = Color(0xFF0F172A);
  static const Color bgSurfaceDark = Color(0xFF1E293B);
  static const Color bgSubtleDark = Color(0xFF334155);
  static const Color borderDark = Color(0xFF334155);
  static const Color borderStrongDark = Color(0xFF475569);

  // -- Text (Dark) --
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textMutedDark = Color(0xFF94A3B8);
  static const Color textDisabledDark = Color(0xFF64748B);
  // -- Palette definitions --
  static const Map<AppColorPalette, _PaletteConfig> _palettes = {
    AppColorPalette.blue: _PaletteConfig(
      accent: Color(0xFF2563EB),
      accentLight: Color(0xFFEFF6FF),
      accentDark: Color(0xFF1D4ED8),
      accentLightDark: Color(0xFF1E3A5F),
      accentBorderLight: Color(0xFFBFDBFE),
      accentBorderDark: Color(0xFF1E40AF),
      accentSelectedDark: Color(0xFF1E3A5F),
      accentTextDark: Color(0xFF60A5FA),
    ),
    AppColorPalette.indigo: _PaletteConfig(
      accent: Color(0xFF4F46E5),
      accentLight: Color(0xFFEEF2FF),
      accentDark: Color(0xFF4338CA),
      accentLightDark: Color(0xFF1E1B4B),
      accentBorderLight: Color(0xFFC7D2FE),
      accentBorderDark: Color(0xFF3730A3),
      accentSelectedDark: Color(0xFF1E1B4B),
      accentTextDark: Color(0xFF818CF8),
    ),
    AppColorPalette.violet: _PaletteConfig(
      accent: Color(0xFF7C3AED),
      accentLight: Color(0xFFF5F3FF),
      accentDark: Color(0xFF6D28D9),
      accentLightDark: Color(0xFF2E1065),
      accentBorderLight: Color(0xFFDDD6FE),
      accentBorderDark: Color(0xFF4C1D95),
      accentSelectedDark: Color(0xFF2E1065),
      accentTextDark: Color(0xFFA78BFA),
    ),
    AppColorPalette.teal: _PaletteConfig(
      accent: Color(0xFF0D9488),
      accentLight: Color(0xFFF0FDFA),
      accentDark: Color(0xFF0F766E),
      accentLightDark: Color(0xFF134E4A),
      accentBorderLight: Color(0xFF99F6E4),
      accentBorderDark: Color(0xFF115E59),
      accentSelectedDark: Color(0xFF134E4A),
      accentTextDark: Color(0xFF2DD4BF),
    ),
    AppColorPalette.rose: _PaletteConfig(
      accent: Color(0xFFE11D48),
      accentLight: Color(0xFFFFF1F2),
      accentDark: Color(0xFFBE123C),
      accentLightDark: Color(0xFF4C0519),
      accentBorderLight: Color(0xFFFFCCD5),
      accentBorderDark: Color(0xFF881337),
      accentSelectedDark: Color(0xFF4C0519),
      accentTextDark: Color(0xFFFB7185),
    ),
  };

  // -- Active palette (set by AppPreferencesProvider on load/change) --
  static AppColorPalette _active = AppColorPalette.blue;

  static void setActivePalette(AppColorPalette p) => _active = p;

  static AppColorPalette get activePalette => _active;

  // -- Accent accessors (palette-aware) --
  static Color get accent => _palettes[_active]!.accent;
  static Color get accentLight => _palettes[_active]!.accentLight;
  static Color get accentDark => _palettes[_active]!.accentDark;
  static Color get accentLightDark => _palettes[_active]!.accentLightDark;
  static Color get accentBorderLight => _palettes[_active]!.accentBorderLight;
  static Color get accentBorderDark => _palettes[_active]!.accentBorderDark;
  static Color get accentSelectedDark => _palettes[_active]!.accentSelectedDark;
  static Color get accentTextDark => _palettes[_active]!.accentTextDark;

  // Returns the primary accent for any palette (used by the palette picker UI).
  static Color paletteAccent(AppColorPalette p) => _palettes[p]!.accent;

  // -- Context-aware helpers --
  static bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bgAppOf(BuildContext context) =>
      _dark(context) ? bgAppDark : bgApp;
  static Color bgSurfaceOf(BuildContext context) =>
      _dark(context) ? bgSurfaceDark : bgSurface;
  static Color bgSubtleOf(BuildContext context) =>
      _dark(context) ? bgSubtleDark : bgSubtle;
  static Color borderOf(BuildContext context) =>
      _dark(context) ? borderDark : border;
  static Color borderStrongOf(BuildContext context) =>
      _dark(context) ? borderStrongDark : borderStrong;
  static Color textPrimaryOf(BuildContext context) =>
      _dark(context) ? textPrimaryDark : textPrimary;
  static Color textSecondaryOf(BuildContext context) =>
      _dark(context) ? textSecondaryDark : textSecondary;
  static Color textMutedOf(BuildContext context) =>
      _dark(context) ? textMutedDark : textMuted;
  static Color textDisabledOf(BuildContext context) =>
      _dark(context) ? textDisabledDark : textDisabled;

  static Color accentSelectedBgOf(BuildContext context) =>
      _dark(context) ? accentSelectedDark : accentLight;

  static Color accentLightOf(BuildContext context) =>
      _dark(context) ? accentLightDark : accentLight;
  static Color accentBorderOf(BuildContext context) =>
      _dark(context) ? accentBorderDark : accentBorderLight;

  // -- Semantic accent variant (purple — used for "Missing Invoice" KPI) --
  static const Color purple = Color(0xFF8B5CF6);

  // -- Semantic status colors --
  static const Color success = Color(0xFF059669);
  static const Color successBg = Color(0xFFECFDF5);
  static const Color successBgDark = Color(0xFF064E3B);
  static const Color successBorder = Color(0xFF86EFAC);
  static const Color successBorderDark = Color(0xFF065F46);
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color warningBgDark = Color(0xFF422006);
  static const Color warningBorder = Color(0xFFFDE68A);
  static const Color warningBorderDark = Color(0xFF78350F);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color dangerBgDark = Color(0xFF450A0A);
  static const Color dangerBorder = Color(0xFFFECACA);
  static const Color dangerBorderDark = Color(0xFF7F1D1D);
  static const Color info = Color(0xFF0284C7);
  static const Color infoBg = Color(0xFFF0F9FF);
  static const Color infoBgDark = Color(0xFF0C2A3D);
  static const Color infoBorder = Color(0xFFBAE6FD);
  static const Color infoBorderDark = Color(0xFF075985);

  static Color successBgOf(BuildContext context) =>
      _dark(context) ? successBgDark : successBg;
  static Color successBorderOf(BuildContext context) =>
      _dark(context) ? successBorderDark : successBorder;
  static Color warningBgOf(BuildContext context) =>
      _dark(context) ? warningBgDark : warningBg;
  static Color warningBorderOf(BuildContext context) =>
      _dark(context) ? warningBorderDark : warningBorder;
  static Color dangerBgOf(BuildContext context) =>
      _dark(context) ? dangerBgDark : dangerBg;
  static Color dangerBorderOf(BuildContext context) =>
      _dark(context) ? dangerBorderDark : dangerBorder;
  static Color infoBgOf(BuildContext context) =>
      _dark(context) ? infoBgDark : infoBg;
  static Color infoBorderOf(BuildContext context) =>
      _dark(context) ? infoBorderDark : infoBorder;

  static const Color successTextDark = Color(0xFF34D399);
  static const Color warningTextDark = Color(0xFFFBBF24);
  static const Color dangerTextDark = Color(0xFFF87171);
  static const Color infoTextDark = Color(0xFF38BDF8);
  static Color successTextOf(BuildContext context) =>
      _dark(context) ? successTextDark : success;
  static Color warningTextOf(BuildContext context) =>
      _dark(context) ? warningTextDark : warning;
  static Color dangerTextOf(BuildContext context) =>
      _dark(context) ? dangerTextDark : danger;
  static Color infoTextOf(BuildContext context) =>
      _dark(context) ? infoTextDark : info;
  static Color accentTextOf(BuildContext context) =>
      _dark(context) ? accentTextDark : accent;

  // -- Sidebar navigation --
  static const Color navBg = Color(0xFF1E293B);
  static const Color navIcon = Color(0xFF94A3B8);
  static const Color navLabel = Color(0xFFCBD5E1);

  // -- Legacy aliases --
  static const Color primary = navBg;
  static const Color background = bgApp;
  static const Color cardBg = bgSurface;
  static const Color sidebar = bgSubtle;

  // -- ThemeData builders --
  static ThemeData get light => lightFor(_active);
  static ThemeData get dark => darkFor(_active);

  static ThemeData lightFor(AppColorPalette palette) =>
      _buildLight(_palettes[palette]!);

  static ThemeData darkFor(AppColorPalette palette) =>
      _buildDark(_palettes[palette]!);

  static ThemeData _buildLight(_PaletteConfig p) {
    // Inter-Schnitt auf Material3-Light-Defaults → dunkler Text.
    final baseText = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.light).textTheme,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: Brightness.light,
        surface: bgSurface,
      ),
      scaffoldBackgroundColor: bgApp,
      textTheme: baseText.copyWith(
        // Headlines + Titles bekommen explizit den primären Textton, damit
        // Screens die nur `theme.textTheme.headlineSmall` etc. verwenden,
        // automatisch theme-aware bleiben.
        displayLarge: baseText.displayLarge?.copyWith(color: textPrimary),
        displayMedium: baseText.displayMedium?.copyWith(color: textPrimary),
        displaySmall: baseText.displaySmall?.copyWith(color: textPrimary),
        headlineLarge: baseText.headlineLarge?.copyWith(color: textPrimary),
        headlineMedium: baseText.headlineMedium?.copyWith(color: textPrimary),
        headlineSmall: baseText.headlineSmall?.copyWith(color: textPrimary),
        titleLarge: baseText.titleLarge?.copyWith(color: textPrimary),
        titleMedium: baseText.titleMedium?.copyWith(color: textPrimary),
        titleSmall: baseText.titleSmall?.copyWith(color: textPrimary),
        bodyLarge: baseText.bodyLarge?.copyWith(color: textSecondary, fontSize: 14),
        bodyMedium: baseText.bodyMedium?.copyWith(color: textSecondary, fontSize: 13),
        bodySmall: baseText.bodySmall?.copyWith(color: textMuted, fontSize: 12),
        labelLarge: baseText.labelLarge?.copyWith(color: textMuted, fontSize: 12),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: navBg,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.1,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        toolbarHeight: 52,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: border, width: 1),
        ),
        color: bgSurface,
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: bgSurface,
        labelStyle: const TextStyle(color: textMuted, fontSize: 13),
        floatingLabelStyle: TextStyle(color: p.accent, fontSize: 12, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: textDisabled, fontSize: 13),
        isDense: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accent,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        extendedTextStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      chipTheme: ChipThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.accent,
        unselectedLabelColor: textMuted,
        indicatorColor: p.accent,
        dividerColor: border,
      ),
    );
  }

  static ThemeData _buildDark(_PaletteConfig p) {
    // ROOT-FIX (2026-05-17): vorher `GoogleFonts.interTextTheme()` ohne
    // Argument → liefert Material3-LIGHT-Defaults (dunkler Text). Im Dark-
    // Mode kollabieren dadurch alle Headlines/Titles auf dunkles Grau auf
    // dunklem Background — sichtbarstes Beispiel: Pricing-Screen-Headline
    // war fast schwarz auf bgAppDark. Korrekt: Light- oder Dark-Material-
    // Textstyles JE NACH brightness als Inter-Basis übergeben.
    final baseText = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: Brightness.dark,
        surface: bgSurfaceDark,
      ),
      scaffoldBackgroundColor: bgAppDark,
      textTheme: baseText.copyWith(
        displayLarge: baseText.displayLarge?.copyWith(color: textPrimaryDark),
        displayMedium: baseText.displayMedium?.copyWith(color: textPrimaryDark),
        displaySmall: baseText.displaySmall?.copyWith(color: textPrimaryDark),
        headlineLarge: baseText.headlineLarge?.copyWith(color: textPrimaryDark),
        headlineMedium: baseText.headlineMedium?.copyWith(color: textPrimaryDark),
        headlineSmall: baseText.headlineSmall?.copyWith(color: textPrimaryDark),
        titleLarge: baseText.titleLarge?.copyWith(color: textPrimaryDark),
        titleMedium: baseText.titleMedium?.copyWith(color: textPrimaryDark),
        titleSmall: baseText.titleSmall?.copyWith(color: textPrimaryDark),
        bodyLarge: baseText.bodyLarge?.copyWith(color: textSecondaryDark, fontSize: 14),
        bodyMedium: baseText.bodyMedium?.copyWith(color: textSecondaryDark, fontSize: 13),
        bodySmall: baseText.bodySmall?.copyWith(color: textMutedDark, fontSize: 12),
        labelLarge: baseText.labelLarge?.copyWith(color: textMutedDark, fontSize: 12),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.1,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        toolbarHeight: 52,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: borderDark, width: 1),
        ),
        color: bgSurfaceDark,
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: bgSurfaceDark,
        labelStyle: const TextStyle(color: textMutedDark, fontSize: 13),
        floatingLabelStyle: TextStyle(color: p.accent, fontSize: 12, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: textDisabledDark, fontSize: 13),
        isDense: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accent,
          side: const BorderSide(color: borderDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        extendedTextStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgSurfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimaryDark,
        ),
      ),
      chipTheme: ChipThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dividerTheme: const DividerThemeData(
        color: borderDark,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.accent,
        unselectedLabelColor: textMutedDark,
        indicatorColor: p.accent,
        dividerColor: borderDark,
      ),
    );
  }
}
