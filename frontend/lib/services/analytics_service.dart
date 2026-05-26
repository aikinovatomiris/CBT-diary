import '../models/analytics_model.dart';
import 'api_client.dart';
import 'api_exception.dart';

class AnalyticsService {
  AnalyticsService._();

  static Future<AnalyticsSummaryModel> getSummary() async {
    try {
      final response = await ApiClient.get('/analytics/summary');

      final data = _safeMap(response.data);
      return AnalyticsSummaryModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить статистику.',
      );
    }
  }

  static Future<AnalyticsDistortionsResponseModel> getDistortions() async {
    try {
      final response = await ApiClient.get('/analytics/distortions');

      final data = _safeMap(response.data);
      return AnalyticsDistortionsResponseModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить когнитивные искажения.',
      );
    }
  }

  static Future<AnalyticsTechniquesResponseModel> getTechniques() async {
    try {
      final response = await ApiClient.get('/analytics/techniques');

      final data = _safeMap(response.data);
      return AnalyticsTechniquesResponseModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить техники.',
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