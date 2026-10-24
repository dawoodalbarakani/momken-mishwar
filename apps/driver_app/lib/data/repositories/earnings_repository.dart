library driver_app.data.repositories.earnings_repository;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/earnings.dart';
import '../services/dio_client.dart';
import '../services/earnings_service.dart';

class EarningsRepository {
  EarningsRepository({required EarningsService earningsService}) : _earningsService = earningsService;

  final EarningsService _earningsService;

  Future<EarningsState> fetchEarnings() async {
    final data = await _earningsService.getEarnings();
    final rides = (data['rides'] as List<dynamic>? ?? [])
        .map((e) => CompletedRide(
              rideId: e['ride_id']?.toString() ?? '',
              fare: (e['fare'] as num?)?.toDouble() ?? 0,
              platformCommission: (e['platform_commission'] as num?)?.toDouble() ?? 0,
              netToDriver: (e['net_to_driver'] as num?)?.toDouble() ?? 0,
              cashCollected: (e['cash_collected'] as num?)?.toDouble() ?? 0,
              completedAt: e['completed_at'] != null
                  ? DateTime.tryParse(e['completed_at'].toString()) ?? DateTime.now()
                  : DateTime.now(),
            ))
        .toList();
    return EarningsState(
      completedRides: rides,
      totalFare: (data['total_fare'] as num?)?.toDouble() ?? 0,
      platformCommission: (data['platform_commission'] as num?)?.toDouble() ?? 0,
      netPayable: (data['net_payable'] as num?)?.toDouble() ?? 0,
      cashCollected: (data['cash_collected'] as num?)?.toDouble() ?? 0,
      platformReceivables: (data['platform_receivables'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<bool> requestPayout(double amount) async {
    try {
      await _earningsService.requestPayout(amount);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final earningsRepositoryProvider = Provider(
  (ref) => EarningsRepository(earningsService: EarningsService(ref.read(dioClientProvider))),
);
