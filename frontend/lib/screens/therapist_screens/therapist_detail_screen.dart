import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/therapist_profile_model.dart';
import '../../services/api_exception.dart';
import '../../services/conversation_service.dart';
import '../../services/therapist_service.dart';
import '../../theme/app_spacing.dart';
import '../../utils/url_helper.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/user_messages_action.dart';

class TherapistDetailScreen extends StatefulWidget {
  final String? profileId;

  const TherapistDetailScreen({
    super.key,
    required this.profileId,
  });

  @override
  State<TherapistDetailScreen> createState() => _TherapistDetailScreenState();
}

class _TherapistDetailScreenState extends State<TherapistDetailScreen> {
  late Future<TherapistProfileModel> _therapistFuture;
  int? _profileId;
  bool _isStartingConversation = false;

  @override
  void initState() {
    super.initState();

    _profileId = int.tryParse(widget.profileId ?? '');

    if (_profileId != null) {
      _therapistFuture = _loadTherapist();
    }
  }

  Future<TherapistProfileModel> _loadTherapist() async {
    final id = _profileId;

    if (id == null) {
      throw const ApiException(
        message: 'Не найден ID специалиста.',
      );
    }

    final therapist = await TherapistService.getTherapistById(id);

    if (therapist.status != null && therapist.status != 'approved') {
      throw const ApiException(
        message: 'Анкета специалиста недоступна.',
      );
    }

    return therapist;
  }

  Future<void> _refresh() async {
    setState(() {
      _therapistFuture = _loadTherapist();
    });

    await _therapistFuture;
  }

  Future<void> _startConversation(TherapistProfileModel therapist) async {
    final therapistUserId = therapist.userId;

    if (therapistUserId == null) {
      _showSnackBar(
        'Backend не вернул user_id специалиста. Нужен user_id, а не id анкеты.',
      );
      return;
    }

    setState(() {
      _isStartingConversation = true;
    });

    try {
      final conversation = await ConversationService.createConversation(
        therapistUserId,
      );

      if (!mounted) return;

      final conversationId = conversation.id;

      if (conversationId == null) {
        _showSnackBar('Сервер не вернул ID переписки.');
        return;
      }

      context.push('/conversations/$conversationId');
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Не удалось открыть переписку со специалистом.');
    } finally {
      if (mounted) {
        setState(() {
          _isStartingConversation = false;
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
          title: const Text('Специалист'),
          actions: const [
            UserMessagesAction(),
          ],
        ),
        body: const AppErrorView(
          message: 'Не найден ID специалиста.',
        ),
      );
    }

    return FutureBuilder<TherapistProfileModel>(
      future: _therapistFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: AppLoading(
              text: 'Загрузка специалиста...',
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is ApiException
              ? error.message
              : 'Не удалось загрузить специалиста.';

          return Scaffold(
            appBar: AppBar(
              title: const Text('Специалист'),
              actions: const [
                UserMessagesAction(),
              ],
            ),
            body: AppErrorView(
              message: message,
              onRetry: _refresh,
            ),
          );
        }

        final therapist = snapshot.data;

        if (therapist == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Специалист'),
              actions: const [
                UserMessagesAction(),
              ],
            ),
            body: AppErrorView(
              message: 'Нет данных специалиста.',
              onRetry: _refresh,
            ),
          );
        }

        return _TherapistDetailContent(
          therapist: therapist,
          isStartingConversation: _isStartingConversation,
          onMessage: () => _startConversation(therapist),
        );
      },
    );
  }
}

class _TherapistDetailContent extends StatelessWidget {
  final TherapistProfileModel therapist;
  final bool isStartingConversation;
  final VoidCallback onMessage;

