import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  factory ApiException.fromDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    // ============================================================
    // 401 Unauthorized
    // Backend security.py возвращает 401, если JWT невалидный,
    // просроченный или отсутствует.
    // ============================================================

    if (statusCode == 401) {
      return ApiException(
        message: 'Ошибка авторизации. Пожалуйста, войдите снова.',
        statusCode: statusCode,
        data: data,
      );
    }

    // ============================================================
    // Backend FastAPI часто возвращает:
    // {"detail": "..."}
    // или список ошибок валидации.
    // Здесь пробуем достать понятное сообщение.
    // ============================================================

    final backendMessage = _extractBackendMessage(data);

    if (backendMessage != null && backendMessage.trim().isNotEmpty) {
      return ApiException(
        message: backendMessage,
        statusCode: statusCode,
        data: data,
      );
    }

    // ============================================================
    // Network / timeout errors
    // ============================================================

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return ApiException(
          message: 'Не удалось подключиться к серверу. Проверьте backend.',
          statusCode: statusCode,
          data: data,
        );

      case DioExceptionType.sendTimeout:
        return ApiException(
          message: 'Сервер слишком долго принимает запрос.',
          statusCode: statusCode,
          data: data,
        );

      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Сервер слишком долго отвечает.',
          statusCode: statusCode,
          data: data,
        );

      case DioExceptionType.connectionError:
        return ApiException(
          message:
              'Нет соединения с сервером. Проверьте адрес backend и интернет.',
          statusCode: statusCode,
          data: data,
        );

      case DioExceptionType.badResponse:
        return ApiException(
          message: 'Ошибка сервера. Код: ${statusCode ?? 'неизвестно'}.',
          statusCode: statusCode,
          data: data,
        );

      case DioExceptionType.cancel:
        return ApiException(
          message: 'Запрос был отменён.',
          statusCode: statusCode,
          data: data,
        );

      case DioExceptionType.badCertificate:
        return ApiException(
          message: 'Ошибка сертификата соединения.',
          statusCode: statusCode,
          data: data,
        );

      case DioExceptionType.unknown:
        return ApiException(
          message: 'Неизвестная ошибка соединения.',
          statusCode: statusCode,
          data: data,
        );
    }
  }

  static String? _extractBackendMessage(dynamic data) {
    if (data == null) return null;

    if (data is String) {
      return data;
    }

    if (data is Map) {
      final detail = data['detail'];

      if (detail is String) {
        return detail;
      }

      // FastAPI validation error:
      // {
      //   "detail": [
      //     {
      //       "loc": [...],
      //       "msg": "...",
      //       "type": "..."
      //     }
      //   ]
      // }
      if (detail is List && detail.isNotEmpty) {
        final firstError = detail.first;

        if (firstError is Map && firstError['msg'] != null) {
          return firstError['msg'].toString();
        }

        return detail.first.toString();
      }

      if (data['message'] != null) {
        return data['message'].toString();
      }
    }

    return null;
  }

  @override
  String toString() {
    return message;
  }
}