library driver_app.data.repositories.auth_repository;

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
    final apiModel = await _authService.verifyOtp(phone, otp);
    final result = AuthResult(accessToken: apiModel['access_token'] as String? ?? '', refreshToken: apiModel['refresh_token'] as String?);
    await _secureStorage.writeAccessToken(result.accessToken);
    if (result.refreshToken != null && result.refreshToken!.isNotEmpty) {
      await _secureStorage.writeRefreshToken(result.refreshToken!);
    }
    _accessToken = result.accessToken;
    return result;
  }

  Future<bool> registerDriver({
    required String name,
    required String phone,
    required String vehicleType,
    required String plateNumber,
    required String nationalId,
    required String licenseNumber,
  }) async {
    try {
      await _authService.registerDriver(
        name: name,
        phone: phone,
        vehicleType: vehicleType,
        plateNumber: plateNumber,
        nationalId: nationalId,
        licenseNumber: licenseNumber,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<AuthUser?> loadMe() async {
    try {
      final data = await _authService.getMe();
      return AuthUser(
        id: data['id']?.toString() ?? '',
        phone: data['phone']?.toString() ?? '',
        name: data['name'] as String?,
        verificationStatus: _parseStatus(data['verification_status']),
      );
    } catch (_) {
      return null;
    }
  }

  VerificationStatus _parseStatus(dynamic v) {
    switch (v?.toString().toLowerCase()) {
      case 'approved':
        return VerificationStatus.approved;
      case 'rejected':
        return VerificationStatus.rejected;
      case 'suspended':
        return VerificationStatus.suspended;
      default:
        return VerificationStatus.pending;
    }
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
