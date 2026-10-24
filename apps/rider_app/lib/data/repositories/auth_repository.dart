
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/auth_user.dart';
import '../services/auth_service.dart';
import '../services/dio_client.dart';
import '../services/secure_storage_service.dart';

class AuthRepository {
  AuthRepository({required AuthService authService, required SecureStorageService secureStorage})
      : _authService = authService,
        _secureStorage = secureStorage;

  final AuthService _authService;
  final SecureStorageService _secureStorage;

  String? _accessToken;

  Future<bool> requestOtp(String phone) async {
    try {
      await _authService.requestOtp(phone);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<AuthResult> verifyOtp(String phone, String otp) async {
    final data = await _authService.verifyOtp(phone, otp);
    final result = AuthResult(
      accessToken: data['access_token'] as String? ?? '',
      refreshToken: data['refresh_token'] as String?,
    );
    await _secureStorage.writeAccessToken(result.accessToken);
    if (result.refreshToken != null && result.refreshToken!.isNotEmpty) {
      await _secureStorage.writeRefreshToken(result.refreshToken!);
    }
    _accessToken = result.accessToken;
    return result;
  }

  Future<String?> get accessToken async => _accessToken ?? await _secureStorage.readAccessToken();

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
