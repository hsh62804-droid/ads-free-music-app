import 'package:flutter/material.dart';

/// Centralized Red & Black design system.
/// All colors, text styles, spacings, and theme data are defined here.
class AppTheme {
  // Brand Colors (Pure Black and Crimson Red)
  static const Color pureBlack = Color(0xFF000000);
  static const Color darkBackground = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF0D0D0D);
  static const Color surfaceElevated = Color(0xFF161616);
  static const Color surfaceBorder = Color(0xFF222222);
  static const Color surfaceHover = Color(0xFF282828);

  // Red Accents
  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkRed = Color(0xFFB20710);
  static const Color glowRed = Color(0xFFFF3B3B);
  static const Color accentRed = primaryRed;

  // Backwards compatibility alias for previous references
  static const Color spotifyGreen = primaryRed;

  // Typography Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF757575);
  static const Color dividerColor = Color(0xFF1F1F1F);

  // Spacing constants
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;

  // Corner radii
  static const double radiusS = 6.0;
  static const double radiusM = 10.0;
  static const double radiusL = 16.0;
  static const double radiusFull = 999.0;

  // Gradient behind album art in Now Playing screen
  static const LinearGradient playerBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF380306), // Dark subtle crimson
      Color(0xFF0D0D0D),
      Color(0xFF000000),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  // Red glow box shadow for poster
  static List<BoxShadow> get posterGlowShadow => [
        BoxShadow(
          color: glowRed.withValues(alpha: 0.25),
          blurRadius: 36,
          spreadRadius: -4,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.8),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  // Global ThemeData
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: pureBlack,
      primaryColor: primaryRed,
      colorScheme: const ColorScheme.dark(
        primary: primaryRed,
        secondary: glowRed,
        surface: surfaceDark,
        onPrimary: textPrimary,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pureBlack,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primaryRed,
        unselectedItemColor: textSecondary,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryRed,
        inactiveTrackColor: surfaceElevated,
        thumbColor: textPrimary,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayColor: primaryRed.withValues(alpha: 0.2),
        trackHeight: 3,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceElevated,
        selectedColor: primaryRed,
        secondarySelectedColor: primaryRed,
        labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
        secondaryLabelStyle: const TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusFull)),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: textPrimary,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }
}
