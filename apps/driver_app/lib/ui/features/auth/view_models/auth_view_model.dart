library driver_app.ui.features.auth.view_models.auth_view_model;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../domain/models/auth_user.dart';

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

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isApproved => _user?.verificationStatus == VerificationStatus.approved;

  Future<bool> initialize() async {
    _setLoading(true, error: null);
    try {
      _token = await _authRepository.accessToken;
      if (_token != null && _token!.isNotEmpty) {
        _user = await _authRepository.loadMe();
      }
    } finally {
      _setLoading(false);
    }
    return isAuthenticated;
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
    } catch (e) {
      _setLoading(false, error: 'فشل التحقق من الرمز');
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
    _setLoading(true, error: null);
    try {
      final ok = await _authRepository.registerDriver(
        name: name,
        phone: phone,
        vehicleType: vehicleType,
        plateNumber: plateNumber,
        nationalId: nationalId,
        licenseNumber: licenseNumber,
      );
      _setLoading(false);
      return ok;
    } catch (e) {
      _setLoading(false, error: 'فشل تسجيل السائق');
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
