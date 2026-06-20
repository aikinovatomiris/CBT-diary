import 'json_helpers.dart';

class AppNotificationModel {
  final int? id;
  final int? userId;
  final int? conversationId;
  final int? senderId;

  final String? senderName;
  final String? title;

  final bool isRead;
  final DateTime? createdAt;

  const AppNotificationModel({
    this.id,
    this.userId,
    this.conversationId,
    this.senderId,
    this.senderName,
    this.title,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotificationModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AppNotificationModel(
      id: JsonHelpers.parseInt(
        json['id'],
      ),
      userId: JsonHelpers.parseInt(
        json['user_id'],
      ),
      conversationId: JsonHelpers.parseInt(
        json['conversation_id'],
      ),
      senderId: JsonHelpers.parseInt(
        json['sender_id'],
      ),
      senderName: JsonHelpers.parseString(
        json['sender_name'],
      ),
      title: JsonHelpers.parseString(
        json['title'],
      ),
      isRead: JsonHelpers.parseBool(
            json['is_read'],
          ) ??
          false,
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
      return DateTime.fromMillisecondsSinceEpoch(
        epochMilliseconds,
        isUtc: true,
      ).toLocal();
    }

    return JsonHelpers.parseDateTime(
      json['created_at'],
    );
  }

  AppNotificationModel copyWith({
    int? id,
    int? userId,
    int? conversationId,
    int? senderId,
    String? senderName,
    String? title,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      conversationId:
          conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      title: title ?? this.title,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_name': senderName,
      'title': title,
      'is_read': isRead,
      'created_at': createdAt?.toIso8601String(),
      'created_at_epoch_ms':
          createdAt?.toUtc().millisecondsSinceEpoch,
    };
  }

  String get displaySenderName {
    final value = senderName?.trim();

    if (value == null || value.isEmpty) {
      return 'Пользователь';
    }

    return value;
  }

  String get displayTitle {
    final value = title?.trim();

    if (value == null || value.isEmpty) {
      return 'Новое сообщение';
    }

    return value;
  }

  bool get canOpenConversation {
    return conversationId != null;
  }

  static List<AppNotificationModel> listFromJson(
    dynamic value,
  ) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => AppNotificationModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }
}