import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_exception.dart';
import '../../services/profile_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;

  String? _oldPasswordError;
  String? _newPasswordError;
  String? _generalError;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _oldPasswordError = null;
      _newPasswordError = null;
      _generalError = null;
    });

    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;

    bool isValid = true;

    if (oldPassword.isEmpty) {
      _oldPasswordError = 'Введите старый пароль';
      isValid = false;
    } else if (oldPassword.length < 6) {
      _oldPasswordError = 'Пароль должен быть не короче 6 символов';
      isValid = false;
    }

    if (newPassword.isEmpty) {
      _newPasswordError = 'Введите новый пароль';
      isValid = false;
    } else if (newPassword.length < 6) {
      _newPasswordError = 'Пароль должен быть не короче 6 символов';
      isValid = false;
    }

    if (oldPassword.isNotEmpty &&
        newPassword.isNotEmpty &&
        oldPassword == newPassword) {
      _newPasswordError = 'Новый пароль должен отличаться от старого';
      isValid = false;
    }

    setState(() {});

    return isValid;
  }

  Future<void> _changePassword() async {
    if (!_validate()) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      final result = await ProfileService.changePassword(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Пароль успешно изменен.'),
        ),
      );

      context.pop();
    } on ApiException catch (error) {
      setState(() {
        _generalError = error.message;
      });
    } catch (_) {
      setState(() {
        _generalError = 'Не удалось изменить пароль.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сменить пароль'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 520 : double.infinity,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    Text(
                      'Смена пароля',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Введите старый пароль и новый пароль для аккаунта.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppCard(
                      hasShadow: false,
                      child: Column(
                        children: [
                          AppTextField(
                            controller: _oldPasswordController,
                            label: 'Старый пароль',
                            hint: 'Введите старый пароль',
                            obscureText: _obscureOldPassword,
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: _obscureOldPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            onSuffixTap: () {
                              setState(() {
                                _obscureOldPassword = !_obscureOldPassword;
                              });
                            },
                            errorText: _oldPasswordError,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            controller: _newPasswordController,
                            label: 'Новый пароль',
                            hint: 'Минимум 6 символов',
                            obscureText: _obscureNewPassword,
                            prefixIcon: Icons.lock_reset_rounded,
                            suffixIcon: _obscureNewPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            onSuffixTap: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                            errorText: _newPasswordError,
                          ),
                          if (_generalError != null) ...[
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              _generalError!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          AppButton(
                            text: 'Сохранить новый пароль',
                            isLoading: _isLoading,
                            onPressed: _changePassword,
                          ),
                        ],
                      ),
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