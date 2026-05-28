import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/token_storage.dart';
import '../../utils/role_helper.dart';
import '../../widgets/app_loading.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 500));

    final hasToken = await TokenStorage.hasToken();

    if (!mounted) return;

    if (!hasToken) {
      context.go(AppRoutes.onboarding);
      return;
    }

    try {
      final user = await AuthService.me(forceRefresh: true);

      if (!mounted) return;

      context.go(
        RoleHelper.startRouteForRole(user.role),
      );
    } catch (_) {
      await AuthService.logout();

      if (!mounted) return;

      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AppLoading(
        text: 'Загрузка...',
      ),
    );
  }
}