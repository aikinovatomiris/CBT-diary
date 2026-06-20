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
  final List<TherapistProfileModel> _pendingTherapists = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingTherapists();
  }

  Future<void> _loadPendingTherapists() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final therapists = await AdminService.getPendingTherapists();

      if (!mounted) return;

      setState(() {
        _pendingTherapists
          ..clear()
          ..addAll(therapists);
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Не удалось загрузить заявки терапевтов.';
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      final therapists = await AdminService.getPendingTherapists();

      if (!mounted) return;

      setState(() {
        _pendingTherapists
          ..clear()
          ..addAll(therapists);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Не удалось обновить список заявок.');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _openDetail(TherapistProfileModel therapist) async {
    final id = therapist.id;

    if (id == null) {
      _showSnackBar('У анкеты нет ID.');
      return;
    }

    final result = await context.push('/admin/therapists/$id');

    if (!mounted) return;

    if (result is Map) {
      final profileId = result['profileId'];
      final action = result['action'];

      if (profileId is int) {
        setState(() {
          _pendingTherapists.removeWhere((item) => item.id == profileId);
        });
      }

      if (action == 'approved') {
        _showSnackBar('Заявка одобрена');
      }

      if (action == 'rejected') {
        _showSnackBar('Заявка отклонена');
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppLoading(
          text: 'Загрузка заявок...',
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: AppErrorView(
          message: _errorMessage!,
          onRetry: _loadPendingTherapists,
        ),
      );
    }

    return _AdminPendingTherapistsContent(
      therapists: _pendingTherapists,
      isRefreshing: _isRefreshing,
      onRefresh: _refresh,
      onOpenDetail: _openDetail,
    );
  }
}

class _AdminPendingTherapistsContent extends StatelessWidget {
  final List<TherapistProfileModel> therapists;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;
  final ValueChanged<TherapistProfileModel> onOpenDetail;

  const _AdminPendingTherapistsContent({
    required this.therapists,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onOpenDetail,
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
                    physics: const AlwaysScrollableScrollPhysics(),
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
                        'Здесь отображаются заявки терапевтов со статусом pending.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (therapists.isEmpty)
                        AppCard(
                          hasShadow: false,
                          child: Text(
                            'Нет заявок на модерацию',
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