library rider_app.domain.models.auth_user;

/// Clean domain model for an authenticated rider.
class AuthUser {
  const AuthUser({required this.id, required this.phone, this.name});

  final String id;
  final String phone;
  final String? name;
}

/// Result of a successful OTP verification, carrying the session token.
class AuthResult {
  const AuthResult({required this.accessToken, this.refreshToken, this.user});

  final String accessToken;
  final String? refreshToken;
  final AuthUser? user;
}
