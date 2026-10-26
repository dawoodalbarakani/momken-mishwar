import 'package:flutter/material.dart';

/// Uber-inspired design tokens.
class UberColors {
  UberColors._();
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color bodyGray = Color(0xFF4B4B4B);
  static const Color mutedGray = Color(0xFFAFAFAF);
  static const Color chipGray = Color(0xFFEFEFEF);
  static const Color hoverGray = Color(0xFFE2E2E2);
  static const Color hoverLight = Color(0xFFF3F3F3);
}

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: UberColors.black,
    onPrimary: UberColors.white,
    secondary: UberColors.black,
    onSecondary: UberColors.white,
    surface: UberColors.white,
    onSurface: UberColors.black,
    error: Color(0xFFD32F2F),
    onError: UberColors.white,
  ),
  scaffoldBackgroundColor: UberColors.white,
  fontFamily: 'Tajawal',
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontSize: 52, fontWeight: FontWeight.w700, height: 1.23, color: UberColors.black),
    displayMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, height: 1.22, color: UberColors.black),
    displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.25, color: UberColors.black),
    headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.33, color: UberColors.black),
    headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.40, color: UberColors.black),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, height: 1.33, color: UberColors.black),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.50, color: UberColors.black),
    bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.25, color: UberColors.bodyGray),
    bodySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.43, color: UberColors.bodyGray),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.25, color: UberColors.black),
    labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.14, color: UberColors.black),
    labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.67, color: UberColors.mutedGray),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: UberColors.white,
    foregroundColor: UberColors.black,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: UberColors.black),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: UberColors.black,
      foregroundColor: UberColors.white,
      elevation: 0,
      // 44px minimum keeps every primary action touch-friendly regardless of
      // label length; width is left free since buttons are usually full-width.
      minimumSize: const Size(0, 44),
      tapTargetSize: MaterialTapTargetSize.padded,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: UberColors.black,
      side: const BorderSide(color: UberColors.black, width: 1),
      minimumSize: const Size(0, 44),
      tapTargetSize: MaterialTapTargetSize.padded,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: UberColors.black,
      minimumSize: const Size(0, 44),
      tapTargetSize: MaterialTapTargetSize.padded,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      tapTargetSize: MaterialTapTargetSize.padded,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: UberColors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: UberColors.black, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: UberColors.black, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: UberColors.black, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1),
    ),
    labelStyle: const TextStyle(color: UberColors.bodyGray, fontSize: 14),
    hintStyle: const TextStyle(color: UberColors.mutedGray, fontSize: 14),
  ),
  cardTheme: CardThemeData(
    color: UberColors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    shadowColor: const Color(0x1F000000),
    margin: const EdgeInsets.all(8),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: UberColors.chipGray,
    labelStyle: const TextStyle(color: UberColors.black, fontSize: 14, fontWeight: FontWeight.w500),
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    side: BorderSide.none,
  ),
  dividerTheme: const DividerThemeData(
    color: UberColors.black,
    thickness: 1,
    space: 16,
  ),
  iconTheme: const IconThemeData(color: UberColors.black, size: 24),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: UberColors.white,
    foregroundColor: UberColors.black,
    elevation: 2,
    shape: const StadiumBorder(),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: UberColors.black,
    contentTextStyle: const TextStyle(color: UberColors.white, fontSize: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    behavior: SnackBarBehavior.floating,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: UberColors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: UberColors.black),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: UberColors.white,
    selectedItemColor: UberColors.black,
    unselectedItemColor: UberColors.mutedGray,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
);
