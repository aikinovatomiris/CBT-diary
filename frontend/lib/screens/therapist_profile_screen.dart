import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/therapist_certificate_model.dart';
import '../models/therapist_profile_model.dart';
import '../services/api_exception.dart';
import '../services/therapist_service.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../utils/constants.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_error_view.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_text_field.dart';

class TherapistProfileScreen extends StatefulWidget {
  const TherapistProfileScreen({super.key});

  @override
  State<TherapistProfileScreen> createState() => _TherapistProfileScreenState();
}

class _TherapistProfileData {
  final TherapistProfileModel profile;
  final List<TherapistCertificateModel> certificates;

  const _TherapistProfileData({
    required this.profile,
    required this.certificates,
  });
}

class _TherapistProfileScreenState extends State<TherapistProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _qualificationController =
      TextEditingController();
  final TextEditingController _therapyApproachesController =
      TextEditingController();
  final TextEditingController _specializationsController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _contactsController = TextEditingController();

  late Future<_TherapistProfileData> _profileFuture;

  bool _onlineAvailable = false;
  bool _isSaving = false;
  bool _isSubmitting = false;
  bool _isUploadingPhoto = false;
  bool _isUploadingCertificate = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _qualificationController.dispose();
    _therapyApproachesController.dispose();
    _specializationsController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _cityController.dispose();
    _contactsController.dispose();
    super.dispose();
  }

  Future<_TherapistProfileData> _loadData() async {
    final profile = await TherapistService.getMyProfile();
    final certificates = await TherapistService.getMyCertificates();

    _fillForm(profile);

    return _TherapistProfileData(
      profile: profile,
      certificates: certificates,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = _loadData();
    });

    await _profileFuture;
  }

  void _fillForm(TherapistProfileModel profile) {
    _fullNameController.text = profile.fullName ?? '';
    _qualificationController.text = profile.qualification ?? '';
    _therapyApproachesController.text = profile.therapyApproaches.join(', ');
    _specializationsController.text = profile.specializations.join(', ');
    _descriptionController.text = profile.description ?? '';
    _priceController.text = profile.price ?? '';
    _cityController.text = profile.city ?? '';
    _contactsController.text = _formatContacts(profile.contacts);
    _onlineAvailable = profile.onlineAvailable ?? false;
  }

  Future<void> _uploadPhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploadingPhoto = true;
      });

      await TherapistService.uploadProfilePhoto(image);

      if (!mounted) return;

      _showSnackBar('Фото профиля загружено.');
      await _refresh();
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Не удалось загрузить фото профиля.');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _uploadCertificate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: kIsWeb,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'webp',
        ],
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _isUploadingCertificate = true;
      });

      await TherapistService.uploadCertificate(result.files.first);

      if (!mounted) return;

      _showSnackBar('Сертификат загружен.');
      await _refresh();
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Не удалось загрузить сертификат.');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingCertificate = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final price = _priceController.text.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      await TherapistService.updateMyProfile(
        fullName: _fullNameController.text,
        qualification: _qualificationController.text,
        therapyApproaches: _splitTextList(_therapyApproachesController.text),
        specializations: _splitTextList(_specializationsController.text),
        description: _descriptionController.text,
        price: price.isEmpty ? null : price,
        contacts: _parseContacts(_contactsController.text),
        city: _cityController.text,
        onlineAvailable: _onlineAvailable,
      );

      if (!mounted) return;

      _showSnackBar('Анкета сохранена.');
      await _refresh();
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Не удалось сохранить анкету.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _submitProfile() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await TherapistService.submitProfile();

      if (!mounted) return;

      _showSnackBar('Анкета отправлена на модерацию.');
      await _refresh();
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Не удалось отправить анкету на модерацию.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  List<String> _splitTextList(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Map<String, dynamic>? _parseContacts(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(text);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
    }

    return {
      'text': text,
    };
  }

  String _formatContacts(Map<String, dynamic>? contacts) {
    if (contacts == null || contacts.isEmpty) {
      return '';
    }

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(contacts);
  }

  String _photoUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return '';
    }

    final trimmedUrl = url.trim();

    if (trimmedUrl.startsWith('http://') ||
        trimmedUrl.startsWith('https://')) {
      return trimmedUrl;
    }

    final baseUrl = AppConstants.baseUrl.endsWith('/')
        ? AppConstants.baseUrl.substring(0, AppConstants.baseUrl.length - 1)
        : AppConstants.baseUrl;

    final path = trimmedUrl.startsWith('/') ? trimmedUrl : '/$trimmedUrl';

    return '$baseUrl$path';
  }

  String _statusTitle(String? status) {
    switch (status) {
      case 'draft':
        return 'Черновик';
      case 'pending':
        return 'На модерации';
      case 'approved':
        return 'Одобрена';
      case 'rejected':
        return 'Отклонена';
      default:
        return 'Не указан';
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
    return FutureBuilder<_TherapistProfileData>(
      future: _profileFuture,
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
              : 'Не удалось загрузить анкету специалиста.';

          return Scaffold(
            appBar: AppBar(
              title: const Text('Анкета'),
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
              title: const Text('Анкета'),
            ),
            body: AppErrorView(
              message: 'Нет данных анкеты.',
              onRetry: _refresh,
            ),
          );
        }

        return _TherapistProfileContent(
          profile: data.profile,
          certificates: data.certificates,
          fullNameController: _fullNameController,
          qualificationController: _qualificationController,
          therapyApproachesController: _therapyApproachesController,
          specializationsController: _specializationsController,
          descriptionController: _descriptionController,
          priceController: _priceController,
          cityController: _cityController,
          contactsController: _contactsController,
          onlineAvailable: _onlineAvailable,
          isSaving: _isSaving,
          isSubmitting: _isSubmitting,
          isUploadingPhoto: _isUploadingPhoto,
          isUploadingCertificate: _isUploadingCertificate,
          onOnlineChanged: (value) {
            setState(() {
              _onlineAvailable = value;
            });
          },
          onUploadPhoto: _uploadPhoto,
          onUploadCertificate: _uploadCertificate,
          onSave: _saveProfile,
          onSubmit: _submitProfile,
          photoUrlBuilder: _photoUrl,
          statusTitle: _statusTitle,
          onRefresh: _refresh,
        );
      },
    );
  }
}

