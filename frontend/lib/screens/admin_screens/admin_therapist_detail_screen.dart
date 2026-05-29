import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/admin_model.dart';
import '../../models/therapist_certificate_model.dart';
import '../../models/therapist_profile_model.dart';
import '../../navigation/app_routes.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../theme/app_spacing.dart';
import '../../utils/url_helper.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';

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

      _closeWithResult(
        profileId: id,
        action: 'approved',
      );
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

      _closeWithResult(
        profileId: id,
        action: 'rejected',
      );
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

  void _closeWithResult({
    required int profileId,
    required String action,
  }) {
    final result = {
      'profileId': profileId,
      'action': action,
    };

    if (context.canPop()) {
      context.pop(result);
      return;
    }

    context.go(AppRoutes.adminTherapists);
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

                    _ProfilePhotoCard(profile: profile),

                    const SizedBox(height: AppSpacing.lg),

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
                      content: _safeText(profile.price, 'Не заполнено'),
                    ),
                    _SectionCard(
                      title: 'Город',
                      content: _safeText(profile.city, 'Не заполнено'),
                    ),
                    _SectionCard(
                      title: 'Онлайн',
                      content: profile.onlineAvailable == true ? 'Да' : 'Нет',
                    ),
                    _SectionCard(
                      title: 'Контакты',
                      content: _contactsText(profile.contacts),
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

  static String _contactsText(Map<String, dynamic>? contacts) {
    if (contacts == null || contacts.isEmpty) {
      return 'Не заполнено';
    }

    final labels = {
      'phone': 'Телефон',
      'whatsapp': 'WhatsApp',
      'telegram': 'Telegram',
      'instagram': 'Instagram',
      'email': 'Email',
    };

    final lines = <String>[];

    contacts.forEach((key, value) {
      final text = value?.toString().trim();

      if (text == null || text.isEmpty) return;

      final label = labels[key] ?? key.toString();
      lines.add('$label: $text');
    });

    if (lines.isEmpty) return 'Не заполнено';

    return lines.join('\n');
  }
}

class _ProfilePhotoCard extends StatelessWidget {
  final TherapistProfileModel profile;

  const _ProfilePhotoCard({
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = UrlHelper.buildFileUrl(profile.photoUrl);
    final hasPhoto = photoUrl.trim().isNotEmpty;

    return AppCard(
      hasShadow: false,
      child: Row(
        children: [
          GestureDetector(
            onTap: hasPhoto
                ? () => _openPhotoPreview(
                      context: context,
                      imageUrl: photoUrl,
                    )
                : null,
            child: CircleAvatar(
              radius: 42,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
              child: hasPhoto
                  ? null
                  : Icon(
                      Icons.person_rounded,
                      color: theme.colorScheme.primary,
                      size: 42,
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Фото профиля',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  hasPhoto
                      ? 'Фото загружено. Нажмите на аватарку для просмотра.'
                      : 'Фото профиля не загружено.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openPhotoPreview({
    required BuildContext context,
    required String imageUrl,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Text('Не удалось загрузить фото.'),
                  );
                },
              ),
            ),
          ),
        );
      },
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
                'Сертификаты не загружены.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...certificates.map(
                (certificate) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _CertificatePreviewCard(
                      certificate: certificate,
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

class _CertificatePreviewCard extends StatelessWidget {
  final TherapistCertificateModel certificate;

  const _CertificatePreviewCard({
    required this.certificate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final fileUrl = UrlHelper.buildFileUrl(certificate.filePath);
    final filename = certificate.originalFilename ?? 'Сертификат';
    final isImage = _isImageFile(filename) || _isImageFile(fileUrl);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImage && fileUrl.trim().isNotEmpty)
            GestureDetector(
              onTap: () => _openCertificatePreview(
                context: context,
                imageUrl: fileUrl,
                filename: filename,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    fileUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _CertificatePlaceholder(
                        filename: filename,
                      );
                    },
                  ),
                ),
              ),
            )
          else
            _CertificatePlaceholder(
              filename: filename,
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            filename,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isImage
                ? 'Нажмите на изображение, чтобы открыть сертификат.'
                : 'Файл сертификата не является изображением. Для предпросмотра поддерживаются JPG, JPEG, PNG, WEBP.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  bool _isImageFile(String value) {
    final lower = value.toLowerCase();

    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  void _openCertificatePreview({
    required BuildContext context,
    required String imageUrl,
    required String filename,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: Text('Не удалось загрузить сертификат.'),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CertificatePlaceholder extends StatelessWidget {
  final String filename;

  const _CertificatePlaceholder({
    required this.filename,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPdf = filename.toLowerCase().endsWith('.pdf');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            isPdf
                ? Icons.picture_as_pdf_outlined
                : Icons.insert_drive_file_outlined,
            size: 42,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isPdf ? 'PDF-сертификат' : 'Файл сертификата',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            filename,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
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