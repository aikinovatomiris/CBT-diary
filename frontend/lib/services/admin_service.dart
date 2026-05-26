import '../models/admin_model.dart';
import '../models/therapist_profile_model.dart';
import 'api_client.dart';
import 'api_exception.dart';

class AdminService {
  AdminService._();

  static Future<AdminModel> getSummary() async {
    try {
      final response = await ApiClient.get('/admin/summary');

      final data = _safeMap(response.data);
      return AdminModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить сводку администратора.',
      );
    }
  }

  static Future<List<TherapistProfileModel>> getPendingTherapists() async {
    try {
      final response = await ApiClient.get('/admin/therapists/pending');
      final data = response.data;

      if (data is List) {
        return data.whereType<Map>().map((item) {
          return TherapistProfileModel.fromJson(
            Map<String, dynamic>.from(item),
          );
        }).toList();
      }

      throw const ApiException(
        message: 'Сервер вернул некорректный список анкет терапевтов.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить анкеты терапевтов на модерации.',
      );
    }
  }

  static Future<AdminTherapistDetailModel> getTherapistById(
    int profileId,
  ) async {
    try {
      final response = await ApiClient.get(
        '/admin/therapists/$profileId',
      );

      final data = _safeMap(response.data);
      return AdminTherapistDetailModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить анкету терапевта.',
      );
    }
  }

  static Future<TherapistProfileModel> approveTherapist(
    int profileId,
  ) async {
    try {
      final response = await ApiClient.patch(
        '/admin/therapists/$profileId/approve',
      );

      final data = _safeMap(response.data);
      final profileData = _extractProfileData(data);

      return TherapistProfileModel.fromJson(profileData);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось одобрить анкету терапевта.',
      );
    }
  }

  static Future<TherapistProfileModel> rejectTherapist(
    int profileId, {
    required String reason,
  }) async {
    try {
      final trimmedReason = reason.trim();

      if (trimmedReason.isEmpty) {
        throw const ApiException(
          message: 'Укажите причину отклонения анкеты.',
        );
      }

      final response = await ApiClient.patch(
        '/admin/therapists/$profileId/reject',
        data: {
          // ВАЖНО:
          // backend AdminRejectTherapistRequest ожидает поле reason,
          // а не rejection_reason.
          'reason': trimmedReason,
        },
      );

      final responseData = _safeMap(response.data);
      final profileData = _extractProfileData(responseData);

      return TherapistProfileModel.fromJson(profileData);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось отклонить анкету терапевта.',
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

  static Map<String, dynamic> _extractProfileData(
    Map<String, dynamic> data,
  ) {
    final profile = data['profile'];

    if (profile is Map<String, dynamic>) {
      return profile;
    }

    if (profile is Map) {
      return Map<String, dynamic>.from(profile);
    }

    return data;
  }
}