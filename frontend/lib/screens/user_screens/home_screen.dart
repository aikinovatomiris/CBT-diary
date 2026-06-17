// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
import '../../widgets/animated_ai_sphere/liquid_ai_orb.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeData {
  final UserModel user;
  final AnalyticsSummaryModel summary;
  final AnalyticsDistortionsResponseModel distortions;
  final AnalyticsTechniquesResponseModel techniques;
  final List<DiaryEntryModel> diaryEntries;
  final List<CBTSessionModel> sessions;

  const _HomeData({
    required this.user,
    required this.summary,
    required this.distortions,
    required this.techniques,
    required this.diaryEntries,
    required this.sessions,
  });

  CBTSessionModel? get activeSession {
    final activeSessions = sessions.where((session) {
      return session.status == 'active';
    }).toList();

    if (activeSessions.isEmpty) {
      return null;
    }

    activeSessions.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return activeSessions.first;
  }

  DiaryEntryModel? get latestEntry {
    if (diaryEntries.isEmpty) {
      return null;
    }

    final sortedEntries = [...diaryEntries];

    sortedEntries.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return sortedEntries.first;
  }

  AnalyticsDistortionModel? get topDistortion {
    final validItems = distortions.items.where((item) {
      final name = item.name;
      final count = item.count ?? 0;

      return name != null && name.trim().isNotEmpty && count > 0;
    }).toList();

    if (validItems.isEmpty) {
      return null;
    }

    validItems.sort((a, b) {
      return (b.count ?? 0).compareTo(a.count ?? 0);
    });

    return validItems.first;
  }

  AnalyticsTechniqueModel? get topTechnique {
    final validItems = techniques.items.where((item) {
      final technique = item.technique;
      final count = item.count ?? 0;

      if (technique == null || technique.trim().isEmpty || count <= 0) {
        return false;
      }

      return technique.trim().toUpperCase() != 'NONE';
    }).toList();

    if (validItems.isEmpty) {
      return null;
    }

    validItems.sort((a, b) {
      return (b.count ?? 0).compareTo(a.count ?? 0);
    });

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
    final user = await AuthService.me();
    final summary = await AnalyticsService.getSummary();
    final distortions = await AnalyticsService.getDistortions();
    final techniques = await AnalyticsService.getTechniques();
    final diaryEntries = await DiaryService.getEntries();
    final sessions = await CbtService.getSessions();

    return _HomeData(
      user: user,
      summary: summary,
      distortions: distortions,
      techniques: techniques,
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
    if (_isCreatingSession) return;

    setState(() {
      _isCreatingSession = true;
    });

    try {
      final session = await CbtService.createSession();

      if (!mounted) return;

      final sessionId = session.id;

      if (sessionId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сервер не вернул ID новой сессии.'),
          ),
        );
        return;
      }

      context.push('${AppRoutes.chat}?session_id=$sessionId');
    } on ApiException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось создать новую сессию.'),
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

  void _continueSession(CBTSessionModel session) {
    final sessionId = session.id;

    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У активной сессии нет ID.'),
        ),
      );
      return;
    }

    context.push('${AppRoutes.chat}?session_id=$sessionId');
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Нет данных';

    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();

    return '$day.$month.$year';
  }

  String _safeText(String? value, {String fallback = 'Не заполнено'}) {
    if (value == null || value.trim().isEmpty) {
      return fallback;
    }

    return value.trim();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _homeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
              message: 'Не удалось получить данные главного экрана.',
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
  final ValueChanged<CBTSessionModel> onContinueSession;
  final String Function(DateTime?) formatDate;
  final String Function(String?, {String fallback}) safeText;

  const _HomeContent({
    required this.data,
    required this.isCreatingSession,
    required this.onRefresh,
    required this.onCreateSession,
    required this.onContinueSession,
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
    final latestEntry = data.latestEntry;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 650;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 620 : double.infinity,
                ),
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      120,
                    ),
                    children: [
                      Text(
                        'Привет, $userName',
                        textAlign: TextAlign.left,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          letterSpacing: -0.7,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      AnimatedAISphere(
                        isLoading: isCreatingSession,
                        onTap: onCreateSession,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      _WeeklyDiaryActivity(
                        entries: data.diaryEntries,
                      ),

                      if (activeSession != null) ...[
                        const SizedBox(height: AppSpacing.xxl),
                        _ContinueSessionCard(
                          session: activeSession,
                          onTap: () => onContinueSession(activeSession),
                          formatDate: formatDate,
                          safeText: safeText,
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xxl),

                      Text(
                        'Аналитика',
                        textAlign: TextAlign.left,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      _AnalyticsCard(
                        data: data,
                        latestEntry: latestEntry,
                        formatDate: formatDate,
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

class _WeeklyDiaryActivity extends StatelessWidget {
  final List<DiaryEntryModel> entries;

  const _WeeklyDiaryActivity({
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final monday = todayDate.subtract(
      Duration(days: todayDate.weekday - DateTime.monday),
    );

    final weekDays = List.generate(7, (index) {
      return monday.add(Duration(days: index));
    });

    final activeDates = entries
        .where((entry) => entry.createdAt != null)
        .map((entry) {
          final localDate = entry.createdAt!.toLocal();
          return DateTime(localDate.year, localDate.month, localDate.day);
        })
        .toList();

    final cardBackground = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

    final borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cardBackground,
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
            children: List.generate(weekDays.length, (index) {
              final day = weekDays[index];
              final hasEntry = activeDates.any((date) {
                return _isSameDate(date, day);
              });
              final isToday = _isSameDate(day, todayDate);

              return Expanded(
                child: _WeekDayIndicator(
                  label: _weekdayLabel(index),
                  hasEntry: hasEntry,
                  isToday: isToday,
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Дни с записями в дневнике',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static String _weekdayLabel(int index) {
    const labels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return labels[index];
  }
}

class _WeekDayIndicator extends StatelessWidget {
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
    final isDark = theme.brightness == Brightness.dark;

    final primary = theme.colorScheme.primary;

    final emptyBackground = isDark
        ? AppColors.darkSurfaceSoft.withOpacity(0.52)
        : AppColors.white.withOpacity(0.58);

    final emptyBorder = isDark
        ? AppColors.darkBorder
        : AppColors.white.withOpacity(0.82);

    final circleColor = hasEntry ? primary : emptyBackground;

    final borderColor = isToday
        ? primary
        : hasEntry
            ? primary.withOpacity(0.36)
            : emptyBorder;

    final textColor = hasEntry
        ? AppColors.white
        : isDark
            ? AppColors.darkMutedText
            : AppColors.lightMutedText;

    final labelColor = isToday
        ? primary
        : theme.colorScheme.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: labelColor,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: isToday ? 36 : 32,
          height: isToday ? 36 : 32,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: isToday ? 1.8 : 1,
            ),
            boxShadow: hasEntry
                ? [
                    BoxShadow(
                      color: primary.withOpacity(isDark ? 0.28 : 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: hasEntry
                ? Icon(
                    Icons.check_rounded,
                    size: isToday ? 18 : 16,
                    color: textColor,
                  )
                : Container(
                    width: isToday ? 5 : 4,
                    height: isToday ? 5 : 4,
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(isToday ? 0.9 : 0.45),
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ContinueSessionCard extends StatelessWidget {
  final CBTSessionModel session;
  final VoidCallback onTap;
  final String Function(DateTime?) formatDate;
  final String Function(String?, {String fallback}) safeText;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SoftIconBox(
                icon: Icons.auto_awesome_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Продолжить сессию',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.35,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          _SmallInfoRow(
            label: 'Текущий шаг',
            value: currentStep,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SmallInfoRow(
            label: 'Создана',
            value: formatDate(session.createdAt),
          ),

          const SizedBox(height: AppSpacing.lg),

          AppButton(
            text: 'Продолжить',
            variant: AppButtonVariant.secondary,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final _HomeData data;
  final DiaryEntryModel? latestEntry;
  final String Function(DateTime?) formatDate;

  const _AnalyticsCard({
    required this.data,
    required this.latestEntry,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;

    final topDistortion = data.topDistortion;
    final topTechnique = data.topTechnique;

    final totalSessions = summary.totalSessions ?? data.sessions.length;
    final finishedSessions = summary.finishedSessions ?? 0;
    final totalDiaryEntries =
        summary.totalDiaryEntries ?? data.diaryEntries.length;

    final latestEntryDate = summary.latestEntryDate ?? latestEntry?.createdAt;

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalyticsGrid(
            children: [
              _AnalyticsTile(
                label: 'Всего сессий',
                value: '$totalSessions',
                icon: Icons.chat_bubble_outline_rounded,
              ),
              _AnalyticsTile(
                label: 'Завершено',
                value: '$finishedSessions',
                icon: Icons.check_circle_outline_rounded,
              ),
              _AnalyticsTile(
                label: 'Записей',
                value: '$totalDiaryEntries',
                icon: Icons.menu_book_rounded,
              ),
              _AnalyticsTile(
                label: 'Последняя запись',
                value: formatDate(latestEntryDate),
                icon: Icons.calendar_today_rounded,
                isDate: true,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          _InsightRow(
            label: 'Частое искажение',
            value: _formatAnalyticsName(topDistortion?.name),
            count: topDistortion?.count,
          ),

          const SizedBox(height: AppSpacing.md),

          _InsightRow(
            label: 'Частая техника',
            value: _formatTechniqueName(topTechnique?.technique),
            count: topTechnique?.count,
          ),
        ],
      ),
    );
  }

  static String _formatAnalyticsName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Нет данных';
    }

    final cleaned = value.trim().replaceAll('_', ' ').toLowerCase();

    if (cleaned.isEmpty) {
      return 'Нет данных';
    }

    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  static String _formatTechniqueName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Нет данных';
    }

    final normalized = value.trim().toUpperCase();

    switch (normalized) {
      case 'SOCRATIC_DIALOGUE':
        return 'Сократический диалог';
      case 'DOWNWARD_ARROW':
        return 'Нисходящая стрелка';
      case 'REFRAMING':
        return 'Рефрейминг';
      case 'SUMMARY':
        return 'Подведение итогов';
      case 'NONE':
        return 'Нет данных';
      default:
        return _formatAnalyticsName(value);
    }
  }
}

class _AnalyticsGrid extends StatelessWidget {
  final List<Widget> children;

  const _AnalyticsGrid({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - AppSpacing.md) / 2;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: children.map((child) {
            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}

class _AnalyticsTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDate;

  const _AnalyticsTile({
    required this.label,
    required this.value,
    required this.icon,
    this.isDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? AppColors.darkSurfaceSoft.withOpacity(0.72)
        : AppColors.white.withOpacity(0.52);

    final borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.white.withOpacity(0.78);

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SoftIconBox(
            icon: icon,
            color: theme.colorScheme.primary,
            size: 34,
            iconSize: 17,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            maxLines: isDate ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: isDate ? 16 : 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final String label;
  final String value;
  final int? count;

  const _InsightRow({
    required this.label,
    required this.value,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hasCount = count != null && count! > 0 && value != 'Нет данных';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SoftIconBox(
          icon: Icons.insights_rounded,
          color: theme.colorScheme.primary,
          size: 34,
          iconSize: 17,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasCount ? '$value · $count' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SmallInfoRow extends StatelessWidget {
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
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.15,
            ),
          ),
        ),
      ],
    );
  }
}

class _SoftIconBox extends StatelessWidget {
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
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(size * 0.38),
        border: Border.all(
          color: color.withOpacity(0.10),
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

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}