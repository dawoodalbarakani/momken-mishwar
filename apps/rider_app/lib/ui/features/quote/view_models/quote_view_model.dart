library rider_app.ui.features.quote.view_models.quote_view_model;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/ride_repository.dart';
import '../../../../domain/models/quote.dart';

/// ViewModel for the fare quote screen.
class QuoteViewModel extends ChangeNotifier {
  QuoteViewModel({required RideRepository rideRepository}) : _rideRepository = rideRepository;

  final RideRepository _rideRepository;

  Quote? _quote;
  Quote? get quote => _quote;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<bool> fetchQuote({required String pickup, required String destination}) async {
    _setLoading(true, error: null);
    try {
      _quote = await _rideRepository.fetchQuote(pickup: pickup, destination: destination);
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false, error: 'فشل جلب تقدير الأجرة');
      return false;
    }
  }

  void _setLoading(bool loading, {String? error}) {
    _isLoading = loading;
    if (error != null) _error = error;
    notifyListeners();
  }
}

final quoteViewModelProvider = ChangeNotifierProvider(
  (ref) => QuoteViewModel(rideRepository: ref.read(rideRepositoryProvider)),
);
