library driver_app.data.services.auth_service;

import 'dio_client.dart';

class AuthService {
  AuthService(this._client);

  final DioClient _client;

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    await _client.post('/auth/otp/request', data: {'phone': phone});
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async =>
      await _client.post<Map<String, dynamic>>(
        '/auth/otp/verify',
        data: {'phone': phone, 'otp': otp},
      );

  Future<Map<String, dynamic>> registerDriver({
    required String name,
    required String phone,
    required String vehicleType,
    required String plateNumber,
    required String nationalId,
    required String licenseNumber,
  }) async =>
      await _client.post<Map<String, dynamic>>(
        '/drivers/register',
        data: {
          'name': name,
          'phone': phone,
          'vehicle_type': vehicleType,
          'plate_number': plateNumber,
          'national_id': nationalId,
          'license_number': licenseNumber,
        },
      );

  Future<Map<String, dynamic>> getMe() async =>
      await _client.get<Map<String, dynamic>>('/drivers/me');
}
