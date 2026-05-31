import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/practice_data.dart';
import '../../models/practice_model.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_card.dart';

class PracticesScreen extends StatelessWidget {
  const PracticesScreen({super.key});

  void _openPractice(BuildContext context, PracticeModel practice) {
    context.push('/practices/${practice.id}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 720 : double.infinity,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    110,
                  ),
                  children: [
                    Text(
                      'Практики для успокоения',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Короткие упражнения, которые можно использовать как паузу перед КПТ-сессией или в момент напряжения. Они не заменяют терапию или медицинскую помощь.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    ...practices.map(
                      (practice) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.lg,
                          ),
                          child: _PracticeCard(
                            practice: practice,
                            onTap: () => _openPractice(context, practice),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  final PracticeModel practice;
  final VoidCallback onTap;

  const _PracticeCard({
    required this.practice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      hasShadow: false,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              _iconForCategory(practice.category),
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  practice.title,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${practice.durationMinutes} мин · ${practice.category}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  practice.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Дыхание':
        return Icons.air_rounded;
      case 'Заземление':
        return Icons.spa_outlined;
      case 'Тревога':
        return Icons.favorite_border_rounded;
      case 'Тело':
        return Icons.accessibility_new_rounded;
      case 'Перед сессией':
        return Icons.psychology_alt_outlined;
      default:
        return Icons.self_improvement_rounded;
    }
  }
}