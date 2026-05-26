class AppConstants {
  AppConstants._();

  // ============================================================
  // API BASE URL
  // Главный адрес FastAPI backend.
  //
  // Для браузера на ноутбуке:
  // http://localhost:8000
  //
  // Для реального Android-телефона через Wi-Fi:
  // нужно поставить IP ноутбука, например:
  // http://192.168.1.10:8000
  //
  // Запуск с другим адресом:
  // flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
  //
  // Для USB можно также использовать adb reverse:
  // adb reverse tcp:8000 tcp:8000
  // Тогда http://localhost:8000 будет работать и на телефоне.
  // ============================================================

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  // ============================================================
  // TIMEOUTS
  // Таймауты запросов к backend.
  // Если backend/LLM отвечает долго, можно увеличить receiveTimeout.
  // ============================================================

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration sendTimeout = Duration(seconds: 20);

  // ============================================================
  // SECURE STORAGE KEYS
  // Ключи для хранения JWT.
  // ============================================================

  static const String accessTokenKey = 'access_token';
}