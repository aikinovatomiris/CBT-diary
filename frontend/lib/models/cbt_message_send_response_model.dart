import 'cbt_message_model.dart';
import 'json_helpers.dart';

class CBTMessageSendResponseModel {
  /// backend field: user_message
  final CBTMessageModel? userMessage;

  /// backend field: assistant_message
  final CBTMessageModel? assistantMessage;

  /// backend field: current_step
  final String? currentStep;

  /// backend field: current_phase
  final String? currentPhase;

  /// backend field: session_status
  final String? sessionStatus;

  const CBTMessageSendResponseModel({
    this.userMessage,
    this.assistantMessage,
    this.currentStep,
    this.currentPhase,
    this.sessionStatus,
  });

  factory CBTMessageSendResponseModel.fromJson(Map<String, dynamic> json) {
    final userMessageJson = JsonHelpers.parseMap(json['user_message']);
    final assistantMessageJson = JsonHelpers.parseMap(
      json['assistant_message'],
    );

    return CBTMessageSendResponseModel(
      userMessage: userMessageJson == null
          ? null
          : CBTMessageModel.fromJson(userMessageJson),
      assistantMessage: assistantMessageJson == null
          ? null
          : CBTMessageModel.fromJson(assistantMessageJson),
      currentStep: JsonHelpers.parseString(json['current_step']),
      currentPhase: JsonHelpers.parseString(json['current_phase']),
      sessionStatus: JsonHelpers.parseString(json['session_status']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_message': userMessage?.toJson(),
      'assistant_message': assistantMessage?.toJson(),
      'current_step': currentStep,
      'current_phase': currentPhase,
      'session_status': sessionStatus,
    };
  }
}