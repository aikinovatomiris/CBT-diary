class JsonHelpers {
  JsonHelpers._();

  static int? parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(
        value.trim(),
      );
    }

    return null;
  }

  static double? parseDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(
        value
            .trim()
            .replaceAll(',', '.'),
      );
    }

    return null;
  }

  static bool? parseBool(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized =
          value.trim().toLowerCase();

      if (
          normalized == 'true' ||
          normalized == '1'
      ) {
        return true;
      }

      if (
          normalized == 'false' ||
          normalized == '0'
      ) {
        return false;
      }
    }

    return null;
  }

  static String? parseString(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      return value;
    }

    return value.toString();
  }

  static DateTime? parseDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      if (value.isUtc) {
        return value.toLocal();
      }

      return value;
    }

    if (value is! String) {
      return null;
    }

    final rawValue = value.trim();

    if (rawValue.isEmpty) {
      return null;
    }

    // Даты вида 2026-06-18 используются в аналитике.
    // Для них нельзя выполнять перевод часового пояса.
    final isDateOnly = RegExp(
      r'^\d{4}-\d{2}-\d{2}$',
    ).hasMatch(rawValue);

    if (isDateOnly) {
      final parsedDate =
          DateTime.tryParse(rawValue);

      if (parsedDate == null) {
        return null;
      }

      return DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
      );
    }

    /*
     * Правильный ответ backend:
     *
     * 2026-06-18T18:35:00.000000+00:00
     * или:
     * 2026-06-18T18:35:00.000000Z
     *
     * DateTime.parse распознаёт его как UTC,
     * после чего toLocal переводит в часовой пояс устройства.
     */
    final hasTimezone = RegExp(
      r'(Z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(rawValue);

    if (hasTimezone) {
      final parsed =
          DateTime.tryParse(rawValue);

      if (parsed == null) {
        return null;
      }

      return parsed.toLocal();
    }

    /*
     * Обратная совместимость.
     *
     * Старые ответы FastAPI могли возвращать UTC
     * без Z и без +00:00:
     *
     * 2026-06-18T18:35:00.000000
     *
     * Поэтому принудительно интерпретируем такую строку
     * как UTC, добавляя Z.
     */
    final parsedAsUtc = DateTime.tryParse(
      '${rawValue}Z',
    );

    if (parsedAsUtc == null) {
      return null;
    }

    return parsedAsUtc.toLocal();
  }

  static Map<String, dynamic>? parseMap(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return null;
  }

  static List<String> parseStringList(
    dynamic value,
  ) {
    if (value == null) {
      return [];
    }

    if (value is List) {
      return value
          .where(
            (item) => item != null,
          )
          .map(
            (item) => item.toString(),
          )
          .toList();
    }

    return [];
  }

  static List<Map<String, dynamic>>
      parseMapList(
    dynamic value,
  ) {
    if (value == null) {
      return [];
    }

    if (value is List) {
      return value
          .whereType<Map>()
          .map(
            (item) =>
                Map<String, dynamic>.from(
              item,
            ),
          )
          .toList();
    }

    return [];
  }
}