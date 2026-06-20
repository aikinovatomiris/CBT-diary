import '../models/app_notification_model.dart';
import 'api_client.dart';
import 'api_exception.dart';

class NotificationService {
  NotificationService._();

  // ============================================================
  // GET /notifications
  // ============================================================

  static Future<List<AppNotificationModel>>
      getNotifications() async {
    try {
      final response = await ApiClient.get(
        '/notifications',
      );

      final data = response.data;

      if (data is! List) {
        throw const ApiException(
          message:
              'Сервер вернул некорректный список уведомлений.',
        );
      }

      final notifications =
          AppNotificationModel.listFromJson(
        data,
      );

      notifications.sort(
        _compareNotifications,
      );

      return notifications;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message:
            'Не удалось загрузить уведомления.',
      );
    }
  }

  // ============================================================
  // PATCH /notifications/{notification_id}/read
  // ============================================================

  static Future<bool> markAsRead(
    int notificationId,
  ) async {
    try {
      final response = await ApiClient.patch(
        '/notifications/$notificationId/read',
      );

      final data = _safeMap(
        response.data,
      );

      return _parseBool(
            data['is_read'],
          ) ??
          true;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message:
            'Не удалось отметить уведомление прочитанным.',
      );
    }
  }

  // ============================================================
  // DELETE /notifications/{notification_id}
  // ============================================================

  static Future<int> deleteNotification(
    int notificationId,
  ) async {
    try {
      final response = await ApiClient.delete(
        '/notifications/$notificationId',
      );

      final data = _safeMap(
        response.data,
      );

      return _parseInt(
            data['deleted_notification_id'],
          ) ??
          notificationId;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message:
            'Не удалось удалить уведомление.',
      );
    }
  }

  // ============================================================
  // DELETE /notifications
  // ============================================================

  static Future<int> deleteAllNotifications() async {
    try {
      final response = await ApiClient.delete(
        '/notifications',
      );

      final data = _safeMap(
        response.data,
      );

      return _parseInt(
            data['deleted_count'],
          ) ??
          0;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message:
            'Не удалось удалить все уведомления.',
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static int _compareNotifications(
    AppNotificationModel first,
    AppNotificationModel second,
  ) {
    final firstDate = first.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final secondDate = second.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final dateCompare = secondDate.compareTo(
      firstDate,
    );

    if (dateCompare != 0) {
      return dateCompare;
    }

    return (second.id ?? 0).compareTo(
      first.id ?? 0,
    );
  }

  static Map<String, dynamic> _safeMap(
    dynamic data,
  ) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(
        data,
      );
    }

    throw const ApiException(
      message:
          'Сервер вернул некорректный ответ.',
    );
  }

  static int? _parseInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    );
  }

  static bool? _parseBool(
    dynamic value,
  ) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized =
          value.trim().toLowerCase();

      if (normalized == 'true' ||
          normalized == '1') {
        return true;
      }

      if (normalized == 'false' ||
          normalized == '0') {
        return false;
      }
    }

    return null;
  }
}