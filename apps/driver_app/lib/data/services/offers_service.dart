library driver_app.data.services.offers_service;

import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'dio_client.dart';
import '../../core/app_constants.dart';

class OffersService {
  OffersService(this._client);

  final DioClient _client;

  Future<List<dynamic>> getOffers() async => await _client.get<List<dynamic>>('/offers');

  Future<Map<String, dynamic>> acceptOffer(String offerId,
      {required String rideId, required String idempotencyKey}) async =>
      await _client.post<Map<String, dynamic>>(
        '/offers/$offerId/accept',
        data: {'ride_id': rideId},
        idempotencyKey: idempotencyKey,
      );

  Future<Map<String, dynamic>> rejectOffer(String offerId) async =>
      await _client.post<Map<String, dynamic>>('/offers/$offerId/reject', data: {});

  WebSocketChannel connectOffersWebSocket() =>
      WebSocketChannel.connect(Uri.parse('${AppConstants.wsBaseUrl}/ws/driver/offers'));
}
