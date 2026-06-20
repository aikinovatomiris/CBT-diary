import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/app_notification_model.dart';
import 'notification_service.dart';
import 'notification_socket_service.dart';

class NotificationController extends ChangeNotifier {
  NotificationController._();

  static final NotificationController instance =
      NotificationController._();

  final Queue<AppNotificationModel> _queue =
      Queue<AppNotificationModel>();

  final Set<int> _knownNotificationIds = <int>{};

  NotificationSocketService? _socketService;

  AppNotificationModel? _currentNotification;

  Timer? _hideTimer;

  bool _isStarting = false;
  bool _isStarted = false;
  bool _isRefreshingUnreadCount = false;

  int _unreadCount = 0;

  static const Duration _displayDuration = Duration(
    seconds: 5,
  );

  AppNotificationModel? get currentNotification {
    return _currentNotification;
  }

  bool get isStarted => _isStarted;

  int get queuedCount => _queue.length;

  int get unreadCount => _unreadCount;

  bool get hasUnread => _unreadCount > 0;

  // ============================================================
  // START
  // ============================================================

  Future<void> start() async {
    if (_isStarting || _isStarted) {
      return;
    }

    _isStarting = true;

    try {
      final socketService =
          NotificationSocketService(
        onNotification:
            _handleIncomingNotification,
      );

      _socketService = socketService;
      _isStarted = true;

      await refreshUnreadCount();

      await socketService.connect();
    } catch (_) {
      /*
       * Ошибка уведомлений не должна мешать работе
       * остальных функций приложения.
       *
       * NotificationSocketService самостоятельно
       * выполняет повторные подключения.
       */
    } finally {
      _isStarting = false;
    }
  }

  // ============================================================
  // REFRESH UNREAD COUNT
  // ============================================================

  Future<void> refreshUnreadCount() async {
    if (_isRefreshingUnreadCount) {
      return;
    }

    _isRefreshingUnreadCount = true;

    try {
      final notifications =
          await NotificationService.getNotifications();

      final newUnreadCount = notifications
          .where(
            (notification) =>
                !notification.isRead,
          )
          .length;

      for (final notification in notifications) {
        final notificationId = notification.id;

        if (notificationId != null) {
          _knownNotificationIds.add(
            notificationId,
          );
        }
      }

      if (_unreadCount != newUnreadCount) {
        _unreadCount = newUnreadCount;

        notifyListeners();
      }
    } catch (_) {
      /*
       * Если список временно недоступен, оставляем
       * последнее известное значение.
       */
    } finally {
      _isRefreshingUnreadCount = false;
    }
  }

  // ============================================================
  // INCOMING NOTIFICATION
  // ============================================================

  void _handleIncomingNotification(
    AppNotificationModel notification,
  ) {
    final notificationId = notification.id;

    if (notificationId != null &&
        _knownNotificationIds.contains(
          notificationId,
        )) {
      return;
    }

    if (notificationId != null) {
      _knownNotificationIds.add(
        notificationId,
      );
    }

    if (!notification.isRead) {
      _unreadCount += 1;
    }

    if (_currentNotification == null) {
      _showNotification(
        notification,
      );

      return;
    }

    _queue.addLast(
      notification,
    );

    notifyListeners();
  }

  void _showNotification(
    AppNotificationModel notification,
  ) {
    _hideTimer?.cancel();

    _currentNotification = notification;

    notifyListeners();

    _hideTimer = Timer(
      _displayDuration,
      dismissCurrent,
    );
  }

  // ============================================================
  // DISMISS BANNER
  // ============================================================

  void dismissCurrent() {
    _hideTimer?.cancel();
    _hideTimer = null;

    if (_currentNotification == null) {
      return;
    }

    _currentNotification = null;

    notifyListeners();

    Future<void>.delayed(
      const Duration(
        milliseconds: 180,
      ),
      _showNextNotification,
    );
  }

  void _showNextNotification() {
    if (_currentNotification != null ||
        _queue.isEmpty) {
      return;
    }

    final nextNotification =
        _queue.removeFirst();

    _showNotification(
      nextNotification,
    );
  }

  // ============================================================
  // MARK AS READ
  // ============================================================

  Future<void> markAsReadSilently(
    AppNotificationModel notification,
  ) async {
    final notificationId = notification.id;

    if (notificationId == null ||
        notification.isRead) {
      return;
    }

    try {
      await NotificationService.markAsRead(
        notificationId,
      );

      if (_unreadCount > 0) {
        _unreadCount -= 1;
      }

      notifyListeners();
    } catch (_) {
      /*
       * Ошибка отметки прочтения не должна блокировать
       * переход пользователя к переписке.
       */
    }
  }

  // ============================================================
  // RESET COUNT
  // ============================================================

  void clearUnreadCountLocally() {
    if (_unreadCount == 0) {
      return;
    }

    _unreadCount = 0;

    notifyListeners();
  }

  // ============================================================
  // STOP
  // ============================================================

  Future<void> stop() async {
    _hideTimer?.cancel();
    _hideTimer = null;

    _queue.clear();
    _knownNotificationIds.clear();

    _currentNotification = null;
    _unreadCount = 0;

    final socketService = _socketService;

    _socketService = null;
    _isStarted = false;
    _isStarting = false;
    _isRefreshingUnreadCount = false;

    if (socketService != null) {
      await socketService.dispose();
    }

    notifyListeners();
  }
}