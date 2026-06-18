import 'json_helpers.dart';

// ============================================================
// SUMMARY
// ============================================================

class AnalyticsSummaryModel {
  final int? totalSessions;
  final int? finishedSessions;
  final int? totalDiaryEntries;
  final DateTime? latestEntryDate;

  const AnalyticsSummaryModel({
    this.totalSessions,
    this.finishedSessions,
    this.totalDiaryEntries,
    this.latestEntryDate,
  });

  factory AnalyticsSummaryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnalyticsSummaryModel(
      totalSessions: JsonHelpers.parseInt(
        json['total_sessions'],
      ),
      finishedSessions: JsonHelpers.parseInt(
        json['finished_sessions'],
      ),
      totalDiaryEntries: JsonHelpers.parseInt(
        json['total_diary_entries'],
      ),
      latestEntryDate: JsonHelpers.parseDateTime(
        json['latest_entry_date'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_sessions': totalSessions,
      'finished_sessions': finishedSessions,
      'total_diary_entries': totalDiaryEntries,
      'latest_entry_date': latestEntryDate?.toIso8601String(),
    };
  }

  int get safeTotalSessions {
    return totalSessions ?? 0;
  }

  int get safeFinishedSessions {
    return finishedSessions ?? 0;
  }

  int get safeTotalDiaryEntries {
    return totalDiaryEntries ?? 0;
  }

  bool get hasSessions {
    return safeTotalSessions > 0;
  }

  bool get hasDiaryEntries {
    return safeTotalDiaryEntries > 0;
  }
}

// ============================================================
// DISTORTIONS
// ============================================================

class AnalyticsDistortionModel {
  final String? name;
  final int? count;

  const AnalyticsDistortionModel({
    this.name,
    this.count,
  });

  factory AnalyticsDistortionModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnalyticsDistortionModel(
      name: JsonHelpers.parseString(
        json['name'],
      ),
      count: JsonHelpers.parseInt(
        json['count'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'count': count,
    };
  }

  static List<AnalyticsDistortionModel> listFromJson(
    dynamic value,
  ) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map(
            (item) => AnalyticsDistortionModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    return [];
  }

  String get safeName {
    final value = name?.trim();

    if (value == null || value.isEmpty) {
      return 'Не указано';
    }

    return value;
  }

  int get safeCount {
    return count ?? 0;
  }
}

class AnalyticsDistortionsResponseModel {
  final List<AnalyticsDistortionModel> items;

  const AnalyticsDistortionsResponseModel({
    this.items = const [],
  });

  factory AnalyticsDistortionsResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnalyticsDistortionsResponseModel(
      items: AnalyticsDistortionModel.listFromJson(
        json['items'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items
          .map(
            (item) => item.toJson(),
          )
          .toList(),
    };
  }

  bool get hasData {
    return items.isNotEmpty;
  }

  AnalyticsDistortionModel? get mostCommon {
    if (items.isEmpty) {
      return null;
    }

    return items.first;
  }
}

// ============================================================
// TECHNIQUES
// ============================================================

class AnalyticsTechniqueModel {
  final String? technique;
  final int? count;

  const AnalyticsTechniqueModel({
    this.technique,
    this.count,
  });

  factory AnalyticsTechniqueModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnalyticsTechniqueModel(
      technique: JsonHelpers.parseString(
        json['technique'],
      ),
      count: JsonHelpers.parseInt(
        json['count'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'technique': technique,
      'count': count,
    };
  }

  static List<AnalyticsTechniqueModel> listFromJson(
    dynamic value,
  ) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map(
            (item) => AnalyticsTechniqueModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    return [];
  }

  String get safeTechnique {
    final value = technique?.trim();

    if (value == null || value.isEmpty) {
      return 'Не указано';
    }

    return value;
  }

  int get safeCount {
    return count ?? 0;
  }
}

class AnalyticsTechniquesResponseModel {
  final List<AnalyticsTechniqueModel> items;

  const AnalyticsTechniquesResponseModel({
    this.items = const [],
  });

  factory AnalyticsTechniquesResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnalyticsTechniquesResponseModel(
      items: AnalyticsTechniqueModel.listFromJson(
        json['items'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items
          .map(
            (item) => item.toJson(),
          )
          .toList(),
    };
  }

  bool get hasData {
    return items.isNotEmpty;
  }

  AnalyticsTechniqueModel? get mostUsed {
    if (items.isEmpty) {
      return null;
    }

    return items.first;
  }
}

// ============================================================
// WELLBEING WEEK
// GET /analytics/wellbeing-week
// ============================================================

class AnalyticsWellbeingDayModel {
  final DateTime? date;
  final String? dayLabel;
  final double? score;
  final int entriesCount;

  const AnalyticsWellbeingDayModel({
    this.date,
    this.dayLabel,
    this.score,
    this.entriesCount = 0,
  });

  factory AnalyticsWellbeingDayModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnalyticsWellbeingDayModel(
      date: JsonHelpers.parseDateTime(
        json['date'],
      ),
      dayLabel: JsonHelpers.parseString(
        json['day_label'],
      ),
      score: _parseDouble(
        json['score'],
      ),
      entriesCount:
          JsonHelpers.parseInt(
            json['entries_count'],
          ) ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': _dateToApiString(date),
      'day_label': dayLabel,
      'score': score,
      'entries_count': entriesCount,
    };
  }

  bool get hasScore {
    return score != null;
  }

  double get safeScore {
    return (score ?? 0).clamp(
      0.0,
      100.0,
    );
  }

  String get safeDayLabel {
    final value = dayLabel?.trim();

    if (value == null || value.isEmpty) {
      return '';
    }

    return value;
  }

