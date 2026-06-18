import '../models/analytics_model.dart';
import 'api_client.dart';
import 'api_exception.dart';

class AnalyticsService {
  AnalyticsService._();

  // ============================================================
  // GET /analytics/summary
  // ============================================================

  static Future<AnalyticsSummaryModel> getSummary() async {
    try {
      final response = await ApiClient.get(
        '/analytics/summary',
      );

      final data = _safeMap(
        response.data,
      );

      return AnalyticsSummaryModel.fromJson(
        data,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message:
            'Не удалось загрузить статистику.',
      );
    }
  }

  // ============================================================
  // GET /analytics/distortions
  // ============================================================

  static Future<AnalyticsDistortionsResponseModel>
  getDistortions() async {
    try {
      final response = await ApiClient.get(
        '/analytics/distortions',
      );

      final data = _safeMap(
        response.data,
      );

      return AnalyticsDistortionsResponseModel.fromJson(
        data,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message:
            'Не удалось загрузить когнитивные искажения.',
      );
    }
  }

  // ============================================================
  // GET /analytics/techniques
  // ============================================================

  static Future<AnalyticsTechniquesResponseModel>
  getTechniques() async {
    try {
      final response = await ApiClient.get(
        '/analytics/techniques',
      );

      final data = _safeMap(
        response.data,
      );

      return AnalyticsTechniquesResponseModel.fromJson(
        data,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message:
            'Не удалось загрузить техники.',
      );
    }
  }

  // ============================================================
  // GET /analytics/wellbeing-week
  // ============================================================

  static Future<AnalyticsWellbeingWeekModel>
  getWellbeingWeek() async {
    try {
      final response = await ApiClient.get(
        '/analytics/wellbeing-week',
      );

      final data = _safeMap(
        response.data,
      );

      return AnalyticsWellbeingWeekModel.fromJson(
        data,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message:
            'Не удалось загрузить динамику состояния за неделю.',
      );
    }
  }

  // ============================================================
  // GET /analytics/resilience
  // ============================================================

  static Future<AnalyticsResilienceModel>
  getResilience() async {
    try {
      final response = await ApiClient.get(
        '/analytics/resilience',
      );

      final data = _safeMap(
        response.data,
      );

      return AnalyticsResilienceModel.fromJson(
        data,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message:
            'Не удалось рассчитать прогресс устойчивости.',
      );
    }
  }

  // ============================================================
  // LOAD ALL ANALYTICS
  // Можно использовать на детальном экране аналитики.
  // ============================================================

  static Future<AnalyticsDetailsData>
  getDetails() async {
    try {
      final results = await Future.wait<dynamic>([
        getSummary(),
        getDistortions(),
        getTechniques(),
        getWellbeingWeek(),
        getResilience(),
      ]);

      return AnalyticsDetailsData(
        summary: results[0] as AnalyticsSummaryModel,
        distortions:
            results[1]
                as AnalyticsDistortionsResponseModel,
        techniques:
            results[2]
                as AnalyticsTechniquesResponseModel,
        wellbeingWeek:
            results[3]
                as AnalyticsWellbeingWeekModel,
        resilience:
            results[4]
                as AnalyticsResilienceModel,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message:
            'Не удалось загрузить подробную аналитику.',
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static Map<String, dynamic> _safeMap(
    dynamic data,
  ) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(
        data,
      );
    }

    throw const ApiException(
      message:
          'Сервер вернул некорректный ответ.',
    );
  }
}

// ============================================================
// COMBINED DATA FOR ANALYTICS SCREEN
// ============================================================

class AnalyticsDetailsData {
  final AnalyticsSummaryModel summary;
  final AnalyticsDistortionsResponseModel distortions;
  final AnalyticsTechniquesResponseModel techniques;
  final AnalyticsWellbeingWeekModel wellbeingWeek;
  final AnalyticsResilienceModel resilience;

  const AnalyticsDetailsData({
    required this.summary,
    required this.distortions,
    required this.techniques,
    required this.wellbeingWeek,
    required this.resilience,
  });
}