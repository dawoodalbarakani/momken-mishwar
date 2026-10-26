
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../domain/models/auth_user.dart';

class AuthState {
  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
  });

  final AuthUser? user;
  final String? token;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => token != null && token!.isNotEmpty;
  bool get isApproved => user?.verificationStatus == VerificationStatus.approved;

  AuthState copyWith({
    AuthUser? user,
    String? token,
    bool? isLoading,
    String? error,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearSession ? null : (user ?? this.user),
      token: clearSession ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  Future<bool> initialize() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await _authRepository.accessToken;
      if (token != null && token.isNotEmpty) {
        final user = await _authRepository.loadMe();
        state = state.copyWith(token: token, user: user, isLoading: false);
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> requestOtp(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ok = await _authRepository.requestOtp(phone);
      state = state.copyWith(isLoading: false);
      return ok;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل طلب رمز التحقق');
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _authRepository.verifyOtp(phone, otp);
      state = state.copyWith(
        token: result.accessToken,
        user: result.user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل التحقق من الرمز');
      return false;
    }
  }

  Future<bool> registerDriver({
    required String name,
    required String phone,
    required String vehicleType,
    required String plateNumber,
    required String nationalId,
    required String licenseNumber,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ok = await _authRepository.registerDriver(
        name: name,
        phone: phone,
        vehicleType: vehicleType,
        plateNumber: plateNumber,
        nationalId: nationalId,
        licenseNumber: licenseNumber,
      );
      state = state.copyWith(isLoading: false);
      return ok;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل تسجيل السائق');
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    state = const AuthState();
  }
}

final authViewModelProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
