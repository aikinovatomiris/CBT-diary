import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/therapist_certificate_model.dart';
import '../../models/therapist_profile_model.dart';
import '../../services/api_exception.dart';
import '../../services/therapist_service.dart';
import '../../theme/app_spacing.dart';
import '../../utils/url_helper.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_text_field.dart';

class TherapistProfileScreen extends StatefulWidget {
  const TherapistProfileScreen({
    super.key,
  });

  @override
  State<TherapistProfileScreen> createState() {
    return _TherapistProfileScreenState();
  }
}

class _TherapistProfileScreenState
    extends State<TherapistProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _fullNameController =
      TextEditingController();

  final TextEditingController
      _qualificationController =
      TextEditingController();

  final TextEditingController
      _therapyApproachesController =
      TextEditingController();

  final TextEditingController
      _specializationsController =
      TextEditingController();

  final TextEditingController
      _descriptionController =
      TextEditingController();

  final TextEditingController _priceController =
      TextEditingController();

  final TextEditingController _cityController =
      TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController();

  final TextEditingController
      _whatsappController =
      TextEditingController();

  final TextEditingController
      _telegramController =
      TextEditingController();

  final TextEditingController
      _instagramController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  TherapistProfileModel? _profile;

  List<TherapistCertificateModel> _certificates = [];

  bool _isLoading = true;
  bool _isFormInitialized = false;
  bool _isEditing = false;

  bool _onlineAvailable = true;

  bool _isSaving = false;
  bool _isSubmitting = false;
  bool _isUploadingPhoto = false;
  bool _isUploadingCertificate = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadInitialData();
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

    _phoneController.dispose();
    _whatsappController.dispose();
    _telegramController.dispose();
    _instagramController.dispose();
    _emailController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD INITIAL DATA
  // ============================================================

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ownProfile =
          await TherapistService.getMyProfile();

      final certificates =
          await TherapistService.getMyCertificates();

      final profile =
          await _loadProfileRatingIfAvailable(
        ownProfile,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
        _certificates = certificates;
        _isLoading = false;
        _isEditing =
            _shouldStartInEditMode(profile);
      });

      _initializeControllersOnce(
        profile,
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Не удалось загрузить анкету специалиста.';
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // LOAD RATING
  // ============================================================

  Future<TherapistProfileModel>
      _loadProfileRatingIfAvailable(
    TherapistProfileModel profile,
  ) async {
    final profileId = profile.id;

    if (profileId == null ||
        !profile.isApproved) {
      return profile;
    }

    try {
      final publicProfile =
          await TherapistService
              .getTherapistById(
        profileId,
      );

      return profile.copyWith(
        averageRating:
            publicProfile.averageRating,
        ratingsCount:
            publicProfile.ratingsCount,
        currentUserRating:
            publicProfile.currentUserRating,
        canRate:
            publicProfile.canRate,
      );
    } catch (_) {
      return profile;
    }
  }

  TherapistProfileModel _preserveRatingData(
    TherapistProfileModel updatedProfile,
  ) {
    final currentProfile = _profile;

    if (currentProfile == null) {
      return updatedProfile;
    }

    return updatedProfile.copyWith(
      averageRating:
          currentProfile.averageRating,
      ratingsCount:
          currentProfile.ratingsCount,
      currentUserRating:
          currentProfile.currentUserRating,
      canRate:
          currentProfile.canRate,
    );
  }

  // ============================================================
  // FORM INITIALIZATION
  // ============================================================

  bool _shouldStartInEditMode(
    TherapistProfileModel profile,
  ) {
    if (profile.isEmptyProfile) {
      return true;
    }

    if (profile.status == null) {
      return true;
    }

    if (profile.status == 'draft') {
      return true;
    }

    if (profile.status == 'rejected') {
      return true;
    }

    return false;
  }

  void _initializeControllersOnce(
    TherapistProfileModel profile,
  ) {
    if (_isFormInitialized) {
      return;
    }

    _fullNameController.text =
        profile.fullName ?? '';

    _qualificationController.text =
        profile.qualification ?? '';

    _therapyApproachesController.text =
        profile.therapyApproaches.join(', ');

    _specializationsController.text =
        profile.specializations.join(', ');

    _descriptionController.text =
        profile.description ?? '';

    _priceController.text =
        profile.price ?? '';

    _cityController.text =
        profile.city ?? '';

    final contacts =
        profile.contacts ?? {};

    _phoneController.text =
        contacts['phone']?.toString() ?? '';

    _whatsappController.text =
        contacts['whatsapp']?.toString() ?? '';

    _telegramController.text =
        contacts['telegram']?.toString() ?? '';

    _instagramController.text =
        contacts['instagram']?.toString() ?? '';

    _emailController.text =
        contacts['email']?.toString() ?? '';

    _onlineAvailable =
        profile.onlineAvailable ?? true;

    _isFormInitialized = true;
  }

  // ============================================================
  // CERTIFICATES
  // ============================================================

  Future<void> _refreshOnlyCertificates() async {
    final certificates =
        await TherapistService
            .getMyCertificates();

    if (!mounted) {
      return;
    }

    setState(() {
      _certificates = certificates;
    });
  }

  // ============================================================
  // PHOTO
  // ============================================================

  Future<void> _uploadPhoto() async {
    try {
      final image =
          await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _isUploadingPhoto = true;
      });

      final updatedProfile =
          await TherapistService
              .uploadProfilePhoto(
        image,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = _profile?.copyWith(
              photoUrl:
                  updatedProfile.photoUrl,
              updatedAt:
                  updatedProfile.updatedAt,
            ) ??
            updatedProfile;
      });

      _showSnackBar(
        'Фото профиля загружено.',
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        error.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Не удалось загрузить фото профиля.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  // ============================================================
  // CERTIFICATE UPLOAD
  // ============================================================

  Future<void> _uploadCertificate() async {
    try {
      final result =
          await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: kIsWeb,
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'jpg',
          'jpeg',
          'png',
        ],
      );

      if (result == null ||
          result.files.isEmpty) {
        return;
      }

      setState(() {
        _isUploadingCertificate = true;
      });

      await TherapistService.uploadCertificate(
        result.files.first,
      );

      await _refreshOnlyCertificates();

      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Сертификат загружен.',
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        error.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Не удалось загрузить сертификат.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingCertificate = false;
        });
      }
    }
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  String? _validateRequiredFields() {
    if (_fullNameController.text
        .trim()
        .isEmpty) {
      return 'Заполните ФИО.';
    }

    if (_qualificationController.text
        .trim()
        .isEmpty) {
      return 'Заполните квалификацию.';
    }

    return null;
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<TherapistProfileModel?> _saveProfile({
    bool silent = false,
  }) async {
    final validationMessage =
        _validateRequiredFields();

    if (validationMessage != null) {
      _showSnackBar(
        validationMessage,
      );

      return null;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedProfile =
          await TherapistService
              .updateMyProfile(
        fullName:
            _fullNameController.text,
        qualification:
            _qualificationController.text,
        therapyApproaches:
            _therapyApproachesController.text,
        specializations:
            _specializationsController.text,
        description:
            _descriptionController.text,
        price:
            _priceController.text,
        contacts:
            _contactsPayload(),
        city:
            _cityController.text,
        onlineAvailable:
            _onlineAvailable,
      );

      if (!mounted) {
        return null;
      }

      setState(() {
        _profile =
            _preserveRatingData(
          updatedProfile,
        );
      });

      if (!silent) {
        _showSnackBar(
          'Анкета сохранена',
        );
      }

      return updatedProfile;
    } on ApiException catch (error) {
      if (!mounted) {
        return null;
      }

      _showSnackBar(
        error.message,
      );

      return null;
    } catch (_) {
      if (!mounted) {
        return null;
      }

      _showSnackBar(
        'Не удалось сохранить анкету.',
      );

      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // SUBMIT PROFILE
  // ============================================================

  Future<void> _submitProfile() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final savedProfile =
          await _saveProfile(
        silent: true,
      );

      if (savedProfile == null) {
        return;
      }

      final updatedProfile =
          await TherapistService
              .submitProfile();

      if (!mounted) {
        return;
      }

      final profileWithRating =
          await _loadProfileRatingIfAvailable(
        updatedProfile,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _profile =
            profileWithRating;
        _isEditing = false;
      });

      _showSnackBar(
        'Анкета отправлена на модерацию',
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        error.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Не удалось отправить анкету на модерацию.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // ============================================================
  // CONTACTS
  // ============================================================

  Map<String, dynamic> _contactsPayload() {
    final contacts =
        <String, dynamic>{};

    void addIfNotEmpty(
      String key,
      TextEditingController controller,
    ) {
      final value =
          controller.text.trim();

      if (value.isNotEmpty) {
        contacts[key] = value;
      }
    }

    addIfNotEmpty(
      'phone',
      _phoneController,
    );

    addIfNotEmpty(
      'whatsapp',
      _whatsappController,
    );

    addIfNotEmpty(
      'telegram',
      _telegramController,
    );

    addIfNotEmpty(
      'instagram',
      _instagramController,
    );

    addIfNotEmpty(
      'email',
      _emailController,
    );

    return contacts;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _statusTitle(
    String? status,
  ) {
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
        return 'Черновик';
    }
  }

  String _safeText(
    String? value,
    String fallback,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return fallback;
    }

    return value.trim();
  }

  String _listText(
    List<String> items,
  ) {
    final filteredItems =
        items
            .map(
              (item) =>
                  item.trim(),
            )
            .where(
              (item) =>
                  item.isNotEmpty,
            )
            .toList();

    if (filteredItems.isEmpty) {
      return 'Не заполнено';
    }

    return filteredItems
        .map(
          (item) =>
              '• $item',
        )
        .join('\n');
  }

  String _contactsText(
    Map<String, dynamic>? contacts,
  ) {
    if (contacts == null ||
        contacts.isEmpty) {
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

    contacts.forEach(
      (
        key,
        value,
      ) {
        final text =
            value?.toString().trim();

        if (text == null ||
            text.isEmpty) {
          return;
        }

        final label =
            labels[key] ??
            key.toString();

        lines.add(
          '$label: $text',
        );
      },
    );

    if (lines.isEmpty) {
      return 'Не заполнено';
    }

    return lines.join('\n');
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  void _showSnackBar(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppLoading(
          text: 'Загрузка анкеты...',
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Анкета специалиста',
          ),
        ),
        body: AppErrorView(
          message: _errorMessage!,
          onRetry: _loadInitialData,
        ),
      );
    }

    final profile = _profile;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Анкета специалиста',
          ),
        ),
        body: AppErrorView(
          message:
              'Анкета специалиста не найдена.',
          onRetry: _loadInitialData,
        ),
      );
    }

    final shouldShowEditForm =
        _isEditing ||
        profile.isDraft ||
        profile.isRejected ||
        profile.isEmptyProfile;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final isWide =
                constraints.maxWidth > 760;

            return Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(
                  maxWidth: isWide
                      ? 720
                      : double.infinity,
                ),
                child: ListView(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    110,
                  ),
                  children: [
                    Text(
                      'Анкета специалиста',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium,
                    ),
                    const SizedBox(
                      height: AppSpacing.sm,
                    ),
                    Text(
                      shouldShowEditForm
                          ? 'Заполните анкету и сохраните изменения.'
                          : 'Просмотр текущей анкеты специалиста.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(
                      height: AppSpacing.xl,
                    ),
                    _StatusCard(
                      statusTitle:
                          _statusTitle(
                        profile.status,
                      ),
                      status:
                          profile.status,
                      rejectionReason:
                          profile
                              .rejectionReason,
                    ),

                    if (profile.hasRating) ...[
                      const SizedBox(
                        height: AppSpacing.lg,
                      ),
                      _TherapistRatingCard(
                        profile: profile,
                      ),
                    ],

                    const SizedBox(
                      height: AppSpacing.lg,
                    ),

                    _PhotoCard(
                      photoUrl:
                          UrlHelper.buildFileUrl(
                        profile.photoUrl,
                      ),
                      isUploading:
                          _isUploadingPhoto,
                      onUpload:
                          _uploadPhoto,
                    ),

                    const SizedBox(
                      height: AppSpacing.lg,
                    ),

                    if (shouldShowEditForm)
                      _EditForm(
                        fullNameController:
                            _fullNameController,
                        qualificationController:
                            _qualificationController,
                        therapyApproachesController:
                            _therapyApproachesController,
                        specializationsController:
                            _specializationsController,
                        descriptionController:
                            _descriptionController,
                        priceController:
                            _priceController,
                        cityController:
                            _cityController,
                        phoneController:
                            _phoneController,
                        whatsappController:
                            _whatsappController,
                        telegramController:
                            _telegramController,
                        instagramController:
                            _instagramController,
                        emailController:
                            _emailController,
                        onlineAvailable:
                            _onlineAvailable,
                        onOnlineChanged:
                            (value) {
                          setState(() {
                            _onlineAvailable =
                                value;
                          });
                        },
                        isSaving:
                            _isSaving,
                        onSave: () {
                          _saveProfile();
                        },
                      )
                    else
                      _ReadOnlyProfileCard(
                        profile:
                            profile,
                        safeText:
                            _safeText,
                        listText:
                            _listText,
                        contactsText:
                            _contactsText,
                        onEdit:
                            _startEditing,
                      ),

                    const SizedBox(
                      height: AppSpacing.lg,
                    ),

                    _CertificatesCard(
                      certificates:
                          _certificates,
                      isUploading:
                          _isUploadingCertificate,
                      onUpload:
                          _uploadCertificate,
                    ),

                    const SizedBox(
                      height: AppSpacing.lg,
                    ),

                    if (shouldShowEditForm)
                      AppButton(
                        text:
                            'Отправить на модерацию',
                        icon:
                            Icons.verified_outlined,
                        isLoading:
                            _isSubmitting,
                        variant:
                            AppButtonVariant
                                .secondary,
                        onPressed:
                            _isSaving ||
                                    _isUploadingCertificate
                                ? null
                                : _submitProfile,
                      ),

                    if (profile.status ==
                            'pending' &&
                        !shouldShowEditForm)
                      const _InfoCard(
                        text:
                            'Анкета отправлена на модерацию.',
                      ),

                    if (profile.status ==
                            'approved' &&
                        !shouldShowEditForm)
                      const _InfoCard(
                        text:
                            'Анкета одобрена и отображается пользователям.',
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
}

// ============================================================
// STATUS CARD
// ============================================================

class _StatusCard extends StatelessWidget {
  final String statusTitle;
  final String? status;
  final String? rejectionReason;

  const _StatusCard({
    required this.statusTitle,
    required this.status,
    required this.rejectionReason,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isRejected =
        status == 'rejected';

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Статус',
            style:
                theme.textTheme.titleLarge,
          ),
          const SizedBox(
            height: AppSpacing.sm,
          ),
          Text(
            statusTitle,
            style:
                theme.textTheme.bodyMedium
                    ?.copyWith(
              color:
                  theme.colorScheme.primary,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          if (isRejected &&
              rejectionReason != null &&
              rejectionReason!
                  .trim()
                  .isNotEmpty) ...[
            const SizedBox(
              height: AppSpacing.md,
            ),
            Text(
              'Причина отклонения:',
              style: theme
                  .textTheme.bodySmall
                  ?.copyWith(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(
              height: AppSpacing.xs,
            ),
            Text(
              rejectionReason!.trim(),
              style: theme
                  .textTheme.bodyMedium
                  ?.copyWith(
                color:
                    theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// RATING CARD
// ============================================================

class _TherapistRatingCard
    extends StatelessWidget {
  final TherapistProfileModel profile;

  const _TherapistRatingCard({
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final averageRating =
        profile.averageRating ?? 0;

    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Рейтинг',
            style:
                theme.textTheme.titleLarge,
          ),
          const SizedBox(
            height: AppSpacing.md,
          ),
          Row(
            children: [
              Icon(
                Icons.star_rounded,
                color:
                    theme.colorScheme.primary,
                size: 30,
              ),
              const SizedBox(
                width: AppSpacing.sm,
              ),
              Text(
                averageRating
                    .toStringAsFixed(1),
                style: theme
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                  color: theme
                      .colorScheme
                      .onSurface,
                ),
              ),
              const SizedBox(
                width: AppSpacing.sm,
              ),
              Expanded(
                child: Text(
                  profile.ratingsCountText,
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: AppSpacing.sm,
          ),
          Text(
            'Средняя оценка пользователей, которые общались с вами в приложении.',
            style:
                theme.textTheme.bodySmall
                    ?.copyWith(
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PHOTO CARD
// ============================================================

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

    final hasPhoto =
        photoUrl.trim().isNotEmpty;

    return AppCard(
      hasShadow: false,
      child: Row(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor:
                theme.colorScheme.primary
                    .withValues(
              alpha: 0.12,
            ),
            backgroundImage: hasPhoto
                ? NetworkImage(
                    photoUrl,
                  )
                : null,
            child: hasPhoto
                ? null
                : Icon(
                    Icons.person_rounded,
                    size: 42,
                    color: theme
                        .colorScheme
                        .primary,
                  ),
          ),
          const SizedBox(
            width: AppSpacing.lg,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Фото профиля',
                  style: theme
                      .textTheme.titleLarge,
                ),
                const SizedBox(
                  height: AppSpacing.xs,
                ),
                Text(
                  hasPhoto
                      ? 'Фото загружено.'
                      : 'Если фото не загружено, будет показан дефолтный аватар.',
                  style: theme
                      .textTheme.bodySmall
                      ?.copyWith(
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(
                  height: AppSpacing.md,
                ),
                AppButton(
                  text:
                      'Загрузить фото',
                  isLoading:
                      isUploading,
                  variant:
                      AppButtonVariant
                          .secondary,
                  onPressed:
                      onUpload,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EDIT FORM
// ============================================================

class _EditForm extends StatelessWidget {
  final TextEditingController
      fullNameController;

  final TextEditingController
      qualificationController;

  final TextEditingController
      therapyApproachesController;

  final TextEditingController
      specializationsController;

  final TextEditingController
      descriptionController;

  final TextEditingController
      priceController;

  final TextEditingController
      cityController;

  final TextEditingController
      phoneController;

  final TextEditingController
      whatsappController;

  final TextEditingController
      telegramController;

  final TextEditingController
      instagramController;

  final TextEditingController
      emailController;

  final bool onlineAvailable;

  final ValueChanged<bool>
      onOnlineChanged;

  final bool isSaving;

  final VoidCallback onSave;

  const _EditForm({
    required this.fullNameController,
    required this.qualificationController,
    required this.therapyApproachesController,
    required this.specializationsController,
    required this.descriptionController,
    required this.priceController,
    required this.cityController,
    required this.phoneController,
    required this.whatsappController,
    required this.telegramController,
    required this.instagramController,
    required this.emailController,
    required this.onlineAvailable,
    required this.onOnlineChanged,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      hasShadow: false,
      child: Column(
        children: [
          AppTextField(
            controller:
                fullNameController,
            label: 'ФИО',
            hint:
                'Полное имя специалиста',
            prefixIcon:
                Icons.badge_outlined,
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          AppTextField(
            controller:
                qualificationController,
            label: 'Квалификация',
            hint:
                'Например: психолог, КПТ-консультант',
            prefixIcon:
                Icons.school_outlined,
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          AppTextField(
            controller:
                therapyApproachesController,
            label:
                'Направления терапии',
            hint:
                'Например: КПТ, ACT, психообразование',
            prefixIcon:
                Icons.psychology_outlined,
            maxLines: 2,
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          AppTextField(
            controller:
                specializationsController,
            label:
                'С какими запросами работает',
            hint:
                'Например: тревожность, самооценка, стресс',
            prefixIcon:
                Icons.topic_outlined,
            maxLines: 2,
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          AppTextField(
            controller:
                descriptionController,
            label: 'Описание',
            hint:
                'Кратко расскажите о себе и подходе',
            prefixIcon:
                Icons.description_outlined,
            maxLines: 5,
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          AppTextField(
            controller:
                priceController,
            label: 'Цена',
            hint:
                'Например: 15000 тг / 50 минут',
            prefixIcon:
                Icons.payments_outlined,
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          AppTextField(
            controller:
                cityController,
            label: 'Город',
            hint:
                'Например: Алматы',
            prefixIcon:
                Icons.location_city_outlined,
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          SwitchListTile(
            value: onlineAvailable,
            onChanged:
                onOnlineChanged,
            contentPadding:
                EdgeInsets.zero,
            title: Text(
              'Онлайн-консультации',
              style: theme
                  .textTheme.bodyMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            subtitle: Text(
              'Включите, если готовы работать онлайн.',
              style: theme
                  .textTheme.bodySmall
                  ?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          AppTextField(
            controller:
                phoneController,
            label: 'Телефон',
            hint: '+77777777777',
            prefixIcon:
                Icons.phone_outlined,
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          AppTextField(
            controller:
                whatsappController,
            label: 'WhatsApp',
            hint: '77777777777',
            prefixIcon:
                Icons.chat_outlined,
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          AppTextField(
            controller:
                telegramController,
            label: 'Telegram',
            hint: '@username',
            prefixIcon:
                Icons
                    .alternate_email_rounded,
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          AppTextField(
            controller:
                instagramController,
            label: 'Instagram',
            hint: '@username',
            prefixIcon:
                Icons.camera_alt_outlined,
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          AppTextField(
            controller:
                emailController,
            label: 'Email для связи',
            hint: 'example@mail.com',
            prefixIcon:
                Icons.email_outlined,
          ),
          const SizedBox(
            height: AppSpacing.xl,
          ),
          AppButton(
            text: 'Сохранить',
            icon:
                Icons.save_outlined,
            isLoading:
                isSaving,
            onPressed:
                onSave,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// READ-ONLY PROFILE CARD
// ============================================================

class _ReadOnlyProfileCard
    extends StatelessWidget {
  final TherapistProfileModel profile;

  final String Function(
    String?,
    String,
  )
  safeText;

  final String Function(
    List<String>,
  )
  listText;

  final String Function(
    Map<String, dynamic>?,
  )
  contactsText;

  final VoidCallback onEdit;

  const _ReadOnlyProfileCard({
    required this.profile,
    required this.safeText,
    required this.listText,
    required this.contactsText,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _ReadOnlyRow(
            title: 'ФИО',
            content: safeText(
              profile.fullName,
              'Не заполнено',
            ),
          ),
          _ReadOnlyRow(
            title: 'Квалификация',
            content: safeText(
              profile.qualification,
              'Не заполнено',
            ),
          ),
          _ReadOnlyRow(
            title:
                'Направления терапии',
            content: listText(
              profile
                  .therapyApproaches,
            ),
          ),
          _ReadOnlyRow(
            title:
                'С какими запросами работает',
            content: listText(
              profile
                  .specializations,
            ),
          ),
          _ReadOnlyRow(
            title: 'Описание',
            content: safeText(
              profile.description,
              'Не заполнено',
            ),
          ),
          _ReadOnlyRow(
            title: 'Цена',
            content: safeText(
              profile.price,
              'Не заполнено',
            ),
          ),
          _ReadOnlyRow(
            title: 'Город',
            content: safeText(
              profile.city,
              'Не заполнено',
            ),
          ),
          _ReadOnlyRow(
            title: 'Онлайн',
            content:
                profile.onlineAvailable ==
                        true
                    ? 'Да'
                    : 'Нет',
          ),
          _ReadOnlyRow(
            title: 'Контакты',
            content: contactsText(
              profile.contacts,
            ),
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          AppButton(
            text:
                'Редактировать анкету',
            icon:
                Icons.edit_outlined,
            variant:
                AppButtonVariant
                    .secondary,
            onPressed:
                onEdit,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// READ-ONLY ROW
// ============================================================

class _ReadOnlyRow extends StatelessWidget {
  final String title;
  final String content;

  const _ReadOnlyRow({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme
                .textTheme.bodySmall
                ?.copyWith(
              color:
                  theme.colorScheme.primary,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(
            height: AppSpacing.xs,
          ),
          Text(
            content,
            style:
                theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CERTIFICATES CARD
// ============================================================

class _CertificatesCard
    extends StatelessWidget {
  final List<TherapistCertificateModel>
      certificates;

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
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Сертификаты',
            style:
                theme.textTheme.titleLarge,
          ),
          const SizedBox(
            height: AppSpacing.sm,
          ),
          Text(
            'Загрузите документы, подтверждающие квалификацию.',
            style: theme
                .textTheme.bodyMedium
                ?.copyWith(
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          if (certificates.isEmpty)
            Text(
              'Сертификаты пока не загружены.',
              style: theme
                  .textTheme.bodyMedium
                  ?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            )
          else
            ...certificates.map(
              (
                certificate,
              ) {
                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom:
                        AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .insert_drive_file_outlined,
                        color: theme
                            .colorScheme
                            .primary,
                      ),
                      const SizedBox(
                        width:
                            AppSpacing.md,
                      ),
                      Expanded(
                        child: Text(
                          certificate
                                  .originalFilename ??
                              'Сертификат',
                          style: theme
                              .textTheme
                              .bodyMedium,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          AppButton(
            text:
                'Загрузить сертификат',
            isLoading:
                isUploading,
            variant:
                AppButtonVariant.secondary,
            onPressed:
                onUpload,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// INFO CARD
// ============================================================

class _InfoCard extends StatelessWidget {
  final String text;

  const _InfoCard({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      hasShadow: false,
      child: Text(
        text,
        style: theme
            .textTheme.bodyMedium
            ?.copyWith(
          color: theme
              .colorScheme
              .onSurfaceVariant,
          fontWeight:
              FontWeight.w600,
        ),
      ),
    );
  }
}