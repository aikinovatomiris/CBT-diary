import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../utils/role_helper.dart';
import 'app_routes.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  final String currentLocation;

  const MainScaffold({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  List<_MainNavItem> _itemsForRole(String role) {
    final userRole = RoleHelper.parse(role);

    switch (userRole) {
      case UserRole.user:
        return const [
          _MainNavItem(
            label: 'Главная',
            icon: Icons.home_rounded,
            route: AppRoutes.home,
          ),
          _MainNavItem(
            label: 'Практики',
            icon: Icons.self_improvement_rounded,
            route: AppRoutes.practices,
          ),
          _MainNavItem(
            label: 'Дневник',
            icon: Icons.book_rounded,
            route: AppRoutes.diary,
          ),
          _MainNavItem(
            label: 'Специалисты',
            icon: Icons.psychology_rounded,
            route: AppRoutes.therapistCatalog,
          ),
          _MainNavItem(
            label: 'Профиль',
            icon: Icons.person_rounded,
            route: AppRoutes.profile,
          ),
        ];

      case UserRole.therapist:
        return const [
          _MainNavItem(
            label: 'Главная',
            icon: Icons.home_rounded,
            route: AppRoutes.therapistHome,
          ),
          _MainNavItem(
            label: 'Анкета',
            icon: Icons.badge_rounded,
            route: AppRoutes.therapistCard,
          ),
          _MainNavItem(
            label: 'Клиенты',
            icon: Icons.forum_rounded,
            route: AppRoutes.therapistMessages,
          ),
          _MainNavItem(
            label: 'Практики',
            icon: Icons.self_improvement_rounded,
            route: AppRoutes.practices,
          ),
          _MainNavItem(
            label: 'Профиль',
            icon: Icons.person_rounded,
            route: AppRoutes.profile,
          ),
        ];

      case UserRole.admin:
        return const [
          _MainNavItem(
            label: 'Админ',
            icon: Icons.admin_panel_settings_rounded,
            route: AppRoutes.adminHome,
          ),
          _MainNavItem(
            label: 'Терапевты',
            icon: Icons.psychology_rounded,
            route: AppRoutes.adminTherapists,
          ),
          _MainNavItem(
            label: 'Пользователи',
            icon: Icons.people_rounded,
            route: AppRoutes.adminUsers,
          ),
          _MainNavItem(
            label: 'Статистика',
            icon: Icons.insights_rounded,
            route: AppRoutes.adminStatistics,
          ),
          _MainNavItem(
            label: 'Профиль',
            icon: Icons.person_rounded,
            route: AppRoutes.profile,
          ),
        ];
    }
  }

  int _currentIndex(List<_MainNavItem> items) {
    final index = items.indexWhere((item) {
      if (item.route == AppRoutes.home) {
        return currentLocation == AppRoutes.home;
      }

      return currentLocation.startsWith(item.route);
    });

    return index == -1 ? 0 : index;
  }

  void _onTap(BuildContext context, List<_MainNavItem> items, int index) {
    final selectedRoute = items[index].route;

    if (currentLocation == selectedRoute) return;

    context.go(selectedRoute);
  }

  @override
  Widget build(BuildContext context) {
    final role = AuthService.cachedUser?.role ?? 'user';
    final items = _itemsForRole(role);
    final selectedIndex = _currentIndex(items);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: child,
          ),
          _BottomNavBar(
            items: items,
            selectedIndex: selectedIndex,
            onTap: (index) => _onTap(context, items, index),
          ),
        ],
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final List<_MainNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final navBackground = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.78)
        : AppColors.lightSurface.withValues(alpha: 0.78);

    final navBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.65)
        : AppColors.lightBorder.withValues(alpha: 0.85);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.xl),
          topRight: Radius.circular(AppRadius.xl),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 18,
            sigmaY: 18,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: navBackground,
              border: Border(
                top: BorderSide(
                  color: navBorder,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              minimum: EdgeInsets.zero,
              child: SizedBox(
                height: 68,
                child: Row(
                  children: List.generate(
                    items.length,
                    (index) {
                      final item = items[index];

                      return _NavItem(
                        icon: item.icon,
                        label: item.label,
                        isSelected: selectedIndex == index,
                        onTap: () => onTap(index),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final selectedColor = theme.colorScheme.primary;
    final unselectedColor = theme.colorScheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 23,
                color: isSelected ? selectedColor : unselectedColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected ? selectedColor : unselectedColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainNavItem {
  final String label;
  final IconData icon;
  final String route;

  const _MainNavItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}