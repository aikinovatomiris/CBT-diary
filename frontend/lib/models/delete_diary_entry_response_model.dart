import 'json_helpers.dart';

class DeleteDiaryEntryResponseModel {
  /// backend field: message
  final String? message;

  /// backend field: deleted_entry_id
  final int? deletedEntryId;

  const DeleteDiaryEntryResponseModel({
    this.message,
    this.deletedEntryId,
  });

  factory DeleteDiaryEntryResponseModel.fromJson(Map<String, dynamic> json) {
    return DeleteDiaryEntryResponseModel(
      message: JsonHelpers.parseString(json['message']),
      deletedEntryId: JsonHelpers.parseInt(json['deleted_entry_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'deleted_entry_id': deletedEntryId,
    };
  }
}