import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF4F1EA);
  static const Color primary = Color(0xFF3E4A3C); // زيتي غامق
  static const Color accent = Color(0xFF5A6C57); // زيتي أفتح
  static const Color card = Color(0xFFFFFFFF);
  static const Color blackCard = Color(0xFF1C1C1C);

  static const Color textPrimary = Color(0xFF2E2E2E);
  static const Color textLight = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: "Poppins", // لو بدك خط نضيف

    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accent,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: AppColors.textPrimary,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blackCard,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
  );
}