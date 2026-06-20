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

  static const Duration _displayDuration = Duration(
    seconds: 5,
  );

  AppNotificationModel? get currentNotification {
    return _currentNotification;
  }

  bool get isStarted => _isStarted;

  int get queuedCount => _queue.length;

  // ============================================================
  // START
  // ============================================================

  Future<void> start() async {
    if (_isStarting || _isStarted) {
      return;
    }

    _isStarting = true;

    try {
      final socketService = NotificationSocketService(
        onNotification: _handleIncomingNotification,
      );

      _socketService = socketService;
      _isStarted = true;

      await socketService.connect();
    } catch (_) {
    } finally {
      _isStarting = false;
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
        _knownNotificationIds.contains(notificationId)) {
      return;
    }

    if (notificationId != null) {
      _knownNotificationIds.add(notificationId);
    }

    if (_currentNotification == null) {
      _showNotification(notification);
      return;
    }

    _queue.addLast(notification);
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
  // DISMISS
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
      const Duration(milliseconds: 180),
      _showNextNotification,
    );
  }

  void _showNextNotification() {
    if (_currentNotification != null ||
        _queue.isEmpty) {
      return;
    }

    final nextNotification = _queue.removeFirst();

    _showNotification(nextNotification);
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
    } catch (_) {
    }
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

    final socketService = _socketService;

    _socketService = null;
    _isStarted = false;
    _isStarting = false;

    if (socketService != null) {
      await socketService.dispose();
    }

    notifyListeners();
  }
}