import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  // ============================================================
  // LIGHT THEME
  // ============================================================

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.lightPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.lightPrimary,
      secondary: AppColors.lightSecondary,
      surface: AppColors.lightSurface,
      error: AppColors.lightError,
      onSurface: AppColors.lightText,
      onSurfaceVariant: AppColors.lightMutedText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Цвет фона всех экранов
      scaffoldBackgroundColor: AppColors.lightBackground,

      colorScheme: colorScheme,

      // Типографика приложения
      textTheme: AppTextStyles.textTheme(
        textColor: AppColors.lightText,
        mutedTextColor: AppColors.lightMutedText,
      ),

      // AppBar: прозрачный, без тени, как в iOS
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.lightText,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.lightText,
          letterSpacing: -0.2,
        ),
      ),

      // Карточки
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.extraLarge,
        ),
      ),

      // Основные кнопки
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.lightPrimary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),

          // Высота кнопки
          minimumSize: const Size(double.infinity, 54),

          // Скругление кнопки
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.large,
          ),

          // Текст кнопки
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),

          elevation: 0,
        ),
      ),

      // Поля ввода
      inputDecorationTheme: InputDecorationTheme(
        filled: true,

        // Цвет поля
        fillColor: AppColors.lightSurface,

        hintStyle: const TextStyle(
          color: AppColors.lightMutedText,
          fontSize: 14,
        ),

        labelStyle: const TextStyle(
          color: AppColors.lightMutedText,
          fontSize: 14,
        ),

        // Отступы внутри поля
        contentPadding: AppSpacing.fieldPadding,

        border: OutlineInputBorder(
          borderRadius: AppRadius.large,
          borderSide: BorderSide.none,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.large,
          borderSide: const BorderSide(
            color: AppColors.lightBorder,
            width: 1,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.large,
          borderSide: const BorderSide(
            color: AppColors.lightPrimary,
            width: 1.4,
          ),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.large,
          borderSide: const BorderSide(
            color: AppColors.lightError,
            width: 1.2,
          ),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.large,
          borderSide: const BorderSide(
            color: AppColors.lightError,
            width: 1.4,
          ),
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.lightText,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.medium,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
      ),
    );
  }

  // ============================================================
  // DARK THEME
  // ============================================================

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.darkPrimary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.darkPrimary,
      secondary: AppColors.darkSecondary,
      surface: AppColors.darkSurface,
      error: AppColors.darkError,
      onSurface: AppColors.darkText,
      onSurfaceVariant: AppColors.darkMutedText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Цвет фона всех экранов
      scaffoldBackgroundColor: AppColors.darkBackground,

      colorScheme: colorScheme,

      // Типографика приложения
      textTheme: AppTextStyles.textTheme(
        textColor: AppColors.darkText,
        mutedTextColor: AppColors.darkMutedText,
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.darkText,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
          letterSpacing: -0.2,
        ),
      ),

      // Карточки
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.extraLarge,
        ),
      ),

      // Основные кнопки
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: AppColors.darkBackground,
          disabledBackgroundColor: AppColors.darkPrimary.withValues(alpha: 0.4),
          disabledForegroundColor:
              AppColors.darkBackground.withValues(alpha: 0.7),

          // Высота кнопки
          minimumSize: const Size(double.infinity, 54),

          // Скругление кнопки
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.large,
          ),

          // Текст кнопки
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),

          elevation: 0,
        ),
      ),

      // Поля ввода
      inputDecorationTheme: InputDecorationTheme(
        filled: true,

        // Цвет поля
        fillColor: AppColors.darkSurface,

        hintStyle: const TextStyle(
          color: AppColors.darkMutedText,
          fontSize: 14,
        ),

        labelStyle: const TextStyle(
          color: AppColors.darkMutedText,
          fontSize: 14,
        ),

        // Отступы внутри поля
        contentPadding: AppSpacing.fieldPadding,

        border: OutlineInputBorder(
          borderRadius: AppRadius.large,
          borderSide: BorderSide.none,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.large,
          borderSide: const BorderSide(
            color: AppColors.darkBorder,
            width: 1,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.large,
          borderSide: const BorderSide(
            color: AppColors.darkPrimary,
            width: 1.4,
          ),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.large,
          borderSide: const BorderSide(
            color: AppColors.darkError,
            width: 1.2,
          ),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.large,
          borderSide: const BorderSide(
            color: AppColors.darkError,
            width: 1.4,
          ),
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkSurfaceSoft,
        contentTextStyle: const TextStyle(
          color: AppColors.darkText,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.medium,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
      ),
    );
  }
}