  static List<AnalyticsWellbeingDayModel> listFromJson(
    dynamic value,
  ) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map(
            (item) => AnalyticsWellbeingDayModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    return [];
  }
}

class AnalyticsWellbeingWeekModel {
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double? averageScore;
  final String? trend;
  final List<AnalyticsWellbeingDayModel> items;

  const AnalyticsWellbeingWeekModel({
    this.periodStart,
    this.periodEnd,
    this.averageScore,
    this.trend,
    this.items = const [],
  });

  factory AnalyticsWellbeingWeekModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnalyticsWellbeingWeekModel(
      periodStart: JsonHelpers.parseDateTime(
        json['period_start'],
      ),
      periodEnd: JsonHelpers.parseDateTime(
        json['period_end'],
      ),
      averageScore: _parseDouble(
        json['average_score'],
      ),
      trend: JsonHelpers.parseString(
        json['trend'],
      ),
      items: AnalyticsWellbeingDayModel.listFromJson(
        json['items'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period_start': _dateToApiString(
        periodStart,
      ),
      'period_end': _dateToApiString(
        periodEnd,
      ),
      'average_score': averageScore,
      'trend': trend,
      'items': items
          .map(
            (item) => item.toJson(),
          )
          .toList(),
    };
  }

  List<AnalyticsWellbeingDayModel> get availableItems {
    return items
        .where(
          (item) => item.hasScore,
        )
        .toList();
  }

  bool get hasData {
    return availableItems.isNotEmpty;
  }

  bool get hasEnoughTrendData {
    return availableItems.length >= 2;
  }

  double get safeAverageScore {
    return (averageScore ?? 0).clamp(
      0.0,
      100.0,
    );
  }

  String get normalizedTrend {
    return trend?.trim().toLowerCase() ??
        'insufficient_data';
  }

  bool get isImproving {
    return normalizedTrend == 'improving';
  }

  bool get isStable {
    return normalizedTrend == 'stable';
  }

  bool get isDeclining {
    return normalizedTrend == 'declining';
  }

  bool get hasInsufficientTrendData {
    return normalizedTrend == 'insufficient_data';
  }

  String get trendTitle {
    switch (normalizedTrend) {
      case 'improving':
        return 'Положительная динамика';
      case 'stable':
        return 'Стабильная динамика';
      case 'declining':
        return 'Есть снижение';
      default:
        return 'Недостаточно данных';
    }
  }
}

// ============================================================
// RESILIENCE
// GET /analytics/resilience
// ============================================================

class AnalyticsResilienceModel {
  final int? score;
  final double completionScore;
  final double? averageWellbeingScore;
  final int totalSessions;
  final int finishedSessions;
  final int sessionsWithWellbeingData;
  final String? dataStatus;

  const AnalyticsResilienceModel({
    this.score,
    this.completionScore = 0,
    this.averageWellbeingScore,
    this.totalSessions = 0,
    this.finishedSessions = 0,
    this.sessionsWithWellbeingData = 0,
    this.dataStatus,
  });

  factory AnalyticsResilienceModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnalyticsResilienceModel(
      score: JsonHelpers.parseInt(
        json['score'],
      ),
      completionScore:
          _parseDouble(
            json['completion_score'],
          ) ??
          0,
      averageWellbeingScore: _parseDouble(
        json['average_wellbeing_score'],
      ),
      totalSessions:
          JsonHelpers.parseInt(
            json['total_sessions'],
          ) ??
          0,
      finishedSessions:
          JsonHelpers.parseInt(
            json['finished_sessions'],
          ) ??
          0,
      sessionsWithWellbeingData:
          JsonHelpers.parseInt(
            json['sessions_with_wellbeing_data'],
          ) ??
          0,
      dataStatus: JsonHelpers.parseString(
        json['data_status'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'completion_score': completionScore,
      'average_wellbeing_score': averageWellbeingScore,
      'total_sessions': totalSessions,
      'finished_sessions': finishedSessions,
      'sessions_with_wellbeing_data':
          sessionsWithWellbeingData,
      'data_status': dataStatus,
    };
  }

  String get normalizedDataStatus {
    return dataStatus?.trim().toLowerCase() ??
        'no_data';
  }

  bool get hasData {
    return score != null &&
        normalizedDataStatus != 'no_data';
  }

  bool get hasNoData {
    return normalizedDataStatus == 'no_data';
  }

  bool get hasLimitedData {
    return normalizedDataStatus == 'limited';
  }

  bool get hasEnoughData {
    return normalizedDataStatus == 'enough';
  }

  int get safeScore {
    return (score ?? 0).clamp(
      0,
      100,
    );
  }

  double get safeCompletionScore {
    return completionScore.clamp(
      0.0,
      100.0,
    );
  }

  double get safeAverageWellbeingScore {
    return (averageWellbeingScore ?? 0).clamp(
      0.0,
      100.0,
    );
  }

  String get dataStatusTitle {
    switch (normalizedDataStatus) {
      case 'limited':
        return 'Предварительный показатель';
      case 'enough':
        return 'Достаточно данных';
      default:
        return 'Недостаточно данных';
    }
  }
}

// ============================================================
// COMMON HELPERS
// ============================================================

double? _parseDouble(dynamic value) {
  if (value == null || value is bool) {
    return null;
  }

  if (value is double) {
    return value;
  }

  if (value is int) {
    return value.toDouble();
  }

  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(
      value.trim().replaceAll(',', '.'),
    );
  }

  return null;
}

String? _dateToApiString(DateTime? value) {
  if (value == null) {
    return null;
  }

  final year = value.year.toString().padLeft(
    4,
    '0',
  );

  final month = value.month.toString().padLeft(
    2,
    '0',
  );

  final day = value.day.toString().padLeft(
    2,
    '0',
  );

  return '$year-$month-$day';
}