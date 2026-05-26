import 'json_helpers.dart';

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