import '../models/token_model.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'token_storage.dart';

class AuthService {
  AuthService._();

  static UserModel? _cachedUser;

  static UserModel? get cachedUser => _cachedUser;

  static Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiClient.post(
        '/auth/register',
        data: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
        },
      );

      final data = _safeMap(response.data);

      return UserModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось зарегистрироваться. Попробуйте ещё раз.',
      );
    }
  }

  static Future<UserModel> registerTherapist({
    required String name,
    required String fullName,
    required String email,
    required String password,
    required String qualification,
  }) async {
    try {
      final response = await ApiClient.post(
        '/auth/register-therapist',
        data: {
          'email': email.trim(),
          'password': password,
          'name': name.trim(),
          'full_name': fullName.trim(),
          'qualification': qualification.trim(),
        },
      );

      final data = _safeMap(response.data);
      final userData = _safeMap(data['user']);

      return UserModel.fromJson(userData);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось создать аккаунт специалиста.',
      );
    }
  }

  static Future<TokenModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiClient.post(
        '/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      final data = _safeMap(response.data);
      final tokenModel = TokenModel.fromJson(data);

      final token = tokenModel.accessToken;

      if (token == null || token.trim().isEmpty) {
        throw const ApiException(
          message: 'Сервер не вернул токен авторизации.',
        );
      }

      _cachedUser = null;
      await TokenStorage.saveToken(token);

      return tokenModel;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось войти. Проверьте email и пароль.',
      );
    }
  }

  static Future<TokenModel> loginWithGoogleIdToken({
    required String idToken,
  }) async {
    try {
      final cleanIdToken = idToken.trim();

      if (cleanIdToken.isEmpty) {
        throw const ApiException(
          message: 'Google не вернул токен авторизации.',
        );
      }

      final response = await ApiClient.post(
        '/auth/google',
        data: {
          'id_token': cleanIdToken,
        },
      );

      final data = _safeMap(response.data);
      final tokenModel = TokenModel.fromJson(data);

      final token = tokenModel.accessToken;

      if (token == null || token.trim().isEmpty) {
        throw const ApiException(
          message: 'Сервер не вернул токен авторизации.',
        );
      }

      _cachedUser = null;
      await TokenStorage.saveToken(token);

      return tokenModel;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось войти через Google.',
      );
    }
  }

  static Future<UserModel> me({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedUser != null) {
      return _cachedUser!;
    }

    try {
      final response = await ApiClient.get('/auth/me');

      final data = _safeMap(response.data);
      final user = UserModel.fromJson(data);

      _cachedUser = user;

      return user;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось получить данные пользователя.',
      );
    }
  }

  static Future<void> logout() async {
    try {
      _cachedUser = null;
      await TokenStorage.clearToken();
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось выйти из аккаунта.',
      );
    }
  }

  static Future<bool> isLoggedIn() async {
    return TokenStorage.hasToken();
  }

  static Map<String, dynamic> _safeMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw const ApiException(
      message: 'Некорректный ответ сервера.',
    );
  }
}