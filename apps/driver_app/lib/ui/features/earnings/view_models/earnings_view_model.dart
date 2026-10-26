
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/earnings_repository.dart';
import '../../../../domain/models/earnings.dart';

class EarningsNotifier extends Notifier<EarningsState> {
  @override
  EarningsState build() {
    // Deferred to the event loop: state cannot be written during build().
    Future(() => fetchEarnings());
    return const EarningsState(isLoading: true);
  }

  Future<void> fetchEarnings() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await ref.read(earningsRepositoryProvider).fetchEarnings();
      state = EarningsState(
        completedRides: result.completedRides,
        totalFare: result.totalFare,
        platformCommission: result.platformCommission,
        netPayable: result.netPayable,
        cashCollected: result.cashCollected,
        platformReceivables: result.platformReceivables,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل جلب الأرباح');
    }
  }

  Future<bool> requestPayout(double amount) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ok = await ref.read(earningsRepositoryProvider).requestPayout(amount);
      state = state.copyWith(isLoading: false);
      return ok;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل إرسال طلب التسوية');
      return false;
    }
  }
}

final earningsViewModelProvider =
    NotifierProvider<EarningsNotifier, EarningsState>(EarningsNotifier.new);
