import 'json_helpers.dart';

class AnalyticsTechniqueModel {
  /// backend field: technique
  final String? technique;

  final int? count;

  const AnalyticsTechniqueModel({
    this.technique,
    this.count,
  });

  factory AnalyticsTechniqueModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsTechniqueModel(
      technique: JsonHelpers.parseString(json['technique']),
      count: JsonHelpers.parseInt(json['count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'technique': technique,
      'count': count,
    };
  }

  static List<AnalyticsTechniqueModel> listFromJson(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) {
            return AnalyticsTechniqueModel.fromJson(
              Map<String, dynamic>.from(item),
            );
          })
          .toList();
    }

    return [];
  }
}

class AnalyticsTechniquesResponseModel {
  /// backend response:
  /// {
  ///   "items": [
  ///     {"technique": "...", "count": 1}
  ///   ]
  /// }
  final List<AnalyticsTechniqueModel> items;

  const AnalyticsTechniquesResponseModel({
    this.items = const [],
  });

  factory AnalyticsTechniquesResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnalyticsTechniquesResponseModel(
      items: AnalyticsTechniqueModel.listFromJson(json['items']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}