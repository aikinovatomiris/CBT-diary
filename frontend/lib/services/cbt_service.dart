import '../models/cbt_message_model.dart';
import '../models/cbt_session_model.dart';
import 'api_client.dart';
import 'api_exception.dart';

class CbtService {
  CbtService._();

  static Future<CBTSessionModel> createSession() async {
    try {
      final response = await ApiClient.post(
        '/cbt/sessions',
        data: {},
      );

      final data = _safeMap(response.data);
      return CBTSessionModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось создать КПТ-сессию.',
      );
    }
  }

  static Future<List<CBTSessionModel>> getSessions() async {
    try {
      final response = await ApiClient.get('/cbt/sessions');
      final data = response.data;

      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) {
              return CBTSessionModel.fromJson(
                Map<String, dynamic>.from(item),
              );
            })
            .toList();
      }

      throw const ApiException(
        message: 'Сервер вернул некорректный список КПТ-сессий.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить КПТ-сессии.',
      );
    }
  }

  static Future<CBTSessionModel> getSession(int id) async {
    try {
      final response = await ApiClient.get('/cbt/sessions/$id');

      final data = _safeMap(response.data);
      return CBTSessionModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить КПТ-сессию.',
      );
    }
  }

  static Future<List<CBTMessageModel>> getMessages(int sessionId) async {
    try {
      final response = await ApiClient.get(
        '/cbt/sessions/$sessionId/messages',
      );

      final data = response.data;

      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) {
              return CBTMessageModel.fromJson(
                Map<String, dynamic>.from(item),
              );
            })
            .toList();
      }

      throw const ApiException(
        message: 'Сервер вернул некорректную историю сообщений.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить сообщения КПТ-сессии.',
      );
    }
  }

  /// POST /cbt/sessions/{session_id}/message
  ///
  /// Backend возвращает:
  /// {
  ///   "user_message": {...},
  ///   "assistant_message": {...},
  ///   "current_step": "...",
  ///   "current_phase": "...",
  ///   "session_status": "..."
  /// }
  ///
  /// Оставляем Map, чтобы не терять нестандартные поля backend.
  static Future<Map<String, dynamic>> sendMessage(
    int sessionId,
    String content,
  ) async {
    try {
      final trimmedContent = content.trim();

      if (trimmedContent.isEmpty) {
        throw const ApiException(
          message: 'Сообщение не может быть пустым.',
        );
      }

      final response = await ApiClient.post(
        '/cbt/sessions/$sessionId/message',
        data: {
          'content': trimmedContent,
        },
      );

      return _safeMap(response.data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось отправить сообщение.',
      );
    }
  }

  /// POST /cbt/sessions/{session_id}/finish
  ///
  /// Backend может вернуть DiaryEntryResponse.
  /// Возвращаем Map, чтобы UI сам достал id записи.
  static Future<Map<String, dynamic>> finishSession(int sessionId) async {
    try {
      final response = await ApiClient.post(
        '/cbt/sessions/$sessionId/finish',
      );

      return _safeMap(response.data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось завершить КПТ-сессию.',
      );
    }
  }

  static CBTMessageModel? parseMessageFromMap(dynamic value) {
    if (value == null) return null;

    if (value is Map<String, dynamic>) {
      return CBTMessageModel.fromJson(value);
    }

    if (value is Map) {
      return CBTMessageModel.fromJson(
        Map<String, dynamic>.from(value),
      );
    }

    return null;
  }

  static int? extractDiaryEntryId(Map<String, dynamic> response) {
    final directId = response['id'];

    if (directId is int) return directId;
    if (directId is String) return int.tryParse(directId);

    final diaryEntry = response['diary_entry'];
    if (diaryEntry is Map) {
      final id = diaryEntry['id'];
      if (id is int) return id;
      if (id is String) return int.tryParse(id);
    }

    final entry = response['entry'];
    if (entry is Map) {
      final id = entry['id'];
      if (id is int) return id;
      if (id is String) return int.tryParse(id);
    }

    return null;
  }

  static Map<String, dynamic> _safeMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw const ApiException(
      message: 'Сервер вернул некорректный ответ.',
    );
  }
}