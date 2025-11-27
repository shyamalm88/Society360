import 'package:flutter/material.dart';

/// Light Theme for Society360 Guard App
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // Color Palette
  static const Color backgroundLight = Color(0xFFF5F5F5); // Light Gray Background
  static const Color surfaceCard = Color(0xFFFFFFFF); // White Cards
  static const Color primaryOrange = Color(0xFFFEAA00); // Warm Orange Accent
  static const Color textDark = Color(0xFF1F2937); // Dark Gray Text
  static const Color textGray = Color(0xFF6B7280); // Muted Gray
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);

  // Text Theme with Large, Readable Fonts
  static const TextTheme _textTheme = TextTheme(
    // Display styles - for hero text
    displayLarge: TextStyle(
      fontSize: 48,
      fontWeight: FontWeight.bold,
      color: textDark,
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.bold,
      color: textDark,
    ),
    displaySmall: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: textDark,
    ),

    // Headline styles - for screen titles
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: textDark,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: textDark,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: textDark,
    ),

    // Title styles - for card titles
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: textDark,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: textDark,
    ),
    titleSmall: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: textDark,
    ),

    // Body styles - for general text
    bodyLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.normal,
      color: textDark,
    ),
    bodyMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: textDark,
    ),
    bodySmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: textGray,
    ),

    // Label styles - for buttons and labels
    labelLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: textDark,
      letterSpacing: 0.5,
    ),
    labelMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: textDark,
    ),
    labelSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textGray,
    ),
  );

  // Main Theme Data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: primaryOrange,
        secondary: primaryOrange,
        surface: surfaceCard,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textDark,
        onError: Colors.white,
      ),

      // Scaffold Background
      scaffoldBackgroundColor: backgroundLight,

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceCard,
        elevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        iconTheme: IconThemeData(
          color: textDark,
          size: 28,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),

      // Elevated Button Theme - for primary actions
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Outlined Button Theme - for secondary actions
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryOrange,
          minimumSize: const Size(double.infinity, 60),
          side: const BorderSide(color: primaryOrange, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryOrange,
          minimumSize: const Size(0, 48),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryOrange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
        hintStyle: const TextStyle(
          color: textGray,
          fontSize: 16,
        ),
        labelStyle: const TextStyle(
          color: textGray,
          fontSize: 16,
        ),
        floatingLabelStyle: const TextStyle(
          color: primaryOrange,
          fontSize: 18,
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 16,
          color: textDark,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Text Theme
      textTheme: _textTheme,

      // Icon Theme
      iconTheme: const IconThemeData(
        color: textDark,
        size: 24,
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: textGray.withOpacity(0.2),
        thickness: 1,
        space: 24,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFFFF3E0),
        labelStyle: const TextStyle(
          color: textDark,
          fontSize: 14,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryOrange,
      ),

      // Font Family (default to system font, can be changed to Inter/Lato)
      fontFamily: 'Inter',
    );
  }
}
