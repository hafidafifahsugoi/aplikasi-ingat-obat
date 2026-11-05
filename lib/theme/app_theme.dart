import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppColors {
  static bool get isDark => AppTheme.themeNotifier.value == ThemeMode.dark;

  // Adaptive Background & Surface
  static Color get background =>
      isDark ? const Color(0xFF111918) : const Color(0xFFF5F8F7);
  static Color get surface =>
      isDark ? const Color(0xFF1B2625) : const Color(0xFFFFFFFF);
  static Color get surfaceSoft =>
      isDark ? const Color(0xFF22312F) : const Color(0xFFEEF5F3);
  static Color get surfaceWarm =>
      isDark ? const Color(0xFF1F2B29) : const Color(0xFFFAF7F5);

  // Primary Soft Sage / Mint Wellness Palette (Const safe)
  static const Color primary = Color(0xFF56ABA0);
  static const Color primaryDark = Color(0xFF3E8E84);
  static const Color primaryLight = Color(0xFF7FC4BC);
  static Color get primarySoft =>
      isDark ? const Color(0xFF1E3734) : const Color(0xFFE3F3F0);

  // Secondary Soft Lavender & Peach Accents
  static const Color accentLavender = Color(0xFF9C8EC9);
  static Color get accentLavenderSoft =>
      isDark ? const Color(0xFF282538) : const Color(0xFFF0EDF9);
  static const Color accentPeach = Color(0xFFF29B8E);
  static Color get accentPeachSoft =>
      isDark ? const Color(0xFF382624) : const Color(0xFFFDF0ED);
  static const Color accentAmber = Color(0xFFEBB665);
  static Color get accentAmberSoft =>
      isDark ? const Color(0xFF362D1E) : const Color(0xFFFDF5E6);

  // Semantic Colors (Soft & Easy on the Eyes)
  static const Color success = Color(0xFF5AB288);
  static Color get successSoft =>
      isDark ? const Color(0xFF1C352A) : const Color(0xFFE7F6EE);
  static const Color warning = Color(0xFFE8A355);
  static Color get warningSoft =>
      isDark ? const Color(0xFF382B1C) : const Color(0xFFFEF4E6);
  static const Color danger = Color(0xFFE27676);
  static Color get dangerSoft =>
      isDark ? const Color(0xFF3A2222) : const Color(0xFFFCEAEA);

  // Adaptive Typography Colors
  static Color get textPrimary =>
      isDark ? const Color(0xFFECF4F3) : const Color(0xFF233735);
  static Color get textSecondary =>
      isDark ? const Color(0xFF9AB0AE) : const Color(0xFF6B8280);
  static Color get textMuted =>
      isDark ? const Color(0xFF687E7C) : const Color(0xFF9EB2B0);
  static Color get border =>
      isDark ? const Color(0xFF2A3B39) : const Color(0xFFE2ECEA);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5EB3A9), Color(0xFF3F8B82)],
  );

  static LinearGradient get authBackgroundGradient => isDark
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111918), Color(0xFF172220), Color(0xFF1B2428)],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE3F3F0), Color(0xFFEEEBF8), Color(0xFFFDF2EF)],
        );

  // Curated Soft Aesthetic Medicine Colors
  static const List<Color> medicinePalette = [
    Color(0xFF5EB19E), // Sage Mint
    Color(0xFFE88D96), // Rose Quartz
    Color(0xFF78A2CC), // Periwinkle Sky
    Color(0xFF9D8EC7), // Soft Lavender
    Color(0xFFF2A679), // Peach Nectar
    Color(0xFF64B5B9), // Aqua Breeze
    Color(0xFFE5B567), // Honey Amber
    Color(0xFFC98CA7), // Berry Mauve
  ];

  static String getColorName(Color color) {
    final val = color.toARGB32();
    if (val == 0xFF5EB19E) return 'Sage Mint';
    if (val == 0xFFE88D96) return 'Rose Pink';
    if (val == 0xFF78A2CC) return 'Sky Blue';
    if (val == 0xFF9D8EC7) return 'Lavender';
    if (val == 0xFFF2A679) return 'Soft Peach';
    if (val == 0xFF64B5B9) return 'Aqua';
    if (val == 0xFFE5B567) return 'Honey';
    if (val == 0xFFC98CA7) return 'Mauve';
    return 'Custom';
  }
}

class AppTheme {
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static void loadThemeFromStorage() {
    try {
      if (Hive.isBoxOpen('session')) {
        final box = Hive.box('session');
        final isDark = box.get('isDarkMode', defaultValue: false) as bool;
        themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
        _updateStatusBar(isDark);
      }
    } catch (_) {}
  }

  static Future<void> toggleTheme() async {
    final newIsDark = themeNotifier.value != ThemeMode.dark;
    themeNotifier.value = newIsDark ? ThemeMode.dark : ThemeMode.light;
    _updateStatusBar(newIsDark);
    try {
      if (Hive.isBoxOpen('session')) {
        await Hive.box('session').put('isDarkMode', newIsDark);
      }
    } catch (_) {}
  }

  static void _updateStatusBar(bool isDark) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111918) : const Color(0xFFF5F8F7);
    final surfaceColor =
        isDark ? const Color(0xFF1B2625) : const Color(0xFFFFFFFF);
    final textPrimary =
        isDark ? const Color(0xFFECF4F3) : const Color(0xFF233735);
    final textMuted =
        isDark ? const Color(0xFF687E7C) : const Color(0xFF9EB2B0);
    final borderColor =
        isDark ? const Color(0xFF2A3B39) : const Color(0xFFE2ECEA);

    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accentLavender,
        surface: surfaceColor,
        error: AppColors.danger,
        brightness: brightness,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
