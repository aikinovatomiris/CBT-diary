import 'json_helpers.dart';

class UserModel {
  final int? id;
  final String? email;
  final String? name;
  final DateTime? createdAt;
  final String? assistantStyle;
  final String role;
  final String authProvider;

  const UserModel({
    this.id,
    this.email,
    this.name,
    this.createdAt,
    this.assistantStyle,
    this.role = 'user',
    this.authProvider = 'local',
  });

  bool get isGoogleAccount => authProvider == 'google';

  bool get canChangePassword => authProvider == 'local';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: JsonHelpers.parseInt(json['id']),
      email: JsonHelpers.parseString(json['email']),
      name: JsonHelpers.parseString(json['name']),
      createdAt: JsonHelpers.parseDateTime(json['created_at']),
      assistantStyle: JsonHelpers.parseString(json['assistant_style']),
      role: _parseRole(json['role']),
      authProvider: _parseAuthProvider(json['auth_provider']),
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
      'auth_provider': authProvider,
    };
  }

  static String _parseRole(dynamic value) {
    final role = JsonHelpers.parseString(value)?.trim().toLowerCase();

    if (role == 'therapist') return 'therapist';
    if (role == 'admin') return 'admin';

    return 'user';
  }

  static String _parseAuthProvider(dynamic value) {
    final provider = JsonHelpers.parseString(value)?.trim().toLowerCase();

    if (provider == 'google') return 'google';

    return 'local';
  }
}