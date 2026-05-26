import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/diary_entry_model.dart';
import '../services/api_exception.dart';
import '../services/diary_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/app_error_view.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_text_field.dart';

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
    _applySearch(_searchQuery);

    return entries;
  }

  Future<void> _refresh() async {
    setState(() {
      _entriesFuture = _loadEntries();
    });

    await _entriesFuture;
  }

  void _applySearch(String value) {
    final query = value.trim().toLowerCase();

    _searchQuery = query;

    if (query.isEmpty) {
      _filteredEntries = [..._allEntries];
    } else {
      _filteredEntries = _allEntries.where((entry) {
        final situation = entry.situation?.toLowerCase() ?? '';
        final automaticThought = entry.automaticThought?.toLowerCase() ?? '';

        return situation.contains(query) || automaticThought.contains(query);
      }).toList();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _openEntry(DiaryEntryModel entry) {
    final id = entry.id;

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У записи нет ID.'),
        ),
      );
      return;
    }

    context.push('/diary/$id');
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Дата не указана';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
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
            appBar: AppBar(
              title: const Text('Дневник'),
            ),
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
          onSearchChanged: _applySearch,
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
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onRefresh;
  final ValueChanged<DiaryEntryModel> onOpenEntry;
  final String Function(DateTime?) formatDate;
  final String Function(String?, {String fallback}) safeText;
  final String? Function(dynamic) formatEmotion;

  const _DiaryListContent({
    required this.searchController,
    required this.entries,
    required this.hasAnyEntries,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onOpenEntry,
    required this.formatDate,
    required this.safeText,
    required this.formatEmotion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Дневник'),
      ),
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
                      Text(
                        'Дневниковые записи',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Здесь сохраняются записи, созданные после КПТ-сессий.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      AppTextField(
                        controller: searchController,
                        hint: 'Поиск по ситуации или мысли',
                        prefixIcon: Icons.search_rounded,
                        onChanged: onSearchChanged,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      if (!hasAnyEntries)
                        const _EmptyDiaryState()
                      else if (entries.isEmpty)
                        const _NoSearchResultsState()
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

    final emotionsBefore = formatEmotion(entry.emotionsBefore);
    final emotionsAfter = formatEmotion(entry.emotionsAfter);

    return AppCard(
      hasShadow: false,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatDate(entry.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            'Ситуация',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            safeText(entry.situation),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            'Автоматическая мысль',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            safeText(entry.automaticThought),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          if (entry.alternativeThought != null &&
              entry.alternativeThought!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Рациональная альтернатива',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              entry.alternativeThought!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
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
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$label: $value',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
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
          Icon(
            Icons.book_outlined,
            color: theme.colorScheme.primary,
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
          Icon(
            Icons.search_off_rounded,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Ничего не найдено',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Попробуй изменить поисковый запрос.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}