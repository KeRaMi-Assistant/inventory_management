import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // -- Accent --
  static const Color accent = Color(0xFF2563EB);
  static const Color accentLight = Color(0xFFEFF6FF);
  static const Color accentDark = Color(0xFF1D4ED8);

  // -- Semantic status colors --
  static const Color success = Color(0xFF059669);
  static const Color successBg = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF0284C7);
  static const Color infoBg = Color(0xFFF0F9FF);

  // -- Sidebar navigation --
  static const Color navBg = Color(0xFF1E293B);
  static const Color navIcon = Color(0xFF94A3B8);
  static const Color navLabel = Color(0xFFCBD5E1);

  // -- Legacy aliases --
  static const Color primary = navBg;
  static const Color background = bgApp;
  static const Color cardBg = bgSurface;
  static const Color sidebar = bgSubtle;
  static ThemeData get light {
    final baseText = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        surface: bgSurface,
      ),
      scaffoldBackgroundColor: bgApp,
      textTheme: baseText.copyWith(
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
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border, width: 1),
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
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: bgSurface,
        labelStyle: const TextStyle(color: textMuted, fontSize: 13),
        floatingLabelStyle: const TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: textDisabled, fontSize: 13),
        isDense: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
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
          foregroundColor: accent,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
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
        labelColor: accent,
        unselectedLabelColor: textMuted,
        indicatorColor: accent,
        dividerColor: border,
      ),
    );
  }

  static ThemeData get dark {
    final baseText = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: bgSurfaceDark,
      ),
      scaffoldBackgroundColor: bgAppDark,
      textTheme: baseText.copyWith(
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
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: borderDark, width: 1),
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
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: bgSurfaceDark,
        labelStyle: const TextStyle(color: textMutedDark, fontSize: 13),
        floatingLabelStyle: const TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: textDisabledDark, fontSize: 13),
        isDense: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
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
          foregroundColor: accent,
          side: const BorderSide(color: borderDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
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
        labelColor: accent,
        unselectedLabelColor: textMutedDark,
        indicatorColor: accent,
        dividerColor: borderDark,
      ),
    );
  }
}
