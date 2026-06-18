// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/analytics_model.dart';
import '../../navigation/app_routes.dart';
import '../../services/analytics_service.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
    super.key,
  });

  @override
  State<AnalyticsScreen> createState() {
    return _AnalyticsScreenState();
  }
}

class _AnalyticsScreenState
    extends State<AnalyticsScreen> {
  late Future<AnalyticsDetailsData>
  _analyticsFuture;

  @override
  void initState() {
    super.initState();

    _analyticsFuture =
        AnalyticsService.getDetails();
  }

  Future<void> _refresh() async {
    setState(() {
      _analyticsFuture =
          AnalyticsService.getDetails();
    });

    await _analyticsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        AnalyticsDetailsData>(
      future: _analyticsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: AppLoading(
              text:
                  'Загрузка аналитики...',
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;

          final message =
              error is ApiException
              ? error.message
              : 'Не удалось загрузить аналитику.';

          return Scaffold(
            appBar: AppBar(
              title:
                  const Text(
                'Аналитика',
              ),
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
              title:
                  const Text(
                'Аналитика',
              ),
            ),
            body: AppErrorView(
              message:
                  'Нет данных аналитики.',
              onRetry: _refresh,
            ),
          );
        }

        return _AnalyticsContent(
          data: data,
          onRefresh: _refresh,
        );
      },
    );
  }
}

class _AnalyticsContent
    extends StatelessWidget {
  final AnalyticsDetailsData data;

  final Future<void> Function()
  onRefresh;

  const _AnalyticsContent({
    required this.data,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Аналитика'),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(
                AppRoutes.home,
              );
            }
          },
          icon: const Icon(
            Icons
                .arrow_back_rounded,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final isWide =
                constraints.maxWidth >
                760;

            return Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(
                  maxWidth:
                      isWide
                      ? 720
                      : double.infinity,
                ),
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.md,
                      AppSpacing.xl,
                      100,
                    ),
                    children: [
                      Text(
                        'Твоя динамика',
                        style: theme
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                          letterSpacing:
                              -0.7,
                        ),
                      ),
                      const SizedBox(
                        height:
                            AppSpacing.sm,
                      ),
                      Text(
                        'Показатели формируются на основе завершённых КПТ-сессий и записей в дневнике.',
                        style: theme
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color: theme
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(
                        height:
                            AppSpacing.xxl,
                      ),
                      _WellbeingChartCard(
                        wellbeing:
                            data.wellbeingWeek,
                      ),
                      const SizedBox(
                        height:
                            AppSpacing.lg,
                      ),
                      _ResilienceCard(
                        resilience:
                            data.resilience,
                      ),
                      const SizedBox(
                        height:
                            AppSpacing.lg,
                      ),
                      _SummarySection(
                        summary:
                            data.summary,
                      ),
                      const SizedBox(
                        height:
                            AppSpacing.lg,
                      ),
                      _DistortionsSection(
                        response:
                            data.distortions,
                      ),
                      const SizedBox(
                        height:
                            AppSpacing.lg,
                      ),
                      _TechniquesSection(
                        response:
                            data.techniques,
                      ),
                      const SizedBox(
                        height:
                            AppSpacing.lg,
                      ),
                      const _AnalyticsNotice(),
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

// ============================================================
// WEEKLY WELLBEING
// ============================================================

class _WellbeingChartCard
    extends StatelessWidget {
  final AnalyticsWellbeingWeekModel
  wellbeing;

  const _WellbeingChartCard({
    required this.wellbeing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final average =
        wellbeing.averageScore;

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Состояние за неделю',
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                            FontWeight
                                .w800,
                        letterSpacing:
                            -0.4,
                      ),
                    ),
                    const SizedBox(
                      height:
                          AppSpacing.xs,
                    ),
                    Text(
                      wellbeing.trendTitle,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: _trendColor(
                          context,
                          wellbeing,
                        ),
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (average != null)
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .end,
                  children: [
                    Text(
                      average
                          .round()
                          .toString(),
                      style: theme
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight
                                .w800,
                        letterSpacing:
                            -0.8,
                      ),
                    ),
                    Text(
                      'среднее',
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: theme
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(
            height: AppSpacing.xl,
          ),
          if (wellbeing.hasData) ...[
            SizedBox(
              height: 230,
              width: double.infinity,
              child: CustomPaint(
                painter:
                    _DetailedWellbeingPainter(
                  items:
                      wellbeing.items,
                  lineColor: theme
                      .colorScheme
                      .primary,
                  gridColor: theme
                      .dividerColor
                      .withOpacity(
                        0.45,
                      ),
                  textColor: theme
                      .colorScheme
                      .onSurfaceVariant,
                  backgroundColor:
                      theme
                          .scaffoldBackgroundColor,
                ),
              ),
            ),
            const SizedBox(
              height: AppSpacing.md,
            ),
            _DayLabels(
              items: wellbeing.items,
            ),
            const SizedBox(
              height: AppSpacing.md,
            ),
            Text(
              '0 — очень тяжело, 100 — спокойно и хорошо',
              style: theme
                  .textTheme.bodySmall
                  ?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ] else
            const _EmptyAnalyticsBlock(
              icon: Icons
                  .show_chart_rounded,
              title:
                  'Пока недостаточно данных',
              description:
                  'Заверши новую КПТ-сессию и оцени общее состояние, чтобы появилась динамика.',
            ),
        ],
      ),
    );
  }

  Color _trendColor(
    BuildContext context,
    AnalyticsWellbeingWeekModel
    wellbeing,
  ) {
    final theme =
        Theme.of(context);

    if (wellbeing.isImproving) {
      return const Color(
        0xFF4F9B79,
      );
    }

    if (wellbeing.isDeclining) {
      return theme
          .colorScheme.error;
    }

    return theme
        .colorScheme.primary;
  }
}

