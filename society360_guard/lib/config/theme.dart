import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium Corporate Theme for Society360 Guard App
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // Premium Color Palette - Corporate & Professional
  static const Color backgroundGradientStart = Color(0xFFF8FAFC); // Soft Blue-Gray
  static const Color backgroundGradientEnd = Color(0xFFE8EEF5); // Light Blue Tint
  static const Color surfaceCard = Color(0xFFFFFFFF); // Pure White Cards
  static const Color primaryOrange = Color(0xFFFF8C42); // Vibrant Professional Orange
  static const Color primaryOrangeLight = Color(0xFFFFBD7C); // Light Orange
  static const Color primaryBlue = Color(0xFF4F46E5); // Deep Indigo (professional)
  static const Color primaryBlueDark = Color(0xFF3730A3); // Darker Indigo
  static const Color accentTeal = Color(0xFF14B8A6); // Modern Teal
  static const Color accentPurple = Color(0xFF9333EA); // Rich Purple

  // Legacy color for backwards compatibility
  static const Color backgroundLight = backgroundGradientStart;

  // Text Colors - Enhanced Contrast
  static const Color textDark = Color(0xFF0F172A); // Deep Slate
  static const Color textGray = Color(0xFF64748B); // Professional Gray
  static const Color textLight = Color(0xFF94A3B8); // Light Gray
  static const Color textWhite = Color(0xFFFFFFFF); // Pure White

  // Status Colors - Modern & Vibrant
  static const Color errorRed = Color(0xFFDC2626);
  static const Color successGreen = Color(0xFF059669);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color infoBlue = Color(0xFF0891B2);

  // Gradient Definitions - Modern & Professional
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryOrange, Color(0xFFFF6B35)],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, primaryBlueDark],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundGradientStart, backgroundGradientEnd],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentTeal, Color(0xFF0D9488)],
  );

  // Shadow Definitions - Subtle & Professional
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.12),
      blurRadius: 32,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // Text Theme with Professional Typography
  static const TextTheme _textTheme = TextTheme(
    // Display styles - for hero text
    displayLarge: TextStyle(
      fontSize: 48,
      fontWeight: FontWeight.bold,
      color: textDark,
      letterSpacing: -1.0,
      height: 1.2,
    ),
    displayMedium: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.bold,
      color: textDark,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    displaySmall: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: textDark,
      letterSpacing: -0.25,
      height: 1.3,
    ),

    // Headline styles - for screen titles
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: textDark,
      letterSpacing: -0.5,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: textDark,
      letterSpacing: -0.25,
      height: 1.3,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: textDark,
      letterSpacing: 0,
      height: 1.4,
    ),

    // Title styles - for card titles
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: textDark,
      letterSpacing: 0,
      height: 1.4,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: textDark,
      letterSpacing: 0.15,
      height: 1.5,
    ),
    titleSmall: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: textDark,
      letterSpacing: 0.1,
      height: 1.5,
    ),

    // Body styles - for general text
    bodyLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.normal,
      color: textDark,
      letterSpacing: 0.15,
      height: 1.6,
    ),
    bodyMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: textDark,
      letterSpacing: 0.25,
      height: 1.6,
    ),
    bodySmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: textGray,
      letterSpacing: 0.4,
      height: 1.6,
    ),

    // Label styles - for buttons and labels
    labelLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: textDark,
      letterSpacing: 0.5,
      height: 1.4,
    ),
    labelMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: textDark,
      letterSpacing: 0.5,
      height: 1.4,
    ),
    labelSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textGray,
      letterSpacing: 0.5,
      height: 1.4,
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
        secondary: primaryBlue,
        surface: surfaceCard,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textDark,
        onError: Colors.white,
        tertiary: accentTeal,
      ),

      // Scaffold Background (gradient applied per screen)
      scaffoldBackgroundColor: backgroundGradientStart,

      // AppBar Theme - Modern & Elevated
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textDark,
          letterSpacing: -0.25,
        ),
        iconTheme: const IconThemeData(
          color: textDark,
          size: 24,
        ),
      ),

      // Card Theme - Enhanced with Shadows
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: textLight.withOpacity(0.1),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),

      // Elevated Button Theme - Gradient & Modern
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      // Outlined Button Theme - Refined
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryOrange,
          minimumSize: const Size(double.infinity, 56),
          side: BorderSide(color: primaryOrange.withOpacity(0.5), width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryOrange,
          minimumSize: const Size(0, 48),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.25,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      // Input Decoration Theme - Modern & Clean
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: textLight.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: textLight.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryOrange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        hintStyle: TextStyle(
          color: textGray.withOpacity(0.7),
          fontSize: 16,
        ),
        labelStyle: const TextStyle(
          color: textGray,
          fontSize: 16,
        ),
        floatingLabelStyle: const TextStyle(
          color: primaryOrange,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Dialog Theme - Modern & Elegant
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceCard,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 16,
          color: textDark,
          height: 1.6,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceCard,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
        color: textLight.withOpacity(0.3),
        thickness: 1,
        space: 24,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: primaryOrangeLight.withOpacity(0.15),
        labelStyle: const TextStyle(
          color: textDark,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryOrange,
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        elevation: 8,
        highlightElevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // Font Family (Inter for professional look)
      fontFamily: 'Inter',
    );
  }
}
