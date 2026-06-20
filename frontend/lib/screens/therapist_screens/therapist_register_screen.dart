import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/app_routes.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';

class TherapistRegisterScreen extends StatefulWidget {
  const TherapistRegisterScreen({super.key});

  @override
  State<TherapistRegisterScreen> createState() =>
      _TherapistRegisterScreenState();
}

class _TherapistRegisterScreenState extends State<TherapistRegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _qualificationController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  String? _nameError;
  String? _fullNameError;
  String? _emailError;
  String? _passwordError;
  String? _qualificationError;
  String? _generalError;

  @override
  void dispose() {
    _nameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _qualificationController.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _nameError = null;
      _fullNameError = null;
      _emailError = null;
      _passwordError = null;
      _qualificationError = null;
      _generalError = null;
    });

    final name = _nameController.text.trim();
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final qualification = _qualificationController.text.trim();

    bool isValid = true;

    if (name.isEmpty) {
      _nameError = 'Введите имя';
      isValid = false;
    }

    if (fullName.isEmpty) {
      _fullNameError = 'Введите ФИО';
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

    if (qualification.isEmpty) {
      _qualificationError = 'Введите квалификацию';
      isValid = false;
    }

    setState(() {});
    return isValid;
  }

  Future<void> _registerTherapist() async {
    if (!_validate()) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      await AuthService.registerTherapist(
        name: _nameController.text.trim(),
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        qualification: _qualificationController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Аккаунт специалиста создан. Войдите и заполните анкету для модерации.',
          ),
        ),
      );

      context.go(AppRoutes.login);
    } on ApiException catch (error) {
      setState(() {
        _generalError = error.message;
      });
    } catch (_) {
      setState(() {
        _generalError = 'Не удалось создать аккаунт специалиста.';
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
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Аккаунт специалиста',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Создайте аккаунт специалиста. После входа нужно будет заполнить анкету для модерации.',
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
                              hint: 'Как отображать в приложении?',
                              textInputAction: TextInputAction.next,
                              prefixIcon: Icons.person_outline_rounded,
                              errorText: _nameError,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: _fullNameController,
                              label: 'ФИО',
                              hint: 'Полное имя специалиста',
                              textInputAction: TextInputAction.next,
                              prefixIcon: Icons.badge_outlined,
                              errorText: _fullNameError,
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
                              textInputAction: TextInputAction.next,
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
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: _qualificationController,
                              label: 'Квалификация',
                              hint: 'Например: психолог, КПТ-консультант',
                              maxLines: 3,
                              textInputAction: TextInputAction.done,
                              prefixIcon: Icons.school_outlined,
                              errorText: _qualificationError,
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
                              text: 'Создать аккаунт специалиста',
                              isLoading: _isLoading,
                              onPressed: _registerTherapist,
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