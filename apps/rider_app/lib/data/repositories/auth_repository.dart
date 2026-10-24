library rider_app.data.repositories.auth_repository;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/otp_verify_api_model.dart';
import '../../domain/models/auth_result.dart';
import '../services/auth_service.dart';
import '../services/secure_storage_service.dart';

/// Single source of truth for authentication. Transforms raw API models into
/// domain [AuthResult] and persists the session token.
class AuthRepository {
  AuthRepository({required AuthService authService, required SecureStorageService secureStorage})
      : _authService = authService,
        _secureStorage = secureStorage;

  final AuthService _authService;
  final SecureStorageService _secureStorage;

  String? _accessToken;

  /// Requests an OTP for the given phone number.
  Future<bool> requestOtp(String phone) async {
    try {
      await _authService.requestOtp(phone);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Verifies the OTP, persists the token, and returns the session result.
  Future<AuthResult> verifyOtp(String phone, String otp) async {
    final apiModel = await _authService.verifyOtp(phone, otp);
    final result = AuthResult(
      accessToken: apiModel.accessToken,
      refreshToken: apiModel.refreshToken,
    );
    await _secureStorage.writeAccessToken(result.accessToken);
    if (result.refreshToken != null && result.refreshToken!.isNotEmpty) {
      await _secureStorage.writeRefreshToken(result.refreshToken!);
    }
    _accessToken = result.accessToken;
    return result;
  }

  /// Current access token, loaded from secure storage on first access.
  Future<String?> get accessToken async => _accessToken ?? await _secureStorage.readAccessToken();

  /// Clears the session token and logs the user out.
  Future<void> logout() async {
    await _secureStorage.clear();
    _accessToken = null;
  }
}

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    authService: AuthService(ref.read(dioClientProvider)),
    secureStorage: ref.read(secureStorageProvider),
  ),
);
