// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/diary_entry_model.dart';
import '../../services/api_exception.dart';
import '../../services/diary_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_text_field.dart';

class DiaryListScreen extends StatefulWidget {
  const DiaryListScreen({super.key});

  @override
  State<DiaryListScreen> createState() => _DiaryListScreenState();
}

class _DiaryListScreenState extends State<DiaryListScreen> {
  final TextEditingController _searchController = TextEditingController();

  late Future<List<DiaryEntryModel>> _entriesFuture;

  List<DiaryEntryModel> _allEntries = [];
  List<DiaryEntryModel> _filteredEntries = [];

  String _searchQuery = '';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _loadEntries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<DiaryEntryModel>> _loadEntries() async {
    final entries = await DiaryService.getEntries();

    entries.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    _allEntries = entries;
    _applyFilters();

    return entries;
  }

  Future<void> _refresh() async {
    setState(() {
      _entriesFuture = _loadEntries();
    });

    await _entriesFuture;
  }

  void _onSearchChanged(String value) {
    _searchQuery = value.trim().toLowerCase();
    _applyFilters();
  }

  void _applyFilters() {
    var result = [..._allEntries];

    final selectedDate = _selectedDate;

    if (selectedDate != null) {
      result = result.where((entry) {
        final createdAt = entry.createdAt;

        if (createdAt == null) {
          return false;
        }

        return _isSameDate(createdAt.toLocal(), selectedDate);
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      result = result.where((entry) {
        final situation = entry.situation?.toLowerCase() ?? '';
        final automaticThought = entry.automaticThought?.toLowerCase() ?? '';
        final alternativeThought =
            entry.alternativeThought?.toLowerCase() ?? '';
        final conclusion = entry.conclusion?.toLowerCase() ?? '';

        return situation.contains(_searchQuery) ||
            automaticThought.contains(_searchQuery) ||
            alternativeThought.contains(_searchQuery) ||
            conclusion.contains(_searchQuery);
      }).toList();
    }

    _filteredEntries = result;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final initialDate = _selectedDate ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Выбери дату',
      cancelText: 'Отмена',
      confirmText: 'Готово',
      builder: (context, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: AppColors.white,
              surface: isDark ? AppColors.darkSurface : AppColors.lightBackground,
              onSurface: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor:
                  isDark ? AppColors.darkSurface : AppColors.lightBackground,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.extraLarge,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
    });

    _applyFilters();
  }

  void _resetDateFilter() {
    setState(() {
      _selectedDate = null;
    });

    _applyFilters();
  }

  bool _hasEntriesForSelectedDate() {
    final selectedDate = _selectedDate;

    if (selectedDate == null) {
      return true;
    }

    return _allEntries.any((entry) {
      final createdAt = entry.createdAt;

      if (createdAt == null) {
        return false;
      }

      return _isSameDate(createdAt.toLocal(), selectedDate);
    });
  }

  Future<void> _openEntry(DiaryEntryModel entry) async {
    final id = entry.id;

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У записи нет ID.'),
        ),
      );
      return;
    }

    await context.push('/diary/$id');

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Дата не указана';

    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();

    return '$day.$month.$year';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();

    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  String _safeText(String? value, {String fallback = 'Не заполнено'}) {
    if (value == null || value.trim().isEmpty) {
      return fallback;
    }

    return value.trim();
  }

  String? _formatEmotion(dynamic value) {
    if (value == null) return null;

    if (value is Map) {
      final rawText = value['raw_text'];

      if (rawText != null && rawText.toString().trim().isNotEmpty) {
        return rawText.toString().trim();
      }

      final items = value['items'];

      if (items is List && items.isNotEmpty) {
        return items.map((item) => item.toString()).join(', ');
      }

      if (value.isNotEmpty) {
        return value.entries.map((entry) {
          return '${entry.key}: ${entry.value}';
        }).join(', ');
      }
    }

    final text = value.toString().trim();

    if (text.isEmpty || text == '{}') {
      return null;
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DiaryEntryModel>>(
      future: _entriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: AppLoading(
              text: 'Загрузка дневника...',
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is ApiException
              ? error.message
              : 'Не удалось загрузить дневник.';

          return Scaffold(
            body: AppErrorView(
              message: message,
              onRetry: _refresh,
            ),
          );
        }

        return _DiaryListContent(
          searchController: _searchController,
          entries: _filteredEntries,
          hasAnyEntries: _allEntries.isNotEmpty,
          selectedDate: _selectedDate,
          hasEntriesForSelectedDate: _hasEntriesForSelectedDate(),
          searchQuery: _searchQuery,
          onSearchChanged: _onSearchChanged,
          onPickDate: _pickDate,
          onResetDateFilter: _resetDateFilter,
          onRefresh: _refresh,
          onOpenEntry: _openEntry,
          formatDate: _formatDate,
          safeText: _safeText,
          formatEmotion: _formatEmotion,
        );
      },
    );
  }
}