class _TherapistProfileContent extends StatelessWidget {
  final TherapistProfileModel profile;
  final List<TherapistCertificateModel> certificates;

  final TextEditingController fullNameController;
  final TextEditingController qualificationController;
  final TextEditingController therapyApproachesController;
  final TextEditingController specializationsController;
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  final TextEditingController cityController;
  final TextEditingController contactsController;

  final bool onlineAvailable;
  final bool isSaving;
  final bool isSubmitting;
  final bool isUploadingPhoto;
  final bool isUploadingCertificate;

  final ValueChanged<bool> onOnlineChanged;
  final VoidCallback onUploadPhoto;
  final VoidCallback onUploadCertificate;
  final VoidCallback onSave;
  final VoidCallback onSubmit;
  final String Function(String?) photoUrlBuilder;
  final String Function(String?) statusTitle;
  final Future<void> Function() onRefresh;

  const _TherapistProfileContent({
    required this.profile,
    required this.certificates,
    required this.fullNameController,
    required this.qualificationController,
    required this.therapyApproachesController,
    required this.specializationsController,
    required this.descriptionController,
    required this.priceController,
    required this.cityController,
    required this.contactsController,
    required this.onlineAvailable,
    required this.isSaving,
    required this.isSubmitting,
    required this.isUploadingPhoto,
    required this.isUploadingCertificate,
    required this.onOnlineChanged,
    required this.onUploadPhoto,
    required this.onUploadCertificate,
    required this.onSave,
    required this.onSubmit,
    required this.photoUrlBuilder,
    required this.statusTitle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Анкета специалиста'),
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
                        'Анкета специалиста',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Заполните профиль, загрузите сертификаты и отправьте анкету на модерацию.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      _StatusCard(
                        status: profile.status,
                        statusTitle: statusTitle(profile.status),
                        rejectionReason: profile.rejectionReason,
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      _PhotoCard(
                        photoUrl: photoUrlBuilder(profile.photoUrl),
                        isUploading: isUploadingPhoto,
                        onUpload: onUploadPhoto,
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      AppCard(
                        hasShadow: false,
                        child: Column(
                          children: [
                            AppTextField(
                              controller: fullNameController,
                              label: 'ФИО',
                              hint: 'Полное имя специалиста',
                              prefixIcon: Icons.badge_outlined,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: qualificationController,
                              label: 'Квалификация',
                              hint: 'Например: психолог, КПТ-консультант',
                              prefixIcon: Icons.school_outlined,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: therapyApproachesController,
                              label: 'Направления терапии',
                              hint: 'Например: КПТ, ACT, DBT',
                              prefixIcon: Icons.psychology_outlined,
                              maxLines: 2,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: specializationsController,
                              label: 'С какими запросами работает',
                              hint: 'Например: тревога, самооценка, стресс',
                              prefixIcon: Icons.topic_outlined,
                              maxLines: 2,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: descriptionController,
                              label: 'Описание',
                              hint: 'Кратко расскажите о себе и подходе',
                              prefixIcon: Icons.description_outlined,
                              maxLines: 5,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: priceController,
                              label: 'Цена',
                              hint: 'Например: 10000',
                              prefixIcon: Icons.payments_outlined,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: cityController,
                              label: 'Город',
                              hint: 'Например: Астана',
                              prefixIcon: Icons.location_city_outlined,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            SwitchListTile(
                              value: onlineAvailable,
                              onChanged: onOnlineChanged,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Онлайн-консультации',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'Включите, если готовы работать онлайн.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: contactsController,
                              label: 'Контакты',
                              hint:
                                  'Можно JSON или обычный текст: телефон, email, Telegram',
                              prefixIcon: Icons.contact_mail_outlined,
                              maxLines: 5,
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            AppButton(
                              text: 'Сохранить анкету',
                              isLoading: isSaving,
                              onPressed: onSave,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      _CertificatesCard(
                        certificates: certificates,
                        isUploading: isUploadingCertificate,
                        onUpload: onUploadCertificate,
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      AppButton(
                        text: 'Отправить на модерацию',
                        icon: Icons.verified_outlined,
                        isLoading: isSubmitting,
                        variant: AppButtonVariant.secondary,
                        onPressed: onSubmit,
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

class _PhotoCard extends StatelessWidget {
  final String photoUrl;
  final bool isUploading;
  final VoidCallback onUpload;

  const _PhotoCard({
    required this.photoUrl,
    required this.isUploading,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto = photoUrl.trim().isNotEmpty;

    return AppCard(
      hasShadow: false,
      child: Row(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
            child: hasPhoto
                ? null
                : Icon(
                    Icons.person_rounded,
                    size: 42,
                    color: theme.colorScheme.primary,
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
                      ? 'Фото загружено.'
                      : 'Если фото не загружено, позже будет показан дефолтный аватар.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  text: 'Загрузить фото',
                  isLoading: isUploading,
                  variant: AppButtonVariant.secondary,
                  onPressed: onUpload,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String? status;
  final String statusTitle;
  final String? rejectionReason;

  const _StatusCard({
    required this.status,
    required this.statusTitle,
    required this.rejectionReason,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRejected = status == 'rejected';

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Статус анкеты',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: AppRadius.large,
            ),
            child: Text(
              statusTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (isRejected &&
              rejectionReason != null &&
              rejectionReason!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Причина отклонения',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              rejectionReason!.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CertificatesCard extends StatelessWidget {
  final List<TherapistCertificateModel> certificates;
  final bool isUploading;
  final VoidCallback onUpload;

  const _CertificatesCard({
    required this.certificates,
    required this.isUploading,
    required this.onUpload,
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
            'Сертификаты',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Загрузите документы, подтверждающие квалификацию.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (certificates.isEmpty)
            Text(
              'Сертификаты пока не загружены.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...certificates.map(
              (certificate) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        Icons.insert_drive_file_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.md),
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
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: 'Загрузить сертификат',
            isLoading: isUploading,
            variant: AppButtonVariant.secondary,
            onPressed: onUpload,
          ),
        ],
      ),
    );
  }
}