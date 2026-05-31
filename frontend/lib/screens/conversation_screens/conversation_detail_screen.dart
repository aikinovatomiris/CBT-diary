import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/conversation_model.dart';
import '../../models/user_model.dart';
import '../../navigation/app_routes.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/conversation_service.dart';
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
  State<ConversationDetailScreen> createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late Future<_ConversationDetailData> _future;

  int? _conversationId;
  UserModel? _currentUser;
  List<ConversationMessageModel> _messages = [];

  bool _isSending = false;
  bool _isOpeningSharedEntry = false;

  @override
  void initState() {
    super.initState();

    _conversationId = int.tryParse(widget.conversationId ?? '');

    if (_conversationId != null) {
      _future = _loadData();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<_ConversationDetailData> _loadData() async {
    final id = _conversationId;

    if (id == null) {
      throw const ApiException(
        message: 'Не найден ID переписки.',
      );
    }

    final user = await AuthService.me();
    final messages = await ConversationService.getMessages(id);

    _currentUser = user;
    _messages = messages;

    _scrollToBottom();

    return _ConversationDetailData(
      currentUser: user,
      messages: messages,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadData();
    });

    await _future;
  }

  Future<void> _sendMessage() async {
    final id = _conversationId;
    final currentUser = _currentUser;
    final content = _messageController.text.trim();

    if (id == null) {
      _showSnackBar('Не найден ID переписки.');
      return;
    }

    if (currentUser?.id == null) {
      _showSnackBar('Не удалось определить пользователя.');
      return;
    }

    if (content.isEmpty) {
      _showSnackBar('Введите сообщение.');
      return;
    }

    final optimisticMessage = ConversationMessageModel(
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
      final sentMessage = await ConversationService.sendMessage(id, content);

      if (!mounted) return;

      setState(() {
        final updatedMessages = [..._messages];
        final index = updatedMessages.indexOf(optimisticMessage);

        if (index != -1) {
          updatedMessages[index] = sentMessage;
        } else {
          updatedMessages.add(sentMessage);
        }

        _messages = updatedMessages;
      });

      await _syncMessagesSilently();
      _scrollToBottom();
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _messages = _messages.where((message) {
          return message != optimisticMessage;
        }).toList();
      });

      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _messages = _messages.where((message) {
          return message != optimisticMessage;
        }).toList();
      });

      _showSnackBar('Не удалось отправить сообщение.');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _openSharedDiaryEntry(
    ConversationMessageModel message,
  ) async {
    final conversationId = _conversationId;
    final diaryEntryId = message.sharedDiaryEntryId;

    if (conversationId == null || diaryEntryId == null) {
      _showSnackBar('Не удалось открыть КПТ-запись.');
      return;
    }

    setState(() {
      _isOpeningSharedEntry = true;
    });

    try {
      final entry = await ConversationService.getSharedDiaryEntry(
        conversationId,
        diaryEntryId,
      );

      if (!mounted) return;

      context.push(
        AppRoutes.sharedDiaryEntry,
        extra: entry,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Не удалось открыть КПТ-запись.');
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningSharedEntry = false;
        });
      }
    }
  }

  Future<void> _syncMessagesSilently() async {
    final id = _conversationId;
    if (id == null) return;

    try {
      final messages = await ConversationService.getMessages(id);

      if (!mounted) return;

      setState(() {
        _messages = messages;
      });
    } catch (_) {
      // Не ломаем экран, если повторная синхронизация не удалась.
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
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
    if (_conversationId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Переписка'),
        ),
        body: const AppErrorView(
          message: 'Не найден ID переписки.',
        ),
      );
    }

    return FutureBuilder<_ConversationDetailData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _messages.isEmpty) {
          return const Scaffold(
            body: AppLoading(
              text: 'Загрузка переписки...',
            ),
          );
        }

        if (snapshot.hasError && _messages.isEmpty) {
          final error = snapshot.error;
          final message = error is ApiException
              ? error.message
              : 'Не удалось загрузить переписку.';

          return Scaffold(
            appBar: AppBar(
              title: const Text('Переписка'),
            ),
            body: AppErrorView(
              message: message,
              onRetry: _refresh,
            ),
          );
        }

        final user = _currentUser ?? snapshot.data?.currentUser;

        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Переписка'),
            ),
            body: AppErrorView(
              message: 'Не удалось определить текущего пользователя.',
              onRetry: _refresh,
            ),
          );
        }

        return _ConversationDetailContent(
          currentUser: user,
          messages: _messages,
          messageController: _messageController,
          scrollController: _scrollController,
          isSending: _isSending,
          isOpeningSharedEntry: _isOpeningSharedEntry,
          onSend: _sendMessage,
          onRefresh: _refresh,
          onOpenSharedDiaryEntry: _openSharedDiaryEntry,
        );
      },
    );
  }
}

