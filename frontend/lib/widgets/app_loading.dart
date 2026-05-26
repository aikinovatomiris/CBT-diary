import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class AppLoading extends StatelessWidget {
  final String? text;

  const AppLoading({
    super.key,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ============================================================
    // LOADING
    // Универсальный виджет загрузки для будущих экранов.
    // ============================================================

    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.colorScheme.primary,
              ),
            ),
            if (text != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                text!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}