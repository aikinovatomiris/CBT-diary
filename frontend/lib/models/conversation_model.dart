import 'json_helpers.dart';

class ConversationModel {
  final int? id;
  final int? userId;
  final int? therapistUserId;

  final DateTime? createdAt;
  final DateTime? lastMessageAt;
  final DateTime? userLastReadAt;
  final DateTime? therapistLastReadAt;

  final String? userName;
  final String? therapistName;
  final String? interlocutorName;

  final String? lastMessageText;
  final int? lastMessageSenderId;

  final int unreadCount;
  final bool hasUnread;

  const ConversationModel({
    this.id,
    this.userId,
    this.therapistUserId,
    this.createdAt,
    this.lastMessageAt,
    this.userLastReadAt,
    this.therapistLastReadAt,
    this.userName,
    this.therapistName,
    this.interlocutorName,
    this.lastMessageText,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    this.hasUnread = false,
  });

  factory ConversationModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final unreadCount =
        JsonHelpers.parseInt(
          json['unread_count'],
        ) ??
        0;

    return ConversationModel(
      id: JsonHelpers.parseInt(
        json['id'],
      ),
      userId: JsonHelpers.parseInt(
        json['user_id'],
      ),
      therapistUserId:
          JsonHelpers.parseInt(
        json['therapist_user_id'],
      ),
      createdAt:
          JsonHelpers.parseDateTime(
        json['created_at'],
      ),
      lastMessageAt:
          JsonHelpers.parseDateTime(
        json['last_message_at'],
      ),
      userLastReadAt:
          JsonHelpers.parseDateTime(
        json['user_last_read_at'],
      ),
      therapistLastReadAt:
          JsonHelpers.parseDateTime(
        json['therapist_last_read_at'],
      ),
      userName:
          JsonHelpers.parseString(
        json['user_name'],
      ),
      therapistName:
          JsonHelpers.parseString(
        json['therapist_name'],
      ),
      interlocutorName:
          JsonHelpers.parseString(
        json['interlocutor_name'],
      ),
      lastMessageText:
          JsonHelpers.parseString(
            json['last_message_text'],
          ) ??
          JsonHelpers.parseString(
            json['last_message'],
          ),
      lastMessageSenderId:
          JsonHelpers.parseInt(
        json['last_message_sender_id'],
      ),
      unreadCount: unreadCount,
      hasUnread:
          JsonHelpers.parseBool(
            json['has_unread'],
          ) ??
          unreadCount > 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'therapist_user_id':
          therapistUserId,
      'created_at':
          createdAt?.toIso8601String(),
      'last_message_at':
          lastMessageAt?.toIso8601String(),
      'user_last_read_at':
          userLastReadAt
              ?.toIso8601String(),
      'therapist_last_read_at':
          therapistLastReadAt
              ?.toIso8601String(),
      'user_name': userName,
      'therapist_name':
          therapistName,
      'interlocutor_name':
          interlocutorName,
      'last_message_text':
          lastMessageText,
      'last_message_sender_id':
          lastMessageSenderId,
      'unread_count': unreadCount,
      'has_unread': hasUnread,
    };
  }
}

class ConversationMessageModel {
  final int? id;
  final int? conversationId;
  final int? senderId;
  final String? content;
  final int? sharedDiaryEntryId;
  final DateTime? createdAt;

  const ConversationMessageModel({
    this.id,
    this.conversationId,
    this.senderId,
    this.content,
    this.sharedDiaryEntryId,
    this.createdAt,
  });

  factory ConversationMessageModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ConversationMessageModel(
      id: JsonHelpers.parseInt(
        json['id'],
      ),
      conversationId:
          JsonHelpers.parseInt(
        json['conversation_id'],
      ),
      senderId:
          JsonHelpers.parseInt(
        json['sender_id'],
      ),
      content:
          JsonHelpers.parseString(
        json['content'],
      ),
      sharedDiaryEntryId:
          JsonHelpers.parseInt(
        json['shared_diary_entry_id'],
      ),
      createdAt: _parseCreatedAt(
        json,
      ),
    );
  }

  static DateTime? _parseCreatedAt(
    Map<String, dynamic> json,
  ) {
    final epochMilliseconds =
        JsonHelpers.parseInt(
      json['created_at_epoch_ms'],
    );

    if (epochMilliseconds != null) {
      return DateTime
          .fromMillisecondsSinceEpoch(
        epochMilliseconds,
        isUtc: true,
      ).toLocal();
    }

    // Совместимость со старыми backend-ответами.
    return JsonHelpers.parseDateTime(
      json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id':
          conversationId,
      'sender_id': senderId,
      'content': content,
      'shared_diary_entry_id':
          sharedDiaryEntryId,
      'created_at':
          createdAt?.toIso8601String(),
      'created_at_epoch_ms':
          createdAt
              ?.toUtc()
              .millisecondsSinceEpoch,
    };
  }
}