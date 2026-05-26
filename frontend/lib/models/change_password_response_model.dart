import 'json_helpers.dart';

class ChangePasswordResponseModel {
  /// backend field: message
  final String? message;

  const ChangePasswordResponseModel({
    this.message,
  });

  factory ChangePasswordResponseModel.fromJson(Map<String, dynamic> json) {
    return ChangePasswordResponseModel(
      message: JsonHelpers.parseString(json['message']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
    };
  }
}