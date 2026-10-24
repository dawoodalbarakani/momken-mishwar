library rider_app.ui.features.auth.view_models.auth_view_model;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/services/dio_client.dart';
import '../../../../domain/models/auth_result.dart';
import '../../../../domain/models/auth_user.dart';

/// ViewModel for the authentication flow (request / verify OTP).
class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required AuthRepository authRepository}) : _authRepository = authRepository;

  final AuthRepository _authRepository;

  AuthUser? _user;
  AuthUser? get user => _user;

  String? _token;
  String? get token => _token;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  /// Loads any persisted session token on startup.
  Future<bool> initialize() async {
    _setLoading(true, error: null);
    try {
      _token = await _authRepository.accessToken;
      // TODO: fetch GET /v1/me to populate [user] once the server contract is stable.
    } finally {
      _setLoading(false);
    }
    return _token != null && _token!.isNotEmpty;
  }

  Future<bool> requestOtp(String phone) async {
    _setLoading(true, error: null);
    try {
      final ok = await _authRepository.requestOtp(phone);
      _setLoading(false);
      return ok;
    } catch (e) {
      _setLoading(false, error: 'فشل طلب رمز التحقق');
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    _setLoading(true, error: null);
    try {
      final result = await _authRepository.verifyOtp(phone, otp);
      _token = result.accessToken;
      _user = result.user;
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setLoading(false, error: e.messageAr);
      return false;
    } catch (e) {
      _setLoading(false, error: 'فشل التحقق من الرمز');
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _token = null;
    _user = null;
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool loading, {String? error}) {
    _isLoading = loading;
    if (error != null) _error = error;
    notifyListeners();
  }
}

final authViewModelProvider = ChangeNotifierProvider(
  (ref) => AuthViewModel(authRepository: ref.read(authRepositoryProvider)),
);
