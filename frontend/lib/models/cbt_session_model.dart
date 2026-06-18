import 'json_helpers.dart';

class CBTSessionModel {
  final int? id;
  final int? userId;

  final String? status;
  final String? currentStep;
  final String? currentPhase;

  final DateTime? createdAt;
  final DateTime? finishedAt;

  final String? situation;
  final String? automaticThought;

  final Map<String, dynamic>? emotionsBefore;

  final String? evidenceFor;
  final String? evidenceAgainst;

  final String? userAlternativeThought;
  final String? assistantAlternativeThought;
  final String? finalAlternativeThought;

  final Map<String, dynamic>? emotionsAfter;

  /// Общая субъективная оценка состояния после сессии:
  /// 0 — очень тяжело;
  /// 100 — спокойно и хорошо.
  final int? wellbeingScoreAfter;

  const CBTSessionModel({
    this.id,
    this.userId,
    this.status,
    this.currentStep,
    this.currentPhase,
    this.createdAt,
    this.finishedAt,
    this.situation,
    this.automaticThought,
    this.emotionsBefore,
    this.evidenceFor,
    this.evidenceAgainst,
    this.userAlternativeThought,
    this.assistantAlternativeThought,
    this.finalAlternativeThought,
    this.emotionsAfter,
    this.wellbeingScoreAfter,
  });

  factory CBTSessionModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CBTSessionModel(
      id: JsonHelpers.parseInt(
        json['id'],
      ),
      userId: JsonHelpers.parseInt(
        json['user_id'],
      ),
      status: JsonHelpers.parseString(
        json['status'],
      ),
      currentStep: JsonHelpers.parseString(
        json['current_step'],
      ),
      currentPhase: JsonHelpers.parseString(
        json['current_phase'],
      ),
      createdAt: JsonHelpers.parseDateTime(
        json['created_at'],
      ),
      finishedAt: JsonHelpers.parseDateTime(
        json['finished_at'],
      ),
      situation: JsonHelpers.parseString(
        json['situation'],
      ),
      automaticThought: JsonHelpers.parseString(
        json['automatic_thought'],
      ),
      emotionsBefore: JsonHelpers.parseMap(
        json['emotions_before'],
      ),
      evidenceFor: JsonHelpers.parseString(
        json['evidence_for'],
      ),
      evidenceAgainst: JsonHelpers.parseString(
        json['evidence_against'],
      ),
      userAlternativeThought:
          JsonHelpers.parseString(
        json['user_alternative_thought'],
      ),
      assistantAlternativeThought:
          JsonHelpers.parseString(
        json['assistant_alternative_thought'],
      ),
      finalAlternativeThought:
          JsonHelpers.parseString(
        json['final_alternative_thought'],
      ),
      emotionsAfter: JsonHelpers.parseMap(
        json['emotions_after'],
      ),
      wellbeingScoreAfter:
          JsonHelpers.parseInt(
        json['wellbeing_score_after'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'status': status,
      'current_step': currentStep,
      'current_phase': currentPhase,
      'created_at': createdAt?.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'situation': situation,
      'automatic_thought': automaticThought,
      'emotions_before': emotionsBefore,
      'evidence_for': evidenceFor,
      'evidence_against': evidenceAgainst,
      'user_alternative_thought': userAlternativeThought,
      'assistant_alternative_thought':
          assistantAlternativeThought,
      'final_alternative_thought':
          finalAlternativeThought,
      'emotions_after': emotionsAfter,
      'wellbeing_score_after': wellbeingScoreAfter,
    };
  }

  bool get isFinished {
    return status == 'finished' ||
        currentStep == 'FINISHED' ||
        currentPhase == 'FINISHED';
  }

  bool get isActive {
    return status == 'active';
  }

  bool get hasWellbeingScore {
    return wellbeingScoreAfter != null;
  }

  int get safeWellbeingScore {
    return (wellbeingScoreAfter ?? 0).clamp(
      0,
      100,
    );
  }
}