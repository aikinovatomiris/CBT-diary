import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/conversation_model.dart';
import '../../models/therapist_profile_model.dart';
import '../../models/user_model.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/conversation_service.dart';
import '../../services/therapist_service.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/url_helper.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({
    super.key,
  });

  @override
  State<ConversationsListScreen> createState() =>
      _ConversationsListScreenState();
}

class _ConversationsListScreenState
    extends State<ConversationsListScreen> {
  late Future<_ConversationsData> _future;

  @override
  void initState() {
    super.initState();

    _future = _loadData();
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<_ConversationsData> _loadData() async {
    final user = await AuthService.me();

    final conversations =
        await ConversationService.getConversations();

    final therapistProfilesByUserId =
        <int, TherapistProfileModel>{};

    /*
     * Пользователю в списке диалогов показываем данные
     * терапевта из публичного каталога:
     *
     * - полное имя;
     * - фотографию профиля.
     *
     * Связь выполняется через therapist.userId,
     * который соответствует conversation.therapistUserId.
     */
    if (user.role == 'user') {
      final therapists =
          await TherapistService.getApprovedTherapists();

      for (final therapist in therapists) {
        final therapistUserId = therapist.userId;

        if (therapistUserId == null) {
          continue;
        }

        therapistProfilesByUserId[
          therapistUserId
        ] = therapist;
      }
    }

    return _ConversationsData(
      currentUser: user,
      conversations: conversations,
      therapistProfilesByUserId:
          therapistProfilesByUserId,
    );
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    setState(() {
      _future = _loadData();
    });

    await _future;
  }

  // ============================================================
  // OPEN CONVERSATION
  // ============================================================

  Future<void> _openConversation(
    ConversationModel conversation,
  ) async {
    final conversationId = conversation.id;

    if (conversationId == null) {
      _showSnackBar(
        'У переписки нет ID.',
      );

      return;
    }

    await context.push(
      '/conversations/$conversationId',
    );

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ConversationsData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: AppLoading(
              text: 'Загрузка переписок...',
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;

          final message = error is ApiException
              ? error.message
              : 'Не удалось загрузить переписки.';

          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Сообщения',
              ),
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
              title: const Text(
                'Сообщения',
              ),
            ),
            body: AppErrorView(
              message: 'Нет данных.',
              onRetry: _refresh,
            ),
          );
        }

        return _ConversationsListContent(
          currentUser: data.currentUser,
          conversations: data.conversations,
          therapistProfilesByUserId:
              data.therapistProfilesByUserId,
          onRefresh: _refresh,
          onOpenConversation: _openConversation,
        );
      },
    );
  }
}

// ============================================================
// DATA
// ============================================================

class _ConversationsData {
  final UserModel currentUser;

  final List<ConversationModel> conversations;

  final Map<int, TherapistProfileModel>
      therapistProfilesByUserId;

  const _ConversationsData({
    required this.currentUser,
    required this.conversations,
    required this.therapistProfilesByUserId,
  });
}

// ============================================================
// CONTENT
// ============================================================

