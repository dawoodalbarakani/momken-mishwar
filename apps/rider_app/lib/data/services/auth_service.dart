
import 'dio_client.dart';

/// Raw API interaction for the /auth endpoints. Returns raw API models (maps)
/// and leaves transformation to the repository layer.
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
}
