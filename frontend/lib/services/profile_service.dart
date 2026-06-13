import '../models/change_password_response_model.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'api_exception.dart';

class ProfileService {
  ProfileService._();

  // ============================================================
  // PATCH /profile/assistant-style
  // ============================================================

  static Future<UserModel> updateAssistantStyle(String assistantStyle) async {
    try {
      final response = await ApiClient.patch(
        '/profile/assistant-style',
        data: {
          'assistant_style': assistantStyle,
        },
      );

      final data = _safeMap(response.data);
      return UserModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось изменить стиль ассистента.',
      );
    }
  }

  // ============================================================
  // PATCH /profile/name
  // ============================================================

  static Future<UserModel> updateName(String name) async {
    try {
      final cleanName = name.trim();

      if (cleanName.isEmpty) {
        throw const ApiException(
          message: 'Имя не может быть пустым.',
        );
      }

      final response = await ApiClient.patch(
        '/profile/name',
        data: {
          'name': cleanName,
        },
      );

      final data = _safeMap(response.data);
      return UserModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось изменить имя.',
      );
    }
  }

  // ============================================================
  // PATCH /profile/change-password
  // ============================================================

  static Future<ChangePasswordResponseModel> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await ApiClient.patch(
        '/profile/change-password',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );

      final data = _safeMap(response.data);
      return ChangePasswordResponseModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось изменить пароль.',
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