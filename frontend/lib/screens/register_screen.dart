import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/app_routes.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _generalError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    bool isValid = true;

    if (name.isEmpty) {
      _nameError = 'Введите имя';
      isValid = false;
    }

    if (email.isEmpty) {
      _emailError = 'Введите email';
      isValid = false;
    }

    if (password.isEmpty) {
      _passwordError = 'Введите пароль';
      isValid = false;
    } else if (password.length < 6) {
      _passwordError = 'Пароль должен быть не короче 6 символов';
      isValid = false;
    }

    setState(() {});
    return isValid;
  }

  Future<void> _register() async {
    if (!_validate()) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      await AuthService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Аккаунт создан. Теперь войдите в приложение.'),
        ),
      );

      context.go(AppRoutes.login);
    } on ApiException catch (error) {
      setState(() {
        _generalError = error.message;
      });
    } catch (_) {
      setState(() {
        _generalError = 'Не удалось создать аккаунт. Попробуйте ещё раз.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _goToLogin() {
    context.go(AppRoutes.login);
  }

  void _goToTherapistRegister() {
    context.push(AppRoutes.registerTherapist);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 650;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 480 : double.infinity,
                ),
                child: Padding(
                  padding: AppSpacing.screenPadding,
                  child: ListView(
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Создать аккаунт',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Зарегистрируйся, чтобы сохранять КПТ-сессии и дневниковые записи.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      AppCard(
                        hasShadow: false,
                        child: Column(
                          children: [
                            AppTextField(
                              controller: _nameController,
                              label: 'Имя',
                              hint: 'Как к тебе обращаться?',
                              textInputAction: TextInputAction.next,
                              prefixIcon: Icons.person_outline_rounded,
                              errorText: _nameError,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: _emailController,
                              label: 'Email',
                              hint: 'example@mail.com',
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              prefixIcon: Icons.email_outlined,
                              errorText: _emailError,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: _passwordController,
                              label: 'Пароль',
                              hint: 'Минимум 6 символов',
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              prefixIcon: Icons.lock_outline_rounded,
                              suffixIcon: _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              onSuffixTap: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              errorText: _passwordError,
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
                              text: 'Зарегистрироваться',
                              isLoading: _isLoading,
                              onPressed: _register,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        text: 'Уже есть аккаунт',
                        variant: AppButtonVariant.ghost,
                        onPressed: _goToLogin,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        text: 'Я специалист',
                        variant: AppButtonVariant.ghost,
                        onPressed: _goToTherapistRegister,
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