library driver_app.ui.features.earnings.view_models.earnings_view_model;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/earnings_repository.dart';
import '../../../../domain/models/earnings.dart';

class EarningsViewModel extends ChangeNotifier {
  EarningsViewModel({required EarningsRepository earningsRepository}) : _earningsRepository = earningsRepository {
    fetchEarnings();
  }

  final EarningsRepository _earningsRepository;

  List<CompletedRide> _completedRides = const [];
  List<CompletedRide> get completedRides => _completedRides;

  double _totalFare = 0;
  double get totalFare => _totalFare;

  double _platformCommission = 0;
  double get platformCommission => _platformCommission;

  double _netPayable = 0;
  double get netPayable => _netPayable;

  double _cashCollected = 0;
  double get cashCollected => _cashCollected;

  double _platformReceivables = 0;
  double get platformReceivables => _platformReceivables;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> fetchEarnings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final state = await _earningsRepository.fetchEarnings();
      _completedRides = state.completedRides;
      _totalFare = state.totalFare;
      _platformCommission = state.platformCommission;
      _netPayable = state.netPayable;
      _cashCollected = state.cashCollected;
      _platformReceivables = state.platformReceivables;
    } catch (e) {
      _error = 'فشل جلب الأرباح';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> requestPayout(double amount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final ok = await _earningsRepository.requestPayout(amount);
      _isLoading = false;
      notifyListeners();
      return ok;
    } catch (e) {
      _isLoading = false;
      _error = 'فشل إرسال طلب التسوية';
      notifyListeners();
      return false;
    }
  }
}

final earningsViewModelProvider = ChangeNotifierProvider(
  (ref) => EarningsViewModel(earningsRepository: ref.read(earningsRepositoryProvider)),
);
