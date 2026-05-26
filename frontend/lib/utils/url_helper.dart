import 'constants.dart';

class UrlHelper {
  UrlHelper._();

  static String buildFileUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }

    final url = value.trim();

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    final baseUrl = AppConstants.baseUrl.endsWith('/')
        ? AppConstants.baseUrl.substring(0, AppConstants.baseUrl.length - 1)
        : AppConstants.baseUrl;

    final path = url.startsWith('/') ? url : '/$url';

    return '$baseUrl$path';
  }
}