import 'package:flutter/material.dart';

import '../../models/admin_model.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<AdminModel> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = AdminService.getSummary();
  }

  Future<void> _refresh() async {
    setState(() {
      _summaryFuture = AdminService.getSummary();
    });

    await _summaryFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminModel>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: AppLoading(
              text: 'Загрузка админ-панели...',
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is ApiException
              ? error.message
              : 'Не удалось загрузить админ-панель.';

          return Scaffold(
            body: AppErrorView(
              message: message,
              onRetry: _refresh,
            ),
          );
        }

        final summary = snapshot.data;

        if (summary == null) {
          return Scaffold(
            body: AppErrorView(
              message: 'Нет данных для админ-панели.',
              onRetry: _refresh,
            ),
          );
        }

        return _AdminDashboardContent(
          summary: summary,
          onRefresh: _refresh,
        );
      },
    );
  }
}

class _AdminDashboardContent extends StatelessWidget {
  final AdminModel summary;
  final Future<void> Function() onRefresh;

  const _AdminDashboardContent({
    required this.summary,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
                        'Админ-панель',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Краткая сводка по пользователям, специалистам и активности приложения.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _StatsGrid(
                        items: [
                          _StatItem(
                            title: 'Пользователи',
                            value: summary.totalUsers.toString(),
                            icon: Icons.people_outline_rounded,
                          ),
                          _StatItem(
                            title: 'Терапевты',
                            value: summary.totalTherapists.toString(),
                            icon: Icons.psychology_outlined,
                          ),
                          _StatItem(
                            title: 'На модерации',
                            value: summary.pendingTherapists.toString(),
                            icon: Icons.pending_actions_rounded,
                          ),
                          _StatItem(
                            title: 'Одобрены',
                            value: summary.approvedTherapists.toString(),
                            icon: Icons.verified_outlined,
                          ),
                          _StatItem(
                            title: 'Отклонены',
                            value: summary.rejectedTherapists.toString(),
                            icon: Icons.block_outlined,
                          ),
                          _StatItem(
                            title: 'Дневниковые записи',
                            value: summary.totalDiaryEntries.toString(),
                            icon: Icons.book_outlined,
                          ),
                          _StatItem(
                            title: 'КПТ-сессии',
                            value: summary.totalCbtSessions.toString(),
                            icon: Icons.chat_bubble_outline_rounded,
                          ),
                        ],
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

class _StatsGrid extends StatelessWidget {
  final List<_StatItem> items;

  const _StatsGrid({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: items.map((item) {
        return SizedBox(
          width: MediaQuery.sizeOf(context).width > 760 ? 220 : double.infinity,
          child: _StatCard(item: item),
        );
      }).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatItem item;

  const _StatCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.icon,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            item.value,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String title;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.title,
    required this.value,
    required this.icon,
  });
}