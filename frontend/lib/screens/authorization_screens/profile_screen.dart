import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_model.dart';
import '../../navigation/app_routes.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_spacing.dart';
import '../../utils/theme_controller.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  State<ProfileScreen> createState() {
    return _ProfileScreenState();
  }
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  late Future<UserModel> _userFuture;

  @override
  void initState() {
    super.initState();

    _userFuture = AuthService.me();
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    final refreshFuture = AuthService.me(
      forceRefresh: true,
    );

    setState(() {
      _userFuture = refreshFuture;
    });

    await refreshFuture;
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await AuthService.logout();

    if (!mounted) {
      return;
    }

    context.go(
      AppRoutes.login,
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  Future<void> _openAssistantSettings() async {
    await context.push(
      AppRoutes.assistantSettings,
    );

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  void _openChangePassword() {
    context.push(
      AppRoutes.changePassword,
    );
  }

  // ============================================================
  // CHANGE NAME
  // ============================================================

  Future<void> _openChangeNameDialog(
    String currentName,
  ) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _ChangeNameDialog(
          initialName: currentName,
        );
      },
    );

    if (!mounted) {
      return;
    }

    final cleanName = newName?.trim();

    if (cleanName == null ||
        cleanName.isEmpty) {
      return;
    }

    try {
      final updatedUser =
          await ProfileService.updateName(
        cleanName,
      );

      if (!mounted) {
        return;
      }

      // Обновляем общий кэш, чтобы новое имя сразу
      // появилось на HomeScreen и других экранах.
      AuthService.updateCachedUser(
        updatedUser,
      );

      setState(() {
        // SynchronousFuture не переводит FutureBuilder
        // обратно на экран загрузки.
        _userFuture =
            SynchronousFuture<UserModel>(
          updatedUser,
        );
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Имя успешно изменено.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            error.message,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось изменить имя.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DISCLAIMER
  // ============================================================

  void _showDisclaimer() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Дисклеймер',
          ),
          content: const Text(
            'КПТ-дневник с ИИ-ассистентом не заменяет психолога, психотерапевта или медицинскую помощь. '
            'Приложение предназначено для самонаблюдения, структурирования мыслей и ведения дневника. '
            'Если тебе очень плохо, есть риск навредить себе или ты чувствуешь, что не справляешься, важно обратиться к близким, специалисту или в экстренные службы.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child: const Text(
                'Понятно',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // FORMATTERS
  // ============================================================

  String _styleTitle(
    String? style,
  ) {
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

  String _safeText(
    String? value, {
    String fallback = 'Не указано',
  }) {
    if (value == null ||
        value.trim().isEmpty) {
      return fallback;
    }

    return value.trim();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: AppLoading(
              text:
                  'Загрузка профиля...',
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;

          final message =
              error is ApiException
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
              message:
                  'Нет данных пользователя.',
              onRetry: _refresh,
            ),
          );
        }

        return _ProfileContent(
          user: user,
          styleTitle: _styleTitle,
          safeText: _safeText,
          onChangeName: () {
            _openChangeNameDialog(
              user.name ?? '',
            );
          },
          onAssistantSettings:
              _openAssistantSettings,
          onChangePassword:
              _openChangePassword,
          onDisclaimer:
              _showDisclaimer,
          onLogout: _logout,
          onRefresh: _refresh,
        );
      },
    );
  }
}

// ============================================================
// CHANGE NAME DIALOG
// ============================================================

class _ChangeNameDialog
    extends StatefulWidget {
  final String initialName;

  const _ChangeNameDialog({
    required this.initialName,
  });

  @override
  State<_ChangeNameDialog> createState() {
    return _ChangeNameDialogState();
  }
}

