library driver_app.domain.models.auth_user;

class AuthUser {
  const AuthUser({required this.id, required this.phone, this.name, this.verificationStatus});

  final String id;
  final String phone;
  final String? name;
  final VerificationStatus? verificationStatus;
}

enum VerificationStatus { pending, approved, rejected, suspended }

class AuthResult {
  const AuthResult({required this.accessToken, this.refreshToken, this.user});

  final String accessToken;
  final String? refreshToken;
  final AuthUser? user;
}
