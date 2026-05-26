import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/analytics_model.dart';
import '../models/cbt_session_model.dart';
import '../models/diary_entry_model.dart';
import '../models/user_model.dart';
import '../navigation/app_routes.dart';
import '../services/analytics_service.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/cbt_service.dart';
import '../services/diary_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_error_view.dart';
import '../widgets/app_loading.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeData {
  final UserModel user;
  final AnalyticsSummaryModel summary;
  final List<DiaryEntryModel> diaryEntries;
  final List<CBTSessionModel> sessions;

  const _HomeData({
    required this.user,
    required this.summary,
    required this.diaryEntries,
    required this.sessions,
  });

  CBTSessionModel? get activeSession {
    for (final session in sessions) {
      if (session.status == 'active') {
        return session;
      }
    }

    return null;
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
    final diaryEntries = await DiaryService.getEntries();
    final sessions = await CbtService.getSessions();

    return _HomeData(
      user: user,
      summary: summary,
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

  void _openDiaryEntry(DiaryEntryModel entry) {
    final entryId = entry.id;

    if (entryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У дневниковой записи нет ID.'),
        ),
      );
      return;
    }

    context.push('/diary/$entryId');
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Нет данных';

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
          onOpenDiaryEntry: _openDiaryEntry,
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
  final ValueChanged<DiaryEntryModel> onOpenDiaryEntry;
  final String Function(DateTime?) formatDate;
  final String Function(String?, {String fallback}) safeText;

  const _HomeContent({
    required this.data,
    required this.isCreatingSession,
    required this.onRefresh,
    required this.onCreateSession,
    required this.onContinueSession,
    required this.onOpenDiaryEntry,
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
        title: const Text('Главная'),
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
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      110,
                    ),
                    children: [
                      Text(
                        'Привет, $userName',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Готова разобрать мысли или продолжить прошлую сессию?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      AppCard(
                        hasShadow: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Новая КПТ-сессия',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Начни новую сессию, чтобы описать ситуацию, мысли, эмоции и найти более рациональный взгляд.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppButton(
                              text: 'Начать новую сессию',
                              isLoading: isCreatingSession,
                              onPressed: onCreateSession,
                            ),
                          ],
                        ),
                      ),

                      if (activeSession != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        AppCard(
                          hasShadow: false,
                          onTap: () => onContinueSession(activeSession),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Продолжить сессию',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Текущий шаг: ${safeText(activeSession.currentStep)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Создана: ${formatDate(activeSession.createdAt)}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              AppButton(
                                text: 'Продолжить',
                                variant: AppButtonVariant.secondary,
                                onPressed: () =>
                                    onContinueSession(activeSession),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.lg),

                      AppCard(
                        hasShadow: false,
                        onTap: latestEntry == null
                            ? null
                            : () => onOpenDiaryEntry(latestEntry),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Последняя запись',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            if (latestEntry == null)
                              Text(
                                'Пока нет дневниковых записей.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                            else ...[
                              Text(
                                safeText(latestEntry.situation),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Дата: ${formatDate(latestEntry.createdAt)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      AppCard(
                        hasShadow: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Краткая статистика',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _StatRow(
                              label: 'Всего сессий',
                              value:
                                  '${data.summary.totalSessions ?? data.sessions.length}',
                            ),
                            _StatRow(
                              label: 'Завершено',
                              value: '${data.summary.finishedSessions ?? 0}',
                            ),
                            _StatRow(
                              label: 'Записей в дневнике',
                              value:
                                  '${data.summary.totalDiaryEntries ?? data.diaryEntries.length}',
                            ),
                            _StatRow(
                              label: 'Последняя запись',
                              value: formatDate(
                                data.summary.latestEntryDate ??
                                    latestEntry?.createdAt,
                              ),
                            ),
                          ],
                        ),
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

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}