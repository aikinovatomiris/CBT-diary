// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../models/analytics_model.dart';
import '../../models/cbt_session_model.dart';
import '../../models/diary_entry_model.dart';
import '../../models/user_model.dart';
import '../../navigation/app_routes.dart';
import '../../services/analytics_service.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/cbt_service.dart';
import '../../services/diary_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() {
    return _HomeScreenState();
  }
}

class _HomeData {
  final UserModel user;

  final AnalyticsSummaryModel summary;

  final AnalyticsDistortionsResponseModel distortions;

  final AnalyticsTechniquesResponseModel techniques;

  final AnalyticsWellbeingWeekModel wellbeingWeek;

  final AnalyticsResilienceModel resilience;

  final List<DiaryEntryModel> diaryEntries;

  final List<CBTSessionModel> sessions;

  const _HomeData({
    required this.user,
    required this.summary,
    required this.distortions,
    required this.techniques,
    required this.wellbeingWeek,
    required this.resilience,
    required this.diaryEntries,
    required this.sessions,
  });

  CBTSessionModel? get activeSession {
    final activeSessions = sessions.where(
      (session) {
        return session.status == 'active';
      },
    ).toList();

    if (activeSessions.isEmpty) {
      return null;
    }

    activeSessions.sort(
      (a, b) {
        final aDate =
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final bDate =
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);

        return bDate.compareTo(aDate);
      },
    );

    return activeSessions.first;
  }

  DiaryEntryModel? get latestEntry {
    if (diaryEntries.isEmpty) {
      return null;
    }

    final sortedEntries = [
      ...diaryEntries,
    ];

    sortedEntries.sort(
      (a, b) {
        final aDate =
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final bDate =
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);

        return bDate.compareTo(aDate);
      },
    );

    return sortedEntries.first;
  }

  AnalyticsDistortionModel? get topDistortion {
    final validItems = distortions.items.where(
      (item) {
        final name = item.name;
        final count = item.count ?? 0;

        return name != null &&
            name.trim().isNotEmpty &&
            count > 0;
      },
    ).toList();

    if (validItems.isEmpty) {
      return null;
    }

    validItems.sort(
      (a, b) {
        return (b.count ?? 0).compareTo(
          a.count ?? 0,
        );
      },
    );

    return validItems.first;
  }

  AnalyticsTechniqueModel? get topTechnique {
    final validItems = techniques.items.where(
      (item) {
        final technique = item.technique;
        final count = item.count ?? 0;

        if (technique == null ||
            technique.trim().isEmpty ||
            count <= 0) {
          return false;
        }

        return technique.trim().toUpperCase() !=
            'NONE';
      },
    ).toList();

    if (validItems.isEmpty) {
      return null;
    }

    validItems.sort(
      (a, b) {
        return (b.count ?? 0).compareTo(
          a.count ?? 0,
        );
      },
    );

    return validItems.first;
  }
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _homeFuture;

  bool _isCreatingSession = false;

  @override
  void initState() {
    super.initState();

    _homeFuture = _loadHomeData();
  }

  Future<_HomeData> _loadHomeData() async {
    final results = await Future.wait<dynamic>(
      [
        AuthService.me(),
        AnalyticsService.getDetails(),
        DiaryService.getEntries(),
        CbtService.getSessions(),
      ],
    );

    final user = results[0] as UserModel;

    final analytics =
        results[1] as AnalyticsDetailsData;

    final diaryEntries =
        results[2] as List<DiaryEntryModel>;

    final sessions =
        results[3] as List<CBTSessionModel>;

    return _HomeData(
      user: user,
      summary: analytics.summary,
      distortions: analytics.distortions,
      techniques: analytics.techniques,
      wellbeingWeek: analytics.wellbeingWeek,
      resilience: analytics.resilience,
      diaryEntries: diaryEntries,
      sessions: sessions,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _homeFuture = _loadHomeData();
    });

    await _homeFuture;
  }

  Future<void> _createSession() async {
    if (_isCreatingSession) {
      return;
    }

    setState(() {
      _isCreatingSession = true;
    });

    try {
      final session =
          await CbtService.createSession();

      if (!mounted) {
        return;
      }

      final sessionId = session.id;

      if (sessionId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Сервер не вернул ID новой сессии.',
            ),
          ),
        );

        return;
      }

      await context.push(
        '${AppRoutes.chat}?session_id=$sessionId',
      );

      if (!mounted) {
        return;
      }

      await _refresh();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось создать новую сессию.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingSession = false;
        });
      }
    }
  }

  Future<void> _continueSession(
    CBTSessionModel session,
  ) async {
    final sessionId = session.id;

    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'У активной сессии нет ID.',
          ),
        ),
      );

      return;
    }

    await context.push(
      '${AppRoutes.chat}?session_id=$sessionId',
    );

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  Future<void> _openAnalytics() async {
    await context.push(
      AppRoutes.analytics,
    );

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Нет данных';
    }

    final localDate = date.toLocal();

    final day = localDate.day
        .toString()
        .padLeft(2, '0');

    final month = localDate.month
        .toString()
        .padLeft(2, '0');

    final year = localDate.year.toString();

    return '$day.$month.$year';
  }

  String _safeText(
    String? value, {
    String fallback = 'Не заполнено',
  }) {
    if (value == null ||
        value.trim().isEmpty) {
      return fallback;
    }

    return value.trim();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _homeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: AppLoading(
              text: 'Загрузка главной...',
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;

          final message = error is ApiException
              ? error.message
              : 'Не удалось загрузить главный экран.';

          return Scaffold(
            body: AppErrorView(
              message: message,
              onRetry: _refresh,
            ),
          );
        }

        final data = snapshot.data;

        if (data == null) {
          return Scaffold(
            body: AppErrorView(
              message:
                  'Не удалось получить данные главного экрана.',
              onRetry: _refresh,
            ),
          );
        }

        return _HomeContent(
          data: data,
          isCreatingSession: _isCreatingSession,
          onRefresh: _refresh,
          onCreateSession: _createSession,
          onContinueSession: _continueSession,
          onOpenAnalytics: _openAnalytics,
          formatDate: _formatDate,
          safeText: _safeText,
        );
      },
    );
  }
}