class _DayLabels
    extends StatelessWidget {
  final List<AnalyticsWellbeingDayModel>
  items;

  const _DayLabels({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: items.map(
        (item) {
          return Expanded(
            child: Column(
              children: [
                Text(
                  item.safeDayLabel,
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  item.score == null
                      ? '—'
                      : item.score!
                          .round()
                          .toString(),
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                    color: item.score ==
                            null
                        ? theme
                            .colorScheme
                            .onSurfaceVariant
                        : theme
                            .colorScheme
                            .primary,
                  ),
                ),
              ],
            ),
          );
        },
      ).toList(),
    );
  }
}

class _DetailedWellbeingPainter
    extends CustomPainter {
  final List<AnalyticsWellbeingDayModel>
  items;

  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final Color backgroundColor;

  const _DetailedWellbeingPainter({
    required this.items,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    required this.backgroundColor,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    const leftPadding = 34.0;
    const rightPadding = 8.0;
    const topPadding = 12.0;
    const bottomPadding = 8.0;

    final chartWidth = math.max(
      0,
      size.width -
          leftPadding -
          rightPadding,
    );

    final chartHeight = math.max(
      0,
      size.height -
          topPadding -
          bottomPadding,
    );

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final labelPainter =
        TextPainter(
      textDirection:
          TextDirection.ltr,
    );

    const levels = [
      100,
      75,
      50,
      25,
      0,
    ];

    for (final level in levels) {
      final y = topPadding +
          (100 - level) /
              100 *
              chartHeight;

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(
          leftPadding +
              chartWidth,
          y,
        ),
        gridPaint,
      );

      labelPainter.text =
          TextSpan(
        text: '$level',
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight:
              FontWeight.w500,
        ),
      );

      labelPainter.layout();

      labelPainter.paint(
        canvas,
        Offset(
          0,
          y -
              labelPainter.height /
                  2,
        ),
      );
    }

    if (items.isEmpty) {
      return;
    }

    final horizontalStep =
        items.length <= 1
        ? 0.0
        : chartWidth /
            (items.length - 1);

    final points =
        <int, Offset>{};

    for (
      int index = 0;
      index < items.length;
      index++
    ) {
      final score = items[index].score;

      if (score == null) {
        continue;
      }

      final normalized =
          score.clamp(0, 100) / 100;

      final x = leftPadding +
          horizontalStep * index;

      final y = topPadding +
          (1 - normalized) *
              chartHeight;

      points[index] = Offset(x, y);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final shadowPaint = Paint()
      ..color = lineColor
          .withOpacity(0.13)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    Path? segmentPath;
    int? previousIndex;

    for (
      int index = 0;
      index < items.length;
      index++
    ) {
      final point = points[index];

      if (point == null) {
        segmentPath = null;
        previousIndex = null;
        continue;
      }

      if (segmentPath == null ||
          previousIndex == null ||
          index != previousIndex + 1) {
        segmentPath = Path()
          ..moveTo(
            point.dx,
            point.dy,
          );
      } else {
        final previousPoint =
            points[previousIndex];

        if (previousPoint != null) {
          final controlDistance =
              (point.dx -
                      previousPoint.dx) /
                  2;

          segmentPath.cubicTo(
            previousPoint.dx +
                controlDistance,
            previousPoint.dy,
            point.dx -
                controlDistance,
            point.dy,
            point.dx,
            point.dy,
          );

          canvas.drawPath(
            segmentPath,
            shadowPaint,
          );

          canvas.drawPath(
            segmentPath,
            linePaint,
          );
        }
      }

      canvas.drawCircle(
        point,
        5.5,
        dotPaint,
      );

      canvas.drawCircle(
        point,
        5.5,
        dotBorderPaint,
      );

      previousIndex = index;
    }
  }

  @override
  bool shouldRepaint(
    covariant _DetailedWellbeingPainter
        oldDelegate,
  ) {
    return oldDelegate.items != items ||
        oldDelegate.lineColor !=
            lineColor ||
        oldDelegate.gridColor !=
            gridColor ||
        oldDelegate.textColor !=
            textColor ||
        oldDelegate.backgroundColor !=
            backgroundColor;
  }
}

