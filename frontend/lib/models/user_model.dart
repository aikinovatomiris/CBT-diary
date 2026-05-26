import 'json_helpers.dart';

class UserModel {
  final int? id;
  final String? email;
  final String? name;
  final DateTime? createdAt;

  /// backend field: assistant_style
  final String? assistantStyle;

  /// backend field: role
  ///
  /// Возможные значения:
  /// - user
  /// - therapist
  /// - admin
  ///
  /// Если backend не вернул role, считаем user.
  final String role;

  const UserModel({
    this.id,
    this.email,
    this.name,
    this.createdAt,
    this.assistantStyle,
    this.role = 'user',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: JsonHelpers.parseInt(json['id']),
      email: JsonHelpers.parseString(json['email']),
      name: JsonHelpers.parseString(json['name']),
      createdAt: JsonHelpers.parseDateTime(json['created_at']),
      assistantStyle: JsonHelpers.parseString(json['assistant_style']),
      role: _parseRole(json['role']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'created_at': createdAt?.toIso8601String(),
      'assistant_style': assistantStyle,
      'role': role,
    };
  }

  static String _parseRole(dynamic value) {
    final role = JsonHelpers.parseString(value)?.trim().toLowerCase();

    if (role == 'therapist') return 'therapist';
    if (role == 'admin') return 'admin';

    return 'user';
  }
}