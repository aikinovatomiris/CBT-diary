import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/app_routes.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/google_auth_service.dart';
import '../../theme/app_spacing.dart';
import '../../utils/role_helper.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  String? _emailError;
  String? _passwordError;
  String? _generalError;

  bool get _isAnyLoading => _isLoading || _isGoogleLoading;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    bool isValid = true;

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

  Future<void> _login() async {
    if (_isAnyLoading) return;
    if (!_validate()) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      await AuthService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = await AuthService.me(forceRefresh: true);

      if (!mounted) return;

      context.go(
        RoleHelper.startRouteForRole(user.role),
      );
    } on ApiException catch (error) {
      setState(() {
        _generalError = error.message;
      });
    } catch (_) {
      setState(() {
        _generalError = 'Не удалось войти. Попробуйте ещё раз.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    if (_isAnyLoading) return;

    setState(() {
      _isGoogleLoading = true;
      _generalError = null;
      _emailError = null;
      _passwordError = null;
    });

    try {
      final idToken = await GoogleAuthService.getGoogleIdToken();

      await AuthService.loginWithGoogleIdToken(
        idToken: idToken,
      );

      final user = await AuthService.me(forceRefresh: true);

      if (!mounted) return;

      context.go(
        RoleHelper.startRouteForRole(user.role),
      );
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _generalError = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _generalError = 'Не удалось войти через Google. Попробуйте ещё раз.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  void _goToRegister() {
    if (_isAnyLoading) return;
    context.go(AppRoutes.register);
  }

  Widget _buildDivider(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Divider(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
          ),
          child: Text(
            'или',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход'),
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
                        'С возвращением',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Войди в аккаунт, чтобы продолжить работу с дневником.',
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
                              hint: 'Введите пароль',
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
                              text: 'Войти',
                              isLoading: _isLoading,
                              onPressed: _login,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _buildDivider(context),
                            const SizedBox(height: AppSpacing.lg),
                            AppButton(
                              text: 'Войти через Google',
                              icon: Icons.g_mobiledata_rounded,
                              variant: AppButtonVariant.ghost,
                              isLoading: _isGoogleLoading,
                              onPressed: _loginWithGoogle,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        text: 'Создать аккаунт',
                        variant: AppButtonVariant.ghost,
                        onPressed: _goToRegister,
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