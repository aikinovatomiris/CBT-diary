import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/therapist_profile_model.dart';
import '../../navigation/app_routes.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/therapist_service.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/url_helper.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';

class TherapistHomeScreen extends StatefulWidget {
  const TherapistHomeScreen({super.key});

  @override
  State<TherapistHomeScreen> createState() => _TherapistHomeScreenState();
}

class _TherapistHomeScreenState extends State<TherapistHomeScreen> {
  late Future<_TherapistHomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_TherapistHomeData> _loadData() async {
    final myProfile = await TherapistService.getMyProfile();
    final approvedTherapists = await TherapistService.getApprovedTherapists();

    final otherTherapists = approvedTherapists.where((therapist) {
      if (myProfile.id != null && therapist.id == myProfile.id) {
        return false;
      }

      if (myProfile.userId != null && therapist.userId == myProfile.userId) {
        return false;
      }

      return therapist.status == null || therapist.status == 'approved';
    }).toList();

    return _TherapistHomeData(
      myProfile: myProfile,
      otherTherapists: otherTherapists,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadData();
    });

    await _future;
  }

  void _openMyProfile() {
    context.go(AppRoutes.therapistCard);
  }

  void _openTherapistDetail(TherapistProfileModel therapist) {
    final id = therapist.id;

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У анкеты терапевта нет ID.'),
        ),
      );
      return;
    }

    context.push('/specialists/$id');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TherapistHomeData>(
      future: _future,
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
              : 'Не удалось загрузить главную страницу.';

          return Scaffold(
            appBar: AppBar(
              title: const Text('Главная'),
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
              title: const Text('Главная'),
            ),
            body: AppErrorView(
              message: 'Нет данных для главной страницы.',
              onRetry: _refresh,
            ),
          );
        }

        return _TherapistHomeContent(
          data: data,
          onRefresh: _refresh,
          onOpenMyProfile: _openMyProfile,
          onOpenTherapistDetail: _openTherapistDetail,
        );
      },
    );
  }
}

class _TherapistHomeData {
  final TherapistProfileModel myProfile;
  final List<TherapistProfileModel> otherTherapists;

  const _TherapistHomeData({
    required this.myProfile,
    required this.otherTherapists,
  });
}

class _TherapistHomeContent extends StatelessWidget {
  final _TherapistHomeData data;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenMyProfile;
  final ValueChanged<TherapistProfileModel> onOpenTherapistDetail;

  const _TherapistHomeContent({
    required this.data,
    required this.onRefresh,
    required this.onOpenMyProfile,
    required this.onOpenTherapistDetail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userName = AuthService.cachedUser?.name?.trim();
    final greetingName =
        userName != null && userName.isNotEmpty ? userName : 'специалист';

    final myProfile = data.myProfile;
    final isApproved = myProfile.status == 'approved';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная'),
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
                        'Здравствуйте, $greetingName',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Здесь вы можете следить за своей анкетой и смотреть профили других специалистов.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      if (isApproved)
                        _MyApprovedProfileCard(
                          profile: myProfile,
                          onOpen: onOpenMyProfile,
                        )
                      else
                        _ProfileHintCard(
                          status: myProfile.status,
                          onOpen: onOpenMyProfile,
                        ),

                      const SizedBox(height: AppSpacing.xl),

                      Text(
                        'Другие терапевты',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Одобренные анкеты специалистов, доступные в каталоге.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      if (data.otherTherapists.isEmpty)
                        AppCard(
                          hasShadow: false,
                          child: Text(
                            'Пока нет других одобренных терапевтов.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        ...data.otherTherapists.map(
                          (therapist) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.lg,
                              ),
                              child: _TherapistPreviewCard(
                                therapist: therapist,
                                buttonText: 'Подробнее',
                                onTap: () => onOpenTherapistDetail(therapist),
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

class _MyApprovedProfileCard extends StatelessWidget {
  final TherapistProfileModel profile;
  final VoidCallback onOpen;

  const _MyApprovedProfileCard({
    required this.profile,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return _TherapistPreviewCard(
      therapist: profile,
      titlePrefix: 'Ваша анкета',
      buttonText: 'Открыть анкету',
      onTap: onOpen,
    );
  }
}

class _ProfileHintCard extends StatelessWidget {
  final String? status;
  final VoidCallback onOpen;

  const _ProfileHintCard({
    required this.status,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Анкета пока не опубликована',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _statusText(status),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Чтобы пользователи увидели вашу анкету в каталоге, заполните профиль, загрузите сертификаты и отправьте анкету на модерацию.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: 'Перейти к анкете',
            icon: Icons.badge_outlined,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }

  String _statusText(String? status) {
    switch (status) {
      case 'draft':
        return 'Статус: черновик';
      case 'pending':
        return 'Статус: на модерации';
      case 'rejected':
        return 'Статус: отклонена';
      case 'approved':
        return 'Статус: одобрена';
      default:
        return 'Статус: черновик';
    }
  }
}

class _TherapistPreviewCard extends StatelessWidget {
  final TherapistProfileModel therapist;
  final String? titlePrefix;
  final String buttonText;
  final VoidCallback onTap;

  const _TherapistPreviewCard({
    required this.therapist,
    required this.buttonText,
    required this.onTap,
    this.titlePrefix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = UrlHelper.buildFileUrl(therapist.photoUrl);
    final hasPhoto = photoUrl.trim().isNotEmpty;

    return AppCard(
      hasShadow: false,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titlePrefix != null) ...[
            Text(
              titlePrefix!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.12),
                backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                child: hasPhoto
                    ? null
                    : Icon(
                        Icons.person_rounded,
                        color: theme.colorScheme.primary,
                        size: 34,
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _safeText(therapist.fullName, 'Специалист'),
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _safeText(
                        therapist.qualification,
                        'Квалификация не указана',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (therapist.specializations.isNotEmpty) ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: therapist.specializations.take(4).map((item) {
                return _SmallChip(text: item);
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          _InfoLine(
            icon: Icons.location_on_outlined,
            text: _safeText(therapist.city, 'Город не указан'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoLine(
            icon: Icons.payments_outlined,
            text: _safeText(therapist.price, 'Цена не указана'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoLine(
            icon: Icons.wifi_rounded,
            text: therapist.onlineAvailable == true
                ? 'Онлайн'
                : 'Очно / по договоренности',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: buttonText,
            variant: AppButtonVariant.secondary,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }

  static String _safeText(String? value, String fallback) {
    if (value == null || value.trim().isEmpty) {
      return fallback;
    }

    return value.trim();
  }
}

class _SmallChip extends StatelessWidget {
  final String text;

  const _SmallChip({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: AppRadius.large,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}