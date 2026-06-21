import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/app_notification_model.dart';
import '../../services/api_exception.dart';
import '../../services/notification_service.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
  });

  @override
  State<NotificationsScreen> createState() {
    return _NotificationsScreenState();
  }
}

class _NotificationsScreenState
    extends State<NotificationsScreen> {
  late Future<List<AppNotificationModel>> _future;

  List<AppNotificationModel> _notifications = [];

  bool _isDeletingAll = false;

  @override
  void initState() {
    super.initState();

    _future = _loadNotifications();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<List<AppNotificationModel>>
      _loadNotifications() async {
    final notifications =
        await NotificationService.getNotifications();

    _notifications = notifications;

    return notifications;
  }

  Future<void> _refresh() async {
    final future = _loadNotifications();

    setState(() {
      _future = future;
    });

    await future;
  }

  // ============================================================
  // OPEN NOTIFICATION
  // ============================================================

  Future<void> _openNotification(
    AppNotificationModel notification,
  ) async {
    final conversationId =
        notification.conversationId;

    if (conversationId == null) {
      _showSnackBar(
        'Не удалось открыть переписку.',
      );

      return;
    }

    final notificationId = notification.id;

    if (notificationId != null &&
        !notification.isRead) {
      try {
        await NotificationService.markAsRead(
          notificationId,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _notifications =
              _notifications.map(
            (item) {
              if (item.id == notificationId) {
                return item.copyWith(
                  isRead: true,
                );
              }

              return item;
            },
          ).toList();
        });
      } catch (_) {
        
      }
    }

    if (!mounted) {
      return;
    }

    await context.push(
      '/conversations/$conversationId',
    );

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // ============================================================
  // DELETE ONE
  // ============================================================

  Future<bool> _deleteNotification(
    AppNotificationModel notification,
  ) async {
    final notificationId = notification.id;

    if (notificationId == null) {
      _showSnackBar(
        'Не удалось определить уведомление.',
      );

      return false;
    }

    try {
      await NotificationService.deleteNotification(
        notificationId,
      );

      return true;
    } on ApiException catch (error) {
      if (mounted) {
        _showSnackBar(
          error.message,
        );
      }

      return false;
    } catch (_) {
      if (mounted) {
        _showSnackBar(
          'Не удалось удалить уведомление.',
        );
      }

      return false;
    }
  }

  void _removeNotificationLocally(
    AppNotificationModel notification,
  ) {
    setState(() {
      _notifications = _notifications
          .where(
            (item) => item.id != notification.id,
          )
          .toList();
    });
  }

  // ============================================================
  // DELETE ALL
  // ============================================================

  Future<void> _confirmDeleteAll() async {
    if (_notifications.isEmpty ||
        _isDeletingAll) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Удалить все уведомления?',
          ),
          content: const Text(
            'Все уведомления будут удалены без возможности восстановления.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Отмена',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Удалить',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeletingAll = true;
    });

    try {
      await NotificationService
          .deleteAllNotifications();

      if (!mounted) {
        return;
      }

      setState(() {
        _notifications = [];
      });

      _showSnackBar(
        'Все уведомления удалены.',
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
        'Не удалось удалить уведомления.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAll = false;
        });
      }
    }
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
    return FutureBuilder<List<AppNotificationModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            _notifications.isEmpty) {
          return const Scaffold(
            body: AppLoading(
              text: 'Загрузка уведомлений...',
            ),
          );
        }

        if (snapshot.hasError &&
            _notifications.isEmpty) {
          final error = snapshot.error;

          final message = error is ApiException
              ? error.message
              : 'Не удалось загрузить уведомления.';

          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Уведомления',
              ),
            ),
            body: AppErrorView(
              message: message,
              onRetry: _refresh,
            ),
          );
        }

        return _NotificationsContent(
          notifications: _notifications,
          isDeletingAll: _isDeletingAll,
          onRefresh: _refresh,
          onDeleteAll: _confirmDeleteAll,
          onOpenNotification:
              _openNotification,
          onDeleteNotification:
              _deleteNotification,
          onRemoveNotificationLocally:
              _removeNotificationLocally,
        );
      },
    );
  }
}

// ============================================================
// CONTENT
// ============================================================

