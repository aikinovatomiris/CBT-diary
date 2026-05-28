import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/conversation_model.dart';
import '../models/therapist_profile_model.dart';
import '../models/user_model.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/conversation_service.dart';
import '../services/therapist_service.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/app_error_view.dart';
import '../widgets/app_loading.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() =>
      _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  late Future<_ConversationsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_ConversationsData> _loadData() async {
    final user = await AuthService.me();
    final conversations = await ConversationService.getConversations();

    final therapistNamesByUserId = <int, String>{};

    if (user.role == 'user') {
      final therapists = await TherapistService.getApprovedTherapists();

      for (final therapist in therapists) {
        final userId = therapist.userId;
        final fullName = therapist.fullName;

        if (userId != null && fullName != null && fullName.trim().isNotEmpty) {
          therapistNamesByUserId[userId] = fullName.trim();
        }
      }
    }

    return _ConversationsData(
      currentUser: user,
      conversations: conversations,
      therapistNamesByUserId: therapistNamesByUserId,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadData();
    });

    await _future;
  }

  void _openConversation(ConversationModel conversation) {
    final id = conversation.id;

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У переписки нет ID.'),
        ),
      );
      return;
    }

    context.push('/conversations/$id').then((_) {
      if (mounted) {
        _refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ConversationsData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
              title: const Text('Сообщения'),
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
              title: const Text('Сообщения'),
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
          therapistNamesByUserId: data.therapistNamesByUserId,
          onRefresh: _refresh,
          onOpenConversation: _openConversation,
        );
      },
    );
  }
}

class _ConversationsData {
  final UserModel currentUser;
  final List<ConversationModel> conversations;
  final Map<int, String> therapistNamesByUserId;

  const _ConversationsData({
    required this.currentUser,
    required this.conversations,
    required this.therapistNamesByUserId,
  });
}

class _ConversationsListContent extends StatelessWidget {
  final UserModel currentUser;
  final List<ConversationModel> conversations;
  final Map<int, String> therapistNamesByUserId;
  final Future<void> Function() onRefresh;
  final ValueChanged<ConversationModel> onOpenConversation;

  const _ConversationsListContent({
    required this.currentUser,
    required this.conversations,
    required this.therapistNamesByUserId,
    required this.onRefresh,
    required this.onOpenConversation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = currentUser.role;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сообщения'),
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
                        'Переписки',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Переписка в приложении не заменяет консультацию и предназначена для первичной связи.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (conversations.isEmpty)
                        AppCard(
                          hasShadow: false,
                          child: Text(
                            role == 'therapist'
                                ? 'Пока нет диалогов с пользователями.'
                                : 'Пока нет диалогов со специалистами.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        ...conversations.map(
                          (conversation) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.lg,
                              ),
                              child: _ConversationCard(
                                conversation: conversation,
                                currentUser: currentUser,
                                therapistNamesByUserId:
                                    therapistNamesByUserId,
                                onTap: () =>
                                    onOpenConversation(conversation),
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

class _ConversationCard extends StatelessWidget {
  final ConversationModel conversation;
  final UserModel currentUser;
  final Map<int, String> therapistNamesByUserId;
  final VoidCallback onTap;

  const _ConversationCard({
    required this.conversation,
    required this.currentUser,
    required this.therapistNamesByUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = _conversationTitle();
    final hasUnread = conversation.unreadCount > 0;
    final lastMessage = conversation.lastMessage?.trim();

    return AppCard(
      hasShadow: false,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: AppRadius.large,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  lastMessage != null && lastMessage.isNotEmpty
                      ? lastMessage
                      : 'Открыть переписку',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (hasUnread) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: AppRadius.medium,
              ),
              child: Text(
                conversation.unreadCount.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  String _conversationTitle() {
    final explicitName = conversation.interlocutorName;

    if (explicitName != null && explicitName.trim().isNotEmpty) {
      return explicitName.trim();
    }

    if (currentUser.role == 'user') {
      final therapistUserId = conversation.therapistUserId;

      if (therapistUserId != null) {
        final therapistName = therapistNamesByUserId[therapistUserId];

        if (therapistName != null && therapistName.trim().isNotEmpty) {
          return therapistName.trim();
        }
      }

      final fallbackName = conversation.therapistName;

      if (fallbackName != null && fallbackName.trim().isNotEmpty) {
        return fallbackName.trim();
      }

      return therapistUserId == null
          ? 'Диалог #${conversation.id ?? ''}'
          : 'Терапевт #$therapistUserId';
    }

    final userName = conversation.userName;

    if (userName != null && userName.trim().isNotEmpty) {
      return userName.trim();
    }

    final userId = conversation.userId;

    return userId == null
        ? 'Диалог #${conversation.id ?? ''}'
        : 'Пользователь #$userId';
  }
}