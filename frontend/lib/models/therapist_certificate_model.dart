import 'json_helpers.dart';

class TherapistCertificateModel {
  final int? id;
  final int? therapistProfileId;
  final String? originalFilename;
  final String? filePath;
  final DateTime? uploadedAt;

  const TherapistCertificateModel({
    this.id,
    this.therapistProfileId,
    this.originalFilename,
    this.filePath,
    this.uploadedAt,
  });

  factory TherapistCertificateModel.fromJson(Map<String, dynamic> json) {
    return TherapistCertificateModel(
      id: JsonHelpers.parseInt(json['id']),
      therapistProfileId: JsonHelpers.parseInt(
        json['therapist_profile_id'],
      ),
      originalFilename: JsonHelpers.parseString(
        json['original_filename'],
      ),
      filePath: JsonHelpers.parseString(json['file_path']),
      uploadedAt: JsonHelpers.parseDateTime(json['uploaded_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'therapist_profile_id': therapistProfileId,
      'original_filename': originalFilename,
      'file_path': filePath,
      'uploaded_at': uploadedAt?.toIso8601String(),
    };
  }
}