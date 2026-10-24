library driver_app.data.services.ride_service;

import 'dart:math';

import 'dio_client.dart';

class RideService {
  RideService(this._client);

  final DioClient _client;

  String _generateIdempotencyKey() {
    final ms = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random.secure().nextInt(900000) + 100000;
    return 'ride_${ms}_$random';
  }

  Future<Map<String, dynamic>> getMe() async => await _client.get<Map<String, dynamic>>('/drivers/me');

  Future<List<dynamic>> getAvailableRides() async =>
      await _client.get<List<dynamic>>('/rides/available');

  Future<Map<String, dynamic>> toggleAvailability({required bool available}) async =>
      await _client.patch<Map<String, dynamic>>(
        '/driver/availability',
        data: {'available': available},
      );

  Future<Map<String, dynamic>> updateLocation({required double latitude, required double longitude}) async =>
      await _client.post<Map<String, dynamic>>(
        '/driver/location',
        data: {'latitude': latitude, 'longitude': longitude},
      );

  Future<Map<String, dynamic>> getRide(String rideId) async =>
      await _client.get<Map<String, dynamic>>('/rides/$rideId');

  Future<Map<String, dynamic>> verifyAssignment(String rideId) async =>
      await _client.get<Map<String, dynamic>>('/rides/$rideId/verify');

  Future<Map<String, dynamic>> startRide(String rideId, {required String startCode}) async =>
      await _client.post<Map<String, dynamic>>(
        '/rides/$rideId/start',
        data: {'start_code': startCode},
      );

  Future<Map<String, dynamic>> completeRide(String rideId) async =>
      await _client.post<Map<String, dynamic>>('/rides/$rideId/complete', data: {});

  Future<Map<String, dynamic>> cancelRide(String rideId,
      {required String reason, required String actor, String? idempotencyKey}) async {
    final key = idempotencyKey ?? _generateIdempotencyKey();
    return await _client.post<Map<String, dynamic>>(
      '/rides/$rideId/cancel',
      data: {'reason': reason, 'actor': actor},
      idempotencyKey: key,
    );
  }
}
