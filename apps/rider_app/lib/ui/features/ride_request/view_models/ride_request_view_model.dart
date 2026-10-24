
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/ride_repository.dart';
import '../../../../domain/models/ride.dart';

/// ViewModel for creating and cancelling a ride request.
class RideRequestViewModel extends ChangeNotifier {
  RideRequestViewModel({required RideRepository rideRepository}) : _rideRepository = rideRepository;

  final RideRepository _rideRepository;

  RideRequestStatus _status = RideRequestStatus.idle;
  RideRequestStatus get status => _status;

  String? _rideId;
  String? get rideId => _rideId;

  String? _driverName;
  String? get driverName => _driverName;

  String? _error;
  String? get error => _error;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<bool> createRide({
    required String pickup,
    required String destination,
    required String quoteId,
  }) async {
    _status = RideRequestStatus.searching;
    _isLoading = true;
    _error = null;
    _rideId = null;
    _driverName = null;
    notifyListeners();
    try {
      final rideId = await _rideRepository.createRide(
        pickup: pickup,
        destination: destination,
        quoteId: quoteId,
      );
      _status = RideRequestStatus.searching;
      _rideId = rideId;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _status = RideRequestStatus.error;
      _isLoading = false;
      _error = 'فشل إنشاء الرحلة';
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelRide() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _rideRepository.cancelRide(_rideId ?? '');
      _status = RideRequestStatus.cancelled;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = 'فشل إلغاء الرحلة';
      notifyListeners();
      return false;
    }
  }

  void setDriverFound(String driverName) {
    _status = RideRequestStatus.driverFound;
    _driverName = driverName;
    _isLoading = false;
    notifyListeners();
  }
}

final rideRequestViewModelProvider = ChangeNotifierProvider(
  (ref) => RideRequestViewModel(rideRepository: ref.read(rideRepositoryProvider)),
);
