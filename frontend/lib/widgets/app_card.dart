import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool hasShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.onTap,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ============================================================
    // CARD STYLE
    // Мягкая карточка с большим скруглением и очень аккуратной тенью.
    // ============================================================

    final card = Container(
      decoration: BoxDecoration(
        // Цвет карточки
        color: theme.cardTheme.color,

        // Скругление карточки
        borderRadius: AppRadius.extraLarge,

        // Мягкая тень
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: isDark ? AppColors.darkShadow : AppColors.lightShadow,

                  // Размытие тени
                  blurRadius: isDark ? 28 : 24,

                  // Смещение тени вниз
                  offset: const Offset(0, 14),
                ),
              ]
            : null,

        // Тонкая рамка для аккуратного разделения элементов
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: isDark ? 0.5 : 0.7),
          width: 1,
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.extraLarge,
      child: InkWell(
        borderRadius: AppRadius.extraLarge,
        onTap: onTap,
        child: card,
      ),
    );
  }
}