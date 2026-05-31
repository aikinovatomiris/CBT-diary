import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();

  // ============================================================
  // FONT
  // ============================================================

  static const String fontFamily = 'SF Pro Display';

  // ============================================================
  // FONT SIZES
  // ============================================================

  static const double headlineLarge = 32;
  static const double headlineMedium = 24;
  static const double titleLarge = 20;
  static const double titleMedium = 17;
  static const double bodyLarge = 16;
  static const double bodyMedium = 14;
  static const double bodySmall = 12;
  static const double button = 16;

  static TextTheme textTheme({
    required Color textColor,
    required Color mutedTextColor,
  }) {
    return TextTheme(
      headlineLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: headlineLarge,
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: -0.7,
        color: textColor,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: headlineMedium,
        fontWeight: FontWeight.w700,
        height: 1.14,
        letterSpacing: -0.45,
        color: textColor,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: titleLarge,
        fontWeight: FontWeight.w700,
        height: 1.22,
        letterSpacing: -0.25,
        color: textColor,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: titleMedium,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.15,
        color: textColor,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: bodyLarge,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: -0.05,
        color: textColor,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: bodyMedium,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: textColor,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: bodySmall,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: mutedTextColor,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: button,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.1,
        color: textColor,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: bodyMedium,
        fontWeight: FontWeight.w500,
        height: 1.25,
        color: mutedTextColor,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: bodySmall,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: mutedTextColor,
      ),
    );
  }
}