class _HomeContent extends StatelessWidget {
  final _HomeData data;

  final bool isCreatingSession;

  final Future<void> Function() onRefresh;

  final VoidCallback onCreateSession;

  final ValueChanged<CBTSessionModel>
  onContinueSession;

  final VoidCallback onOpenAnalytics;

  final String Function(DateTime?) formatDate;

  final String Function(
    String?, {
    String fallback,
  })
  safeText;

  const _HomeContent({
    required this.data,
    required this.isCreatingSession,
    required this.onRefresh,
    required this.onCreateSession,
    required this.onContinueSession,
    required this.onOpenAnalytics,
    required this.formatDate,
    required this.safeText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final userName = safeText(
      data.user.name,
      fallback: 'пользователь',
    );

    final activeSession = data.activeSession;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide =
                constraints.maxWidth > 650;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide
                      ? 620
                      : double.infinity,
                ),
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      120,
                    ),
                    children: [
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Привет, $userName',
                                  style: theme
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                    fontWeight:
                                        FontWeight.w700,
                                    letterSpacing: -0.35,
                                  ),
                                ),
                                const SizedBox(
                                  height: AppSpacing.sm,
                                ),
                                Text(
                                  'Готовы разобраться в себе?',
                                  style: theme
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                    color: theme
                                        .colorScheme
                                        .onSurfaceVariant,
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
                      const SizedBox(
                        height: AppSpacing.xxl,
                      ),
                      _LottieSessionOrb(
                        isLoading: isCreatingSession,
                        onTap: onCreateSession,
                      ),
                      const SizedBox(
                        height: AppSpacing.xl,
                      ),
                      _WeeklyDiaryActivity(
                        entries: data.diaryEntries,
                      ),
                      if (activeSession != null) ...[
                        const SizedBox(
                          height: AppSpacing.xxl,
                        ),
                        _ContinueSessionCard(
                          session: activeSession,
                          onTap: () {
                            onContinueSession(
                              activeSession,
                            );
                          },
                          formatDate: formatDate,
                          safeText: safeText,
                        ),
                      ],
                      const SizedBox(
                        height: AppSpacing.xxl,
                      ),
                      _AnalyticsOverviewCard(
                        data: data,
                        onTap: onOpenAnalytics,
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

// ============================================================
// MESSAGES ACTION
// ============================================================

class _MessagesActionShell extends StatelessWidget {
  const _MessagesActionShell();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

    final borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

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
                ? AppColors.darkShadow.withOpacity(
                    0.12,
                  )
                : AppColors.lightShadow.withOpacity(
                    0.45,
                  ),
            blurRadius: 18,
            offset: const Offset(
              0,
              8,
            ),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.large,
        child: InkWell(
          onTap: () {
            context.push(
              AppRoutes.conversations,
            );
          },
          borderRadius: AppRadius.large,
          child: Center(
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: theme.colorScheme.primary,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SESSION ORB
// ============================================================

class _LottieSessionOrb extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _LottieSessionOrb({
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness ==
        Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth;

        final orbSize = availableWidth
            .clamp(260.0, 380.0)
            .toDouble();

        return Center(
          child: Semantics(
            button: true,
            label: isLoading
                ? 'Создание КПТ-сессии'
                : 'Начать новую КПТ-сессию',
            child: GestureDetector(
              behavior:
                  HitTestBehavior.opaque,
              onTap:
                  isLoading ? null : onTap,
              child: SizedBox(
                width: orbSize,
                height: orbSize,
                child: Stack(
                  alignment:
                      Alignment.center,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Lottie.asset(
                          'assets/lottie/Orbit.json',
                          fit: BoxFit.contain,
                          repeat: true,
                          animate: true,
                          frameRate:
                              FrameRate.max,
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Container(
                        width: orbSize * 0.58,
                        height: orbSize * 0.58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient:
                              RadialGradient(
                            colors: isDark
                                ? [
                                    const Color(
                                      0xFF080B22,
                                    ).withOpacity(
                                      0.42,
                                    ),
                                    const Color(
                                      0xFF080B22,
                                    ).withOpacity(
                                      0.12,
                                    ),
                                    Colors
                                        .transparent,
                                  ]
                                : [
                                    Colors.white
                                        .withOpacity(
                                      0.58,
                                    ),
                                    Colors.white
                                        .withOpacity(
                                      0.20,
                                    ),
                                    Colors
                                        .transparent,
                                  ],
                            stops: const [
                              0.0,
                              0.62,
                              1.0,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Text(
                          'КПТ-сессия',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            fontSize:
                                orbSize *
                                0.074,
                            fontWeight:
                                FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(
                                    0xFF1A1A2E,
                                  ),
                            letterSpacing:
                                -0.5,
                            shadows: isDark
                                ? [
                                    Shadow(
                                      color:
                                          const Color(
                                            0xFF3B82FF,
                                          ).withOpacity(
                                            0.60,
                                          ),
                                      blurRadius:
                                          20,
                                    ),
                                  ]
                                : [
                                    Shadow(
                                      color:
                                          const Color(
                                            0xFF8A5CFF,
                                          ).withOpacity(
                                            0.30,
                                          ),
                                      blurRadius:
                                          12,
                                    ),
                                  ],
                          ),
                        ),
                        SizedBox(
                          height:
                              orbSize *
                              0.018,
                        ),
                        Text(
                          isLoading
                              ? 'Создаём сессию…'
                              : 'Начать сессию',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            fontSize:
                                orbSize *
                                0.041,
                            fontWeight:
                                FontWeight.w500,
                            color: isDark
                                ? Colors.white
                                    .withOpacity(
                                      0.72,
                                    )
                                : const Color(
                                    0xFF5F6472,
                                  ),
                            letterSpacing:
                                0.1,
                          ),
                        ),
                        SizedBox(
                          height:
                              orbSize *
                              0.055,
                        ),
                        _LottieStartButton(
                          size:
                              orbSize *
                              0.15,
                          isLoading:
                              isLoading,
                          isDark: isDark,
                          onPressed: onTap,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LottieStartButton
    extends StatelessWidget {
  final double size;
  final bool isLoading;
  final bool isDark;
  final VoidCallback onPressed;

  const _LottieStartButton({
    required this.size,
    required this.isLoading,
    required this.isDark,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context)
            .colorScheme
            .primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder:
            const CircleBorder(),
        onTap:
            isLoading
                ? null
                : onPressed,
        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 180,
          ),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white
                .withOpacity(
              isDark ? 0.94 : 0.90,
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white
                      .withOpacity(
                        0.80,
                      )
                  : primary
                      .withOpacity(
                        0.20,
                      ),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: primary
                    .withOpacity(
                  isDark
                      ? 0.38
                      : 0.20,
                ),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width:
                        size * 0.36,
                    height:
                        size * 0.36,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: primary,
                    ),
                  )
                : Icon(
                    Icons
                        .arrow_forward_rounded,
                    size:
                        size * 0.46,
                    color: primary,
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// WEEKLY DIARY ACTIVITY
// ============================================================

class _WeeklyDiaryActivity
    extends StatelessWidget {
  final List<DiaryEntryModel> entries;

  const _WeeklyDiaryActivity({
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness ==
        Brightness.dark;

    final today = DateTime.now();

    final todayDate = DateTime(
      today.year,
      today.month,
      today.day,
    );

    final monday = todayDate.subtract(
      Duration(
        days:
            todayDate.weekday -
            DateTime.monday,
      ),
    );

    final weekDays = List.generate(
      7,
      (index) {
        return monday.add(
          Duration(days: index),
        );
      },
    );

    final activeDates = entries
        .where(
          (entry) =>
              entry.createdAt != null,
        )
        .map(
          (entry) {
            final localDate =
                entry.createdAt!
                    .toLocal();

            return DateTime(
              localDate.year,
              localDate.month,
              localDate.day,
            );
          },
        )
        .toList();

    final cardBackground = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

    final borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    return Container(
      padding:
          const EdgeInsets.all(
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius:
            AppRadius.extraLarge,
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              weekDays.length,
              (index) {
                final day =
                    weekDays[index];

                final hasEntry =
                    activeDates.any(
                  (date) {
                    return _isSameDate(
                      date,
                      day,
                    );
                  },
                );

                final isToday =
                    _isSameDate(
                  day,
                  todayDate,
                );

                return Expanded(
                  child:
                      _WeekDayIndicator(
                    label:
                        _weekdayLabel(
                      index,
                    ),
                    hasEntry:
                        hasEntry,
                    isToday:
                        isToday,
                  ),
                );
              },
            ),
          ),
          const SizedBox(
            height: AppSpacing.md,
          ),
          Text(
            'Дни с записями в дневнике',
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

  static String _weekdayLabel(
    int index,
  ) {
    const labels = [
      'Пн',
      'Вт',
      'Ср',
      'Чт',
      'Пт',
      'Сб',
      'Вс',
    ];

    return labels[index];
  }
}

class _WeekDayIndicator
    extends StatelessWidget {
  final String label;
  final bool hasEntry;
  final bool isToday;

  const _WeekDayIndicator({
    required this.label,
    required this.hasEntry,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness ==
        Brightness.dark;

    final primary =
        theme.colorScheme.primary;

    final emptyBackground = isDark
        ? AppColors.darkSurfaceSoft
            .withOpacity(0.52)
        : AppColors.white
            .withOpacity(0.58);

    final emptyBorder = isDark
        ? AppColors.darkBorder
        : AppColors.white
            .withOpacity(0.82);

    final circleColor = hasEntry
        ? primary
        : emptyBackground;

    final borderColor = isToday
        ? primary
        : hasEntry
            ? primary.withOpacity(
                0.36,
              )
            : emptyBorder;

    final textColor = hasEntry
        ? AppColors.white
        : isDark
            ? AppColors.darkMutedText
            : AppColors.lightMutedText;

    final labelColor = isToday
        ? primary
        : theme
            .colorScheme
            .onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme
              .textTheme.labelSmall
              ?.copyWith(
            color: labelColor,
            fontWeight: isToday
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        const SizedBox(
          height: AppSpacing.sm,
        ),
        AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 180,
          ),
          width:
              isToday ? 36 : 32,
          height:
              isToday ? 36 : 32,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width:
                  isToday ? 1.8 : 1,
            ),
            boxShadow: hasEntry
                ? [
                    BoxShadow(
                      color: primary
                          .withOpacity(
                        isDark
                            ? 0.28
                            : 0.18,
                      ),
                      blurRadius: 12,
                      offset:
                          const Offset(
                        0,
                        4,
                      ),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: hasEntry
                ? Icon(
                    Icons
                        .check_rounded,
                    size:
                        isToday
                            ? 18
                            : 16,
                    color:
                        textColor,
                  )
                : Container(
                    width:
                        isToday
                            ? 5
                            : 4,
                    height:
                        isToday
                            ? 5
                            : 4,
                    decoration:
                        BoxDecoration(
                      color: textColor
                          .withOpacity(
                        isToday
                            ? 0.9
                            : 0.45,
                      ),
                      shape:
                          BoxShape.circle,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ACTIVE SESSION
// ============================================================

class _ContinueSessionCard
    extends StatelessWidget {
  final CBTSessionModel session;

  final VoidCallback onTap;

  final String Function(DateTime?)
  formatDate;

  final String Function(
    String?, {
    String fallback,
  })
  safeText;

  const _ContinueSessionCard({
    required this.session,
    required this.onTap,
    required this.formatDate,
    required this.safeText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final currentStep = safeText(
      session.currentStep,
      fallback: 'Шаг не указан',
    );

    return AppCard(
      hasShadow: false,
      onTap: onTap,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SoftIconBox(
                icon: Icons
                    .auto_awesome_rounded,
                color: theme
                    .colorScheme
                    .primary,
              ),
              const SizedBox(
                width: AppSpacing.md,
              ),
              Expanded(
                child: Text(
                  'Продолжить сессию',
                  style: theme
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                    letterSpacing:
                        -0.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          _SmallInfoRow(
            label: 'Текущий шаг',
            value: currentStep,
          ),
          const SizedBox(
            height: AppSpacing.sm,
          ),
          _SmallInfoRow(
            label: 'Создана',
            value: formatDate(
              session.createdAt,
            ),
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          AppButton(
            text: 'Продолжить',
            variant:
                AppButtonVariant
                    .secondary,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HOME ANALYTICS OVERVIEW
// ============================================================

class _AnalyticsOverviewCard
    extends StatelessWidget {
  final _HomeData data;
  final VoidCallback onTap;

  const _AnalyticsOverviewCard({
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final summary = data.summary;

    final totalSessions =
        summary.totalSessions ??
        data.sessions.length;

    final totalEntries =
        summary.totalDiaryEntries ??
        data.diaryEntries.length;

    final techniquesCount =
        data.techniques.items
            .where(
              (item) =>
                  (item.count ?? 0) > 0,
            )
            .length;


    return AppCard(
      hasShadow: false,
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Аналитика',
                    style: theme
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                      letterSpacing:
                          -0.45,
                    ),
                  ),
                ),
                Icon(
                  Icons
                      .chevron_right_rounded,
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                  size: 28,
                ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _HomeMoodPreview(
                    wellbeing:
                        data.wellbeingWeek,
                  ),
                ),
                const SizedBox(
                  width: AppSpacing.xl,
                ),
                Expanded(
                  child:
                      _HomeResiliencePreview(
                    resilience:
                        data.resilience,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: theme.dividerColor
                .withOpacity(0.55),
          ),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child:
                      _AnalyticsBottomValue(
                    label: 'Записей',
                    value:
                        '$totalEntries',
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: theme
                      .dividerColor
                      .withOpacity(
                        0.55,
                      ),
                ),
                Expanded(
                  child:
                      _AnalyticsBottomValue(
                    label: 'Техник',
                    value:
                        '$techniquesCount',
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: theme
                      .dividerColor
                      .withOpacity(
                        0.55,
                      ),
                ),
                Expanded(
                  child:
                      _AnalyticsBottomValue(
                    label: 'Сессий',
                    value:
                        '$totalSessions',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMoodPreview
    extends StatelessWidget {
  final AnalyticsWellbeingWeekModel
  wellbeing;

  const _HomeMoodPreview({
    required this.wellbeing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Состояние',
          style: theme
              .textTheme.bodyMedium
              ?.copyWith(
            color: theme
                .colorScheme
                .onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'за неделю',
          style: theme
              .textTheme.bodySmall
              ?.copyWith(
            color: theme
                .colorScheme
                .onSurfaceVariant,
          ),
        ),
        const SizedBox(
          height: AppSpacing.lg,
        ),
        SizedBox(
          height: 92,
          width: double.infinity,
          child: wellbeing.hasData
              ? CustomPaint(
                  painter:
                      _MiniWellbeingPainter(
                    items:
                        wellbeing.items,
                    lineColor: theme
                        .colorScheme
                        .primary,
                    mutedColor: theme
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(
                          0.18,
                        ),
                  ),
                )
              : Center(
                  child: Text(
                    'Нет данных',
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: theme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _HomeResiliencePreview
    extends StatelessWidget {
  final AnalyticsResilienceModel
  resilience;

  const _HomeResiliencePreview({
    required this.resilience,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final score =
        resilience.safeScore;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Устойчивость',
          style: theme
              .textTheme.bodyMedium
              ?.copyWith(
            color: theme
                .colorScheme
                .onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          resilience.hasData
              ? '$score%'
              : '—',
          style: theme
              .textTheme
              .headlineMedium
              ?.copyWith(
            fontWeight:
                FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(
          height: AppSpacing.md,
        ),
        Center(
          child: SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              alignment:
                  Alignment.center,
              children: [
                SizedBox.expand(
                  child:
                      CircularProgressIndicator(
                    value:
                        resilience.hasData
                            ? score / 100
                            : 0,
                    strokeWidth: 7,
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
                Icon(
                  Icons
                      .favorite_rounded,
                  color: theme
                      .colorScheme
                      .primary,
                  size: 31,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsBottomValue
    extends StatelessWidget {
  final String label;
  final String value;

  const _AnalyticsBottomValue({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.all(
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme
                .textTheme.bodyMedium
                ?.copyWith(
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme
                .textTheme
                .titleLarge
                ?.copyWith(
              fontWeight:
                  FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniWellbeingPainter
    extends CustomPainter {
  final List<AnalyticsWellbeingDayModel>
  items;

  final Color lineColor;
  final Color mutedColor;

  const _MiniWellbeingPainter({
    required this.items,
    required this.lineColor,
    required this.mutedColor,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (items.isEmpty) {
      return;
    }

    final gridPaint = Paint()
      ..color = mutedColor
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(0, size.height * 0.75),
      Offset(
        size.width,
        size.height * 0.75,
      ),
      gridPaint,
    );

    final points =
        <int, Offset>{};

    final horizontalStep =
        items.length <= 1
        ? 0.0
        : size.width /
            (items.length - 1);

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

      final x =
          horizontalStep * index;

      final y = size.height -
          normalized *
              (size.height - 10) -
          5;

      points[index] = Offset(x, y);
    }

    if (points.isEmpty) {
      return;
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    Path? currentPath;
    int? previousIndex;

    for (
      int index = 0;
      index < items.length;
      index++
    ) {
      final point = points[index];

      if (point == null) {
        currentPath = null;
        previousIndex = null;
        continue;
      }

      if (currentPath == null ||
          previousIndex == null ||
          index != previousIndex + 1) {
        currentPath = Path()
          ..moveTo(
            point.dx,
            point.dy,
          );
      } else {
        currentPath.lineTo(
          point.dx,
          point.dy,
        );
      }

      if (previousIndex != null &&
          index == previousIndex + 1) {
        canvas.drawPath(
          currentPath,
          linePaint,
        );
      }

      canvas.drawCircle(
        point,
        3.5,
        dotPaint,
      );

      previousIndex = index;
    }
  }

  @override
  bool shouldRepaint(
    covariant _MiniWellbeingPainter
        oldDelegate,
  ) {
    return oldDelegate.items != items ||
        oldDelegate.lineColor !=
            lineColor ||
        oldDelegate.mutedColor !=
            mutedColor;
  }
}

// ============================================================
// SHARED HOME WIDGETS
// ============================================================

class _SmallInfoRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _SmallInfoRow({
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
        Flexible(
          child: Text(
            value,
            textAlign:
                TextAlign.right,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: theme
                .textTheme.bodyMedium
                ?.copyWith(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SoftIconBox
    extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const _SoftIconBox({
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color:
            color.withOpacity(0.11),
        borderRadius:
            BorderRadius.circular(
          size * 0.38,
        ),
        border: Border.all(
          color:
              color.withOpacity(0.10),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: iconSize,
      ),
    );
  }
}

bool _isSameDate(
  DateTime a,
  DateTime b,
) {
  return a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;
}