class _ConversationDetailData {
  final UserModel currentUser;
  final List<ConversationMessageModel> messages;

  const _ConversationDetailData({
    required this.currentUser,
    required this.messages,
  });
}

class _ConversationDetailContent extends StatelessWidget {
  final UserModel currentUser;
  final List<ConversationMessageModel> messages;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final bool isSending;
  final bool isOpeningSharedEntry;
  final VoidCallback onSend;
  final Future<void> Function() onRefresh;
  final ValueChanged<ConversationMessageModel> onOpenSharedDiaryEntry;

  const _ConversationDetailContent({
    required this.currentUser,
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
        title: const Text('Переписка'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
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
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.md,
                        AppSpacing.xl,
                        AppSpacing.sm,
                      ),
                      child: AppCard(
                        hasShadow: false,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'Переписка в приложении не заменяет консультацию и предназначена для первичной связи.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: messages.isEmpty
                          ? _EmptyMessagesState(
                              onRefresh: onRefresh,
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.xl,
                                AppSpacing.md,
                                AppSpacing.xl,
                                AppSpacing.lg,
                              ),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[index];

                                return _MessageBubble(
                                  message: message,
                                  isMine: message.senderId == currentUser.id,
                                  isOpeningSharedEntry: isOpeningSharedEntry,
                                  onOpenSharedDiaryEntry: () {
                                    onOpenSharedDiaryEntry(message);
                                  },
                                );
                              },
                            ),
                    ),
                    _MessageInput(
                      controller: messageController,
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
}

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
    final hasSharedDiary = message.sharedDiaryEntryId != null;

    final bubbleColor = isMine
        ? theme.colorScheme.primary
        : theme.cardTheme.color ?? theme.colorScheme.surface;

    final textColor =
        isMine ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        constraints: const BoxConstraints(
          maxWidth: 520,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.lg),
            topRight: Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(
              isMine ? AppRadius.lg : AppRadius.sm,
            ),
            bottomRight: Radius.circular(
              isMine ? AppRadius.sm : AppRadius.lg,
            ),
          ),
          border: isMine
              ? null
              : Border.all(
                  color: theme.dividerColor.withOpacity(0.6),
                ),
        ),
        child: hasSharedDiary
            ? _SharedDiaryMessageCard(
                isMine: isMine,
                textColor: textColor,
                isLoading: isOpeningSharedEntry,
                onOpen: onOpenSharedDiaryEntry,
              )
            : Text(
                message.content?.trim().isNotEmpty == true
                    ? message.content!.trim()
                    : 'Сообщение',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                ),
              ),
      ),
    );
  }
}

class _SharedDiaryMessageCard extends StatelessWidget {
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
    final isDark = theme.brightness == Brightness.dark;

    final cardBackground = isMine
        ? AppColors.white.withOpacity(isDark ? 0.13 : 0.12)
        : theme.colorScheme.primary.withOpacity(isDark ? 0.12 : 0.08);

    final cardBorder = isMine
        ? AppColors.white.withOpacity(isDark ? 0.16 : 0.18)
        : theme.colorScheme.primary.withOpacity(isDark ? 0.20 : 0.12);

    return Container(
      width: 260,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: AppRadius.large,
        border: Border.all(
          color: cardBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.description_outlined,
            color: textColor,
            size: 24,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'КПТ-запись',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Дневниковая запись, отправленная в переписку.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SharedDiaryOpenButton(
            isLoading: isLoading,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}

class _SharedDiaryOpenButton extends StatelessWidget {
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
          onTap: isLoading ? null : onPressed,
          borderRadius: AppRadius.large,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Text(
                    'Открыть',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.15,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

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
    final isDark = theme.brightness == Brightness.dark;

    final inputBackground =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final inputBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 48,
                maxHeight: 132,
              ),
              decoration: BoxDecoration(
                color: inputBackground,
                borderRadius: AppRadius.large,
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
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: theme.textTheme.bodyMedium,
                cursorColor: theme.colorScheme.primary,
                decoration: InputDecoration(
                  hintText: 'Напишите сообщение...',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 48,
            height: 48,
            child: FilledButton(
              onPressed: isSending ? null : onSend,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.large,
                ),
              ),
              child: isSending
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
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

class _EmptyMessagesState extends StatelessWidget {
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
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          AppCard(
            hasShadow: false,
            child: Text(
              'Сообщений пока нет. Напишите первое сообщение.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}