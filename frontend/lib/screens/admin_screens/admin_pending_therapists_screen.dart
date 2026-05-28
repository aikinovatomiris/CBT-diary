import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/therapist_profile_model.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';

class AdminPendingTherapistsScreen extends StatefulWidget {
  const AdminPendingTherapistsScreen({super.key});

  @override
  State<AdminPendingTherapistsScreen> createState() =>
      _AdminPendingTherapistsScreenState();
}

class _AdminPendingTherapistsScreenState
    extends State<AdminPendingTherapistsScreen> {
  late Future<List<TherapistProfileModel>> _therapistsFuture;

  @override
  void initState() {
    super.initState();
    _therapistsFuture = AdminService.getPendingTherapists();
  }

  Future<void> _refresh() async {
    setState(() {
      _therapistsFuture = AdminService.getPendingTherapists();
    });

    await _therapistsFuture;
  }

  void _openDetail(TherapistProfileModel therapist) {
    final id = therapist.id;

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У анкеты нет ID.'),
        ),
      );
      return;
    }

    context.push('/admin/therapists/$id').then((_) {
      if (context.mounted) {
        _refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TherapistProfileModel>>(
      future: _therapistsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: AppLoading(
              text: 'Загрузка анкет...',
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is ApiException
              ? error.message
              : 'Не удалось загрузить анкеты терапевтов.';

          return Scaffold(
            appBar: AppBar(
              title: const Text('Терапевты'),
            ),
            body: AppErrorView(
              message: message,
              onRetry: _refresh,
            ),
          );
        }

        final therapists = snapshot.data ?? [];

        return _AdminPendingTherapistsContent(
          therapists: therapists,
          onRefresh: _refresh,
          onOpenDetail: _openDetail,
        );
      },
    );
  }
}

class _AdminPendingTherapistsContent extends StatelessWidget {
  final List<TherapistProfileModel> therapists;
  final Future<void> Function() onRefresh;
  final ValueChanged<TherapistProfileModel> onOpenDetail;

  const _AdminPendingTherapistsContent({
    required this.therapists,
    required this.onRefresh,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Терапевты'),
      ),
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
                        'Анкеты на модерации',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Здесь отображаются специалисты со статусом pending.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (therapists.isEmpty)
                        AppCard(
                          hasShadow: false,
                          child: Text(
                            'Анкет на модерации пока нет.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        ...therapists.map(
                          (therapist) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.lg,
                              ),
                              child: _PendingTherapistCard(
                                therapist: therapist,
                                onTap: () => onOpenDetail(therapist),
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

class _PendingTherapistCard extends StatelessWidget {
  final TherapistProfileModel therapist;
  final VoidCallback onTap;

  const _PendingTherapistCard({
    required this.therapist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      hasShadow: false,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _safeText(therapist.fullName, 'ФИО не указано'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _safeText(therapist.qualification, 'Квалификация не указана'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Статус: ${_safeText(therapist.status, 'pending')}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: 'Открыть анкету',
            variant: AppButtonVariant.secondary,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }

  String _safeText(String? value, String fallback) {
    if (value == null || value.trim().isEmpty) return fallback;
    return value.trim();
  }
}