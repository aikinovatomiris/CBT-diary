import 'package:google_sign_in/google_sign_in.dart';

import 'api_exception.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static const String _serverClientId =
      '156120586276-8700tcup3dmgn7qphrr49vg70fvabmar.apps.googleusercontent.com';

  static bool _isInitialized = false;

  static Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: _serverClientId,
      );

      _isInitialized = true;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось подготовить вход через Google.',
      );
    }
  }

  static Future<String> getGoogleIdToken() async {
    try {
      await _initialize();

      final account = await GoogleSignIn.instance.authenticate();

      final auth = account.authentication;
      final idToken = auth.idToken;

      if (idToken == null || idToken.trim().isEmpty) {
        throw const ApiException(
          message:
              'Google не вернул idToken. Проверьте Web Client ID, Android Client ID, package name и SHA-1.',
        );
      }

      return idToken;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось выполнить вход через Google.',
      );
    }
  }

  static Future<void> signOut() async {
    try {
      await _initialize();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось выйти из Google-аккаунта.',
      );
    }
  }
}