import 'package:dio/dio.dart';

import '../models/delete_diary_entry_response_model.dart';
import '../models/diary_entry_model.dart';
import 'api_client.dart';
import 'api_exception.dart';

class DiaryService {
  DiaryService._();

  // ============================================================
  // GET /diary
  // ============================================================

  static Future<List<DiaryEntryModel>> getEntries() async {
    try {
      final response = await ApiClient.get('/diary');
      final data = response.data;

      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) {
              return DiaryEntryModel.fromJson(
                Map<String, dynamic>.from(item),
              );
            })
            .toList();
      }

      throw const ApiException(
        message: 'Сервер вернул некорректный список дневниковых записей.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить дневник.',
      );
    }
  }

  // ============================================================
  // GET /diary/{entry_id}
  // ============================================================

  static Future<DiaryEntryModel> getEntry(int id) async {
    try {
      final response = await ApiClient.get('/diary/$id');
      final data = _safeMap(response.data);

      return DiaryEntryModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить дневниковую запись.',
      );
    }
  }

  // ============================================================
  // DELETE /diary/{entry_id}
  // ============================================================

  static Future<DeleteDiaryEntryResponseModel> deleteEntry(int id) async {
    try {
      final response = await ApiClient.delete('/diary/$id');
      final data = _safeMap(response.data);

      return DeleteDiaryEntryResponseModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось удалить дневниковую запись.',
      );
    }
  }

  // ============================================================
  // GET /diary/{entry_id}/export-text
  // ============================================================

  static Future<String> exportEntryText(int id) async {
    try {
      final response = await ApiClient.dio.get(
        '/diary/$id/export-text',
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Accept': 'text/plain',
          },
        ),
      );

      final data = response.data;

      if (data == null) {
        return '';
      }

      if (data is String) {
        return data;
      }

      return data.toString();
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось экспортировать дневниковую запись.',
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

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