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
      onPrimary: AppColors.lightOnPrimary,
      secondary: AppColors.lightSecondary,
      onSecondary: AppColors.lightOnPrimary,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightText,
      onSurfaceVariant: AppColors.lightMutedText,
      error: AppColors.lightError,
      onError: AppColors.white,
      outline: AppColors.lightBorder,
      shadow: AppColors.lightShadow,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTextStyles.fontFamily,

      // Главный фон всех экранов.
      scaffoldBackgroundColor: AppColors.lightBackground,

      colorScheme: colorScheme,

      // Мягкие эффекты нажатия.
      splashColor: AppColors.lightPrimary.withValues(alpha: 0.08),
      highlightColor: AppColors.lightPrimary.withValues(alpha: 0.04),

      // Типографика приложения.
      textTheme: AppTextStyles.textTheme(
        textColor: AppColors.lightText,
        mutedTextColor: AppColors.lightMutedText,
      ),

      // ========================================================
      // APP BAR
      // ========================================================
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.lightText,
        iconTheme: IconThemeData(
          color: AppColors.lightText,
          size: 22,
        ),
        actionsIconTheme: IconThemeData(
          color: AppColors.lightText,
          size: 22,
        ),
        titleTextStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.lightText,
          letterSpacing: -0.2,
        ),
      ),

      // ========================================================
      // CARDS
      // ========================================================
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: AppColors.lightShadow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.extraLarge,
          side: const BorderSide(
            color: AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),

      // ========================================================
      // FILLED BUTTONS
      // ========================================================
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: AppColors.lightOnPrimary,
          disabledBackgroundColor: AppColors.lightPrimary.withValues(alpha: 0.35),
          disabledForegroundColor:
              AppColors.lightOnPrimary.withValues(alpha: 0.7),
          minimumSize: const Size(double.infinity, 54),
          padding: AppSpacing.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.button,
          ),
          textStyle: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),

      // ========================================================
      // TEXT BUTTONS
      // ========================================================
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lightPrimary,
          textStyle: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.medium,
          ),
        ),
      ),

      // ========================================================
      // OUTLINED BUTTONS
      // ========================================================
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightText,
          side: const BorderSide(
            color: AppColors.lightDivider,
            width: 1,
          ),
          minimumSize: const Size(double.infinity, 52),
          padding: AppSpacing.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.button,
          ),
          textStyle: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ========================================================
      // INPUTS
      // ========================================================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        hintStyle: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: AppColors.lightMutedText,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: AppColors.lightMutedText,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        errorStyle: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: AppColors.lightError,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: AppSpacing.fieldPadding,
        border: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: const BorderSide(
            color: AppColors.lightBorder,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: const BorderSide(
            color: AppColors.lightBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: const BorderSide(
            color: AppColors.lightPrimary,
            width: 1.3,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: const BorderSide(
            color: AppColors.lightError,
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: const BorderSide(
            color: AppColors.lightError,
            width: 1.3,
          ),
        ),
      ),

      // ========================================================
      // ICONS
      // ========================================================
      iconTheme: const IconThemeData(
        color: AppColors.lightText,
        size: 22,
      ),

      // ========================================================
      // DIVIDERS
      // ========================================================
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
        space: 1,
      ),

      // ========================================================
      // SNACK BAR
      // ========================================================
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.lightText,
        contentTextStyle: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: AppColors.white,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.medium,
        ),
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
      onPrimary: AppColors.darkOnPrimary,
      secondary: AppColors.darkSecondary,
      onSecondary: AppColors.darkOnPrimary,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      onSurfaceVariant: AppColors.darkMutedText,
      error: AppColors.darkError,
      onError: AppColors.white,
      outline: AppColors.darkBorder,
      shadow: AppColors.darkShadow,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTextStyles.fontFamily,

      // Главный фон всех экранов.
      scaffoldBackgroundColor: AppColors.darkBackground,

      colorScheme: colorScheme,

      // Мягкие эффекты нажатия.
      splashColor: AppColors.darkPrimary.withValues(alpha: 0.14),
      highlightColor: AppColors.darkPrimary.withValues(alpha: 0.08),

      // Типографика приложения.
      textTheme: AppTextStyles.textTheme(
        textColor: AppColors.darkText,
        mutedTextColor: AppColors.darkMutedText,
      ),

      // ========================================================
      // APP BAR
      // ========================================================
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.darkText,
        iconTheme: IconThemeData(
          color: AppColors.darkText,
          size: 22,
        ),
        actionsIconTheme: IconThemeData(
          color: AppColors.darkText,
          size: 22,
        ),
        titleTextStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
          letterSpacing: -0.2,
        ),
      ),

      // ========================================================
      // CARDS
      // ========================================================
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: AppColors.darkShadow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.extraLarge,
          side: const BorderSide(
            color: AppColors.darkBorder,
            width: 1,
          ),
        ),
      ),

      // ========================================================
      // FILLED BUTTONS
      // ========================================================
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: AppColors.darkOnPrimary,
          disabledBackgroundColor: AppColors.darkPrimary.withValues(alpha: 0.35),
          disabledForegroundColor:
              AppColors.darkOnPrimary.withValues(alpha: 0.65),
          minimumSize: const Size(double.infinity, 54),
          padding: AppSpacing.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.button,
          ),
          textStyle: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),

      // ========================================================
      // TEXT BUTTONS
      // ========================================================
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkPrimary,
          textStyle: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.medium,
          ),
        ),
      ),

      // ========================================================
      // OUTLINED BUTTONS
      // ========================================================
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkText,
          side: const BorderSide(
            color: AppColors.darkBorder,
            width: 1,
          ),
          minimumSize: const Size(double.infinity, 52),
          padding: AppSpacing.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.button,
          ),
          textStyle: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ========================================================
      // INPUTS
      // ========================================================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        hintStyle: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: AppColors.darkMutedText,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: AppColors.darkMutedText,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        errorStyle: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: AppColors.darkError,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: AppSpacing.fieldPadding,
        border: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: const BorderSide(
            color: AppColors.darkBorder,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: const BorderSide(
            color: AppColors.darkBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: const BorderSide(
            color: AppColors.darkPrimary,
            width: 1.3,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: const BorderSide(
            color: AppColors.darkError,
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: const BorderSide(
            color: AppColors.darkError,
            width: 1.3,
          ),
        ),
      ),

      // ========================================================
      // ICONS
      // ========================================================
      iconTheme: const IconThemeData(
        color: AppColors.darkText,
        size: 22,
      ),

      // ========================================================
      // DIVIDERS
      // ========================================================
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
        space: 1,
      ),

      // ========================================================
      // SNACK BAR
      // ========================================================
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkSurfaceSoft,
        contentTextStyle: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: AppColors.darkText,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.medium,
        ),
      ),
    );
  }
}