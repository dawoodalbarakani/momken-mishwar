
/// Raw API model for POST /auth/otp/verify.
class OtpVerifyApiModel {
  const OtpVerifyApiModel({required this.accessToken, this.refreshToken});

  final String accessToken;
  final String? refreshToken;

  factory OtpVerifyApiModel.fromJson(Map<String, dynamic> json) {
    return OtpVerifyApiModel(
      accessToken: (json['access_token'] as String?) ?? '',
      refreshToken: json['refresh_token'] as String?,
    );
  }
}
