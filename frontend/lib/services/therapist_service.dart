import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../models/therapist_certificate_model.dart';
import '../models/therapist_profile_model.dart';
import 'api_client.dart';
import 'api_exception.dart';

class TherapistService {
  TherapistService._();

  // ============================================================
  // GET /therapist/profile
  // ============================================================

  static Future<TherapistProfileModel> getMyProfile() async {
    try {
      final response = await ApiClient.get('/therapist/profile');

      final data = _safeMap(response.data);
      return TherapistProfileModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить анкету специалиста.',
      );
    }
  }

  // ============================================================
  // PATCH /therapist/profile
  // ============================================================

  static Future<TherapistProfileModel> updateMyProfile({
    String? fullName,
    String? qualification,
    List<String>? therapyApproaches,
    List<String>? specializations,
    String? description,
    String? price,
    Map<String, dynamic>? contacts,
    String? city,
    bool? onlineAvailable,
  }) async {
    try {
      final data = <String, dynamic>{};

      if (fullName != null) {
        data['full_name'] = fullName.trim();
      }

      if (qualification != null) {
        data['qualification'] = qualification.trim();
      }

      if (therapyApproaches != null) {
        data['therapy_approaches'] = therapyApproaches;
      }

      if (specializations != null) {
        data['specializations'] = specializations;
      }

      if (description != null) {
        data['description'] = description.trim();
      }

      if (price != null) {
        data['price'] = price.trim();
      }

      if (contacts != null) {
        data['contacts'] = contacts;
      }

      if (city != null) {
        data['city'] = city.trim();
      }

      if (onlineAvailable != null) {
        data['online_available'] = onlineAvailable;
      }

      final response = await ApiClient.patch(
        '/therapist/profile',
        data: data,
      );

      final responseData = _safeMap(response.data);
      return TherapistProfileModel.fromJson(responseData);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось обновить анкету специалиста.',
      );
    }
  }

  // ============================================================
  // POST /therapist/profile/submit
  // ============================================================

  static Future<TherapistProfileModel> submitProfile() async {
    try {
      final response = await ApiClient.post(
        '/therapist/profile/submit',
      );

      final data = _safeMap(response.data);
      return TherapistProfileModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось отправить анкету на модерацию.',
      );
    }
  }

  // ============================================================
  // GET /therapist/profile/certificates
  // ============================================================

  static Future<List<TherapistCertificateModel>> getMyCertificates() async {
    try {
      final response = await ApiClient.get(
        '/therapist/profile/certificates',
      );

      final data = response.data;

      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) {
              return TherapistCertificateModel.fromJson(
                Map<String, dynamic>.from(item),
              );
            })
            .toList();
      }

      throw const ApiException(
        message: 'Сервер вернул некорректный список сертификатов.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить сертификаты специалиста.',
      );
    }
  }

  // ============================================================
  // POST /therapist/profile/certificates
  // ============================================================

  static Future<TherapistCertificateModel> uploadCertificate(
    PlatformFile file,
  ) async {
    try {
      final multipartFile = await _multipartFileFromPlatformFile(file);

      final formData = FormData.fromMap({
        'file': multipartFile,
      });

      final response = await ApiClient.dio.post(
        '/therapist/profile/certificates',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      final data = _safeMap(response.data);
      return TherapistCertificateModel.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить сертификат.',
      );
    }
  }

  // ============================================================
  // POST /therapist/profile/photo
  // ============================================================

  static Future<TherapistProfileModel> uploadProfilePhoto(
    XFile file,
  ) async {
    try {
      final bytes = await file.readAsBytes();

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: file.name.isNotEmpty ? file.name : 'profile_photo.jpg',
        ),
      });

      final response = await ApiClient.dio.post(
        '/therapist/profile/photo',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      final data = _safeMap(response.data);
      return TherapistProfileModel.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить фото профиля.',
      );
    }
  }

  // ============================================================
  // GET /therapists
  // ============================================================

  static Future<List<TherapistProfileModel>> getApprovedTherapists({
    String? city,
    String? specialization,
    bool? onlineAvailable,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};

      if (city != null && city.trim().isNotEmpty) {
        queryParameters['city'] = city.trim();
      }

      if (specialization != null && specialization.trim().isNotEmpty) {
        queryParameters['specialization'] = specialization.trim();
      }

      if (onlineAvailable != null) {
        queryParameters['online_available'] = onlineAvailable;
      }

      final response = await ApiClient.get(
        '/therapists',
        queryParameters: queryParameters,
      );

      final data = response.data;

      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) {
              return TherapistProfileModel.fromJson(
                Map<String, dynamic>.from(item),
              );
            })
            .toList();
      }

      throw const ApiException(
        message: 'Сервер вернул некорректный список терапевтов.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить список терапевтов.',
      );
    }
  }

  // ============================================================
  // GET /therapists/{profile_id}
  // ============================================================

  static Future<TherapistProfileModel> getTherapistById(
    int profileId,
  ) async {
    try {
      final response = await ApiClient.get(
        '/therapists/$profileId',
      );

      final data = _safeMap(response.data);
      return TherapistProfileModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Не удалось загрузить профиль терапевта.',
      );
    }
  }

  // ============================================================
  // Helpers
  // ============================================================

  static Future<MultipartFile> _multipartFileFromPlatformFile(
    PlatformFile file,
  ) async {
    final fileName = file.name.isNotEmpty ? file.name : 'certificate';

    if (file.bytes != null) {
      return MultipartFile.fromBytes(
        file.bytes!,
        filename: fileName,
      );
    }

    final path = file.path;

    if (path == null || path.trim().isEmpty) {
      throw const ApiException(
        message: 'Не удалось прочитать файл сертификата.',
      );
    }

    return MultipartFile.fromFile(
      path,
      filename: fileName,
    );
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