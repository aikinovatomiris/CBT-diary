import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/app_routes.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _goToLogin(BuildContext context) {
    context.push(AppRoutes.login);
  }

  void _goToRegister(BuildContext context) {
    context.push(AppRoutes.register);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 650;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 520 : double.infinity,
                ),
                child: Padding(
                  padding: AppSpacing.screenPadding,
                  child: ListView(
                    children: [
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        'КПТ-дневник',
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Приложение помогает фиксировать ситуации, автоматические мысли, эмоции и постепенно формировать более рациональный взгляд.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      AppCard(
                        hasShadow: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Что можно делать',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const _InfoItem(
                              icon: Icons.chat_bubble_outline_rounded,
                              text: 'Вести КПТ-сессию с ИИ-ассистентом',
                            ),
                            const _InfoItem(
                              icon: Icons.book_outlined,
                              text: 'Сохранять дневниковые записи',
                            ),
                            const _InfoItem(
                              icon: Icons.insights_outlined,
                              text: 'Смотреть простую аналитику',
                            ),
                            const _InfoItem(
                              icon: Icons.self_improvement_outlined,
                              text: 'Открывать практики и упражнения',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        hasShadow: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Важно',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Это приложение не заменяет психолога, психотерапевта или медицинскую помощь. Если тебе очень плохо или есть риск причинить вред себе, важно обратиться к близким, специалисту или в экстренную службу.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      AppButton(
                        text: 'Войти',
                        onPressed: () => _goToLogin(context),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        text: 'Создать аккаунт',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => _goToRegister(context),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}