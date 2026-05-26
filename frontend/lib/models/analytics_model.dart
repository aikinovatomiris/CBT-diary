import 'json_helpers.dart';

class AnalyticsDistortionModel {

  final String? name;

  final int? count;

  const AnalyticsDistortionModel({
    this.name,
    this.count,
  });

  factory AnalyticsDistortionModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsDistortionModel(
      name: JsonHelpers.parseString(json['name']),
      count: JsonHelpers.parseInt(json['count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'count': count,
    };
  }

  static List<AnalyticsDistortionModel> listFromJson(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) {
            return AnalyticsDistortionModel.fromJson(
              Map<String, dynamic>.from(item),
            );
          })
          .toList();
    }

    return [];
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
      items: AnalyticsDistortionModel.listFromJson(json['items']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

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

  factory AnalyticsSummaryModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummaryModel(
      totalSessions: JsonHelpers.parseInt(json['total_sessions']),
      finishedSessions: JsonHelpers.parseInt(json['finished_sessions']),
      totalDiaryEntries: JsonHelpers.parseInt(json['total_diary_entries']),
      latestEntryDate: JsonHelpers.parseDateTime(json['latest_entry_date']),
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
}

class AnalyticsTechniqueModel {

  final String? technique;

  final int? count;

  const AnalyticsTechniqueModel({
    this.technique,
    this.count,
  });

  factory AnalyticsTechniqueModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsTechniqueModel(
      technique: JsonHelpers.parseString(json['technique']),
      count: JsonHelpers.parseInt(json['count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'technique': technique,
      'count': count,
    };
  }

  static List<AnalyticsTechniqueModel> listFromJson(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) {
            return AnalyticsTechniqueModel.fromJson(
              Map<String, dynamic>.from(item),
            );
          })
          .toList();
    }

    return [];
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
      items: AnalyticsTechniqueModel.listFromJson(json['items']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}