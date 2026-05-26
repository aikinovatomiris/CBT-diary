import 'json_helpers.dart';
import 'therapist_certificate_model.dart';
import 'therapist_profile_model.dart';

class AdminModel {
  final int totalUsers;
  final int totalTherapists;
  final int pendingTherapists;
  final int approvedTherapists;
  final int rejectedTherapists;
  final int totalDiaryEntries;
  final int totalCbtSessions;

  final Map<String, dynamic> rawJson;

  const AdminModel({
    this.totalUsers = 0,
    this.totalTherapists = 0,
    this.pendingTherapists = 0,
    this.approvedTherapists = 0,
    this.rejectedTherapists = 0,
    this.totalDiaryEntries = 0,
    this.totalCbtSessions = 0,
    this.rawJson = const {},
  });

  factory AdminModel.fromJson(Map<String, dynamic> json) {
    return AdminModel(
      totalUsers: JsonHelpers.parseInt(json['total_users']) ?? 0,
      totalTherapists: JsonHelpers.parseInt(json['total_therapists']) ?? 0,
      pendingTherapists: JsonHelpers.parseInt(json['pending_therapists']) ?? 0,
      approvedTherapists:
          JsonHelpers.parseInt(json['approved_therapists']) ?? 0,
      rejectedTherapists:
          JsonHelpers.parseInt(json['rejected_therapists']) ?? 0,
      totalDiaryEntries:
          JsonHelpers.parseInt(json['total_diary_entries']) ?? 0,
      totalCbtSessions:
          JsonHelpers.parseInt(json['total_cbt_sessions']) ??
              JsonHelpers.parseInt(json['total_sessions']) ??
              0,
      rawJson: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_users': totalUsers,
      'total_therapists': totalTherapists,
      'pending_therapists': pendingTherapists,
      'approved_therapists': approvedTherapists,
      'rejected_therapists': rejectedTherapists,
      'total_diary_entries': totalDiaryEntries,
      'total_cbt_sessions': totalCbtSessions,
    };
  }
}

class AdminTherapistDetailModel {
  final TherapistProfileModel profile;
  final List<TherapistCertificateModel> certificates;
  final Map<String, dynamic> rawJson;

  const AdminTherapistDetailModel({
    required this.profile,
    this.certificates = const [],
    this.rawJson = const {},
  });

  factory AdminTherapistDetailModel.fromJson(Map<String, dynamic> json) {
    final profileJson = _extractProfileJson(json);

    return AdminTherapistDetailModel(
      profile: TherapistProfileModel.fromJson(profileJson),
      certificates: _parseCertificates(json['certificates']),
      rawJson: json,
    );
  }

  static Map<String, dynamic> _extractProfileJson(Map<String, dynamic> json) {
    final profile = json['profile'];

    if (profile is Map<String, dynamic>) {
      return profile;
    }

    if (profile is Map) {
      return Map<String, dynamic>.from(profile);
    }

    return json;
  }

  static List<TherapistCertificateModel> _parseCertificates(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((item) {
        return TherapistCertificateModel.fromJson(
          Map<String, dynamic>.from(item),
        );
      }).toList();
    }

    return [];
  }
}