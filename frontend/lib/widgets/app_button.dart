import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

enum AppButtonVariant {
  primary,
  secondary,
  ghost,
}

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final AppButtonVariant variant;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ============================================================
    // BUTTON COLORS
    // primary: основная кнопка
    // secondary: мягкая кнопка
    // ghost: текстовая кнопка без фона
    // ============================================================

    final Color backgroundColor;
    final Color foregroundColor;
    final BorderSide borderSide;

    switch (variant) {
      case AppButtonVariant.primary:
        backgroundColor = theme.colorScheme.primary;
        foregroundColor = isDark ? AppColors.darkBackground : Colors.white;
        borderSide = BorderSide.none;
        break;

      case AppButtonVariant.secondary:
        backgroundColor = isDark
            ? AppColors.darkPrimarySoft
            : AppColors.lightPrimarySoft;
        foregroundColor = theme.colorScheme.primary;
        borderSide = BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
        );
        break;

      case AppButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        foregroundColor = theme.colorScheme.primary;
        borderSide = BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        );
        break;
    }

    final child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: foregroundColor,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(text),
            ],
          );

    return SizedBox(
      width: double.infinity,

      // Высота кнопки
      height: 54,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.45),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.65),
          elevation: 0,

          // Скругление кнопки
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.large,
            side: borderSide,
          ),

          // Размер текста кнопки
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
        child: child,
      ),
    );
  }
}