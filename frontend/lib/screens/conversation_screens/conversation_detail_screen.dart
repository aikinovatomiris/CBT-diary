import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/conversation_model.dart';
import '../../models/user_model.dart';
import '../../navigation/app_routes.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/conversation_service.dart';
import '../../services/conversation_socket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';

class ConversationDetailScreen extends StatefulWidget {
  final String? conversationId;

  const ConversationDetailScreen({
    super.key,
    required this.conversationId,
  });

  @override
  State<ConversationDetailScreen> createState() {
    return _ConversationDetailScreenState();
  }
}

class _ConversationDetailScreenState
    extends State<ConversationDetailScreen> {
  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  late Future<_ConversationDetailData> _future;

  int? _conversationId;
  UserModel? _currentUser;

  String _conversationTitle = 'Переписка';

  List<ConversationMessageModel> _messages = [];

  ConversationSocketService? _socketService;

  bool _isSending = false;
  bool _isOpeningSharedEntry = false;
  bool _socketWasStarted = false;

  @override
  void initState() {
    super.initState();

    _conversationId = int.tryParse(
      widget.conversationId ?? '',
    );

    if (_conversationId != null) {
      _future = _loadData();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    _socketService?.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<_ConversationDetailData> _loadData() async {
    final id = _conversationId;

    if (id == null) {
      throw const ApiException(
        message: 'Не найден ID переписки.',
      );
    }

    final user = await AuthService.me();

    final conversations =
        await ConversationService.getConversations();

    ConversationModel? currentConversation;

    for (final conversation in conversations) {
      if (conversation.id == id) {
        currentConversation = conversation;
        break;
      }
    }

    final messages =
        await ConversationService.getMessages(id);

    final conversationTitle =
        _resolveConversationTitle(
      conversation: currentConversation,
      currentUser: user,
    );

    _currentUser = user;
    _messages = messages;
    _conversationTitle = conversationTitle;

    await _markAsReadSilently();
    await _startSocketSilently();

    _scrollToBottom(
      animated: false,
    );

    return _ConversationDetailData(
      currentUser: user,
      messages: messages,
      conversationTitle: conversationTitle,
    );
  }

  String _resolveConversationTitle({
    required ConversationModel? conversation,
    required UserModel currentUser,
  }) {
    if (conversation == null) {
      return 'Переписка';
    }

    final interlocutorName =
        conversation.interlocutorName?.trim();

    if (interlocutorName != null &&
        interlocutorName.isNotEmpty) {
      return interlocutorName;
    }

    if (currentUser.role == 'user') {
      final therapistName =
          conversation.therapistName?.trim();

      if (therapistName != null &&
          therapistName.isNotEmpty) {
        return therapistName;
      }

      return 'Терапевт';
    }

    if (currentUser.role == 'therapist') {
      final userName =
          conversation.userName?.trim();

      if (userName != null &&
          userName.isNotEmpty) {
        return userName;
      }

      return 'Пользователь';
    }

    return 'Переписка';
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadData();
    });

    await _future;
  }

  // ============================================================
  // WEBSOCKET
  // ============================================================

  Future<void> _startSocketSilently() async {
    final id = _conversationId;

    if (id == null || _socketWasStarted) {
      return;
    }

    _socketWasStarted = true;

    final service = ConversationSocketService(
      conversationId: id,
      onMessage: _handleSocketMessage,
    );

    _socketService = service;

    try {
      await service.connect();
    } catch (_) {
      // WebSocket не должен ломать обычную REST-переписку.
    }
  }

  void _handleSocketMessage(
    ConversationMessageModel incomingMessage,
  ) {
    if (!mounted) {
      return;
    }

    final currentUserId = _currentUser?.id;

    if (currentUserId == null) {
      return;
    }

    // Собственное сообщение уже добавляется через REST-ответ.
    if (incomingMessage.senderId == currentUserId) {
      return;
    }

    final incomingId = incomingMessage.id;

    final alreadyExists = incomingId != null &&
        _messages.any(
          (message) => message.id == incomingId,
        );

    if (alreadyExists) {
      return;
    }

    setState(() {
      _messages = [
        ..._messages,
        incomingMessage,
      ]..sort(_compareMessages);
    });

    _markAsReadSilently();
    _scrollToBottom();
  }

  int _compareMessages(
    ConversationMessageModel first,
    ConversationMessageModel second,
  ) {
    final firstDate = first.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final secondDate = second.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final dateCompare = firstDate.compareTo(
      secondDate,
    );

    if (dateCompare != 0) {
      return dateCompare;
    }

    return (first.id ?? 0).compareTo(
      second.id ?? 0,
    );
  }

  // ============================================================
  // READ
  // ============================================================

  Future<void> _markAsReadSilently() async {
    final id = _conversationId;

    if (id == null) {
      return;
    }

    try {
      await ConversationService
          .markConversationAsRead(id);
    } catch (_) {
      // Ошибка отметки прочтения не должна закрывать чат.
    }
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage() async {
    final id = _conversationId;
    final currentUser = _currentUser;

    final content =
        _messageController.text.trim();

    if (id == null) {
      _showSnackBar(
        'Не найден ID переписки.',
      );
      return;
    }

    if (currentUser?.id == null) {
      _showSnackBar(
        'Не удалось определить пользователя.',
      );
      return;
    }

    if (content.isEmpty) {
      _showSnackBar(
        'Введите сообщение.',
      );
      return;
    }

    final optimisticMessage =
        ConversationMessageModel(
      id: null,
      conversationId: id,
      senderId: currentUser!.id,
      content: content,
      sharedDiaryEntryId: null,
      createdAt: DateTime.now(),
    );

    setState(() {
      _isSending = true;

      _messages = [
        ..._messages,
        optimisticMessage,
      ];
    });

    _messageController.clear();

    _scrollToBottom();

    try {
      final sentMessage =
          await ConversationService.sendMessage(
        id,
        content,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final updatedMessages = [
          ..._messages,
        ];

        final optimisticIndex =
            updatedMessages.indexOf(
          optimisticMessage,
        );

        final sentMessageAlreadyExists =
            sentMessage.id != null &&
                updatedMessages.any(
                  (message) =>
                      message.id == sentMessage.id,
                );

        if (optimisticIndex != -1) {
          if (sentMessageAlreadyExists) {
            updatedMessages.removeAt(
              optimisticIndex,
            );
          } else {
            updatedMessages[optimisticIndex] =
                sentMessage;
          }
        } else if (!sentMessageAlreadyExists) {
          updatedMessages.add(
            sentMessage,
          );
        }

        updatedMessages.sort(
          _compareMessages,
        );

        _messages = updatedMessages;
      });

      _scrollToBottom();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages = _messages
            .where(
              (message) =>
                  message != optimisticMessage,
            )
            .toList();
      });

      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages = _messages
            .where(
              (message) =>
                  message != optimisticMessage,
            )
            .toList();
      });

      _showSnackBar(
        'Не удалось отправить сообщение.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // ============================================================
  // SHARED DIARY
  // ============================================================

  Future<void> _openSharedDiaryEntry(
    ConversationMessageModel message,
  ) async {
    final conversationId = _conversationId;
    final diaryEntryId =
        message.sharedDiaryEntryId;

    if (conversationId == null ||
        diaryEntryId == null) {
      _showSnackBar(
        'Не удалось открыть КПТ-запись.',
      );
      return;
    }

    setState(() {
      _isOpeningSharedEntry = true;
    });

    try {
      final entry =
          await ConversationService
              .getSharedDiaryEntry(
        conversationId,
        diaryEntryId,
      );

      if (!mounted) {
        return;
      }

      await context.push(
        AppRoutes.sharedDiaryEntry,
        extra: entry,
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Не удалось открыть КПТ-запись.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningSharedEntry = false;
        });
      }
    }
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _scrollToBottom({
    bool animated = true,
  }) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!_scrollController.hasClients) {
          return;
        }

        final target =
            _scrollController.position.maxScrollExtent;

        if (!animated) {
          _scrollController.jumpTo(target);
          return;
        }

        _scrollController.animateTo(
          target,
          duration: const Duration(
            milliseconds: 220,
          ),
          curve: Curves.easeOut,
        );
      },
    );
  }

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
    if (_conversationId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Переписка',
          ),
        ),
        body: const AppErrorView(
          message: 'Не найден ID переписки.',
        ),
      );
    }

    return FutureBuilder<_ConversationDetailData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            _messages.isEmpty) {
          return const Scaffold(
            body: AppLoading(
              text: 'Загрузка переписки...',
            ),
          );
        }

        if (snapshot.hasError &&
            _messages.isEmpty) {
          final error = snapshot.error;

          final message = error is ApiException
              ? error.message
              : 'Не удалось загрузить переписку.';

          return Scaffold(
            appBar: AppBar(
              title: Text(
                _conversationTitle,
              ),
            ),
            body: AppErrorView(
              message: message,
              onRetry: _refresh,
            ),
          );
        }

        final user =
            _currentUser ??
            snapshot.data?.currentUser;

        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                _conversationTitle,
              ),
            ),
            body: AppErrorView(
              message:
                  'Не удалось определить текущего пользователя.',
              onRetry: _refresh,
            ),
          );
        }

        final conversationTitle =
            snapshot.data?.conversationTitle ??
            _conversationTitle;

        return _ConversationDetailContent(
          currentUser: user,
          conversationTitle: conversationTitle,
          messages: _messages,
          messageController:
              _messageController,
          scrollController:
              _scrollController,
          isSending: _isSending,
          isOpeningSharedEntry:
              _isOpeningSharedEntry,
          onSend: _sendMessage,
          onRefresh: _refresh,
          onOpenSharedDiaryEntry:
              _openSharedDiaryEntry,
        );
      },
    );
  }
}

