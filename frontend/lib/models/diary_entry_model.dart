import 'json_helpers.dart';

class DiaryEntryModel {
  final int? id;
  final int? userId;
  final int? sessionId;

  final String? situation;
  final String? automaticThought;
  final Map<String, dynamic>? emotionsBefore;
  final Map<String, dynamic>? emotionsAfter;
  final Map<String, dynamic>? cognitiveDistortions;
  final String? evidenceFor;
  final String? evidenceAgainst;
  final String? alternativeThought;
  final String? conclusion;
  final DateTime? createdAt;

  const DiaryEntryModel({
    this.id,
    this.userId,
    this.sessionId,
    this.situation,
    this.automaticThought,
    this.emotionsBefore,
    this.emotionsAfter,
    this.cognitiveDistortions,
    this.evidenceFor,
    this.evidenceAgainst,
    this.alternativeThought,
    this.conclusion,
    this.createdAt,
  });

  factory DiaryEntryModel.fromJson(Map<String, dynamic> json) {
    return DiaryEntryModel(
      id: JsonHelpers.parseInt(json['id']),
      userId: JsonHelpers.parseInt(json['user_id']),
      sessionId: JsonHelpers.parseInt(json['session_id']),
      situation: JsonHelpers.parseString(json['situation']),
      automaticThought: JsonHelpers.parseString(json['automatic_thought']),
      emotionsBefore: JsonHelpers.parseMap(json['emotions_before']),
      emotionsAfter: JsonHelpers.parseMap(json['emotions_after']),
      cognitiveDistortions: JsonHelpers.parseMap(
        json['cognitive_distortions'],
      ),
      evidenceFor: JsonHelpers.parseString(json['evidence_for']),
      evidenceAgainst: JsonHelpers.parseString(json['evidence_against']),
      alternativeThought: JsonHelpers.parseString(json['alternative_thought']),
      conclusion: JsonHelpers.parseString(json['conclusion']),
      createdAt: JsonHelpers.parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'session_id': sessionId,
      'situation': situation,
      'automatic_thought': automaticThought,
      'emotions_before': emotionsBefore,
      'emotions_after': emotionsAfter,
      'cognitive_distortions': cognitiveDistortions,
      'evidence_for': evidenceFor,
      'evidence_against': evidenceAgainst,
      'alternative_thought': alternativeThought,
      'conclusion': conclusion,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}