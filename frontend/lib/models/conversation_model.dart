import 'json_helpers.dart';

class ConversationModel {
  final int? id;
  final int? userId;
  final int? therapistUserId;
  final DateTime? createdAt;

  /// Эти поля backend сейчас может НЕ возвращать.
  /// Они nullable и используются только если появятся в response позже.
  final String? userName;
  final String? therapistName;
  final String? interlocutorName;
  final String? lastMessage;
  final int unreadCount;

  const ConversationModel({
    this.id,
    this.userId,
    this.therapistUserId,
    this.createdAt,
    this.userName,
    this.therapistName,
    this.interlocutorName,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: JsonHelpers.parseInt(json['id']),
      userId: JsonHelpers.parseInt(json['user_id']),
      therapistUserId: JsonHelpers.parseInt(json['therapist_user_id']),
      createdAt: JsonHelpers.parseDateTime(json['created_at']),
      userName: JsonHelpers.parseString(json['user_name']),
      therapistName: JsonHelpers.parseString(json['therapist_name']),
      interlocutorName: JsonHelpers.parseString(json['interlocutor_name']),
      lastMessage: JsonHelpers.parseString(json['last_message']),
      unreadCount: JsonHelpers.parseInt(json['unread_count']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'therapist_user_id': therapistUserId,
      'created_at': createdAt?.toIso8601String(),
      'user_name': userName,
      'therapist_name': therapistName,
      'interlocutor_name': interlocutorName,
      'last_message': lastMessage,
      'unread_count': unreadCount,
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

  factory ConversationMessageModel.fromJson(Map<String, dynamic> json) {
    return ConversationMessageModel(
      id: JsonHelpers.parseInt(json['id']),
      conversationId: JsonHelpers.parseInt(json['conversation_id']),
      senderId: JsonHelpers.parseInt(json['sender_id']),
      content: JsonHelpers.parseString(json['content']),
      sharedDiaryEntryId: JsonHelpers.parseInt(
        json['shared_diary_entry_id'],
      ),
      createdAt: JsonHelpers.parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'shared_diary_entry_id': sharedDiaryEntryId,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}