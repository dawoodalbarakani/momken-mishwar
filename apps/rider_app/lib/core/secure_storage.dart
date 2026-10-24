library rider_app.core.secure_storage;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted key-value storage for sensitive data (access / refresh tokens).
class SecureStorage {
  SecureStorage._internal();
  static final SecureStorage instance = SecureStorage._internal();

  static const String accessTokenKey = 'mishwar_access_token';
  static const String refreshTokenKey = 'mishwar_refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> writeAccessToken(String token) async {
    await _storage.write(key: accessTokenKey, value: token);
  }

  Future<String?> readAccessToken() async {
    return await _storage.read(key: accessTokenKey);
  }

  Future<void> writeRefreshToken(String token) async {
    await _storage.write(key: refreshTokenKey, value: token);
  }

  Future<String?> readRefreshToken() async {
    return await _storage.read(key: refreshTokenKey);
  }

  Future<void> clear() async {
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: refreshTokenKey);
  }
}
