library driver_app.features.earnings.earnings_provider;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/secure_storage.dart';

class CompletedRide {
  const CompletedRide({
    required this.rideId,
    required this.fare,
    required this.platformCommission,
    required this.netToDriver,
    required this.cashCollected,
    required this.completedAt,
  });
  final String rideId;
  final double fare;
  final double platformCommission;
  final double netToDriver;
  final double cashCollected;
  final DateTime completedAt;
}

class EarningsState {
  const EarningsState({
    this.completedRides = const [],
    this.totalFare = 0,
    this.platformCommission = 0,
    this.netPayable = 0,
    this.cashCollected = 0,
    this.platformReceivables = 0,
    this.isLoading = false,
    this.error,
  });
  final List<CompletedRide> completedRides;
  final double totalFare;        // إجمالي الأجرة من الرحلات المكتملة
  final double platformCommission; // عمولة المنصة
  final double netPayable;       // صافي مستحقات السائق
  final double cashCollected;    // نقد محصل من الركاب
  final double platformReceivables; // مستحقات المنصة على السائق (نقد محصل - عمولة مستحقة)
  final bool isLoading;
  final String? error;

  EarningsState copyWith({List<CompletedRide>? completedRides, double? totalFare, double? platformCommission, double? netPayable, double? cashCollected, double? platformReceivables, bool? isLoading, String? error}) {
    return EarningsState(
      completedRides: completedRides ?? this.completedRides,
      totalFare: totalFare ?? this.totalFare,
      platformCommission: platformCommission ?? this.platformCommission,
      netPayable: netPayable ?? this.netPayable,
      cashCollected: cashCollected ?? this.cashCollected,
      platformReceivables: platformReceivables ?? this.platformReceivables,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class EarningsNotifier extends StateNotifier<EarningsState> {
  EarningsNotifier(this._client) : super(const EarningsState()) {
    fetchEarnings();
  }

  final DioClient _client;

  Future<void> fetchEarnings() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _client.get<Map<String, dynamic>>('/earnings');
      final rides = (data?['rides'] as List<dynamic>? ?? [])
          .map((e) => CompletedRide(
                rideId: e['ride_id']?.toString() ?? '',
                fare: (e['fare'] as num?)?.toDouble() ?? 0,
                platformCommission: (e['platform_commission'] as num?)?.toDouble() ?? 0,
                netToDriver: (e['net_to_driver'] as num?)?.toDouble() ?? 0,
                cashCollected: (e['cash_collected'] as num?)?.toDouble() ?? 0,
                completedAt: e['completed_at'] != null ? DateTime.tryParse(e['completed_at'].toString()) ?? DateTime.now() : DateTime.now(),
              ))
          .toList();
      state = state.copyWith(
        completedRides: rides,
        totalFare: (data?['total_fare'] as num?)?.toDouble() ?? 0,
        platformCommission: (data?['platform_commission'] as num?)?.toDouble() ?? 0,
        netPayable: (data?['net_payable'] as num?)?.toDouble() ?? 0,
        cashCollected: (data?['cash_collected'] as num?)?.toDouble() ?? 0,
        platformReceivables: (data?['platform_receivables'] as num?)?.toDouble() ?? 0,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل جلب الأرباح');
    }
  }

  Future<bool> requestPayout(double amount) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _client.post('/earnings/payout-request', data: {'amount': amount});
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل إرسال طلب التسوية');
      return false;
    }
  }
}

final earningsProvider = StateNotifierProvider<EarningsNotifier, EarningsState>((ref) {
  return EarningsNotifier(DioClient(SecureStorage.instance));
});
