library rider_app.features.auth.auth_provider;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/secure_storage.dart';
import '../../core/constants.dart';

class AuthUser {
  const AuthUser({required this.id, required this.phone, this.name});
  final String id;
  final String phone;
  final String? name;
}

class AuthState {
  const AuthState({this.user, this.token, this.isLoading = false, this.error});
  final AuthUser? user;
  final String? token;
  final bool isLoading;
  final String? error;

  AuthState copyWith({AuthUser? user, String? token, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
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
      // TODO: fetch GET /v1/me to populate user once server contract is stable.
    }
    state = state.copyWith(isLoading: false);
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

  Future<void> logout() async {
    await SecureStorage.instance.clear();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(DioClient(SecureStorage.instance)); // TODO: inject a shared DioClient instance
});
