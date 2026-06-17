import '../models/conversation_model.dart';
import '../models/diary_entry_model.dart';
import 'api_client.dart';
import 'api_exception.dart';

class ConversationService {
  ConversationService._();

  // ============================================================
  // POST /conversations
  // ============================================================

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
        message:
            'Не удалось создать переписку со специалистом.',
      );
    }
  }

  // ============================================================
  // GET /conversations
  // ============================================================

  static Future<List<ConversationModel>> getConversations() async {
    try {
      final response = await ApiClient.get(
        '/conversations',
      );

      final data = response.data;

      if (data is! List) {
        throw const ApiException(
          message:
              'Сервер вернул некорректный список переписок.',
        );
      }

      final conversations = data
          .whereType<Map>()
          .map(
            (item) => ConversationModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      // Backend уже сортирует чаты по last_message_at.
      // Локальная сортировка оставлена как страховка.
      conversations.sort((a, b) {
        final aDate = a.lastMessageAt ??
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final bDate = b.lastMessageAt ??
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final dateCompare = bDate.compareTo(aDate);

        if (dateCompare != 0) {
          return dateCompare;
        }

        return (b.id ?? 0).compareTo(a.id ?? 0);
      });

      return conversations;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить переписки.',
      );
    }
  }

  // ============================================================
  // GET /conversations/{conversation_id}/messages
  // ============================================================

  static Future<List<ConversationMessageModel>> getMessages(
    int conversationId,
  ) async {
    try {
      final response = await ApiClient.get(
        '/conversations/$conversationId/messages',
      );

      final data = response.data;

      if (data is! List) {
        throw const ApiException(
          message:
              'Сервер вернул некорректный список сообщений.',
        );
      }

      final messages = data
          .whereType<Map>()
          .map(
            (item) => ConversationMessageModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      messages.sort((a, b) {
        final aDate = a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final bDate = b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final dateCompare = aDate.compareTo(bDate);

        if (dateCompare != 0) {
          return dateCompare;
        }

        return (a.id ?? 0).compareTo(b.id ?? 0);
      });

      return messages;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить сообщения.',
      );
    }
  }

  // ============================================================
  // POST /conversations/{conversation_id}/messages
  // ============================================================

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

  // ============================================================
  // PATCH /conversations/{conversation_id}/read
  // ============================================================

  static Future<void> markConversationAsRead(
    int conversationId,
  ) async {
    try {
      await ApiClient.patch(
        '/conversations/$conversationId/read',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message:
            'Не удалось отметить сообщения прочитанными.',
      );
    }
  }

  // ============================================================
  // POST /conversations/{conversation_id}/share-diary-entry
  // ============================================================

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
        message:
            'Не удалось поделиться дневниковой записью.',
      );
    }
  }

  // ============================================================
  // GET /conversations/{conversation_id}/shared-diary/{entry_id}
  // ============================================================

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
        message:
            'Не удалось загрузить общую дневниковую запись.',
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

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