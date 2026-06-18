import 'json_helpers.dart';

class TherapistProfileModel {
  final int? id;
  final int? userId;

  final String? fullName;
  final String? qualification;

  final List<String> therapyApproaches;
  final List<String> specializations;

  final String? description;
  final String? price;

  final Map<String, dynamic>? contacts;

  final String? city;
  final bool? onlineAvailable;

  final String? status;
  final String? rejectionReason;

  final String? photoUrl;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Возвращается публичными endpoints /therapists.
  /// Для обычного пользователя показывает,
  /// добавлен ли специалист в его закладки.
  final bool isFavorite;

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
    this.isFavorite = false,
  });

  factory TherapistProfileModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return TherapistProfileModel(
      id: JsonHelpers.parseInt(
        json['id'],
      ),
      userId: _parseUserId(json),
      fullName: JsonHelpers.parseString(
        json['full_name'],
      ),
      qualification: JsonHelpers.parseString(
        json['qualification'],
      ),
      therapyApproaches: _parseStringList(
        json['therapy_approaches'],
      ),
      specializations: _parseStringList(
        json['specializations'],
      ),
      description: JsonHelpers.parseString(
        json['description'],
      ),
      price: JsonHelpers.parseString(
        json['price'],
      ),
      contacts: JsonHelpers.parseMap(
        json['contacts'],
      ),
      city: JsonHelpers.parseString(
        json['city'],
      ),
      onlineAvailable: JsonHelpers.parseBool(
        json['online_available'],
      ),
      status: JsonHelpers.parseString(
        json['status'],
      ),
      rejectionReason: JsonHelpers.parseString(
        json['rejection_reason'],
      ),
      photoUrl:
          JsonHelpers.parseString(
            json['photo_url'],
          ) ??
          JsonHelpers.parseString(
            json['photo_path'],
          ),
      createdAt: JsonHelpers.parseDateTime(
        json['created_at'],
      ),
      updatedAt: JsonHelpers.parseDateTime(
        json['updated_at'],
      ),
      isFavorite:
          JsonHelpers.parseBool(
            json['is_favorite'],
          ) ??
          false,
    );
  }

  TherapistProfileModel copyWith({
    int? id,
    int? userId,
    String? fullName,
    String? qualification,
    List<String>? therapyApproaches,
    List<String>? specializations,
    String? description,
    String? price,
    Map<String, dynamic>? contacts,
    String? city,
    bool? onlineAvailable,
    String? status,
    String? rejectionReason,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
  }) {
    return TherapistProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      qualification:
          qualification ?? this.qualification,
      therapyApproaches:
          therapyApproaches ??
          this.therapyApproaches,
      specializations:
          specializations ??
          this.specializations,
      description:
          description ?? this.description,
      price: price ?? this.price,
      contacts: contacts ?? this.contacts,
      city: city ?? this.city,
      onlineAvailable:
          onlineAvailable ??
          this.onlineAvailable,
      status: status ?? this.status,
      rejectionReason:
          rejectionReason ??
          this.rejectionReason,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt:
          createdAt ?? this.createdAt,
      updatedAt:
          updatedAt ?? this.updatedAt,
      isFavorite:
          isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'qualification': qualification,
      'therapy_approaches':
          therapyApproaches.join(', '),
      'specializations':
          specializations.join(', '),
      'description': description,
      'price': price,
      'contacts': contacts,
      'city': city,
      'online_available': onlineAvailable,
      'status': status,
      'rejection_reason': rejectionReason,
      'photo_url': photoUrl,
      'created_at':
          createdAt?.toIso8601String(),
      'updated_at':
          updatedAt?.toIso8601String(),
      'is_favorite': isFavorite,
    };
  }

  static int? _parseUserId(
    Map<String, dynamic> json,
  ) {
    final directUserId =
        JsonHelpers.parseInt(
      json['user_id'],
    );

    if (directUserId != null) {
      return directUserId;
    }

    final therapistUserId =
        JsonHelpers.parseInt(
      json['therapist_user_id'],
    );

    if (therapistUserId != null) {
      return therapistUserId;
    }

    final user = json['user'];

    if (user is Map<String, dynamic>) {
      return JsonHelpers.parseInt(
        user['id'],
      );
    }

    if (user is Map) {
      return JsonHelpers.parseInt(
        user['id'],
      );
    }

    return null;
  }

  static List<String> _parseStringList(
    dynamic value,
  ) {
    if (value == null) {
      return [];
    }

    if (value is List) {
      return value
          .map(
            (item) =>
                item.toString().trim(),
          )
          .where(
            (item) => item.isNotEmpty,
          )
          .toList();
    }

    if (value is String) {
      return value
          .split(',')
          .map(
            (item) => item.trim(),
          )
          .where(
            (item) => item.isNotEmpty,
          )
          .toList();
    }

    return [];
  }

  bool get hasPhoto {
    return photoUrl != null &&
        photoUrl!.trim().isNotEmpty;
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

  bool get isDraft {
    return status == null ||
        status == 'draft';
  }

  bool get isEmptyProfile {
    final hasText = [
      fullName,
      qualification,
      description,
      price,
      city,
    ].any(
      (value) =>
          value != null &&
          value.trim().isNotEmpty,
    );

    return !hasText &&
        therapyApproaches.isEmpty &&
        specializations.isEmpty &&
        (contacts == null ||
            contacts!.isEmpty);
  }
}