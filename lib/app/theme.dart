import 'package:flutter/material.dart';

class AppColors {
  // Primary Healthcare Palette
  static const Color primary = Color(0xFF0F766E); // Medical Teal
  static const Color secondary = Color(0xFF2563EB); // Healthcare Blue
  static const Color accent = Color(0xFF06B6D4); // Aqua

  // Status & Emergency Palette
  static const Color emergency = Color(0xFFDC2626); // Emergency Red
  static const Color success = Color(0xFF16A34A); // Success Green
  static const Color warning = Color(0xFFF59E0B); // Warning Amber

  // Background & Surface
  static const Color background = Color(0xFFF8FAFC); // Soft Slate Gray
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);

  // Typography
  static const Color textPrimary = Color(0xFF0F172A); // Dark Slate Header
  static const Color textSecondary = Color(0xFF64748B); // Slate Muted Body
  static const Color textDisabled = Color(0xFF94A3B8); // Light Muted
}

class AppTheme {
  // Backwards compatibility aliases
  static const Color primaryTeal = AppColors.primary;
  static const Color primaryBlue = AppColors.secondary;
  static const Color secondaryBlue = AppColors.secondary;
  static const Color accentGreen = AppColors.success;
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentRed = AppColors.emergency;
  static const Color backgroundLight = AppColors.background;
  static const Color surfaceWhite = AppColors.surface;
  static const Color textDark = AppColors.textPrimary;
  static const Color textMuted = AppColors.textSecondary;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.emergency,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            );
          }
          return const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.normal,
          );
        }),
      ),
    );
  }
}
