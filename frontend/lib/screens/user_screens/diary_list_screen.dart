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

  static const int _itemsPerPage = 6;

  String _searchQuery = '';
  DateTime? _selectedDate;
  DateTimeRange? _selectedDateRange;
  int _currentPage = 1;

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
    _currentPage = 1;
    _applyFilters();
  }

  void _applyFilters() {
    var result = [..._allEntries];

    final selectedDate = _selectedDate;
    final selectedDateRange = _selectedDateRange;

    if (selectedDate != null) {
      result = result.where((entry) {
        final createdAt = entry.createdAt;

        if (createdAt == null) {
          return false;
        }

        return _isSameDate(createdAt.toLocal(), selectedDate);
      }).toList();
    } else if (selectedDateRange != null) {
      final rangeStart = _dateOnly(selectedDateRange.start);
      final rangeEnd = _dateOnly(selectedDateRange.end);

      result = result.where((entry) {
        final createdAt = entry.createdAt;

        if (createdAt == null) {
          return false;
        }

        final entryDate = _dateOnly(createdAt.toLocal());

        return !entryDate.isBefore(rangeStart) &&
            !entryDate.isAfter(rangeEnd);
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

    final totalPages = _totalPages;

    if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }

    if (_currentPage < 1) {
      _currentPage = 1;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openDateFilter() async {
    final selectedMode = await showModalBottomSheet<_DateFilterMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const _DateFilterModeSheet();
      },
    );

    if (!mounted || selectedMode == null) {
      return;
    }

    if (selectedMode == _DateFilterMode.singleDate) {
      await _pickSingleDate();
    } else {
      await _pickDateRange();
    }
  }

  Future<void> _pickSingleDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? _selectedDateRange?.start ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Выбери дату',
      cancelText: 'Отмена',
      confirmText: 'Готово',
      builder: _datePickerThemeBuilder,
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = _dateOnly(pickedDate);
      _selectedDateRange = null;
      _currentPage = 1;
    });

    _applyFilters();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange = _selectedDateRange ??
        DateTimeRange(
          start: _selectedDate ?? now,
          end: _selectedDate ?? now,
        );

    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Выбери период',
      cancelText: 'Отмена',
      confirmText: 'Готово',
      saveText: 'Готово',
      builder: _datePickerThemeBuilder,
    );

    if (pickedRange == null) {
      return;
    }

    setState(() {
      _selectedDate = null;
      _selectedDateRange = DateTimeRange(
        start: _dateOnly(pickedRange.start),
        end: _dateOnly(pickedRange.end),
      );
      _currentPage = 1;
    });

    _applyFilters();
  }

  Widget _datePickerThemeBuilder(BuildContext context, Widget? child) {
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
  }

  void _resetDateFilter() {
    setState(() {
      _selectedDate = null;
      _selectedDateRange = null;
      _currentPage = 1;
    });

    _applyFilters();
  }

  bool _hasEntriesForSelectedPeriod() {
    if (_selectedDate == null && _selectedDateRange == null) {
      return true;
    }

    return _allEntries.any((entry) {
      final createdAt = entry.createdAt;

      if (createdAt == null) {
        return false;
      }

      final entryDate = _dateOnly(createdAt.toLocal());

      if (_selectedDate != null) {
        return _isSameDate(entryDate, _selectedDate!);
      }

      final range = _selectedDateRange!;
      final rangeStart = _dateOnly(range.start);
      final rangeEnd = _dateOnly(range.end);

      return !entryDate.isBefore(rangeStart) &&
          !entryDate.isAfter(rangeEnd);
    });
  }

  int get _totalPages {
    if (_filteredEntries.isEmpty) {
      return 1;
    }

    return (_filteredEntries.length / _itemsPerPage).ceil();
  }

  List<DiaryEntryModel> get _visibleEntries {
    if (_filteredEntries.isEmpty) {
      return [];
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(
      0,
      _filteredEntries.length,
    );

    return _filteredEntries.sublist(startIndex, endIndex);
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _currentPage) {
      return;
    }

    setState(() {
      _currentPage = page;
    });
  }

  DateTime _dateOnly(DateTime date) {
    final localDate = date.toLocal();

    return DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );
  }

  String _formatDateFilter() {
    if (_selectedDate != null) {
      return 'Дата: ${_formatDate(_selectedDate)}';
    }

    final range = _selectedDateRange;

    if (range != null) {
      return 'Период: ${_formatDate(range.start)} — ${_formatDate(range.end)}';
    }

    return '';
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
          entries: _visibleEntries,
          hasAnyEntries: _allEntries.isNotEmpty,
          hasDateFilter: _selectedDate != null || _selectedDateRange != null,
          dateFilterText: _formatDateFilter(),
          hasEntriesForSelectedPeriod: _hasEntriesForSelectedPeriod(),
          searchQuery: _searchQuery,
          currentPage: _currentPage,
          totalPages: _totalPages,
          totalFilteredEntries: _filteredEntries.length,
          onSearchChanged: _onSearchChanged,
          onPickDate: _openDateFilter,
          onResetDateFilter: _resetDateFilter,
          onPageChanged: _goToPage,
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
  final bool hasDateFilter;
  final String dateFilterText;
  final bool hasEntriesForSelectedPeriod;
  final String searchQuery;
  final int currentPage;
  final int totalPages;
  final int totalFilteredEntries;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPickDate;
  final VoidCallback onResetDateFilter;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function() onRefresh;
  final ValueChanged<DiaryEntryModel> onOpenEntry;
  final String Function(DateTime?) formatDate;
  final String Function(String?, {String fallback}) safeText;
  final String? Function(dynamic) formatEmotion;

  const _DiaryListContent({
    required this.searchController,
    required this.entries,
    required this.hasAnyEntries,
    required this.hasDateFilter,
    required this.dateFilterText,
    required this.hasEntriesForSelectedPeriod,
    required this.searchQuery,
    required this.currentPage,
    required this.totalPages,
    required this.totalFilteredEntries,
    required this.onSearchChanged,
    required this.onPickDate,
    required this.onResetDateFilter,
    required this.onPageChanged,
    required this.onRefresh,
    required this.onOpenEntry,
    required this.formatDate,
    required this.safeText,
    required this.formatEmotion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDateFilterActive = hasDateFilter;

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

                      if (hasDateFilter) ...[
                        const SizedBox(height: AppSpacing.md),
                        _DateFilterChip(
                          filterText: dateFilterText,
                          onReset: onResetDateFilter,
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xl),

                      if (!hasAnyEntries)
                        const _EmptyDiaryState()
                      else if (entries.isEmpty)
                        _FilteredEmptyState(
                          hasDateFilter: hasDateFilter,
                          hasEntriesForSelectedPeriod:
                              hasEntriesForSelectedPeriod,
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

                      if (totalFilteredEntries > 0 && totalPages > 1) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _PaginationBar(
                          currentPage: currentPage,
                          totalPages: totalPages,
                          onPageChanged: onPageChanged,
                        ),
                      ],
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


enum _DateFilterMode {
  singleDate,
  dateRange,
}

class _DateFilterModeSheet extends StatelessWidget {
  const _DateFilterModeSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: AppRadius.extraLarge,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Фильтр по дате',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Покажи записи за один день или за выбранный период.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _DateFilterModeTile(
              icon: Icons.calendar_today_rounded,
              title: 'Одна дата',
              subtitle: 'Записи за конкретный день',
              onTap: () {
                Navigator.of(context).pop(_DateFilterMode.singleDate);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _DateFilterModeTile(
              icon: Icons.date_range_rounded,
              title: 'Период',
              subtitle: 'Записи между двумя датами',
              onTap: () {
                Navigator.of(context).pop(_DateFilterMode.dateRange);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DateFilterModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DateFilterModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.large,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceSoft.withOpacity(0.72)
                : AppColors.lightPrimarySoft.withOpacity(0.58),
            borderRadius: AppRadius.large,
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.10),
                  borderRadius: AppRadius.medium,
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
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
  final String filterText;
  final VoidCallback onReset;

  const _DateFilterChip({
    required this.filterText,
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
              filterText,
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


class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final visiblePages = _buildVisiblePages();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PaginationButton(
          icon: Icons.chevron_left_rounded,
          isEnabled: currentPage > 1,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        const SizedBox(width: AppSpacing.sm),
        ...visiblePages.map((page) {
          if (page == null) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                '…',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: _PaginationButton(
              label: page.toString(),
              isActive: page == currentPage,
              onTap: () => onPageChanged(page),
            ),
          );
        }),
        const SizedBox(width: AppSpacing.sm),
        _PaginationButton(
          icon: Icons.chevron_right_rounded,
          isEnabled: currentPage < totalPages,
          onTap: () => onPageChanged(currentPage + 1),
        ),
      ],
    );
  }

  List<int?> _buildVisiblePages() {
    if (totalPages <= 5) {
      return List<int>.generate(totalPages, (index) => index + 1);
    }

    if (currentPage <= 3) {
      return [1, 2, 3, 4, null, totalPages];
    }

    if (currentPage >= totalPages - 2) {
      return [
        1,
        null,
        totalPages - 3,
        totalPages - 2,
        totalPages - 1,
        totalPages,
      ];
    }

    return [
      1,
      null,
      currentPage - 1,
      currentPage,
      currentPage + 1,
      null,
      totalPages,
    ];
  }
}

class _PaginationButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool isActive;
  final bool isEnabled;
  final VoidCallback onTap;

  const _PaginationButton({
    this.label,
    this.icon,
    this.isActive = false,
    this.isEnabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final backgroundColor = isActive
        ? primary
        : isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface;

    final foregroundColor = isActive
        ? AppColors.white
        : isEnabled
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant.withOpacity(0.42);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: AppRadius.medium,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: AppRadius.medium,
            border: Border.all(
              color: isActive
                  ? primary
                  : isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: icon != null
              ? Icon(
                  icon,
                  color: foregroundColor,
                  size: 20,
                )
              : Text(
                  label ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
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
  final bool hasEntriesForSelectedPeriod;
  final bool hasSearchQuery;

  const _FilteredEmptyState({
    required this.hasDateFilter,
    required this.hasEntriesForSelectedPeriod,
    required this.hasSearchQuery,
  });

  @override
  Widget build(BuildContext context) {
    if (hasDateFilter && !hasEntriesForSelectedPeriod) {
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
            'За выбранный период записей нет',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Попробуй выбрать другую дату, другой период или сбросить фильтр.',
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