import 'json_helpers.dart';

class AnalyticsDistortionModel {
  /// backend field: name
  ///
  /// В schemas.py:
  /// class AnalyticsDistortionItem(BaseModel):
  ///     name: str
  ///     count: int
  final String? name;

  final int? count;

  const AnalyticsDistortionModel({
    this.name,
    this.count,
  });

  factory AnalyticsDistortionModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsDistortionModel(
      name: JsonHelpers.parseString(json['name']),
      count: JsonHelpers.parseInt(json['count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'count': count,
    };
  }

  static List<AnalyticsDistortionModel> listFromJson(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) {
            return AnalyticsDistortionModel.fromJson(
              Map<String, dynamic>.from(item),
            );
          })
          .toList();
    }

    return [];
  }
}

class AnalyticsDistortionsResponseModel {
  /// backend response:
  /// {
  ///   "items": [
  ///     {"name": "...", "count": 1}
  ///   ]
  /// }
  final List<AnalyticsDistortionModel> items;

  const AnalyticsDistortionsResponseModel({
    this.items = const [],
  });

  factory AnalyticsDistortionsResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnalyticsDistortionsResponseModel(
      items: AnalyticsDistortionModel.listFromJson(json['items']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}