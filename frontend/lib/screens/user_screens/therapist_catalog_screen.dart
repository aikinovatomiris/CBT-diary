import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/therapist_profile_model.dart';
import '../../services/api_exception.dart';
import '../../services/therapist_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/url_helper.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/user_messages_action.dart';
import '../../widgets/app_text_field.dart';

class TherapistCatalogScreen extends StatefulWidget {
  const TherapistCatalogScreen({
    super.key,
  });

  @override
  State<TherapistCatalogScreen> createState() =>
      _TherapistCatalogScreenState();
}

class _TherapistCatalogScreenState extends State<TherapistCatalogScreen> {
  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _cityController = TextEditingController();

  late Future<List<TherapistProfileModel>> _therapistsFuture;

  List<TherapistProfileModel> _allTherapists = [];

  List<TherapistProfileModel> _filteredTherapists = [];

  final Set<int> _updatingFavoriteIds = <int>{};

  String _searchQuery = '';
  String _cityFilter = '';

  bool? _onlineAvailable;
  bool _favoritesOnly = false;
  String _ratingSortOrder = 'none';

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
      favoritesOnly: _favoritesOnly,
    );

    final approvedTherapists = therapists.where(
      (therapist) {
        return therapist.status == null || therapist.status == 'approved';
      },
    ).toList();

    _allTherapists = approvedTherapists;

    _filteredTherapists = _calculateFilteredTherapists();

    return approvedTherapists;
  }

  Future<void> _refresh() async {
    setState(() {
      _therapistsFuture = _loadTherapists();
    });

    await _therapistsFuture;
  }

  void _onSearchChanged(
    String value,
  ) {
    _searchQuery = value.trim().toLowerCase();

    _applyFilters();
  }

  void _onCityChanged(
    String value,
  ) {
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

  void _toggleFavoritesFilter() {
    setState(() {
      _favoritesOnly = !_favoritesOnly;

      _therapistsFuture = _loadTherapists();
    });
  }

  void _setRatingSortOrder(
    String order,
  ) {
    setState(() {
      _ratingSortOrder = order;
      _applyFilters();
    });
  }

  void _setOnlineAvailable(
    bool? value,
  ) {
    setState(() {
      _onlineAvailable = value;
      _therapistsFuture = _loadTherapists();
    });
  }

  List<TherapistProfileModel> _calculateFilteredTherapists() {
    var filtered = _allTherapists.where(
      (therapist) {
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

        final matchesFavorite = !_favoritesOnly || therapist.isFavorite;

        final isApproved =
            therapist.status == null || therapist.status == 'approved';

        return isApproved &&
            matchesSearch &&
            matchesCity &&
            matchesOnline &&
            matchesFavorite;
      },
    ).toList();

    if (_ratingSortOrder == 'highest') {
      filtered.sort(
        (a, b) {
          final aRating = a.averageRating ?? 0.0;
          final bRating = b.averageRating ?? 0.0;
          return bRating.compareTo(aRating);
        },
      );
    }

    return filtered;
  }

  void _applyFilters() {
    if (!mounted) {
      return;
    }

    setState(() {
      _filteredTherapists = _calculateFilteredTherapists();
    });
  }

  Future<void> _toggleFavorite(
    TherapistProfileModel therapist,
  ) async {
    final profileId = therapist.id;

    if (profileId == null) {
      _showSnackBar(
        'У профиля специалиста нет ID.',
      );

      return;
    }

    if (_updatingFavoriteIds.contains(profileId)) {
      return;
    }

    final oldValue = therapist.isFavorite;

    final optimisticValue = !oldValue;

    _replaceTherapistFavoriteState(
      profileId: profileId,
      isFavorite: optimisticValue,
      isUpdating: true,
    );

    try {
      final savedValue = await TherapistService.setFavorite(
        profileId: profileId,
        isFavorite: optimisticValue,
      );

      if (!mounted) {
        return;
      }

      _replaceTherapistFavoriteState(
        profileId: profileId,
        isFavorite: savedValue,
        isUpdating: false,
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _replaceTherapistFavoriteState(
        profileId: profileId,
        isFavorite: oldValue,
        isUpdating: false,
      );

      _showSnackBar(
        error.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _replaceTherapistFavoriteState(
        profileId: profileId,
        isFavorite: oldValue,
        isUpdating: false,
      );

      _showSnackBar(
        'Не удалось изменить закладку.',
      );
    }
  }

  void _replaceTherapistFavoriteState({
    required int profileId,
    required bool isFavorite,
    required bool isUpdating,
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      _allTherapists = _allTherapists.map(
        (therapist) {
          if (therapist.id != profileId) {
            return therapist;
          }

          return therapist.copyWith(
            isFavorite: isFavorite,
          );
        },
      ).toList();

      if (isUpdating) {
        _updatingFavoriteIds.add(profileId);
      } else {
        _updatingFavoriteIds.remove(profileId);
      }

      _filteredTherapists = _calculateFilteredTherapists();
    });
  }

  Future<void> _openTherapist(
    TherapistProfileModel therapist,
  ) async {
    final id = therapist.id;

    if (id == null) {
      _showSnackBar(
        'У профиля специалиста нет ID.',
      );

      return;
    }

    await context.push('/specialists/$id');

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  void _showSnackBar(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
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
          favoritesOnly: _favoritesOnly,
          onlineAvailable: _onlineAvailable,
          ratingSortOrder: _ratingSortOrder,
          updatingFavoriteIds: _updatingFavoriteIds,
          onSearchChanged: _onSearchChanged,
          onCityChanged: _onCityChanged,
          onSetOnlineAvailable: _setOnlineAvailable,
          onSetRatingSortOrder: _setRatingSortOrder,
          onToggleFavoritesFilter: _toggleFavoritesFilter,
          onToggleFavorite: _toggleFavorite,
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
  final bool favoritesOnly;

  final bool? onlineAvailable;
  final String ratingSortOrder;

  final Set<int> updatingFavoriteIds;

  final ValueChanged<String> onSearchChanged;

  final ValueChanged<String> onCityChanged;

  final ValueChanged<bool?> onSetOnlineAvailable;

  final ValueChanged<String> onSetRatingSortOrder;

  final VoidCallback onToggleFavoritesFilter;

  final ValueChanged<TherapistProfileModel> onToggleFavorite;

  final Future<void> Function() onRefresh;

  final ValueChanged<TherapistProfileModel> onOpenTherapist;

  const _TherapistCatalogContent({
    required this.searchController,
    required this.cityController,
    required this.therapists,
    required this.hasAnyTherapists,
    required this.favoritesOnly,
    required this.onlineAvailable,
    required this.ratingSortOrder,
    required this.updatingFavoriteIds,
    required this.onSearchChanged,
    required this.onCityChanged,
    required this.onSetOnlineAvailable,
    required this.onSetRatingSortOrder,
    required this.onToggleFavoritesFilter,
    required this.onToggleFavorite,
    required this.onRefresh,
    required this.onOpenTherapist,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final isWide = constraints.maxWidth > 760;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 720 : double.infinity,
                ),
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      110,
                    ),
                    children: [
                      const _CatalogHeader(),
                      const SizedBox(
                        height: AppSpacing.xl,
                      ),
                      AppTextField(
                        controller: searchController,
                        hint:
                            'Поиск по ФИО, квалификации, специализации или подходу',
                        prefixIcon: Icons.search_rounded,
                        onChanged: onSearchChanged,
                      ),
                      const SizedBox(
                        height: AppSpacing.md,
                      ),
                      AppTextField(
                        controller: cityController,
                        hint: 'Фильтр по городу',
                        prefixIcon: Icons.location_city_outlined,
                        onChanged: onCityChanged,
                      ),
                      const SizedBox(
                        height: AppSpacing.md,
                      ),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _FilterMenuButton(
                            onlineAvailable: onlineAvailable,
                            ratingSortOrder: ratingSortOrder,
                            onSetOnlineAvailable: onSetOnlineAvailable,
                            onSetRatingSortOrder: onSetRatingSortOrder,
                          ),
                          _CatalogFilterButton(
                            title: favoritesOnly
                                ? 'В закладках'
                                : 'Все специалисты',
                            icon: favoritesOnly
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            isActive: favoritesOnly,
                            onTap: onToggleFavoritesFilter,
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: AppSpacing.lg,
                      ),
                      if (favoritesOnly && therapists.isEmpty)
                        const _EmptyFavoritesState()
                      else if (!hasAnyTherapists)
                        const _EmptyTherapistsState()
                      else if (therapists.isEmpty)
                        const _NoTherapistSearchResultsState()
                      else
                        ...therapists.map(
                          (therapist) {
                            final id = therapist.id;

                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.lg,
                              ),
                              child: _TherapistCard(
                                therapist: therapist,
                                isFavoriteUpdating: id != null &&
                                    updatingFavoriteIds.contains(id),
                                onToggleFavorite: () {
                                  onToggleFavorite(therapist);
                                },
                                onTap: () {
                                  onOpenTherapist(therapist);
                                },
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
                const SizedBox(
                  height: AppSpacing.sm,
                ),
                Text(
                  'Каталог одобренных терапевтов',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: AppSpacing.md,
          ),
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
                ? AppColors.darkShadow.withOpacity(0.05)
                : AppColors.lightShadow.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
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

class _FilterMenuButton extends StatelessWidget {
  final bool? onlineAvailable;
  final String ratingSortOrder;
  final ValueChanged<bool?> onSetOnlineAvailable;
  final ValueChanged<String> onSetRatingSortOrder;

  const _FilterMenuButton({
    required this.onlineAvailable,
    required this.ratingSortOrder,
    required this.onSetOnlineAvailable,
    required this.onSetRatingSortOrder,
  });

  String _getFilterTitle() {
    final hasOnlineFilter = onlineAvailable != null;
    final hasRatingFilter = ratingSortOrder != 'none';

    if (hasOnlineFilter && hasRatingFilter) {
      return 'Фильтры активны';
    }

    if (hasOnlineFilter || hasRatingFilter) {
      return 'Фильтр активен';
    }

    return 'Фильтры';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    final hasActiveFilters = onlineAvailable != null || ratingSortOrder != 'none';

    final backgroundColor = hasActiveFilters
        ? theme.colorScheme.primary.withOpacity(isDark ? 0.18 : 0.11)
        : isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface;

    final borderColor = hasActiveFilters
        ? theme.colorScheme.primary.withOpacity(isDark ? 0.28 : 0.16)
        : isDark
            ? AppColors.darkBorder
            : AppColors.lightBorder;

    final contentColor = hasActiveFilters
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;

    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.large,
      ),
      onSelected: (value) {},
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem<String>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Формат',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: AppSpacing.sm,
                ),
                _FilterMenuOption(
                  title: 'Все форматы',
                  isSelected: onlineAvailable == null,
                  onTap: () {
                    onSetOnlineAvailable(null);
                    Navigator.pop(context);
                  },
                ),
                _FilterMenuOption(
                  title: 'Только онлайн',
                  isSelected: onlineAvailable == true,
                  onTap: () {
                    onSetOnlineAvailable(true);
                    Navigator.pop(context);
                  },
                ),
                _FilterMenuOption(
                  title: 'Только очно',
                  isSelected: onlineAvailable == false,
                  onTap: () {
                    onSetOnlineAvailable(false);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(
                  height: AppSpacing.md,
                ),
                Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(
                  height: AppSpacing.md,
                ),
                Text(
                  'Рейтинг',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: AppSpacing.sm,
                ),
                _FilterMenuOption(
                  title: 'По умолчанию',
                  isSelected: ratingSortOrder == 'none',
                  onTap: () {
                    onSetRatingSortOrder('none');
                    Navigator.pop(context);
                  },
                ),
                _FilterMenuOption(
                  title: 'Самый высокий рейтинг',
                  isSelected: ratingSortOrder == 'highest',
                  onTap: () {
                    onSetRatingSortOrder('highest');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ];
      },
      child: Material(
        color: Colors.transparent,
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
              const SizedBox(
                width: AppSpacing.sm,
              ),
              Text(
                _getFilterTitle(),
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

class _FilterMenuOption extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterMenuOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 20,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(
              width: AppSpacing.sm,
            ),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogFilterButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _CatalogFilterButton({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

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
                icon,
                size: 17,
                color: contentColor,
              ),
              const SizedBox(
                width: AppSpacing.sm,
              ),
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

  final bool isFavoriteUpdating;

  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const _TherapistCard({
    required this.therapist,
    required this.isFavoriteUpdating,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final photoUrl = UrlHelper.buildFileUrl(
      therapist.photoUrl,
    );

    final hasPhoto = photoUrl.isNotEmpty;

    final name = _safeText(
      therapist.fullName,
      'Специалист',
    );

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
              const SizedBox(
                width: AppSpacing.md,
              ),
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
                    const SizedBox(
                      height: AppSpacing.xs,
                    ),
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
              const SizedBox(
                width: AppSpacing.xs,
              ),
              _FavoriteIconButton(
                isFavorite: therapist.isFavorite,
                isLoading: isFavoriteUpdating,
                onPressed: onToggleFavorite,
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ],
          ),
          const SizedBox(
            height: AppSpacing.md,
          ),
          _TherapistRatingSummary(
            averageRating: therapist.averageRating,
            ratingsCount: therapist.ratingsCount,
          ),
          if (therapist.specializations.isNotEmpty) ...[
            const SizedBox(
              height: AppSpacing.lg,
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: therapist.specializations
                  .take(4)
                  .map(
                    (item) => _Chip(
                      text: item,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(
            height: AppSpacing.lg,
          ),
          _TherapistInfoPanel(
            children: [
              _InfoLine(
                icon: Icons.location_on_outlined,
                text: _safeText(
                  therapist.city,
                  'Город не указан',
                ),
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
        ],
      ),
    );
  }

  String _safeText(
    String? value,
    String fallback,
  ) {
    if (value == null || value.trim().isEmpty) {
      return fallback;
    }

    return value.trim();
  }
}

class _TherapistRatingSummary extends StatelessWidget {
  final double? averageRating;
  final int ratingsCount;

  const _TherapistRatingSummary({
    required this.averageRating,
    required this.ratingsCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hasRating = averageRating != null && ratingsCount > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          hasRating ? Icons.star_rounded : Icons.star_border_rounded,
          size: 19,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(
          width: AppSpacing.xs,
        ),
        Text(
          hasRating ? averageRating!.toStringAsFixed(1) : 'Нет оценок',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: hasRating
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (hasRating) ...[
          const SizedBox(
            width: AppSpacing.xs,
          ),
          Text(
            '· ${_formatRatingsCount(ratingsCount)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  static String _formatRatingsCount(
    int count,
  ) {
    final lastTwoDigits = count % 100;
    final lastDigit = count % 10;

    if (lastTwoDigits >= 11 && lastTwoDigits <= 14) {
      return '$count оценок';
    }

    if (lastDigit == 1) {
      return '$count оценка';
    }

    if (lastDigit >= 2 && lastDigit <= 4) {
      return '$count оценки';
    }

    return '$count оценок';
  }
}

class _FavoriteIconButton extends StatelessWidget {
  final bool isFavorite;
  final bool isLoading;
  final VoidCallback onPressed;

  const _FavoriteIconButton({
    required this.isFavorite,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IconButton(
      tooltip: isFavorite ? 'Удалить из закладок' : 'Добавить в закладки',
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
          : Icon(
              isFavorite
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: theme.colorScheme.primary,
              size: 23,
            ),
    );
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            Flexible(
              fit: FlexFit.loose,
              child: children[i],
            ),
            if (i != children.length - 1)
              const SizedBox(
                width: AppSpacing.md,
              ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        _InfoIcon(
          icon: icon,
        ),
        const SizedBox(
          width: AppSpacing.xs,
        ),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
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

    return Icon(
      icon,
      size: 16,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }
}

class _EmptyFavoritesState extends StatelessWidget {
  const _EmptyFavoritesState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _EmptyIcon(
            icon: Icons.bookmark_border_rounded,
          ),
          const SizedBox(
            height: AppSpacing.md,
          ),
          Text(
            'В закладках пока пусто',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(
            height: AppSpacing.sm,
          ),
          Text(
            'Добавляй подходящих специалистов в закладки, чтобы быстро находить их позже.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
          const _EmptyIcon(
            icon: Icons.person_search_rounded,
          ),
          const SizedBox(
            height: AppSpacing.md,
          ),
          Text(
            'Пока нет одобренных специалистов',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(
            height: AppSpacing.sm,
          ),
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
          const _EmptyIcon(
            icon: Icons.search_off_rounded,
          ),
          const SizedBox(
            height: AppSpacing.md,
          ),
          Text(
            'Специалисты не найдены',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(
            height: AppSpacing.sm,
          ),
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