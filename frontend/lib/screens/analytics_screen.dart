import 'package:flutter/material.dart';

import '../models/analytics_model.dart';
import '../services/analytics_service.dart';
import '../services/api_exception.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/app_error_view.dart';
import '../widgets/app_loading.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsData {
  final AnalyticsSummaryModel summary;
  final List<AnalyticsDistortionModel> distortions;
  final List<AnalyticsTechniqueModel> techniques;

  const _AnalyticsData({
    required this.summary,
    required this.distortions,
    required this.techniques,
  });
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<_AnalyticsData> _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _analyticsFuture = _loadAnalytics();
  }

  Future<_AnalyticsData> _loadAnalytics() async {
    final summary = await AnalyticsService.getSummary();
    final distortionsResponse = await AnalyticsService.getDistortions();
    final techniquesResponse = await AnalyticsService.getTechniques();

    return _AnalyticsData(
      summary: summary,
      distortions: distortionsResponse.items,
      techniques: techniquesResponse.items,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _analyticsFuture = _loadAnalytics();
    });

    await _analyticsFuture;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Нет данных';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AnalyticsData>(
      future: _analyticsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: AppLoading(
              text: 'Загрузка аналитики...',
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is ApiException
              ? error.message
              : 'Не удалось загрузить аналитику.';

          return Scaffold(
            appBar: AppBar(
              title: const Text('Аналитика'),
            ),
            body: AppErrorView(
              message: message,
              onRetry: _refresh,
            ),
          );
        }

        final data = snapshot.data;

        if (data == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Аналитика'),
            ),
            body: AppErrorView(
              message: 'Нет данных аналитики.',
              onRetry: _refresh,
            ),
          );
        }

        return _AnalyticsContent(
          data: data,
          onRefresh: _refresh,
          formatDate: _formatDate,
        );
      },
    );
  }
}

class _AnalyticsContent extends StatelessWidget {
  final _AnalyticsData data;
  final Future<void> Function() onRefresh;
  final String Function(DateTime?) formatDate;

  const _AnalyticsContent({
    required this.data,
    required this.onRefresh,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;

    final totalSessions = summary.totalSessions ?? 0;
    final finishedSessions = summary.finishedSessions ?? 0;
    final totalDiaryEntries = summary.totalDiaryEntries ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Аналитика'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 750;

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
                      const _AnalyticsHeader(),

                      const SizedBox(height: AppSpacing.xl),

                      _SummaryGrid(
                        totalSessions: totalSessions,
                        finishedSessions: finishedSessions,
                        totalDiaryEntries: totalDiaryEntries,
                        latestEntryDate: formatDate(summary.latestEntryDate),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      _TechniquesSection(
                        techniques: data.techniques,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      _DistortionsSection(
                        distortions: data.distortions,
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

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Аналитика',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Краткая сводка по КПТ-сессиям, дневниковым записям, техникам и когнитивным искажениям.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final int totalSessions;
  final int finishedSessions;
  final int totalDiaryEntries;
  final String latestEntryDate;

  const _SummaryGrid({
    required this.totalSessions,
    required this.finishedSessions,
    required this.totalDiaryEntries,
    required this.latestEntryDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Всего сессий',
                value: totalSessions.toString(),
                icon: Icons.chat_bubble_outline_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _SummaryCard(
                title: 'Завершено',
                value: finishedSessions.toString(),
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Записей',
                value: totalDiaryEntries.toString(),
                icon: Icons.book_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _SummaryCard(
                title: 'Последняя',
                value: latestEntryDate,
                icon: Icons.event_note_outlined,
                isDate: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool isDate;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.isDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      hasShadow: false,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isDate
                ? theme.textTheme.titleMedium
                : theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TechniquesSection extends StatelessWidget {
  final List<AnalyticsTechniqueModel> techniques;

  const _TechniquesSection({
    required this.techniques,
  });

  static const List<String> expectedTechniques = [
    'SOCRATIC_DIALOGUE',
    'DOWNWARD_ARROW',
    'REFRAMING',
    'GROUNDING',
    'SUMMARY',
  ];

  @override
  Widget build(BuildContext context) {
    final techniqueCounts = <String, int>{};

    for (final item in techniques) {
      final technique = item.technique;

      if (technique == null || technique.trim().isEmpty) {
        continue;
      }

      techniqueCounts[technique] = item.count ?? 0;
    }

    final totalCount = techniqueCounts.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Техники ассистента',
            subtitle: 'Какие техники чаще использовались в сессиях.',
          ),

          const SizedBox(height: AppSpacing.lg),

          if (totalCount == 0)
            const _EmptyAnalyticsState(
              text: 'Пока недостаточно данных по техникам.',
            )
          else
            ...expectedTechniques.map((technique) {
              final count = techniqueCounts[technique] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ProgressItem(
                  title: _techniqueTitle(technique),
                  subtitle: technique,
                  count: count,
                  maxCount: _maxCount(techniqueCounts),
                ),
              );
            }),
        ],
      ),
    );
  }

  static int _maxCount(Map<String, int> values) {
    if (values.isEmpty) return 1;

    final max = values.values.fold<int>(
      0,
      (previous, current) => current > previous ? current : previous,
    );

    return max <= 0 ? 1 : max;
  }

  static String _techniqueTitle(String technique) {
    switch (technique) {
      case 'SOCRATIC_DIALOGUE':
        return 'Сократический диалог';
      case 'DOWNWARD_ARROW':
        return 'Стрела вниз';
      case 'REFRAMING':
        return 'Рефрейминг';
      case 'GROUNDING':
        return 'Заземление';
      case 'SUMMARY':
        return 'Итоги';
      default:
        return technique;
    }
  }
}

class _DistortionsSection extends StatelessWidget {
  final List<AnalyticsDistortionModel> distortions;

  const _DistortionsSection({
    required this.distortions,
  });

  @override
  Widget build(BuildContext context) {
    final visibleDistortions = distortions.where((item) {
      final name = item.name;
      final count = item.count ?? 0;

      return name != null && name.trim().isNotEmpty && count > 0;
    }).toList();

    visibleDistortions.sort((a, b) {
      final aCount = a.count ?? 0;
      final bCount = b.count ?? 0;

      return bCount.compareTo(aCount);
    });

    final maxCount = visibleDistortions.isEmpty
        ? 1
        : visibleDistortions
            .map((item) => item.count ?? 0)
            .reduce((a, b) => a > b ? a : b);

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Когнитивные искажения',
            subtitle: 'Частота искажений, найденных в дневниковых записях.',
          ),

          const SizedBox(height: AppSpacing.lg),

          if (visibleDistortions.isEmpty)
            const _EmptyAnalyticsState(
              text: 'Пока недостаточно данных по когнитивным искажениям.',
            )
          else
            ...visibleDistortions.map((distortion) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ProgressItem(
                  title: distortion.name ?? 'Без названия',
                  count: distortion.count ?? 0,
                  maxCount: maxCount <= 0 ? 1 : maxCount,
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ProgressItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int count;
  final int maxCount;

  const _ProgressItem({
    required this.title,
    this.subtitle,
    required this.count,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final safeMax = maxCount <= 0 ? 1 : maxCount;
    final progress = (count / safeMax).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              count.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),

        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.sm),

        ClipRRect(
          borderRadius: AppRadius.medium,
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyAnalyticsState extends StatelessWidget {
  final String text;

  const _EmptyAnalyticsState({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.large,
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: theme.colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}