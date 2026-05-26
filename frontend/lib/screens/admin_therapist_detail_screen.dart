import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/admin_model.dart';
import '../models/therapist_certificate_model.dart';
import '../models/therapist_profile_model.dart';
import '../navigation/app_routes.dart';
import '../services/admin_service.dart';
import '../services/api_exception.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_error_view.dart';
import '../widgets/app_loading.dart';

class AdminTherapistDetailScreen extends StatefulWidget {
  final String? profileId;

  const AdminTherapistDetailScreen({
    super.key,
    required this.profileId,
  });

  @override
  State<AdminTherapistDetailScreen> createState() =>
      _AdminTherapistDetailScreenState();
}

class _AdminTherapistDetailScreenState
    extends State<AdminTherapistDetailScreen> {
  late Future<AdminTherapistDetailModel> _detailFuture;

  int? _profileId;
  bool _isApproving = false;
  bool _isRejecting = false;

  @override
  void initState() {
    super.initState();

    _profileId = int.tryParse(widget.profileId ?? '');

    if (_profileId != null) {
      _detailFuture = _loadDetail();
    }
  }

  Future<AdminTherapistDetailModel> _loadDetail() async {
    final id = _profileId;

    if (id == null) {
      throw const ApiException(
        message: 'Не найден ID анкеты.',
      );
    }

    return AdminService.getTherapistById(id);
  }

  Future<void> _refresh() async {
    setState(() {
      _detailFuture = _loadDetail();
    });

    await _detailFuture;
  }

  Future<void> _approve() async {
    final id = _profileId;

    if (id == null) {
      _showSnackBar('Не найден ID анкеты.');
      return;
    }

    setState(() {
      _isApproving = true;
    });

    try {
      await AdminService.approveTherapist(id);

      if (!mounted) return;

      _showSnackBar('Анкета одобрена.');
      context.go(AppRoutes.adminTherapists);
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Не удалось одобрить анкету.');
    } finally {
      if (mounted) {
        setState(() {
          _isApproving = false;
        });
      }
    }
  }

  Future<void> _openRejectDialog() async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return AlertDialog(
          title: const Text('Отклонить анкету'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Причина отклонения',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: Text(
                'Отклонить',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (reason == null) return;

    if (reason.trim().isEmpty) {
      _showSnackBar('Укажите причину отклонения.');
      return;
    }

    await _reject(reason);
  }

  Future<void> _reject(String reason) async {
    final id = _profileId;

    if (id == null) {
      _showSnackBar('Не найден ID анкеты.');
      return;
    }

    setState(() {
      _isRejecting = true;
    });

    try {
      await AdminService.rejectTherapist(
        id,
        reason: reason,
      );

      if (!mounted) return;

      _showSnackBar('Анкета отклонена.');
      context.go(AppRoutes.adminTherapists);
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Не удалось отклонить анкету.');
    } finally {
      if (mounted) {
        setState(() {
          _isRejecting = false;
        });
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
    if (_profileId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Анкета терапевта'),
        ),
        body: AppErrorView(
          message: 'Не найден ID анкеты.',
          onRetry: () => context.go(AppRoutes.adminTherapists),
          retryText: 'К списку',
        ),
      );
    }

    return FutureBuilder<AdminTherapistDetailModel>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: AppLoading(
              text: 'Загрузка анкеты...',
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is ApiException
              ? error.message
              : 'Не удалось загрузить анкету.';

          return Scaffold(
            appBar: AppBar(
              title: const Text('Анкета терапевта'),
            ),
            body: AppErrorView(
              message: message,
              onRetry: _refresh,
            ),
          );
        }

        final detail = snapshot.data;

        if (detail == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Анкета терапевта'),
            ),
            body: AppErrorView(
              message: 'Нет данных анкеты.',
              onRetry: _refresh,
            ),
          );
        }

        return _AdminTherapistDetailContent(
          profile: detail.profile,
          certificates: detail.certificates,
          isApproving: _isApproving,
          isRejecting: _isRejecting,
          onApprove: _approve,
          onReject: _openRejectDialog,
        );
      },
    );
  }
}

class _AdminTherapistDetailContent extends StatelessWidget {
  final TherapistProfileModel profile;
  final List<TherapistCertificateModel> certificates;
  final bool isApproving;
  final bool isRejecting;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _AdminTherapistDetailContent({
    required this.profile,
    required this.certificates,
    required this.isApproving,
    required this.isRejecting,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = profile.status == 'pending';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Анкета терапевта'),
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    110,
                  ),
                  children: [
                    Text(
                      'Анкета терапевта',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Просмотр анкеты специалиста перед модерацией.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SectionCard(
                      title: 'Статус',
                      content: _safeText(profile.status, 'Не указан'),
                    ),
                    _SectionCard(
                      title: 'ФИО',
                      content: _safeText(profile.fullName, 'Не заполнено'),
                    ),
                    _SectionCard(
                      title: 'Квалификация',
                      content:
                          _safeText(profile.qualification, 'Не заполнено'),
                    ),
                    _SectionCard(
                      title: 'Направления терапии',
                      content: _listText(profile.therapyApproaches),
                    ),
                    _SectionCard(
                      title: 'С какими запросами работает',
                      content: _listText(profile.specializations),
                    ),
                    _SectionCard(
                      title: 'Описание',
                      content: _safeText(profile.description, 'Не заполнено'),
                    ),
                    _SectionCard(
                      title: 'Цена',
                      content: profile.price == null
                          ? 'Не заполнено'
                          : '${profile.price!.toStringAsFixed(0)} ₸',
                    ),
                    _SectionCard(
                      title: 'Город',
                      content: _safeText(profile.city, 'Не заполнено'),
                    ),
                    _SectionCard(
                      title: 'Онлайн',
                      content: profile.onlineAvailable == true ? 'Да' : 'Нет',
                    ),
                    _CertificatesCard(
                      certificates: certificates,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (isPending) ...[
                      AppButton(
                        text: 'Одобрить',
                        icon: Icons.check_circle_outline_rounded,
                        isLoading: isApproving,
                        onPressed: isRejecting ? null : onApprove,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        text: 'Отклонить',
                        icon: Icons.block_outlined,
                        variant: AppButtonVariant.ghost,
                        isLoading: isRejecting,
                        onPressed: isApproving ? null : onReject,
                      ),
                    ] else
                      AppCard(
                        hasShadow: false,
                        child: Text(
                          'Анкета уже обработана.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static String _safeText(String? value, String fallback) {
    if (value == null || value.trim().isEmpty) return fallback;
    return value.trim();
  }

  static String _listText(List<String> items) {
    final filteredItems = items.where((item) => item.trim().isNotEmpty).toList();

    if (filteredItems.isEmpty) {
      return 'Не заполнено';
    }

    return filteredItems.map((item) => '• $item').join('\n');
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String content;

  const _SectionCard({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        hasShadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              content,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificatesCard extends StatelessWidget {
  final List<TherapistCertificateModel> certificates;

  const _CertificatesCard({
    required this.certificates,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        hasShadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Сертификаты',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (certificates.isEmpty)
              Text(
                'Сертификаты не загружены или backend не возвращает их в этом endpoint.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...certificates.map(
                (certificate) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file_outlined,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            certificate.originalFilename ?? 'Сертификат',
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
    );
  }
}