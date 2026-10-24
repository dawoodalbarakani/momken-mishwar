
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/ride_repository.dart';
import '../../../../domain/models/ride.dart';

class RideTrackingViewModel extends ChangeNotifier {
  RideTrackingViewModel({
    required RideRepository rideRepository,
    required this.rideId,
  }) : _rideRepository = rideRepository {
    _restore();
  }

  final RideRepository _rideRepository;
  final String rideId;

  RideStatus _status = RideStatus.assigned;
  RideStatus get status => _status;

  String? _pickup;
  String? get pickup => _pickup;

  String? _destination;
  String? get destination => _destination;

  String? _customerName;
  String? get customerName => _customerName;

  String? _customerPhone;
  String? get customerPhone => _customerPhone;

  String? _startCode;
  String? get startCode => _startCode;

  bool _verifiedAssignment = false;
  bool get verifiedAssignment => _verifiedAssignment;

  bool _started = false;
  bool get started => _started;

  bool _completed = false;
  bool get completed => _completed;

  RideCancellation? _cancellation;
  RideCancellation? get cancellation => _cancellation;

  final bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  bool get canStart => _verifiedAssignment && !_started && _status == RideStatus.assigned;
  bool get canComplete => _started && _status == RideStatus.inProgress && !_completed;

  StreamSubscription? _wsSubscription;

  Future<void> _restore() async {
    try {
      final ride = await _rideRepository.getRide(rideId);
      _status = ride.status;
      _pickup = ride.pickup;
      _destination = ride.destination;
      _customerName = ride.customerName;
      _customerPhone = ride.customerPhone;
      _startCode = ride.startCode;
      _verifiedAssignment = ride.verifiedAssignment;
    } catch (e) {
      _error = 'فشل استعادة حالة الرحلة';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyAssignment() async {
    try {
      final ok = await _rideRepository.verifyAssignment(rideId);
      _verifiedAssignment = ok;
      notifyListeners();
      return ok;
    } catch (e) {
      _error = 'فشل التحقق من الإسناد';
      notifyListeners();
      return false;
    }
  }

  Future<bool> startRide(String enteredStartCode) async {
    if (!_verifiedAssignment) {
      _error = 'يجب التحقق من إسناد الرحلة أولاً';
      notifyListeners();
      return false;
    }
    if (_startCode == null) {
      _error = 'رمز بدء الرحلة غير متوفر من الخادم';
      notifyListeners();
      return false;
    }
    if (enteredStartCode.trim() != _startCode) {
      _error = 'رمز بدء الرحلة غير صحيح';
      notifyListeners();
      return false;
    }
    try {
      final ok = await _rideRepository.startRide(rideId, startCode: enteredStartCode.trim());
      if (ok) {
        _started = true;
        _status = RideStatus.inProgress;
        notifyListeners();
      }
      return ok;
    } catch (e) {
      _error = 'فشل بدء الرحلة';
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeRide() async {
    if (!canComplete) {
      _error = 'لا يمكن إنهاء الرحلة في الحالة الحالية';
      notifyListeners();
      return false;
    }
    try {
      final ok = await _rideRepository.completeRide(rideId);
      if (ok) {
        _status = RideStatus.completed;
        _completed = true;
        notifyListeners();
      }
      return ok;
    } catch (e) {
      _error = 'فشل إنهاء الرحلة';
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelRide({required String reason, required String actor}) async {
    if (_status == RideStatus.completed || _status == RideStatus.cancelled) {
      _error = 'الرحلة مكتملة أو ملغاة مسبقاً';
      notifyListeners();
      return false;
    }
    try {
      final ok = await _rideRepository.cancelRide(rideId, reason: reason, actor: actor);
      if (ok) {
        _status = RideStatus.cancelled;
        _cancellation = RideCancellation(reason: reason, actor: actor, cancelledAt: DateTime.now());
        notifyListeners();
      }
      return ok;
    } catch (e) {
      _error = 'فشل إلغاء الرحلة';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}

final rideTrackingViewModelProvider =
    ChangeNotifierProvider.family<RideTrackingViewModel, String>(
  (ref, rideId) => RideTrackingViewModel(
    rideRepository: ref.read(rideRepositoryProvider),
    rideId: rideId,
  ),
);
