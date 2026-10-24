library rider_app.data.services.ride_service;

import 'dart:math';

import 'dio_client.dart';

/// Raw API interaction for the /quotes and /rides endpoints. Returns raw API
/// models (maps) and leaves transformation to the repository layer.
class RideService {
  RideService(this._client);

  final DioClient _client;

  String _generateIdempotencyKey() {
    final ms = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random.secure().nextInt(900000) + 100000;
    return 'ride_${ms}_$random';
  }

  Future<Map<String, dynamic>> fetchQuote({
    required String pickup,
    required String destination,
  }) async =>
      await _client.post<Map<String, dynamic>>(
        '/quotes',
        data: {'pickup': pickup, 'destination': destination},
      );

  Future<Map<String, dynamic>> createRide({
    required String pickup,
    required String destination,
    required String quoteId,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _generateIdempotencyKey();
    return await _client.post<Map<String, dynamic>>(
      '/rides',
      data: {'pickup': pickup, 'destination': destination, 'quote_id': quoteId},
      idempotencyKey: key,
    );
  }

  Future<Map<String, dynamic>> cancelRide(String rideId, {String? idempotencyKey}) async {
    final key = idempotencyKey ?? _generateIdempotencyKey();
    return await _client.post<Map<String, dynamic>>(
      '/rides/$rideId/cancel',
      data: {},
      idempotencyKey: key,
    );
  }

  Future<Map<String, dynamic>> getRide(String rideId) async =>
      await _client.get<Map<String, dynamic>>('/rides/$rideId');
}
