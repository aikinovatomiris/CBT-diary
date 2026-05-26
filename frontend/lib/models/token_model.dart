import 'json_helpers.dart';

class TokenModel {
  final String? accessToken;
  final String? tokenType;

  const TokenModel({
    this.accessToken,
    this.tokenType,
  });

  factory TokenModel.fromJson(Map<String, dynamic> json) {
    return TokenModel(
      accessToken: JsonHelpers.parseString(json['access_token']),
      tokenType: JsonHelpers.parseString(json['token_type']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
    };
  }

  bool get hasToken {
    return accessToken != null && accessToken!.isNotEmpty;
  }
}