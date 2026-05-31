import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/therapist_profile_model.dart';
import '../../services/api_exception.dart';
import '../../services/therapist_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/url_helper.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/user_messages_action.dart';

class TherapistCatalogScreen extends StatefulWidget {
  const TherapistCatalogScreen({super.key});

  @override
  State<TherapistCatalogScreen> createState() => _TherapistCatalogScreenState();
}

class _TherapistCatalogScreenState extends State<TherapistCatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  late Future<List<TherapistProfileModel>> _therapistsFuture;

  List<TherapistProfileModel> _allTherapists = [];
  List<TherapistProfileModel> _filteredTherapists = [];

  String _searchQuery = '';
  String _cityFilter = '';
  bool? _onlineAvailable;

  @override
  void initState() {
    super.initState();
    _therapistsFuture = _loadTherapists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<List<TherapistProfileModel>> _loadTherapists() async {
    final therapists = await TherapistService.getApprovedTherapists(
      city: _cityFilter.isEmpty ? null : _cityFilter,
      onlineAvailable: _onlineAvailable,
    );

    final approvedTherapists = therapists.where((therapist) {
      return therapist.status == null || therapist.status == 'approved';
    }).toList();

    _allTherapists = approvedTherapists;
    _applyFilters();

    return approvedTherapists;
  }

  Future<void> _refresh() async {
    setState(() {
      _therapistsFuture = _loadTherapists();
    });

    await _therapistsFuture;
  }

  void _onSearchChanged(String value) {
    _searchQuery = value.trim().toLowerCase();
    _applyFilters();
  }

  void _onCityChanged(String value) {
    _cityFilter = value.trim().toLowerCase();
    _applyFilters();
  }

  void _toggleOnlineFilter() {
    setState(() {
      if (_onlineAvailable == null) {
        _onlineAvailable = true;
      } else if (_onlineAvailable == true) {
        _onlineAvailable = false;
      } else {
        _onlineAvailable = null;
      }

      _therapistsFuture = _loadTherapists();
    });
  }

  void _applyFilters() {
    final filtered = _allTherapists.where((therapist) {
      final searchText = [
        therapist.fullName,
        therapist.qualification,
        therapist.specializations.join(' '),
        therapist.therapyApproaches.join(' '),
      ].whereType<String>().join(' ').toLowerCase();

      final city = therapist.city?.toLowerCase() ?? '';

      final matchesSearch =
          _searchQuery.isEmpty || searchText.contains(_searchQuery);

      final matchesCity = _cityFilter.isEmpty || city.contains(_cityFilter);

      final matchesOnline =
          _onlineAvailable == null ||
          therapist.onlineAvailable == _onlineAvailable;

      final isApproved =
          therapist.status == null || therapist.status == 'approved';

      return isApproved && matchesSearch && matchesCity && matchesOnline;
    }).toList();

    if (!mounted) return;

    setState(() {
      _filteredTherapists = filtered;
    });
  }

  void _openTherapist(TherapistProfileModel therapist) {
    final id = therapist.id;

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У профиля специалиста нет ID.'),
        ),
      );
      return;
    }

    context.push('/specialists/$id');
  }

  String _onlineFilterTitle() {
    if (_onlineAvailable == null) return 'Все форматы';
    if (_onlineAvailable == true) return 'Только онлайн';
    return 'Только очно';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TherapistProfileModel>>(
      future: _therapistsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: AppLoading(
              text: 'Загрузка специалистов...',
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is ApiException
              ? error.message
              : 'Не удалось загрузить каталог специалистов.';

          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  const _CatalogHeader(
                    compact: true,
                  ),
                  Expanded(
                    child: AppErrorView(
                      message: message,
                      onRetry: _refresh,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return _TherapistCatalogContent(
          searchController: _searchController,
          cityController: _cityController,
          therapists: _filteredTherapists,
          hasAnyTherapists: _allTherapists.isNotEmpty,
          onlineFilterTitle: _onlineFilterTitle(),
          onSearchChanged: _onSearchChanged,
          onCityChanged: _onCityChanged,
          onToggleOnlineFilter: _toggleOnlineFilter,
          onRefresh: _refresh,
          onOpenTherapist: _openTherapist,
        );
      },
    );
  }
}

class _TherapistCatalogContent extends StatelessWidget {
  final TextEditingController searchController;
  final TextEditingController cityController;
  final List<TherapistProfileModel> therapists;
  final bool hasAnyTherapists;
  final String onlineFilterTitle;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCityChanged;
  final VoidCallback onToggleOnlineFilter;
  final Future<void> Function() onRefresh;
  final ValueChanged<TherapistProfileModel> onOpenTherapist;

  const _TherapistCatalogContent({
    required this.searchController,
    required this.cityController,
    required this.therapists,
    required this.hasAnyTherapists,
    required this.onlineFilterTitle,
    required this.onSearchChanged,
    required this.onCityChanged,
    required this.onToggleOnlineFilter,
    required this.onRefresh,
    required this.onOpenTherapist,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 760;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 720 : double.infinity,
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
                      const _CatalogHeader(),

                      const SizedBox(height: AppSpacing.xl),

                      AppTextField(
                        controller: searchController,
                        hint:
                            'Поиск по ФИО, квалификации, специализации или подходу',
                        prefixIcon: Icons.search_rounded,
                        onChanged: onSearchChanged,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      AppTextField(
                        controller: cityController,
                        hint: 'Фильтр по городу',
                        prefixIcon: Icons.location_city_outlined,
                        onChanged: onCityChanged,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: _FormatFilterButton(
                          title: onlineFilterTitle,
                          onTap: onToggleOnlineFilter,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      if (!hasAnyTherapists)
                        const _EmptyTherapistsState()
                      else if (therapists.isEmpty)
                        const _NoTherapistSearchResultsState()
                      else
                        ...therapists.map(
                          (therapist) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.lg,
                              ),
                              child: _TherapistCard(
                                therapist: therapist,
                                onTap: () => onOpenTherapist(therapist),
                              ),
                            );
                          },
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

class _CatalogHeader extends StatelessWidget {
  final bool compact;

  const _CatalogHeader({
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final horizontalPadding = compact ? AppSpacing.xl : 0.0;
    final verticalPadding = compact ? AppSpacing.xl : 0.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        verticalPadding,
        horizontalPadding,
        compact ? AppSpacing.md : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Специалисты',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Каталог одобренных терапевтов',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const _MessagesActionShell(),
        ],
      ),
    );
  }
}

class _MessagesActionShell extends StatelessWidget {
  const _MessagesActionShell();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.large,
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.darkShadow.withOpacity(0.12)
                : AppColors.lightShadow.withOpacity(0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IconTheme(
        data: IconThemeData(
          color: theme.colorScheme.primary,
          size: 21,
        ),
        child: const UserMessagesAction(),
      ),
    );
  }
}

class _FormatFilterButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _FormatFilterButton({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isActive = title != 'Все форматы';

    final backgroundColor = isActive
        ? theme.colorScheme.primary.withOpacity(isDark ? 0.18 : 0.11)
        : isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface;

    final borderColor = isActive
        ? theme.colorScheme.primary.withOpacity(isDark ? 0.28 : 0.16)
        : isDark
            ? AppColors.darkBorder
            : AppColors.lightBorder;

    final contentColor =
        isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.large,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: AppRadius.large,
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 17,
                color: contentColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: contentColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TherapistCard extends StatelessWidget {
  final TherapistProfileModel therapist;
  final VoidCallback onTap;

  const _TherapistCard({
    required this.therapist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = UrlHelper.buildFileUrl(therapist.photoUrl);
    final hasPhoto = photoUrl.isNotEmpty;

    final name = _safeText(therapist.fullName, 'Специалист');
    final qualification = _safeText(
      therapist.qualification,
      'Квалификация не указана',
    );

    return AppCard(
      hasShadow: false,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TherapistAvatar(
                photoUrl: photoUrl,
                hasPhoto: hasPhoto,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.45,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      qualification,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ],
          ),

          if (therapist.specializations.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: therapist.specializations.take(4).map((item) {
                return _Chip(text: item);
              }).toList(),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          _TherapistInfoPanel(
            children: [
              _InfoLine(
                icon: Icons.location_on_outlined,
                text: _safeText(therapist.city, 'Город не указан'),
              ),
              _InfoLine(
                icon: Icons.payments_outlined,
                text: therapist.price == null || therapist.price!.trim().isEmpty
                    ? 'Цена не указана'
                    : therapist.price!.trim(),
              ),
              _InfoLine(
                icon: Icons.laptop_mac_rounded,
                text: therapist.onlineAvailable == true
                    ? 'Онлайн'
                    : 'Очно / по договоренности',
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          AppButton(
            text: 'Подробнее',
            variant: AppButtonVariant.secondary,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }

  String _safeText(String? value, String fallback) {
    if (value == null || value.trim().isEmpty) return fallback;
    return value.trim();
  }
}

class _TherapistAvatar extends StatelessWidget {
  final String photoUrl;
  final bool hasPhoto;

  const _TherapistAvatar({
    required this.photoUrl,
    required this.hasPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary.withOpacity(0.10),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withOpacity(0.10),
        backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
        child: hasPhoto
            ? null
            : Icon(
                Icons.person_outline_rounded,
                color: theme.colorScheme.primary,
                size: 32,
              ),
      ),
    );
  }
}

class _TherapistInfoPanel extends StatelessWidget {
  final List<Widget> children;

  const _TherapistInfoPanel({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark
        ? AppColors.darkSurfaceSoft.withOpacity(0.72)
        : AppColors.white.withOpacity(0.52);

    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.white.withOpacity(0.78);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.large,
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = theme.colorScheme.primary.withOpacity(
      isDark ? 0.16 : 0.10,
    );

    final borderColor = theme.colorScheme.primary.withOpacity(
      isDark ? 0.18 : 0.12,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.large,
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.05,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        _InfoIcon(icon: icon),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: -0.05,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoIcon extends StatelessWidget {
  final IconData icon;

  const _InfoIcon({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 15,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

class _EmptyTherapistsState extends StatelessWidget {
  const _EmptyTherapistsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EmptyIcon(
            icon: Icons.person_search_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Пока нет одобренных специалистов',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Когда администратор одобрит анкеты специалистов, они появятся здесь.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoTherapistSearchResultsState extends StatelessWidget {
  const _NoTherapistSearchResultsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EmptyIcon(
            icon: Icons.search_off_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Специалисты не найдены',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Попробуй изменить поиск, город или формат консультации.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyIcon extends StatelessWidget {
  final IconData icon;

  const _EmptyIcon({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.11),
        borderRadius: AppRadius.large,
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.10),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: theme.colorScheme.primary,
        size: 21,
      ),
    );
  }
}