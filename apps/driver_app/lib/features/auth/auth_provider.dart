library driver_app.features.auth.auth_provider;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/secure_storage.dart';
import '../../core/constants.dart';

enum VerificationStatus { pending, approved, rejected, suspended }

class AuthUser {
  const AuthUser({required this.id, required this.phone, this.name, this.verificationStatus});
  final String id;
  final String phone;
  final String? name;
  final VerificationStatus? verificationStatus;
}

class AuthState {
  const AuthState({this.user, this.token, this.verificationStatus, this.isLoading = false, this.error});
  final AuthUser? user;
  final String? token;
  final VerificationStatus? verificationStatus;
  final bool isLoading;
  final String? error;

  AuthState copyWith({AuthUser? user, String? token, VerificationStatus? verificationStatus, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get isAuthenticated => token != null && token!.isNotEmpty;
  bool get isApproved => verificationStatus == VerificationStatus.approved;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._client) : super(const AuthState()) {
    _load();
  }

  final DioClient _client;

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    final token = await SecureStorage.instance.readAccessToken();
    if (token != null && token.isNotEmpty) {
      state = state.copyWith(token: token);
      try {
        final data = await _client.get<Map<String, dynamic>>('/drivers/me');
        state = state.copyWith(
          user: AuthUser(
            id: data?['id']?.toString() ?? '',
            phone: data?['phone']?.toString() ?? '',
            name: data?['name']?.toString(),
            verificationStatus: _parseStatus(data?['verification_status']),
          ),
          verificationStatus: _parseStatus(data?['verification_status']),
        );
      } catch (e) {
        // keep token; profile fetch non-fatal
      }
    }
    state = state.copyWith(isLoading: false);
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

  Future<bool> requestOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _client.post('/auth/otp/request', data: {'phone': phone});
      state = state.copyWith(isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.messageAr);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل طلب رمز التحقق');
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _client.post<Map<String, dynamic>>(
        '/auth/otp/verify',
        data: {'phone': phone, 'otp': otp},
      );
      final token = data?['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw ApiException(code: 'NO_TOKEN', messageAr: 'لم يُرجَع توكن من الخادم', messageEn: 'No token returned from server');
      }
      await SecureStorage.instance.writeAccessToken(token);
      final refresh = data?['refresh_token'];
      if (refresh != null) await SecureStorage.instance.writeRefreshToken(refresh.toString());
      state = state.copyWith(isLoading: false, token: token);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.messageAr);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل التحقق من الرمز');
      return false;
    }
  }

  Future<bool> registerDriver({required String name, required String phone, required String vehicleType, required String plateNumber, required String nationalId, required String licenseNumber}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _client.post('/drivers/register', data: {
        'name': name,
        'phone': phone,
        'vehicle_type': vehicleType,
        'plate_number': plateNumber,
        'national_id': nationalId,
        'license_number': licenseNumber,
      });
      state = state.copyWith(isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.messageAr);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل تسجيل السائق');
      return false;
    }
  }

  Future<void> logout() async {
    await SecureStorage.instance.clear();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(DioClient(SecureStorage.instance));
});