class _DiaryListContent extends StatelessWidget {
  final TextEditingController searchController;
  final List<DiaryEntryModel> entries;
  final bool hasAnyEntries;
  final DateTime? selectedDate;
  final bool hasEntriesForSelectedDate;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPickDate;
  final VoidCallback onResetDateFilter;
  final Future<void> Function() onRefresh;
  final ValueChanged<DiaryEntryModel> onOpenEntry;
  final String Function(DateTime?) formatDate;
  final String Function(String?, {String fallback}) safeText;
  final String? Function(dynamic) formatEmotion;

  const _DiaryListContent({
    required this.searchController,
    required this.entries,
    required this.hasAnyEntries,
    required this.selectedDate,
    required this.hasEntriesForSelectedDate,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onPickDate,
    required this.onResetDateFilter,
    required this.onRefresh,
    required this.onOpenEntry,
    required this.formatDate,
    required this.safeText,
    required this.formatEmotion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDateFilterActive = selectedDate != null;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 680 : double.infinity,
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Дневник',
                                  style: theme.textTheme.headlineMedium,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Записи после КПТ-сессий',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          _CalendarIconButton(
                            isActive: isDateFilterActive,
                            onTap: onPickDate,
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      AppTextField(
                        controller: searchController,
                        hint: 'Поиск по ситуации или мысли',
                        prefixIcon: Icons.search_rounded,
                        onChanged: onSearchChanged,
                      ),

                      if (selectedDate != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _DateFilterChip(
                          dateText: formatDate(selectedDate),
                          onReset: onResetDateFilter,
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xl),

                      if (!hasAnyEntries)
                        const _EmptyDiaryState()
                      else if (entries.isEmpty)
                        _FilteredEmptyState(
                          hasDateFilter: selectedDate != null,
                          hasEntriesForSelectedDate:
                              hasEntriesForSelectedDate,
                          hasSearchQuery: searchQuery.isNotEmpty,
                        )
                      else
                        ...entries.map(
                          (entry) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.lg,
                              ),
                              child: _DiaryEntryCard(
                                entry: entry,
                                onTap: () => onOpenEntry(entry),
                                formatDate: formatDate,
                                safeText: safeText,
                                formatEmotion: formatEmotion,
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

class _CalendarIconButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _CalendarIconButton({
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primary = theme.colorScheme.primary;

    final backgroundColor = isActive
        ? primary.withOpacity(isDark ? 0.18 : 0.12)
        : isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface;

    final borderColor = isActive
        ? primary.withOpacity(isDark ? 0.30 : 0.22)
        : isDark
            ? AppColors.darkBorder
            : AppColors.lightBorder;

    final iconColor = isActive
        ? primary
        : isDark
            ? AppColors.darkText
            : AppColors.lightText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.large,
        child: Container(
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
                    ? AppColors.darkShadow.withOpacity(0.14)
                    : AppColors.lightShadow.withOpacity(0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.calendar_today_rounded,
            color: iconColor,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  final String dateText;
  final VoidCallback onReset;

  const _DateFilterChip({
    required this.dateText,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primary = theme.colorScheme.primary;

    final backgroundColor = isDark
        ? AppColors.darkSurfaceSoft.withOpacity(0.72)
        : AppColors.lightPrimarySoft.withOpacity(0.78);

    final borderColor = isDark
        ? primary.withOpacity(0.20)
        : primary.withOpacity(0.12);

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
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            color: primary,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Дата: $dateText',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: primary,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.15,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onReset,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                'Сбросить',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaryEntryCard extends StatelessWidget {
  final DiaryEntryModel entry;
  final VoidCallback onTap;
  final String Function(DateTime?) formatDate;
  final String Function(String?, {String fallback}) safeText;
  final String? Function(dynamic) formatEmotion;

  const _DiaryEntryCard({
    required this.entry,
    required this.onTap,
    required this.formatDate,
    required this.safeText,
    required this.formatEmotion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final emotionsBefore = formatEmotion(entry.emotionsBefore);
    final emotionsAfter = formatEmotion(entry.emotionsAfter);

    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return AppCard(
      hasShadow: false,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: AppRadius.extraLarge,
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SoftDateBadge(
                  date: entry.createdAt,
                  formatDate: formatDate,
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            _EntryTextBlock(
              title: 'Ситуация',
              text: safeText(entry.situation),
              isPrimary: true,
            ),

            const SizedBox(height: AppSpacing.md),

            _EntryTextBlock(
              title: 'Автоматическая мысль',
              text: safeText(entry.automaticThought),
            ),

            if (entry.alternativeThought != null &&
                entry.alternativeThought!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _EntryTextBlock(
                title: 'Рациональная альтернатива',
                text: entry.alternativeThought!.trim(),
                isPrimary: true,
              ),
            ],

            if (emotionsBefore != null || emotionsAfter != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (emotionsBefore != null)
                    _EmotionChip(
                      label: 'До',
                      value: emotionsBefore,
                    ),
                  if (emotionsAfter != null)
                    _EmotionChip(
                      label: 'После',
                      value: emotionsAfter,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SoftDateBadge extends StatelessWidget {
  final DateTime? date;
  final String Function(DateTime?) formatDate;

  const _SoftDateBadge({
    required this.date,
    required this.formatDate,
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
        color: theme.colorScheme.primary.withOpacity(0.10),
        borderRadius: AppRadius.medium,
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            color: theme.colorScheme.primary,
            size: 15,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            formatDate(date),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTextBlock extends StatelessWidget {
  final String title;
  final String text;
  final bool isPrimary;

  const _EntryTextBlock({
    required this.title,
    required this.text,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.05,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isPrimary
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
            height: 1.45,
            fontWeight: isPrimary ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _EmotionChip extends StatelessWidget {
  final String label;
  final String value;

  const _EmotionChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 280,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.10),
        borderRadius: AppRadius.medium,
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.10),
          width: 1,
        ),
      ),
      child: Text(
        '$label: $value',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.05,
        ),
      ),
    );
  }
}

class _EmptyDiaryState extends StatelessWidget {
  const _EmptyDiaryState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EmptyStateIcon(
            icon: Icons.menu_book_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Записей пока нет',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Когда ты завершишь КПТ-сессию, здесь появится дневниковая запись.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  final bool hasDateFilter;
  final bool hasEntriesForSelectedDate;
  final bool hasSearchQuery;

  const _FilteredEmptyState({
    required this.hasDateFilter,
    required this.hasEntriesForSelectedDate,
    required this.hasSearchQuery,
  });

  @override
  Widget build(BuildContext context) {
    if (hasDateFilter && !hasEntriesForSelectedDate) {
      return const _NoDateResultsState();
    }

    if (hasSearchQuery) {
      return const _NoSearchResultsState();
    }

    return const _NoSearchResultsState();
  }
}

class _NoDateResultsState extends StatelessWidget {
  const _NoDateResultsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EmptyStateIcon(
            icon: Icons.calendar_today_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'На эту дату записей нет',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Попробуй выбрать другую дату или сбросить фильтр.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSearchResultsState extends StatelessWidget {
  const _NoSearchResultsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EmptyStateIcon(
            icon: Icons.search_off_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Ничего не найдено',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Попробуй изменить поисковый запрос или сбросить фильтр.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateIcon extends StatelessWidget {
  final IconData icon;

  const _EmptyStateIcon({
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