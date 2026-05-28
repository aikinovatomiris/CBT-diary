import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/practice_data.dart';
import '../../models/practice_model.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';

class PracticeDetailScreen extends StatefulWidget {
  final String? practiceId;

  const PracticeDetailScreen({
    super.key,
    required this.practiceId,
  });

  @override
  State<PracticeDetailScreen> createState() => _PracticeDetailScreenState();
}

class _PracticeDetailScreenState extends State<PracticeDetailScreen> {
  PracticeModel? _practice;

  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isTimerRunning = false;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();

    _practice = _findPractice(widget.practiceId);

    if (_practice != null) {
      _remainingSeconds = _practice!.timerSeconds;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  PracticeModel? _findPractice(String? id) {
    if (id == null) return null;

    for (final practice in practices) {
      if (practice.id == id) {
        return practice;
      }
    }

    return null;
  }

  void _startPractice() {
    final practice = _practice;

    if (practice == null) return;

    setState(() {
      _hasStarted = true;
    });

    if (!practice.hasTimer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Следуй инструкции в удобном темпе.'),
        ),
      );
      return;
    }

    if (_isTimerRunning) return;

    setState(() {
      _isTimerRunning = true;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (_remainingSeconds <= 1) {
          timer.cancel();

          if (!mounted) return;

          setState(() {
            _remainingSeconds = 0;
            _isTimerRunning = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Практика завершена. Можно вернуться к обычному темпу.'),
            ),
          );

          return;
        }

        if (!mounted) return;

        setState(() {
          _remainingSeconds--;
        });
      },
    );
  }

  void _pauseTimer() {
    _timer?.cancel();

    setState(() {
      _isTimerRunning = false;
    });
  }

  void _resetTimer() {
    final practice = _practice;

    if (practice == null) return;

    _timer?.cancel();

    setState(() {
      _remainingSeconds = practice.timerSeconds;
      _isTimerRunning = false;
      _hasStarted = false;
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    final minutesText = minutes.toString().padLeft(2, '0');
    final secondsText = seconds.toString().padLeft(2, '0');

    return '$minutesText:$secondsText';
  }

  String _breathingHint(PracticeModel practice) {
    if (practice.id == 'breathing_4_6') {
      return 'Вдох на 4 · Выдох на 6';
    }

    if (practice.id == 'box_breathing') {
      return 'Вдох 4 · Пауза 4 · Выдох 4 · Пауза 4';
    }

    return 'Дыши спокойно, без усилия';
  }

  @override
  Widget build(BuildContext context) {
    final practice = _practice;

    if (practice == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Практика'),
        ),
        body: AppErrorView(
          message: 'Практика не найдена.',
          onRetry: () => context.go('/practices'),
          retryText: 'К практикам',
        ),
      );
    }

    return _PracticeDetailContent(
      practice: practice,
      remainingSeconds: _remainingSeconds,
      isTimerRunning: _isTimerRunning,
      hasStarted: _hasStarted,
      formattedTime: _formatTime(_remainingSeconds),
      breathingHint: _breathingHint(practice),
      onStart: _startPractice,
      onPause: _pauseTimer,
      onReset: _resetTimer,
    );
  }
}

class _PracticeDetailContent extends StatelessWidget {
  final PracticeModel practice;
  final int remainingSeconds;
  final bool isTimerRunning;
  final bool hasStarted;
  final String formattedTime;
  final String breathingHint;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;

  const _PracticeDetailContent({
    required this.practice,
    required this.remainingSeconds,
    required this.isTimerRunning,
    required this.hasStarted,
    required this.formattedTime,
    required this.breathingHint,
    required this.onStart,
    required this.onPause,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isTimerFinished = practice.hasTimer && remainingSeconds == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Практика'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 720 : double.infinity,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  children: [
                    Text(
                      practice.title,
                      style: theme.textTheme.headlineMedium,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    Text(
                      '${practice.durationMinutes} мин · ${practice.category}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    AppCard(
                      hasShadow: false,
                      child: Text(
                        practice.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),

                    if (practice.hasTimer) ...[
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        hasShadow: false,
                        child: Column(
                          children: [
                            Text(
                              formattedTime,
                              style: theme.textTheme.headlineLarge?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              isTimerFinished
                                  ? 'Практика завершена'
                                  : breathingHint,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            if (!isTimerRunning)
                              AppButton(
                                text: hasStarted && !isTimerFinished
                                    ? 'Продолжить'
                                    : 'Начать',
                                icon: Icons.play_arrow_rounded,
                                onPressed: onStart,
                              )
                            else
                              AppButton(
                                text: 'Пауза',
                                icon: Icons.pause_rounded,
                                variant: AppButtonVariant.secondary,
                                onPressed: onPause,
                              ),
                            const SizedBox(height: AppSpacing.md),
                            AppButton(
                              text: 'Сбросить',
                              icon: Icons.refresh_rounded,
                              variant: AppButtonVariant.ghost,
                              onPressed: onReset,
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.lg),

                    AppCard(
                      hasShadow: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Инструкция',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          ...practice.steps.asMap().entries.map(
                            (entry) {
                              final index = entry.key + 1;
                              final step = entry.value;

                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        index.toString(),
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Text(
                                        step,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    AppCard(
                      hasShadow: false,
                      child: Text(
                        'Важно: эти практики не заменяют терапию, консультацию специалиста или экстренную помощь. Используй их как мягкую паузу для самонаблюдения.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),

                    if (!practice.hasTimer) ...[
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        text: 'Начать',
                        icon: Icons.play_arrow_rounded,
                        onPressed: onStart,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}