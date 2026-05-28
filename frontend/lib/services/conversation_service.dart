import '../models/conversation_model.dart';
import '../models/diary_entry_model.dart';
import 'api_client.dart';
import 'api_exception.dart';

class ConversationService {
  ConversationService._();

  static Future<ConversationModel> createConversation(
    int therapistUserId,
  ) async {
    try {
      final response = await ApiClient.post(
        '/conversations',
        data: {
          'therapist_user_id': therapistUserId,
        },
      );

      final data = _safeMap(response.data);
      return ConversationModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось создать переписку со специалистом.',
      );
    }
  }

  static Future<List<ConversationModel>> getConversations() async {
    try {
      final response = await ApiClient.get('/conversations');
      final data = response.data;

      if (data is List) {
        final conversations = data.whereType<Map>().map((item) {
          return ConversationModel.fromJson(
            Map<String, dynamic>.from(item),
          );
        }).toList();

        conversations.sort((a, b) {
          final unreadCompare = b.unreadCount.compareTo(a.unreadCount);
          if (unreadCompare != 0) return unreadCompare;

          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

          return bDate.compareTo(aDate);
        });

        return conversations;
      }

      throw const ApiException(
        message: 'Сервер вернул некорректный список переписок.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить переписки.',
      );
    }
  }

  static Future<List<ConversationMessageModel>> getMessages(
    int conversationId,
  ) async {
    try {
      final response = await ApiClient.get(
        '/conversations/$conversationId/messages',
      );

      final data = response.data;

      if (data is List) {
        return data.whereType<Map>().map((item) {
          return ConversationMessageModel.fromJson(
            Map<String, dynamic>.from(item),
          );
        }).toList();
      }

      throw const ApiException(
        message: 'Сервер вернул некорректный список сообщений.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить сообщения.',
      );
    }
  }

  static Future<ConversationMessageModel> sendMessage(
    int conversationId,
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
        '/conversations/$conversationId/messages',
        data: {
          'content': trimmedContent,
        },
      );

      final data = _safeMap(response.data);
      return ConversationMessageModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось отправить сообщение.',
      );
    }
  }

  static Future<ConversationMessageModel> shareDiaryEntry(
    int conversationId,
    int diaryEntryId,
  ) async {
    try {
      final response = await ApiClient.post(
        '/conversations/$conversationId/share-diary-entry',
        data: {
          'diary_entry_id': diaryEntryId,
        },
      );

      final data = _safeMap(response.data);
      return ConversationMessageModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось поделиться дневниковой записью.',
      );
    }
  }

  static Future<DiaryEntryModel> getSharedDiaryEntry(
    int conversationId,
    int diaryEntryId,
  ) async {
    try {
      final response = await ApiClient.get(
        '/conversations/$conversationId/shared-diary/$diaryEntryId',
      );

      final data = _safeMap(response.data);
      return DiaryEntryModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить общую дневниковую запись.',
      );
    }
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