import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/constants.dart';

class TokenStorage {
  TokenStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // ============================================================
  // SAVE TOKEN
  // Сохраняет JWT access_token после login/register.
  // ============================================================

  static Future<void> saveToken(String token) async {
    await _storage.write(
      key: AppConstants.accessTokenKey,
      value: token,
    );
  }

  // ============================================================
  // GET TOKEN
  // Возвращает JWT token или null, если пользователь не авторизован.
  // ============================================================

  static Future<String?> getToken() async {
    return _storage.read(
      key: AppConstants.accessTokenKey,
    );
  }

  // ============================================================
  // CLEAR TOKEN
  // Удаляет token при logout или 401.
  // ============================================================

  static Future<void> clearToken() async {
    await _storage.delete(
      key: AppConstants.accessTokenKey,
    );
  }

  // ============================================================
  // HAS TOKEN
  // Проверяет, есть ли сохранённый token.
  // ============================================================

  static Future<bool> hasToken() async {
    final token = await getToken();

    return token != null && token.trim().isNotEmpty;
  }
}