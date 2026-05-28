import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/therapist_profile_model.dart';
import '../../services/api_exception.dart';
import '../../services/therapist_service.dart';
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

      final matchesOnline = _onlineAvailable == null ||
          therapist.onlineAvailable == _onlineAvailable;

      final isApproved = therapist.status == null || therapist.status == 'approved';

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
            appBar: AppBar(
              title: const Text('Специалисты'),
              actions: const [
                UserMessagesAction(),
              ],
            ),
            body: AppErrorView(
              message: message,
              onRetry: _refresh,
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Специалисты'),
        actions: const [
          UserMessagesAction(),
        ],
      ),
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
                      Text(
                        'Каталог специалистов',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Здесь отображаются специалисты, анкеты которых одобрены модерацией.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

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
                        child: TextButton.icon(
                          onPressed: onToggleOnlineFilter,
                          icon: const Icon(Icons.tune_rounded),
                          label: Text(onlineFilterTitle),
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

    return AppCard(
      hasShadow: false,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.12),
                backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                child: hasPhoto
                    ? null
                    : Icon(
                        Icons.person_rounded,
                        color: theme.colorScheme.primary,
                        size: 34,
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _safeText(therapist.fullName, 'Специалист'),
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _safeText(therapist.qualification, 'Квалификация не указана'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          if (therapist.specializations.isNotEmpty) ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: therapist.specializations.take(4).map((item) {
                return _Chip(text: item);
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          _InfoLine(
            icon: Icons.location_on_outlined,
            text: _safeText(therapist.city, 'Город не указан'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoLine(
            icon: Icons.payments_outlined,
            text: therapist.price == null || therapist.price!.trim().isEmpty
                ? 'Цена не указана'
                : therapist.price!.trim(),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoLine(
            icon: Icons.wifi_rounded,
            text: therapist.onlineAvailable == true
                ? 'Онлайн'
                : 'Очно / по договоренности',
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

class _Chip extends StatelessWidget {
  final String text;

  const _Chip({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: AppRadius.large,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
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
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
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
      child: Text(
        'Пока нет одобренных специалистов.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
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
      child: Text(
        'По вашему запросу специалисты не найдены.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}