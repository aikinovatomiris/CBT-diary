import 'dart:ui';

import 'package:flutter/cupertino.dart';
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
            icon: Icons.grid_view_rounded,
            selectedIcon: Icons.grid_view_rounded,
            route: AppRoutes.home,
          ),
          _MainNavItem(
            label: 'Практики',
            icon: CupertinoIcons.sparkles,
            selectedIcon: CupertinoIcons.sparkles,
            route: AppRoutes.practices,
          ),
          _MainNavItem(
            label: 'Дневник',
            icon: CupertinoIcons.book,
            selectedIcon: CupertinoIcons.book_fill,
            route: AppRoutes.diary,
          ),
          _MainNavItem(
            label: 'Специалисты',
            icon: CupertinoIcons.person_2,
            selectedIcon: CupertinoIcons.person_2_fill,
            route: AppRoutes.therapistCatalog,
          ),
          _MainNavItem(
            label: 'Профиль',
            icon: CupertinoIcons.person,
            selectedIcon: CupertinoIcons.person_fill,
            route: AppRoutes.profile,
          ),
        ];

      case UserRole.therapist:
        return const [
          _MainNavItem(
            label: 'Главная',
            icon: Icons.grid_view_rounded,
            selectedIcon: Icons.grid_view_rounded,
            route: AppRoutes.therapistHome,
          ),
          _MainNavItem(
            label: 'Анкета',
            icon: CupertinoIcons.doc_text,
            selectedIcon: CupertinoIcons.doc_text_fill,
            route: AppRoutes.therapistCard,
          ),
          _MainNavItem(
            label: 'Сообщения',
            icon: CupertinoIcons.chat_bubble_2,
            selectedIcon: CupertinoIcons.chat_bubble_2_fill,
            route: AppRoutes.therapistMessages,
          ),
          _MainNavItem(
            label: 'Практики',
            icon: CupertinoIcons.sparkles,
            selectedIcon: CupertinoIcons.sparkles,
            route: AppRoutes.practices,
          ),
          _MainNavItem(
            label: 'Профиль',
            icon: CupertinoIcons.person,
            selectedIcon: CupertinoIcons.person_fill,
            route: AppRoutes.profile,
          ),
        ];

      case UserRole.admin:
        return const [
          _MainNavItem(
            label: 'Админ',
            icon: CupertinoIcons.slider_horizontal_3,
            selectedIcon: CupertinoIcons.slider_horizontal_3,
            route: AppRoutes.adminHome,
          ),
          _MainNavItem(
            label: 'Терапевты',
            icon: CupertinoIcons.person_2,
            selectedIcon: CupertinoIcons.person_2_fill,
            route: AppRoutes.adminTherapists,
          ),
          _MainNavItem(
            label: 'Профиль',
            icon: CupertinoIcons.person,
            selectedIcon: CupertinoIcons.person_fill,
            route: AppRoutes.profile,
          ),
        ];
    }
  }

  int _currentIndex(
    List<_MainNavItem> items,
  ) {
    final currentPath = _normalizeLocation(
      currentLocation,
    );

    int selectedIndex = -1;
    int selectedRouteLength = -1;

    for (int i = 0; i < items.length; i++) {
      final route = items[i].route;

      final isExactMatch =
          currentPath == route;

      final isNestedMatch =
          currentPath.startsWith(
        '$route/',
      );

      if ((isExactMatch || isNestedMatch) &&
          route.length > selectedRouteLength) {
        selectedIndex = i;
        selectedRouteLength = route.length;
      }
    }

    return selectedIndex == -1
        ? 0
        : selectedIndex;
  }

  String _normalizeLocation(
    String location,
  ) {
    final uri = Uri.tryParse(location);

    if (uri == null || uri.path.isEmpty) {
      return location;
    }

    return uri.path;
  }

  void _onTap(
    BuildContext context,
    List<_MainNavItem> items,
    int index,
  ) {
    final selectedRoute = items[index].route;

    final currentPath = _normalizeLocation(
      currentLocation,
    );

    if (currentPath == selectedRoute) {
      return;
    }

    context.go(selectedRoute);
  }

  @override
  Widget build(BuildContext context) {
    final role =
        AuthService.cachedUser?.role ??
        'user';

    final items = _itemsForRole(role);

    final selectedIndex = _currentIndex(
      items,
    );

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
            onTap: (index) {
              _onTap(
                context,
                items,
                index,
              );
            },
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

    final isDark =
        theme.brightness ==
        Brightness.dark;

    final navBackground = AppColors.darkSurface;

    final navOverlay = AppColors.darkSurface;

    final navBorder = AppColors.darkBorder;

    final shadowColor = AppColors.darkShadow.withValues(
      alpha: 0.28,
    );

    return Positioned(
      left: 16,
      right: 16,
      bottom: 0,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        minimum: const EdgeInsets.only(
          bottom: 10,
        ),
        child: ClipRRect(
          borderRadius: AppRadius.extraLarge,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: isDark ? 10 : 18,
              sigmaY: isDark ? 10 : 18,
            ),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: navBackground,
                borderRadius:
                    AppRadius.extraLarge,
                border: Border.all(
                  color: navBorder,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius:
                        isDark ? 22 : 28,
                    offset: const Offset(
                      0,
                      10,
                    ),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: navOverlay,
                  borderRadius:
                      AppRadius.extraLarge,
                ),
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 7,
                ),
                child: Row(
                  children: List.generate(
                    items.length,
                    (index) {
                      final item = items[index];

                      return _NavItem(
                        icon: item.icon,
                        selectedIcon:
                            item.selectedIcon,
                        label: item.label,
                        isSelected:
                            selectedIndex == index,
                        onTap: () {
                          onTap(index);
                        },
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
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    final selectedColor = AppColors.darkPrimary;

    final unselectedColor = AppColors.darkMutedText;

    final selectedBackground = AppColors.darkPrimarySoft;

    final selectedBorder = AppColors.darkPrimary.withValues(
      alpha: 0.16,
    );

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(
                milliseconds: 180,
              ),
              curve: Curves.easeOutCubic,
              width: 46,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedBackground
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: isSelected
                      ? selectedBorder
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: AnimatedScale(
                duration: const Duration(
                  milliseconds: 180,
                ),
                curve: Curves.easeOutCubic,
                scale: isSelected ? 1.04 : 1,
                child: Icon(
                  isSelected
                      ? selectedIcon
                      : icon,
                  size: isSelected ? 24 : 23,
                  color: isSelected
                      ? selectedColor
                      : unselectedColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainNavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;

  const _MainNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });
}