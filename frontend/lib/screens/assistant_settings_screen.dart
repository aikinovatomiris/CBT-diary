import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/user_model.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_error_view.dart';
import '../widgets/app_loading.dart';

class AssistantSettingsScreen extends StatefulWidget {
  const AssistantSettingsScreen({super.key});

  @override
  State<AssistantSettingsScreen> createState() =>
      _AssistantSettingsScreenState();
}

class _AssistantSettingsScreenState extends State<AssistantSettingsScreen> {
  late Future<UserModel> _userFuture;

  String? _selectedStyle;
  bool _isSaving = false;

  final List<_AssistantStyleOption> _styles = const [
    _AssistantStyleOption(
      value: 'supportive',
      title: 'Поддерживающий',
      description: 'Больше мягкости, поддержки и спокойного тона.',
    ),
    _AssistantStyleOption(
      value: 'friendly',
      title: 'Дружелюбный',
      description: 'Более живой и разговорный стиль.',
    ),
    _AssistantStyleOption(
      value: 'structured',
      title: 'Структурированный',
      description: 'Больше порядка, шагов и четкой логики.',
    ),
    _AssistantStyleOption(
      value: 'concise',
      title: 'Краткий',
      description: 'Меньше текста, только самое важное.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUser();
  }

  Future<UserModel> _loadUser() async {
    final user = await AuthService.me();

    _selectedStyle = user.assistantStyle;

    return user;
  }

  Future<void> _refresh() async {
    setState(() {
      _userFuture = _loadUser();
    });

    await _userFuture;
  }

  Future<void> _save() async {
    final style = _selectedStyle;

    if (style == null || style.trim().isEmpty) {
      _showSnackBar('Выберите стиль ассистента.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ProfileService.updateAssistantStyle(style);

      if (!mounted) return;

      _showSnackBar('Стиль ассистента обновлен.');

      context.pop();
    } on ApiException catch (error) {
      if (!mounted) return;

      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;

      _showSnackBar('Не удалось сохранить стиль ассистента.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: AppLoading(
              text: 'Загрузка настроек...',
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is ApiException
              ? error.message
              : 'Не удалось загрузить настройки.';

          return Scaffold(
            appBar: AppBar(
              title: const Text('Стиль ассистента'),
            ),
            body: AppErrorView(
              message: message,
              onRetry: _refresh,
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Стиль ассистента'),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWide ? 620 : double.infinity,
                    ),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.xl,
                        AppSpacing.xl,
                        AppSpacing.xl,
                      ),
                      children: [
                        Text(
                          'Настройки ассистента',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Выбери стиль, в котором ассистент будет отвечать во время КПТ-сессий.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        ..._styles.map(
                          (style) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: _StyleCard(
                                option: style,
                                isSelected: _selectedStyle == style.value,
                                onTap: () {
                                  setState(() {
                                    _selectedStyle = style.value;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          text: 'Сохранить',
                          isLoading: _isSaving,
                          onPressed: _save,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _AssistantStyleOption {
  final String value;
  final String title;
  final String description;

  const _AssistantStyleOption({
    required this.value,
    required this.title,
    required this.description,
  });
}

class _StyleCard extends StatelessWidget {
  final _AssistantStyleOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _StyleCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      hasShadow: false,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  option.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Icon(
            isSelected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}