class _NotificationsContent
    extends StatelessWidget {
  final List<AppNotificationModel>
      notifications;

  final bool isDeletingAll;

  final Future<void> Function() onRefresh;

  final VoidCallback onDeleteAll;

  final ValueChanged<AppNotificationModel>
      onOpenNotification;

  final Future<bool> Function(
    AppNotificationModel notification,
  )
  onDeleteNotification;

  final ValueChanged<AppNotificationModel>
      onRemoveNotificationLocally;

  const _NotificationsContent({
    required this.notifications,
    required this.isDeletingAll,
    required this.onRefresh,
    required this.onDeleteAll,
    required this.onOpenNotification,
    required this.onDeleteNotification,
    required this.onRemoveNotificationLocally,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Уведомления',
        ),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed:
                  isDeletingAll ? null : onDeleteAll,
              child: isDeletingAll
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Удалить все',
                      style: theme
                          .textTheme.bodyMedium
                          ?.copyWith(
                        color: theme
                            .colorScheme.error,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
            ),
          const SizedBox(
            width: AppSpacing.sm,
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
                child: notifications.isEmpty
                    ? _EmptyNotificationsState(
                        onRefresh: onRefresh,
                      )
                    : RefreshIndicator(
                        onRefresh: onRefresh,
                        child: ListView.builder(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          padding:
                              const EdgeInsets.fromLTRB(
                            AppSpacing.xl,
                            AppSpacing.lg,
                            AppSpacing.xl,
                            110,
                          ),
                          itemCount:
                              notifications.length,
                          itemBuilder:
                              (context, index) {
                            final notification =
                                notifications[index];

                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom:
                                    AppSpacing.md,
                              ),
                              child: Dismissible(
                                key: ValueKey<String>(
                                  'notification-${notification.id}',
                                ),
                                direction:
                                    DismissDirection
                                        .endToStart,
                                confirmDismiss:
                                    (_) async {
                                  return onDeleteNotification(
                                    notification,
                                  );
                                },
                                onDismissed: (_) {
                                  onRemoveNotificationLocally(
                                    notification,
                                  );
                                },
                                background:
                                    _DeleteBackground(
                                  notification:
                                      notification,
                                ),
                                child:
                                    _NotificationCard(
                                  notification:
                                      notification,
                                  onTap: () {
                                    onOpenNotification(
                                      notification,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
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

// ============================================================
// NOTIFICATION CARD
// ============================================================

class _NotificationCard
    extends StatelessWidget {
  final AppNotificationModel notification;

  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final isUnread = !notification.isRead;

    return AppCard(
      hasShadow: false,
      onTap: onTap,
      padding: const EdgeInsets.all(
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary
                      .withValues(
                    alpha: isDark ? 0.18 : 0.10,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme
                        .colorScheme.primary
                        .withValues(
                      alpha:
                          isDark ? 0.24 : 0.14,
                    ),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons
                      .chat_bubble_outline_rounded,
                  color:
                      theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              if (isUnread)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme
                                .cardTheme.color ??
                            theme
                                .scaffoldBackgroundColor,
                        width: 2,
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
                Text(
                  notification.displaySenderName,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme.bodyMedium
                      ?.copyWith(
                    fontWeight: isUnread
                        ? FontWeight.w800
                        : FontWeight.w700,
                  ),
                ),
                const SizedBox(
                  height: AppSpacing.xs,
                ),
                Text(
                  notification.displayTitle,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme.bodySmall
                      ?.copyWith(
                    color: isUnread
                        ? theme.colorScheme
                            .onSurface
                        : theme.colorScheme
                            .onSurfaceVariant,
                    fontWeight: isUnread
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                const SizedBox(
                  height: AppSpacing.xs,
                ),
                Text(
                  _formatDateTime(
                    notification.createdAt,
                  ),
                  style: theme
                      .textTheme.bodySmall
                      ?.copyWith(
                    color: theme.colorScheme
                        .onSurfaceVariant,
                    fontSize: 11,
                  ),
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

  String _formatDateTime(
    DateTime? value,
  ) {
    if (value == null) {
      return '';
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

    final hour =
        date.hour.toString().padLeft(2, '0');

    final minute =
        date.minute.toString().padLeft(2, '0');

    if (difference == 0) {
      return 'Сегодня, $hour:$minute';
    }

    if (difference == 1) {
      return 'Вчера, $hour:$minute';
    }

    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    if (date.year == now.year) {
      return '$day.$month, $hour:$minute';
    }

    return '$day.$month.${date.year}, '
        '$hour:$minute';
  }
}

// ============================================================
// DELETE BACKGROUND
// ============================================================

class _DeleteBackground
    extends StatelessWidget {
  final AppNotificationModel notification;

  const _DeleteBackground({
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.error,
        borderRadius: AppRadius.extraLarge,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
      ),
      alignment: Alignment.centerRight,
      child: Icon(
        Icons.delete_outline_rounded,
        color: theme.colorScheme.onError,
        size: 25,
      ),
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class _EmptyNotificationsState
    extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyNotificationsState({
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xxl,
          AppSpacing.xl,
          110,
        ),
        children: [
          AppCard(
            hasShadow: false,
            padding: const EdgeInsets.all(
              AppSpacing.xl,
            ),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: theme
                        .colorScheme.primary
                        .withValues(
                      alpha: 0.10,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons
                        .notifications_none_rounded,
                    color:
                        theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(
                  height: AppSpacing.lg,
                ),
                Text(
                  'Уведомлений пока нет',
                  textAlign: TextAlign.center,
                  style: theme
                      .textTheme.titleMedium
                      ?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(
                  height: AppSpacing.sm,
                ),
                Text(
                  'Здесь появятся уведомления о новых сообщениях.',
                  textAlign: TextAlign.center,
                  style: theme
                      .textTheme.bodyMedium
                      ?.copyWith(
                    color: theme.colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}