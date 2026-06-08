import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_model.dart';
import '../../navigation/app_routes.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../theme/app_spacing.dart';
import '../../utils/theme_controller.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserModel> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = AuthService.me();
  }

  Future<void> _refresh() async {
    setState(() {
      _userFuture = AuthService.me();
    });

    await _userFuture;
  }

  Future<void> _logout() async {
    await AuthService.logout();

    if (!mounted) return;

    context.go(AppRoutes.login);
  }

  void _openAssistantSettings() {
    context.push(AppRoutes.assistantSettings).then((_) {
      if (mounted) {
        _refresh();
      }
    });
  }

  void _openChangePassword() {
    context.push(AppRoutes.changePassword);
  }

  void _showDisclaimer() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Дисклеймер'),
          content: const Text(
            'КПТ-дневник с ИИ-ассистентом не заменяет психолога, психотерапевта или медицинскую помощь. '
            'Приложение предназначено для самонаблюдения, структурирования мыслей и ведения дневника. '
            'Если тебе очень плохо, есть риск навредить себе или ты чувствуешь, что не справляешься, важно обратиться к близким, специалисту или в экстренные службы.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        );
      },
    );
  }

  String _styleTitle(String? style) {
    switch (style) {
      case 'supportive':
        return 'Поддерживающий';
      case 'friendly':
        return 'Дружелюбный';
      case 'structured':
        return 'Структурированный';
      case 'concise':
        return 'Краткий';
      default:
        return 'Не указан';
    }
  }

  String _safeText(String? value, {String fallback = 'Не указано'}) {
    if (value == null || value.trim().isEmpty) {
      return fallback;
    }

    return value.trim();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: AppLoading(
              text: 'Загрузка профиля...',
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is ApiException
              ? error.message
              : 'Не удалось загрузить профиль.';

          return Scaffold(
            body: AppErrorView(
              message: message,
              onRetry: _refresh,
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return Scaffold(
            body: AppErrorView(
              message: 'Нет данных пользователя.',
              onRetry: _refresh,
            ),
          );
        }

        return _ProfileContent(
          user: user,
          styleTitle: _styleTitle,
          safeText: _safeText,
          onAssistantSettings: _openAssistantSettings,
          onChangePassword: _openChangePassword,
          onDisclaimer: _showDisclaimer,
          onLogout: _logout,
          onRefresh: _refresh,
        );
      },
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final UserModel user;
  final String Function(String?) styleTitle;
  final String Function(String?, {String fallback}) safeText;
  final VoidCallback onAssistantSettings;
  final VoidCallback onChangePassword;
  final VoidCallback onDisclaimer;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRefresh;

  const _ProfileContent({
    required this.user,
    required this.styleTitle,
    required this.safeText,
    required this.onAssistantSettings,
    required this.onChangePassword,
    required this.onDisclaimer,
    required this.onLogout,
    required this.onRefresh,
  });

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
                  maxWidth: isWide ? 620 : double.infinity,
                ),
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      110,
                    ),
                    children: [
                      Text(
                        'Профиль',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Данные аккаунта и настройки приложения.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      AppCard(
                        hasShadow: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              safeText(user.name),
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              safeText(user.email),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _InfoRow(
                              label: 'Стиль ассистента',
                              value: styleTitle(user.assistantStyle),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      AppCard(
                        hasShadow: false,
                        child: Column(
                          children: [
                            _ProfileActionTile(
                              icon: Icons.smart_toy_outlined,
                              title: 'Настройки ассистента',
                              subtitle: 'Выбрать стиль общения',
                              onTap: onAssistantSettings,
                            ),
                            const Divider(),
                            if (user.canChangePassword) ...[
                              _ProfileActionTile(
                                icon: Icons.lock_outline_rounded,
                                title: 'Сменить пароль',
                                subtitle: 'Обновить пароль аккаунта',
                                onTap: onChangePassword,
                              ),
                              const Divider(),
                            ],
                            ValueListenableBuilder<ThemeMode>(
                              valueListenable: ThemeController.themeMode,
                              // ignore: unnecessary_underscores
                              builder: (context, _, __) {
                                return _ProfileActionTile(
                                  icon: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Icons.dark_mode_rounded
                                      : Icons.light_mode_rounded,
                                  title: 'Тема приложения',
                                  subtitle: ThemeController.getThemeTitle(
                                    context,
                                  ),
                                  onTap: () {
                                    ThemeController.toggleTheme(context);
                                  },
                                );
                              },
                            ),
                            const Divider(),

                            _ProfileActionTile(
                              icon: Icons.info_outline_rounded,
                              title: 'Дисклеймер',
                              subtitle: 'Важная информация о приложении',
                              onTap: onDisclaimer,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      AppButton(
                        text: 'Выйти',
                        icon: Icons.logout_rounded,
                        variant: AppButtonVariant.ghost,
                        onPressed: onLogout,
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: theme.colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}