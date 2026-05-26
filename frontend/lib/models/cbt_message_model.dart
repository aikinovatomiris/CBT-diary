import 'json_helpers.dart';

class CBTMessageModel {
  final int? id;
  final int? sessionId;
  final String? role;
  final String? content;
  final DateTime? createdAt;
  final String? usedTechnique;

  const CBTMessageModel({
    this.id,
    this.sessionId,
    this.role,
    this.content,
    this.createdAt,
    this.usedTechnique,
  });

  factory CBTMessageModel.fromJson(Map<String, dynamic> json) {
    return CBTMessageModel(
      id: JsonHelpers.parseInt(json['id']),
      sessionId: JsonHelpers.parseInt(json['session_id']),
      role: JsonHelpers.parseString(json['role']),
      content: JsonHelpers.parseString(json['content']),
      createdAt: JsonHelpers.parseDateTime(json['created_at']),
      usedTechnique: JsonHelpers.parseString(json['used_technique']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'role': role,
      'content': content,
      'created_at': createdAt?.toIso8601String(),
      'used_technique': usedTechnique,
    };
  }

  bool get isUser {
    return role == 'user';
  }

  bool get isAssistant {
    return role == 'assistant';
  }
}