// ============================================================
// RESILIENCE
// ============================================================

class _ResilienceCard
    extends StatelessWidget {
  final AnalyticsResilienceModel
  resilience;

  const _ResilienceCard({
    required this.resilience,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final score =
        resilience.safeScore;

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Прогресс устойчивости',
            style: theme
                .textTheme
                .titleLarge
                ?.copyWith(
              fontWeight:
                  FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(
            height: AppSpacing.xs,
          ),
          Text(
            resilience
                .dataStatusTitle,
            style: theme
                .textTheme.bodySmall
                ?.copyWith(
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
          const SizedBox(
            height: AppSpacing.xl,
          ),
          if (resilience.hasData)
            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final isWide =
                    constraints.maxWidth >
                    520;

                final indicator =
                    _ResilienceIndicator(
                  score: score,
                );

                final details =
                    _ResilienceDetails(
                  resilience:
                      resilience,
                );

                if (isWide) {
                  return Row(
                    children: [
                      indicator,
                      const SizedBox(
                        width:
                            AppSpacing.xxl,
                      ),
                      Expanded(
                        child: details,
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    indicator,
                    const SizedBox(
                      height:
                          AppSpacing.xl,
                    ),
                    details,
                  ],
                );
              },
            )
          else
            const _EmptyAnalyticsBlock(
              icon: Icons
                  .favorite_border_rounded,
              title:
                  'Показатель ещё не рассчитан',
              description:
                  'Для расчёта нужна хотя бы одна завершённая сессия с итоговой оценкой состояния.',
            ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          Text(
            'Внутренний показатель приложения. Он не является медицинской или диагностической оценкой.',
            style: theme
                .textTheme.bodySmall
                ?.copyWith(
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResilienceIndicator
    extends StatelessWidget {
  final int score;

  const _ResilienceIndicator({
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 164,
      height: 164,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child:
                CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 11,
              strokeCap:
                  StrokeCap.round,
              backgroundColor: theme
                  .colorScheme
                  .primary
                  .withOpacity(
                    0.10,
                  ),
              color: theme
                  .colorScheme
                  .primary,
            ),
          ),
          Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons
                    .favorite_rounded,
                color: theme
                    .colorScheme
                    .primary,
                size: 29,
              ),
              const SizedBox(
                height:
                    AppSpacing.xs,
              ),
              Text(
                '$score%',
                style: theme
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight
                          .w800,
                  letterSpacing:
                      -0.9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResilienceDetails
    extends StatelessWidget {
  final AnalyticsResilienceModel
  resilience;

  const _ResilienceDetails({
    required this.resilience,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProgressDetailRow(
          label:
              'Завершение сессий',
          value:
              resilience
                  .safeCompletionScore,
          valueText:
              '${resilience.safeCompletionScore.round()}%',
        ),
        const SizedBox(
          height: AppSpacing.lg,
        ),
        _ProgressDetailRow(
          label:
              'Среднее состояние',
          value: resilience
              .safeAverageWellbeingScore,
          valueText:
              '${resilience.safeAverageWellbeingScore.round()}',
        ),
        const SizedBox(
          height: AppSpacing.lg,
        ),
        _InformationRow(
          label:
              'Сессий с оценкой',
          value:
              '${resilience.sessionsWithWellbeingData}',
        ),
      ],
    );
  }
}

class _ProgressDetailRow
    extends StatelessWidget {
  final String label;
  final double value;
  final String valueText;

  const _ProgressDetailRow({
    required this.label,
    required this.value,
    required this.valueText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final normalized =
        value.clamp(0, 100) / 100;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight
                          .w600,
                ),
              ),
            ),
            Text(
              valueText,
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(
          height: AppSpacing.sm,
        ),
        ClipRRect(
          borderRadius:
              AppRadius.large,
          child:
              LinearProgressIndicator(
            value: normalized,
            minHeight: 8,
            backgroundColor: theme
                .colorScheme
                .primary
                .withOpacity(
                  0.10,
                ),
            color: theme
                .colorScheme
                .primary,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SUMMARY
// ============================================================

class _SummarySection
    extends StatelessWidget {
  final AnalyticsSummaryModel summary;

  const _SummarySection({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final latestDate =
        _formatDate(
      summary.latestEntryDate,
    );

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Общая активность',
            subtitle:
                'Основные показатели работы с дневником',
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          _AnalyticsGrid(
            children: [
              _MetricTile(
                label:
                    'Всего сессий',
                value:
                    '${summary.safeTotalSessions}',
                icon: Icons
                    .chat_bubble_outline_rounded,
              ),
              _MetricTile(
                label:
                    'Завершено',
                value:
                    '${summary.safeFinishedSessions}',
                icon: Icons
                    .check_circle_outline_rounded,
              ),
              _MetricTile(
                label:
                    'Записей',
                value:
                    '${summary.safeTotalDiaryEntries}',
                icon: Icons
                    .menu_book_rounded,
              ),
              _MetricTile(
                label:
                    'Последняя запись',
                value: latestDate,
                icon: Icons
                    .calendar_today_rounded,
                compactValue: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DISTORTIONS
// ============================================================

class _DistortionsSection
    extends StatelessWidget {
  final AnalyticsDistortionsResponseModel
  response;

  const _DistortionsSection({
    required this.response,
  });

  @override
  Widget build(BuildContext context) {
    final items = response.items
        .where(
          (item) =>
              item.safeCount > 0,
        )
        .toList();

    final maxCount = items.isEmpty
        ? 1
        : items
            .map(
              (item) =>
                  item.safeCount,
            )
            .reduce(math.max);

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title:
                'Когнитивные искажения',
            subtitle:
                'Какие мыслительные шаблоны встречались чаще',
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          if (items.isEmpty)
            const _EmptyAnalyticsBlock(
              icon:
                  Icons.psychology_alt_outlined,
              title:
                  'Пока нет данных',
              description:
                  'Искажения появятся после завершённых КПТ-сессий.',
            )
          else
            ...items.take(6).map(
              (item) {
                return Padding(
                  padding:
                      const EdgeInsets
                          .only(
                    bottom:
                        AppSpacing.md,
                  ),
                  child:
                      _RankedAnalyticsRow(
                    label:
                        _formatName(
                      item.safeName,
                    ),
                    count:
                        item.safeCount,
                    progress:
                        item.safeCount /
                        maxCount,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ============================================================
// TECHNIQUES
// ============================================================

class _TechniquesSection
    extends StatelessWidget {
  final AnalyticsTechniquesResponseModel
  response;

  const _TechniquesSection({
    required this.response,
  });

  @override
  Widget build(BuildContext context) {
    final items = response.items
        .where(
          (item) =>
              item.safeCount > 0 &&
              item.safeTechnique
                      .toUpperCase() !=
                  'NONE',
        )
        .toList();

    final maxCount = items.isEmpty
        ? 1
        : items
            .map(
              (item) =>
                  item.safeCount,
            )
            .reduce(math.max);

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title:
                'Использованные техники',
            subtitle:
                'Какие методы применялись в работе с мыслями',
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          if (items.isEmpty)
            const _EmptyAnalyticsBlock(
              icon:
                  Icons.auto_awesome_outlined,
              title:
                  'Пока нет данных',
              description:
                  'Техники появятся после прохождения КПТ-сессий.',
            )
          else
            ...items.take(6).map(
              (item) {
                return Padding(
                  padding:
                      const EdgeInsets
                          .only(
                    bottom:
                        AppSpacing.md,
                  ),
                  child:
                      _RankedAnalyticsRow(
                    label:
                        _formatTechnique(
                      item.safeTechnique,
                    ),
                    count:
                        item.safeCount,
                    progress:
                        item.safeCount /
                        maxCount,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ============================================================
// COMMON ANALYTICS WIDGETS
// ============================================================

class _SectionTitle
    extends StatelessWidget {
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
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme
              .textTheme.titleLarge
              ?.copyWith(
            fontWeight:
                FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(
          height: AppSpacing.xs,
        ),
        Text(
          subtitle,
          style: theme
              .textTheme.bodySmall
              ?.copyWith(
            color: theme
                .colorScheme
                .onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _AnalyticsGrid
    extends StatelessWidget {
  final List<Widget> children;

  const _AnalyticsGrid({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final itemWidth =
            (constraints.maxWidth -
                    AppSpacing.md) /
                2;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing:
              AppSpacing.md,
          children: children.map(
            (child) {
              return SizedBox(
                width: itemWidth,
                child: child,
              );
            },
          ).toList(),
        );
      },
    );
  }
}

class _MetricTile
    extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool compactValue;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.compactValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness ==
        Brightness.dark;

    return Container(
      padding:
          const EdgeInsets.all(
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors
                .darkSurfaceSoft
                .withOpacity(0.72)
            : AppColors.white
                .withOpacity(0.52),
        borderRadius:
            AppRadius.large,
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.white
                  .withOpacity(
                    0.78,
                  ),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _MetricIcon(
            icon: icon,
          ),
          const SizedBox(
            height: AppSpacing.md,
          ),
          Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: theme
                .textTheme
                .titleLarge
                ?.copyWith(
              fontSize:
                  compactValue
                  ? 16
                  : 22,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme
                .textTheme.bodySmall
                ?.copyWith(
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricIcon
    extends StatelessWidget {
  final IconData icon;

  const _MetricIcon({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context)
            .colorScheme
            .primary;

    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: primary
            .withOpacity(0.11),
        borderRadius:
            BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        color: primary,
        size: 18,
      ),
    );
  }
}

class _RankedAnalyticsRow
    extends StatelessWidget {
  final String label;
  final int count;
  final double progress;

  const _RankedAnalyticsRow({
    required this.label,
    required this.count,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight
                          .w600,
                ),
              ),
            ),
            const SizedBox(
              width: AppSpacing.md,
            ),
            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal:
                    AppSpacing.sm,
                vertical: 4,
              ),
              decoration:
                  BoxDecoration(
                color: theme
                    .colorScheme
                    .primary
                    .withOpacity(
                      0.10,
                    ),
                borderRadius:
                    AppRadius.medium,
              ),
              child: Text(
                '$count',
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: theme
                      .colorScheme
                      .primary,
                  fontWeight:
                      FontWeight
                          .w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(
          height: AppSpacing.sm,
        ),
        ClipRRect(
          borderRadius:
              AppRadius.large,
          child:
              LinearProgressIndicator(
            value: progress.clamp(
              0,
              1,
            ),
            minHeight: 7,
            backgroundColor: theme
                .colorScheme
                .primary
                .withOpacity(
                  0.08,
                ),
            color: theme
                .colorScheme
                .primary,
          ),
        ),
      ],
    );
  }
}

class _InformationRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _InformationRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme
                .textTheme.bodyMedium
                ?.copyWith(
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(
          width: AppSpacing.md,
        ),
        Text(
          value,
          style: theme
              .textTheme.bodyMedium
              ?.copyWith(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _EmptyAnalyticsBlock
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _EmptyAnalyticsBlock({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .primary
            .withOpacity(0.06),
        borderRadius:
            AppRadius.large,
        border: Border.all(
          color: theme
              .colorScheme
              .primary
              .withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: theme
                .colorScheme
                .primary,
            size: 28,
          ),
          const SizedBox(
            height: AppSpacing.md,
          ),
          Text(
            title,
            textAlign:
                TextAlign.center,
            style: theme
                .textTheme
                .bodyMedium
                ?.copyWith(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(
            height: AppSpacing.xs,
          ),
          Text(
            description,
            textAlign:
                TextAlign.center,
            style: theme
                .textTheme.bodySmall
                ?.copyWith(
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsNotice
    extends StatelessWidget {
  const _AnalyticsNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      hasShadow: false,
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons
                .info_outline_rounded,
            color: theme
                .colorScheme
                .primary,
            size: 22,
          ),
          const SizedBox(
            width: AppSpacing.md,
          ),
          Expanded(
            child: Text(
              'Аналитика помогает наблюдать личную динамику, но не является диагнозом или профессиональной психологической оценкой.',
              style: theme
                  .textTheme.bodySmall
                  ?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FORMATTERS
// ============================================================

String _formatDate(
  DateTime? value,
) {
  if (value == null) {
    return 'Нет данных';
  }

  final local = value.toLocal();

  final day = local.day
      .toString()
      .padLeft(2, '0');

  final month = local.month
      .toString()
      .padLeft(2, '0');

  return '$day.$month.${local.year}';
}

String _formatName(
  String value,
) {
  final cleaned = value
      .trim()
      .replaceAll('_', ' ')
      .toLowerCase();

  if (cleaned.isEmpty) {
    return 'Не указано';
  }

  return cleaned[0].toUpperCase() +
      cleaned.substring(1);
}

String _formatTechnique(
  String value,
) {
  switch (
      value.trim().toUpperCase()) {
    case 'SOCRATIC_DIALOGUE':
      return 'Сократический диалог';

    case 'DOWNWARD_ARROW':
      return 'Нисходящая стрелка';

    case 'REFRAMING':
      return 'Рефрейминг';

    case 'SUMMARY':
      return 'Подведение итогов';

    case 'GROUNDING':
      return 'Заземление';

    default:
      return _formatName(value);
  }
}