// ============================================================
// DATA
// ============================================================

class _ConversationDetailData {
  final UserModel currentUser;

  final List<ConversationMessageModel> messages;

  final String conversationTitle;

  const _ConversationDetailData({
    required this.currentUser,
    required this.messages,
    required this.conversationTitle,
  });
}

// ============================================================
// CONTENT
// ============================================================

class _ConversationDetailContent
    extends StatelessWidget {
  final UserModel currentUser;

  final String conversationTitle;

  final List<ConversationMessageModel> messages;

  final TextEditingController messageController;

  final ScrollController scrollController;

  final bool isSending;
  final bool isOpeningSharedEntry;

  final VoidCallback onSend;

  final Future<void> Function() onRefresh;

  final ValueChanged<ConversationMessageModel>
      onOpenSharedDiaryEntry;

  const _ConversationDetailContent({
    required this.currentUser,
    required this.conversationTitle,
    required this.messages,
    required this.messageController,
    required this.scrollController,
    required this.isSending,
    required this.isOpeningSharedEntry,
    required this.onSend,
    required this.onRefresh,
    required this.onOpenSharedDiaryEntry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          conversationTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: onRefresh,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
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
                child: Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.md,
                        AppSpacing.xl,
                        AppSpacing.sm,
                      ),
                      child: AppCard(
                        hasShadow: false,
                        padding:
                            const EdgeInsets.all(
                          AppSpacing.md,
                        ),
                        child: Text(
                          'Переписка в приложении не заменяет консультацию и предназначена для первичной связи.',
                          style: theme
                              .textTheme.bodySmall
                              ?.copyWith(
                            color: theme.colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: messages.isEmpty
                          ? _EmptyMessagesState(
                              onRefresh: onRefresh,
                            )
                          : RefreshIndicator(
                              onRefresh: onRefresh,
                              child: ListView.builder(
                                controller:
                                    scrollController,
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(
                                  AppSpacing.xl,
                                  AppSpacing.md,
                                  AppSpacing.xl,
                                  AppSpacing.lg,
                                ),
                                itemCount:
                                    messages.length,
                                itemBuilder:
                                    (context, index) {
                                  final message =
                                      messages[index];

                                  final previous =
                                      index > 0
                                          ? messages[
                                              index - 1
                                            ]
                                          : null;

                                  final showDate =
                                      _shouldShowDate(
                                    previous: previous,
                                    current: message,
                                  );

                                  return Column(
                                    children: [
                                      if (showDate)
                                        _MessageDateDivider(
                                          date: message
                                              .createdAt,
                                        ),
                                      _MessageBubble(
                                        message: message,
                                        isMine:
                                            message.senderId ==
                                                currentUser.id,
                                        isOpeningSharedEntry:
                                            isOpeningSharedEntry,
                                        onOpenSharedDiaryEntry:
                                            () {
                                          onOpenSharedDiaryEntry(
                                            message,
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                    ),
                    _MessageInput(
                      controller:
                          messageController,
                      isSending: isSending,
                      onSend: onSend,
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

  bool _shouldShowDate({
    required ConversationMessageModel? previous,
    required ConversationMessageModel current,
  }) {
    if (previous == null) {
      return true;
    }

    final previousDate =
        previous.createdAt?.toLocal();

    final currentDate =
        current.createdAt?.toLocal();

    if (previousDate == null ||
        currentDate == null) {
      return previousDate != currentDate;
    }

    return previousDate.year != currentDate.year ||
        previousDate.month != currentDate.month ||
        previousDate.day != currentDate.day;
  }
}

// ============================================================
// DATE DIVIDER
// ============================================================

class _MessageDateDivider
    extends StatelessWidget {
  final DateTime? date;

  const _MessageDateDivider({
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.lg,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme
                .surfaceContainerHighest
                .withValues(
              alpha: 0.62,
            ),
            borderRadius: AppRadius.medium,
          ),
          child: Text(
            _formatDate(date),
            style:
                theme.textTheme.bodySmall?.copyWith(
              color: theme
                  .colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(
    DateTime? value,
  ) {
    if (value == null) {
      return 'Дата не указана';
    }

    final date = value.toLocal();
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final dateOnly = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final difference =
        today.difference(dateOnly).inDays;

    if (difference == 0) {
      return 'Сегодня';
    }

    if (difference == 1) {
      return 'Вчера';
    }

    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];

    final month = months[
      date.month - 1
    ];

    if (date.year == now.year) {
      return '${date.day} $month';
    }

    return '${date.day} $month ${date.year}';
  }
}

// ============================================================
// MESSAGE BUBBLE
// ============================================================

class _MessageBubble extends StatelessWidget {
  final ConversationMessageModel message;

  final bool isMine;
  final bool isOpeningSharedEntry;

  final VoidCallback onOpenSharedDiaryEntry;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.isOpeningSharedEntry,
    required this.onOpenSharedDiaryEntry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hasSharedDiary =
        message.sharedDiaryEntryId != null;

    final bubbleColor = isMine
        ? theme.colorScheme.primary
        : theme.cardTheme.color ??
            theme.colorScheme.surface;

    final textColor = isMine
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    final timeColor = isMine
        ? theme.colorScheme.onPrimary.withValues(
            alpha: 0.72,
          )
        : theme.colorScheme.onSurfaceVariant;

    final screenWidth =
        MediaQuery.sizeOf(context).width;

    final maxBubbleWidth = screenWidth > 760
        ? 520.0
        : screenWidth * 0.76;

    return Align(
      alignment: isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: AppSpacing.md,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxBubbleWidth,
          ),
          child: IntrinsicWidth(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(
                    AppRadius.lg,
                  ),
                  topRight: Radius.circular(
                    AppRadius.lg,
                  ),
                  bottomLeft: Radius.circular(
                    isMine
                        ? AppRadius.lg
                        : AppRadius.sm,
                  ),
                  bottomRight: Radius.circular(
                    isMine
                        ? AppRadius.sm
                        : AppRadius.lg,
                  ),
                ),
                border: isMine
                    ? null
                    : Border.all(
                        color: theme.dividerColor
                            .withValues(
                          alpha: 0.6,
                        ),
                      ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Align(
                    alignment:
                        Alignment.centerLeft,
                    child: hasSharedDiary
                        ? _SharedDiaryMessageCard(
                            isMine: isMine,
                            textColor: textColor,
                            isLoading:
                                isOpeningSharedEntry,
                            onOpen:
                                onOpenSharedDiaryEntry,
                          )
                        : Text(
                            message.content
                                        ?.trim()
                                        .isNotEmpty ==
                                    true
                                ? message.content!
                                    .trim()
                                : 'Сообщение',
                            style: theme
                                .textTheme.bodyMedium
                                ?.copyWith(
                              color: textColor,
                              height: 1.42,
                            ),
                          ),
                  ),
                  const SizedBox(
                    height: AppSpacing.xs,
                  ),
                  Text(
                    _formatTime(
                      message.createdAt,
                    ),
                    style: theme
                        .textTheme.bodySmall
                        ?.copyWith(
                      color: timeColor,
                      fontSize: 11,
                      height: 1,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(
    DateTime? value,
  ) {
    if (value == null) {
      return '';
    }

    final local = value.toLocal();

    final hour = local.hour
        .toString()
        .padLeft(2, '0');

    final minute = local.minute
        .toString()
        .padLeft(2, '0');

    return '$hour:$minute';
  }
}

// ============================================================
// SHARED DIARY CARD
// ============================================================

class _SharedDiaryMessageCard
    extends StatelessWidget {
  final bool isMine;
  final Color textColor;
  final bool isLoading;
  final VoidCallback onOpen;

  const _SharedDiaryMessageCard({
    required this.isMine,
    required this.textColor,
    required this.isLoading,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness == Brightness.dark;

    final cardBackground = isMine
        ? AppColors.white.withValues(
            alpha: isDark ? 0.13 : 0.12,
          )
        : theme.colorScheme.primary.withValues(
            alpha: isDark ? 0.12 : 0.08,
          );

    final cardBorder = isMine
        ? AppColors.white.withValues(
            alpha: isDark ? 0.16 : 0.18,
          )
        : theme.colorScheme.primary.withValues(
            alpha: isDark ? 0.20 : 0.12,
          );

    return Container(
      width: 260,
      padding: const EdgeInsets.all(
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: AppRadius.large,
        border: Border.all(
          color: cardBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.description_outlined,
            color: textColor,
            size: 24,
          ),
          const SizedBox(
            height: AppSpacing.sm,
          ),
          Text(
            'КПТ-запись',
            style:
                theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(
            height: AppSpacing.xs,
          ),
          Text(
            'Дневниковая запись, отправленная в переписку.',
            style:
                theme.textTheme.bodySmall?.copyWith(
              color: textColor.withValues(
                alpha: 0.8,
              ),
            ),
          ),
          const SizedBox(
            height: AppSpacing.md,
          ),
          _SharedDiaryOpenButton(
            isLoading: isLoading,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SHARED DIARY BUTTON
// ============================================================

class _SharedDiaryOpenButton
    extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _SharedDiaryOpenButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Material(
        color: AppColors.white,
        borderRadius: AppRadius.large,
        child: InkWell(
          onTap:
              isLoading ? null : onPressed,
          borderRadius: AppRadius.large,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme
                          .colorScheme.primary,
                    ),
                  )
                : Text(
                    'Открыть',
                    style: theme
                        .textTheme.bodyMedium
                        ?.copyWith(
                      color: theme
                          .colorScheme.primary,
                      fontWeight:
                          FontWeight.w800,
                      letterSpacing: -0.15,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MESSAGE INPUT
// ============================================================

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;

  final bool isSending;

  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness == Brightness.dark;

    final inputBackground = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

    final inputBorder = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.darkBorder
                : AppColors.lightDivider,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 48,
                maxHeight: 132,
              ),
              decoration: BoxDecoration(
                color: inputBackground,
                borderRadius:
                    AppRadius.large,
                border: Border.all(
                  color: inputBorder,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: controller,
                enabled: !isSending,
                minLines: 1,
                maxLines: 5,
                keyboardType:
                    TextInputType.multiline,
                textInputAction:
                    TextInputAction.newline,
                style:
                    theme.textTheme.bodyMedium,
                cursorColor:
                    theme.colorScheme.primary,
                decoration: InputDecoration(
                  hintText:
                      'Напишите сообщение...',
                  hintStyle: theme
                      .textTheme.bodyMedium
                      ?.copyWith(
                    color: theme.colorScheme
                        .onSurfaceVariant,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder:
                      InputBorder.none,
                  focusedBorder:
                      InputBorder.none,
                  disabledBorder:
                      InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal:
                        AppSpacing.lg,
                    vertical: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            width: AppSpacing.sm,
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: FilledButton(
              onPressed:
                  isSending ? null : onSend,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      AppRadius.large,
                ),
              ),
              child: isSending
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class _EmptyMessagesState
    extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyMessagesState({
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(
          AppSpacing.xl,
        ),
        children: [
          AppCard(
            hasShadow: false,
            child: Text(
              'Сообщений пока нет. Напишите первое сообщение.',
              style:
                  theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}