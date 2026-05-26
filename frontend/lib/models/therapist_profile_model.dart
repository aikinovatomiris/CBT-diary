import 'json_helpers.dart';

class TherapistProfileModel {
  final int? id;
  final int? userId;

  final String? fullName;
  final String? qualification;

  final List<String> therapyApproaches;
  final List<String> specializations;

  final String? description;
  final double? price;

  final Map<String, dynamic>? contacts;

  final String? city;
  final bool? onlineAvailable;

  final String? status;
  final String? rejectionReason;

  ///
  /// Может быть null. На UI позже покажем дефолтный аватар.
  final String? photoUrl;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TherapistProfileModel({
    this.id,
    this.userId,
    this.fullName,
    this.qualification,
    this.therapyApproaches = const [],
    this.specializations = const [],
    this.description,
    this.price,
    this.contacts,
    this.city,
    this.onlineAvailable,
    this.status,
    this.rejectionReason,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory TherapistProfileModel.fromJson(Map<String, dynamic> json) {
    return TherapistProfileModel(
      id: JsonHelpers.parseInt(json['id']),
      userId: JsonHelpers.parseInt(json['user_id']),
      fullName: JsonHelpers.parseString(json['full_name']),
      qualification: JsonHelpers.parseString(json['qualification']),
      therapyApproaches: JsonHelpers.parseStringList(
        json['therapy_approaches'],
      ),
      specializations: JsonHelpers.parseStringList(
        json['specializations'],
      ),
      description: JsonHelpers.parseString(json['description']),
      price: JsonHelpers.parseDouble(json['price']),
      contacts: JsonHelpers.parseMap(json['contacts']),
      city: JsonHelpers.parseString(json['city']),
      onlineAvailable: JsonHelpers.parseBool(json['online_available']),
      status: JsonHelpers.parseString(json['status']),
      rejectionReason: JsonHelpers.parseString(json['rejection_reason']),
      photoUrl: JsonHelpers.parseString(json['photo_url']),
      createdAt: JsonHelpers.parseDateTime(json['created_at']),
      updatedAt: JsonHelpers.parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'qualification': qualification,
      'therapy_approaches': therapyApproaches,
      'specializations': specializations,
      'description': description,
      'price': price,
      'contacts': contacts,
      'city': city,
      'online_available': onlineAvailable,
      'status': status,
      'rejection_reason': rejectionReason,
      'photo_url': photoUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get hasPhoto {
    return photoUrl != null && photoUrl!.trim().isNotEmpty;
  }

  bool get isApproved {
    return status == 'approved';
  }

  bool get isPending {
    return status == 'pending';
  }

  bool get isRejected {
    return status == 'rejected';
  }
}