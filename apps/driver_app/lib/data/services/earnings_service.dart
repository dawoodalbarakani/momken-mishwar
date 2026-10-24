library driver_app.data.services.earnings_service;

import 'dio_client.dart';

class EarningsService {
  EarningsService(this._client);

  final DioClient _client;

  Future<Map<String, dynamic>> getEarnings() async =>
      await _client.get<Map<String, dynamic>>('/earnings');

  Future<Map<String, dynamic>> requestPayout(double amount) async =>
      await _client.post<Map<String, dynamic>>(
        '/earnings/payout-request',
        data: {'amount': amount},
      );
}
