import 'package:flutter/material.dart';

const Color primaryGreen = Color(0xFF2F4F46);
const Color lightCream = Color(0xFFF5F1EB);
const Color softGreen = Color(0xFF3E6B5C);

final ThemeData appTheme = ThemeData(
  scaffoldBackgroundColor: lightCream,
  fontFamily: 'Playfair',
  primaryColor: primaryGreen,
  colorScheme: ColorScheme.fromSeed(
    seedColor: primaryGreen,
    primary: primaryGreen,
    background: lightCream,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: primaryGreen,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: primaryGreen, width: 1),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 1),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    backgroundColor: primaryGreen,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 56),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      fontFamily: 'Playfair', // 👈 ضيفي هاي
    ),
  ),
),
);