class _ConversationsListContent
    extends StatelessWidget {
  final UserModel currentUser;

  final List<ConversationModel> conversations;

  final Map<int, TherapistProfileModel>
      therapistProfilesByUserId;

  final Future<void> Function() onRefresh;

  final ValueChanged<ConversationModel>
      onOpenConversation;

  const _ConversationsListContent({
    required this.currentUser,
    required this.conversations,
    required this.therapistProfilesByUserId,
    required this.onRefresh,
    required this.onOpenConversation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final role = currentUser.role;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Сообщения',
        ),
      ),
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
                constraints: BoxConstraints(
                  maxWidth: isWide
                      ? 720
                      : double.infinity,
                ),
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      110,
                    ),
                    children: [
                      if (conversations.isEmpty)
                        AppCard(
                          hasShadow: false,
                          child: Text(
                            role == 'therapist'
                                ? 'Пока нет диалогов с пользователями.'
                                : 'Пока нет диалогов со специалистами.',
                            style: theme
                                .textTheme.bodyMedium
                                ?.copyWith(
                              color: theme
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        ...conversations.map(
                          (conversation) {
                            final therapistProfile =
                                _therapistProfileFor(
                              conversation,
                            );

                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom:
                                    AppSpacing.md,
                              ),
                              child: _ConversationCard(
                                conversation:
                                    conversation,
                                currentUser:
                                    currentUser,
                                therapistProfile:
                                    therapistProfile,
                                onTap: () {
                                  onOpenConversation(
                                    conversation,
                                  );
                                },
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

  TherapistProfileModel? _therapistProfileFor(
    ConversationModel conversation,
  ) {
    if (currentUser.role != 'user') {
      return null;
    }

    final therapistUserId =
        conversation.therapistUserId;

    if (therapistUserId == null) {
      return null;
    }

    return therapistProfilesByUserId[
      therapistUserId
    ];
  }
}

// ============================================================
// CONVERSATION CARD
// ============================================================

class _ConversationCard extends StatelessWidget {
  final ConversationModel conversation;
  final UserModel currentUser;

  final TherapistProfileModel?
      therapistProfile;

  final VoidCallback onTap;

  const _ConversationCard({
    required this.conversation,
    required this.currentUser,
    required this.therapistProfile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = _conversationTitle();

    final hasUnread =
        conversation.hasUnread ||
        conversation.unreadCount > 0;

    final lastMessage =
        conversation.lastMessageText?.trim();

    final lastActivityAt =
        conversation.lastMessageAt ??
        conversation.createdAt;

    final isOwnLastMessage =
        conversation.lastMessageSenderId != null &&
        conversation.lastMessageSenderId ==
            currentUser.id;

    final photoUrl = UrlHelper.buildFileUrl(
      therapistProfile?.photoUrl,
    );

    final hasPhoto =
        currentUser.role == 'user' &&
        photoUrl.isNotEmpty;

    return AppCard(
      hasShadow: false,
      onTap: onTap,
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _ConversationAvatar(
                photoUrl: photoUrl,
                hasPhoto: hasPhoto,
              ),
              if (hasUnread)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme
                            .cardTheme.color ??
                            theme
                                .scaffoldBackgroundColor,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(
            width: AppSpacing.md,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: theme
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          fontWeight: hasUnread
                              ? FontWeight.w800
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: AppSpacing.sm,
                    ),
                    Text(
                      _formatConversationDate(
                        lastActivityAt,
                      ),
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
                        color: hasUnread
                            ? theme
                                .colorScheme.primary
                            : theme
                                .colorScheme
                                .onSurfaceVariant,
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: AppSpacing.xs,
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _buildLastMessageText(
                          lastMessage:
                              lastMessage,
                          isOwnLastMessage:
                              isOwnLastMessage,
                        ),
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color: hasUnread
                              ? theme
                                  .colorScheme
                                  .onSurface
                              : theme
                                  .colorScheme
                                  .onSurfaceVariant,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (hasUnread) ...[
                      const SizedBox(
                        width: AppSpacing.sm,
                      ),
                      _UnreadBadge(
                        count: conversation
                            .unreadCount,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(
            width: AppSpacing.sm,
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: theme
                .colorScheme.onSurfaceVariant,
            size: 23,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LAST MESSAGE
  // ============================================================

  String _buildLastMessageText({
    required String? lastMessage,
    required bool isOwnLastMessage,
  }) {
    if (lastMessage == null ||
        lastMessage.isEmpty) {
      return 'Открыть переписку';
    }

    if (isOwnLastMessage) {
      return 'Вы: $lastMessage';
    }

    return lastMessage;
  }

  // ============================================================
  // TITLE
  // ============================================================

  String _conversationTitle() {
    final explicitName =
        conversation.interlocutorName;

    if (explicitName != null &&
        explicitName.trim().isNotEmpty) {
      return explicitName.trim();
    }

    if (currentUser.role == 'user') {
      final profileName =
          therapistProfile?.fullName;

      if (profileName != null &&
          profileName.trim().isNotEmpty) {
        return profileName.trim();
      }

      final fallbackName =
          conversation.therapistName;

      if (fallbackName != null &&
          fallbackName.trim().isNotEmpty) {
        return fallbackName.trim();
      }

      final therapistUserId =
          conversation.therapistUserId;

      return therapistUserId == null
          ? 'Диалог #${conversation.id ?? ''}'
          : 'Терапевт #$therapistUserId';
    }

    final userName = conversation.userName;

    if (userName != null &&
        userName.trim().isNotEmpty) {
      return userName.trim();
    }

    final userId = conversation.userId;

    return userId == null
        ? 'Диалог #${conversation.id ?? ''}'
        : 'Пользователь #$userId';
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatConversationDate(
    DateTime? date,
  ) {
    if (date == null) {
      return '';
    }

    final localDate = date.toLocal();
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final messageDay = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );

    final difference =
        today.difference(messageDay).inDays;

    if (difference == 0) {
      return _formatTime(
        localDate,
      );
    }

    if (difference == 1) {
      return 'Вчера';
    }

    if (localDate.year == now.year) {
      return '${localDate.day.toString().padLeft(2, '0')}.'
          '${localDate.month.toString().padLeft(2, '0')}';
    }

    return '${localDate.day.toString().padLeft(2, '0')}.'
        '${localDate.month.toString().padLeft(2, '0')}.'
        '${localDate.year}';
  }

  String _formatTime(
    DateTime date,
  ) {
    final hour =
        date.hour.toString().padLeft(2, '0');

    final minute =
        date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }
}

// ============================================================
// CONVERSATION AVATAR
// Внешне повторяет аватар из каталога специалистов.
// ============================================================

class _ConversationAvatar
    extends StatelessWidget {
  final String photoUrl;
  final bool hasPhoto;

  const _ConversationAvatar({
    required this.photoUrl,
    required this.hasPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary
            .withValues(
          alpha: 0.10,
        ),
        border: Border.all(
          color: theme.colorScheme.primary
              .withValues(
            alpha: 0.12,
          ),
          width: 1,
        ),
      ),
      child: CircleAvatar(
        backgroundColor:
            theme.colorScheme.primary
                .withValues(
          alpha: 0.10,
        ),
        backgroundImage: hasPhoto
            ? NetworkImage(photoUrl)
            : null,
        child: hasPhoto
            ? null
            : Icon(
                Icons.person_outline_rounded,
                color:
                    theme.colorScheme.primary,
                size: 32,
              ),
      ),
    );
  }
}

// ============================================================
// UNREAD BADGE
// ============================================================

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final text = count > 99
        ? '99+'
        : count > 0
            ? count.toString()
            : '';

    if (text.isEmpty) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(
        minWidth: 22,
        minHeight: 22,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: AppRadius.medium,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style:
            theme.textTheme.bodySmall?.copyWith(
          color:
              theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          height: 1,
        ),
      ),
    );
  }
}