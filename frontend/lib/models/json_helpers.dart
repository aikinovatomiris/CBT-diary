class JsonHelpers {
  JsonHelpers._();

  static int? parseInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    if (value is double) return value.toInt();

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }

  static double? parseDouble(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;

    if (value is int) return value.toDouble();

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  static bool? parseBool(dynamic value) {
    if (value == null) return null;

    if (value is bool) return value;

    if (value is String) {
      final normalized = value.toLowerCase().trim();

      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }

    return null;
  }

  static String? parseString(dynamic value) {
    if (value == null) return null;

    if (value is String) return value;

    return value.toString();
  }

  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) return value;

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static Map<String, dynamic>? parseMap(dynamic value) {
    if (value == null) return null;

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  static List<String> parseStringList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .where((item) => item != null)
          .map((item) => item.toString())
          .toList();
    }

    return [];
  }

  static List<Map<String, dynamic>> parseMapList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return [];
  }
}