  const _TherapistDetailContent({
    required this.therapist,
    required this.isStartingConversation,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = UrlHelper.buildFileUrl(therapist.photoUrl);
    final hasPhoto = photoUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Специалист'),
        actions: const [
          UserMessagesAction(),
        ],
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
                    AppCard(
                      hasShadow: false,
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 56,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.12),
                            backgroundImage:
                                hasPhoto ? NetworkImage(photoUrl) : null,
                            child: hasPhoto
                                ? null
                                : Icon(
                                    Icons.person_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 56,
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            _safeText(therapist.fullName, 'Специалист'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _safeText(
                              therapist.qualification,
                              'Квалификация не указана',
                            ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            text: 'Написать специалисту',
                            icon: Icons.chat_bubble_outline_rounded,
                            isLoading: isStartingConversation,
                            onPressed: onMessage,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionCard(
                      title: 'Направления терапии',
                      content: _listText(therapist.therapyApproaches),
                    ),
                    _SectionCard(
                      title: 'С какими запросами работает',
                      content: _listText(therapist.specializations),
                    ),
                    _SectionCard(
                      title: 'Описание',
                      content: _safeText(
                        therapist.description,
                        'Описание не заполнено',
                      ),
                    ),
                    _SectionCard(
                      title: 'Цена',
                      content: _safeText(
                        therapist.price,
                        'Цена не указана',
                      ),
                    ),
                    _SectionCard(
                      title: 'Город',
                      content: _safeText(
                        therapist.city,
                        'Город не указан',
                      ),
                    ),
                    _SectionCard(
                      title: 'Формат',
                      content: therapist.onlineAvailable == true
                          ? 'Онлайн'
                          : 'Очно / по договоренности',
                    ),
                    _SectionCard(
                      title: 'Контакты',
                      content: _contactsText(therapist.contacts),
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
    if (value == null || value.trim().isEmpty) {
      return fallback;
    }

    return value.trim();
  }

  static String _listText(List<String> items) {
    final filteredItems = items
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (filteredItems.isEmpty) {
      return 'Не заполнено';
    }

    return filteredItems.map((item) => '• $item').join('\n');
  }

  static String _contactsText(Map<String, dynamic>? contacts) {
    if (contacts == null || contacts.isEmpty) {
      return 'Контакты не указаны';
    }

    return _formatDynamicText(contacts);
  }

  static String _formatDynamicText(dynamic value) {
    if (value == null) {
      return 'Не заполнено';
    }

    if (value is String) {
      final trimmed = value.trim();

      if (trimmed.isEmpty) {
        return 'Не заполнено';
      }

      return trimmed;
    }

    if (value is num || value is bool) {
      return value.toString();
    }

    if (value is List) {
      final items = value
          .map(_formatDynamicText)
          .where((item) => item.trim().isNotEmpty && item != 'Не заполнено')
          .toList();

      if (items.isEmpty) {
        return 'Не заполнено';
      }

      return items.map((item) => '• $item').join('\n');
    }

    if (value is Map) {
      if (value.isEmpty) {
        return 'Не заполнено';
      }

      final rawText = value['raw_text'];
      if (rawText != null && rawText.toString().trim().isNotEmpty) {
        return rawText.toString().trim();
      }

      final text = value['text'];
      if (text != null && text.toString().trim().isNotEmpty) {
        return text.toString().trim();
      }

      final items = value['items'];
      if (items is List && items.isNotEmpty) {
        return _formatDynamicText(items);
      }

      final lines = <String>[];

      value.forEach((key, mapValue) {
        final formattedKey = _humanizeKey(key.toString());
        final formattedValue = _formatDynamicText(mapValue);

        if (formattedValue.trim().isEmpty || formattedValue == 'Не заполнено') {
          return;
        }

        lines.add('$formattedKey: $formattedValue');
      });

      if (lines.isEmpty) {
        return 'Не заполнено';
      }

      return lines.join('\n');
    }

    final fallback = value.toString().trim();

    if (fallback.isEmpty || fallback == '{}' || fallback == '[]') {
      return 'Не заполнено';
    }

    return fallback;
  }

  static String _humanizeKey(String key) {
    switch (key) {
      case 'telegram':
        return 'Telegram';
      case 'phone':
        return 'Телефон';
      case 'email':
        return 'Email';
      case 'instagram':
        return 'Instagram';
      case 'whatsapp':
        return 'WhatsApp';
      case 'website':
        return 'Сайт';
      case 'text':
        return 'Текст';
      case 'raw_text':
        return 'Текст';
      case 'items':
        return 'Список';
      default:
        return _capitalizeFirst(key.replaceAll('_', ' '));
    }
  }

  static String _capitalizeFirst(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return trimmed;
    }

    return trimmed[0].toUpperCase() + trimmed.substring(1);
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