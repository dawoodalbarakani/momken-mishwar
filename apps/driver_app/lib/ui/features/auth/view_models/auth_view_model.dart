
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../domain/models/auth_user.dart';

class AuthState {
  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
    this.isInitializing = true,
  });

  final AuthUser? user;
  final String? token;
  final bool isLoading;
  final String? error;

  /// True until the one-time session restore has completed. The router uses
  /// this to hold on the splash until auth is known.
  final bool isInitializing;

  bool get isAuthenticated => token != null && token!.isNotEmpty;
  bool get isApproved => user?.verificationStatus == VerificationStatus.approved;

  AuthState copyWith({
    AuthUser? user,
    String? token,
    bool? isLoading,
    String? error,
    bool? isInitializing,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearSession ? null : (user ?? this.user),
      token: clearSession ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isInitializing: isInitializing ?? this.isInitializing,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuthState &&
      other.user == user &&
      other.token == token &&
      other.isLoading == isLoading &&
      other.error == error &&
      other.isInitializing == isInitializing;

  @override
  int get hashCode => Object.hash(user, token, isLoading, error, isInitializing);
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
        state = state.copyWith(
          token: token,
          user: user,
          isLoading: false,
          isInitializing: false,
        );
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isInitializing: false,
        error: 'تعذر استعادة الجلسة',
      );
      return false;
    } finally {
      // Guarantees the splash resolves even when the token path is taken or an
      // error was thrown above.
      state = state.copyWith(isLoading: false, isInitializing: false);
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
    // isInitializing: false → the guard sends us straight to /login instead of
    // re-showing the splash.
    state = const AuthState(isInitializing: false);
  }
}

final authViewModelProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
