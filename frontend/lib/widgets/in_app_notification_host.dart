import 'package:flutter/material.dart';

import '../models/app_notification_model.dart';
import '../navigation/app_router.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../services/notification_controller.dart';

class InAppNotificationHost extends StatefulWidget {
  final Widget child;

  const InAppNotificationHost({
    super.key,
    required this.child,
  });

  @override
  State<InAppNotificationHost> createState() {
    return _InAppNotificationHostState();
  }
}

class _InAppNotificationHostState
    extends State<InAppNotificationHost> {
  final NotificationController _controller =
      NotificationController.instance;

  @override
  void initState() {
    super.initState();

    _controller.addListener(
      _handleControllerChanged,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(
      _handleControllerChanged,
    );

    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }

    final notification =
        _controller.currentNotification;

    if (notification != null &&
        _isConversationAlreadyOpen(notification)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          if (mounted &&
              _controller.currentNotification?.id ==
                  notification.id) {
            _controller.dismissCurrent();
          }
        },
      );
    }

    setState(() {});
  }

  bool _isConversationAlreadyOpen(
    AppNotificationModel notification,
  ) {
    final conversationId =
        notification.conversationId;

    if (conversationId == null) {
      return false;
    }

    final currentPath = appRouter
        .routeInformationProvider
        .value
        .uri
        .path;

    return currentPath ==
        '/conversations/$conversationId';
  }

  Future<void> _openNotification(
    AppNotificationModel notification,
  ) async {
    final conversationId =
        notification.conversationId;

    if (conversationId == null) {
      _controller.dismissCurrent();
      return;
    }

    _controller.dismissCurrent();

    await _controller.markAsReadSilently(
      notification,
    );

    final targetPath =
        '/conversations/$conversationId';

    final currentPath = appRouter
        .routeInformationProvider
        .value
        .uri
        .path;

    if (currentPath == targetPath) {
      return;
    }

    appRouter.push(
      targetPath,
    );
  }

  @override
  Widget build(BuildContext context) {
    final notification =
        _controller.currentNotification;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            minimum: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(
                milliseconds: 220,
              ),
              reverseDuration: const Duration(
                milliseconds: 170,
              ),
              transitionBuilder: (
                child,
                animation,
              ) {
                final slideAnimation =
                    Tween<Offset>(
                  begin: const Offset(0, -0.35),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  ),
                );

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: slideAnimation,
                    child: child,
                  ),
                );
              },
              child: notification == null
                  ? const SizedBox.shrink()
                  : _NotificationBanner(
                      key: ValueKey<int?>(
                        notification.id,
                      ),
                      notification: notification,
                      onTap: () {
                        _openNotification(
                          notification,
                        );
                      },
                      onDismiss: () {
                        _controller.dismissCurrent();
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  final AppNotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : theme.colorScheme.surface;

    final borderColor = theme.dividerColor.withValues(
      alpha: isDark ? 0.75 : 0.55,
    );

    return Dismissible(
      key: ValueKey<String>(
        'notification-${notification.id}',
      ),
      direction: DismissDirection.up,
      onDismissed: (_) {
        onDismiss();
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.extraLarge,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: 72,
              maxWidth: 560,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: AppRadius.extraLarge,
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.28 : 0.12,
                  ),
                  blurRadius: 26,
                  offset: const Offset(
                    0,
                    10,
                  ),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary
                        .withValues(
                      alpha: isDark ? 0.18 : 0.10,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 21,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(
                  width: AppSpacing.md,
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.displaySenderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        notification.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color: theme.colorScheme
                              .onSurfaceVariant,
                          fontWeight: FontWeight.w500,
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
                  size: 22,
                  color: theme.colorScheme
                      .onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}