class _ChangeNameDialogState
    extends State<_ChangeNameDialog> {
  late final TextEditingController
      _controller;

  String? _errorText;

  @override
  void initState() {
    super.initState();

    _controller =
        TextEditingController(
      text: widget.initialName.trim(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  void _submit() {
    final value =
        _controller.text.trim();

    if (value.isEmpty) {
      setState(() {
        _errorText =
            'Имя не может быть пустым';
      });

      return;
    }

    Navigator.of(context).pop(
      value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Изменить имя',
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction:
            TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Имя',
          hintText:
              'Как к тебе обращаться?',
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText == null) {
            return;
          }

          setState(() {
            _errorText = null;
          });
        },
        onSubmitted: (_) {
          _submit();
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Отмена',
          ),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(
            'Сохранить',
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PROFILE CONTENT
// ============================================================

class _ProfileContent
    extends StatelessWidget {
  final UserModel user;

  final String Function(String?)
      styleTitle;

  final String Function(
    String?, {
    String fallback,
  })
  safeText;

  final VoidCallback onChangeName;
  final VoidCallback onAssistantSettings;
  final VoidCallback onChangePassword;
  final VoidCallback onDisclaimer;

  final Future<void> Function() onLogout;
  final Future<void> Function() onRefresh;

  const _ProfileContent({
    required this.user,
    required this.styleTitle,
    required this.safeText,
    required this.onChangeName,
    required this.onAssistantSettings,
    required this.onChangePassword,
    required this.onDisclaimer,
    required this.onLogout,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final isWide =
                constraints.maxWidth >
                700;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide
                      ? 620
                      : double.infinity,
                ),
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      110,
                    ),
                    children: [
                      Text(
                        'Профиль',
                        style: theme
                            .textTheme
                            .headlineMedium,
                      ),
                      const SizedBox(
                        height:
                            AppSpacing.sm,
                      ),
                      AppCard(
                        hasShadow: false,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              safeText(
                                user.name,
                              ),
                              style: theme
                                  .textTheme
                                  .titleLarge,
                            ),
                            const SizedBox(
                              height:
                                  AppSpacing
                                      .sm,
                            ),
                            Text(
                              safeText(
                                user.email,
                              ),
                              style: theme
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                color: theme
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(
                              height:
                                  AppSpacing
                                      .lg,
                            ),
                            _InfoRow(
                              label:
                                  'Стиль ассистента',
                              value:
                                  styleTitle(
                                user.assistantStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height:
                            AppSpacing.lg,
                      ),
                      AppCard(
                        hasShadow: false,
                        child: Column(
                          children: [
                            _ProfileActionTile(
                              icon:
                                  Icons.edit_outlined,
                              title:
                                  'Изменить имя',
                              subtitle:
                                  'Обновить имя для профиля и приветствия',
                              onTap:
                                  onChangeName,
                            ),
                            const Divider(),
                            _ProfileActionTile(
                              icon: Icons
                                  .smart_toy_outlined,
                              title:
                                  'Настройки ассистента',
                              subtitle:
                                  'Выбрать стиль общения',
                              onTap:
                                  onAssistantSettings,
                            ),
                            const Divider(),
                            if (user
                                .canChangePassword) ...[
                              _ProfileActionTile(
                                icon: Icons
                                    .lock_outline_rounded,
                                title:
                                    'Сменить пароль',
                                subtitle:
                                    'Обновить пароль аккаунта',
                                onTap:
                                    onChangePassword,
                              ),
                              const Divider(),
                            ],
                            ValueListenableBuilder<
                                ThemeMode>(
                              valueListenable:
                                  ThemeController
                                      .themeMode,
                              builder: (
                                context,
                                themeMode,
                                child,
                              ) {
                                return _ProfileActionTile(
                                  icon: Theme.of(
                                            context,
                                          ).brightness ==
                                          Brightness
                                              .dark
                                      ? Icons
                                          .dark_mode_rounded
                                      : Icons
                                          .light_mode_rounded,
                                  title:
                                      'Тема приложения',
                                  subtitle:
                                      ThemeController
                                          .getThemeTitle(
                                    context,
                                  ),
                                  onTap: () {
                                    ThemeController
                                        .toggleTheme(
                                      context,
                                    );
                                  },
                                );
                              },
                            ),
                            const Divider(),
                            _ProfileActionTile(
                              icon: Icons
                                  .info_outline_rounded,
                              title:
                                  'Дисклеймер',
                              subtitle:
                                  'Важная информация о приложении',
                              onTap:
                                  onDisclaimer,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height:
                            AppSpacing.lg,
                      ),
                      AppButton(
                        text: 'Выйти',
                        icon:
                            Icons.logout_rounded,
                        variant:
                            AppButtonVariant
                                .ghost,
                        onPressed:
                            onLogout,
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

// ============================================================
// INFO ROW
// ============================================================

class _InfoRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme
                .textTheme.bodyMedium
                ?.copyWith(
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(
          width: AppSpacing.md,
        ),
        Text(
          value,
          style: theme
              .textTheme.bodyMedium
              ?.copyWith(
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PROFILE ACTION TILE
// ============================================================

class _ProfileActionTile
    extends StatelessWidget {
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
    final theme =
        Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(18),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: theme
                  .colorScheme.primary,
              size: 22,
            ),
            const SizedBox(
              width: AppSpacing.md,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    title,
                    style: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    subtitle,
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: theme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons
                  .chevron_right_rounded,
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}