
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/services/connectivity_service.dart';
import '../../../../data/repositories/ride_repository.dart';
import '../../../../domain/models/available_ride.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required RideRepository rideRepository,
    required ConnectivityService connectivityService,
  })  : _rideRepository = rideRepository,
        _connectivityService = connectivityService {
    _listenConnectivity();
  }

  final RideRepository _rideRepository;
  final ConnectivityService _connectivityService;
  StreamSubscription? _connectivitySubscription;

  AvailabilityStatus _availability = AvailabilityStatus.offline;
  AvailabilityStatus get availability => _availability;

  List<AvailableRide> _availableRides = const [];
  List<AvailableRide> get availableRides => _availableRides;

  EarningsSummary? _earningsSummary;
  EarningsSummary? get earningsSummary => _earningsSummary;

  DateTime? _lastLocationUpdate;
  DateTime? get lastLocationUpdate => _lastLocationUpdate;

  ConnectionStatus _connectionStatus = ConnectionStatus.unknown;
  ConnectionStatus get connectionStatus => _connectionStatus;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  void _listenConnectivity() {
    _connectivitySubscription = _connectivityService.watch().listen((status) {
      _connectionStatus = status;
      notifyListeners();
    });
  }

  Future<bool> toggleAvailability() async {
    final target = _availability == AvailabilityStatus.offline ? AvailabilityStatus.online : AvailabilityStatus.offline;
    _setLoading(true, error: null);
    try {
      final ok = await _rideRepository.toggleAvailability(available: target == AvailabilityStatus.online);
      if (ok) {
        _availability = target;
      }
      _setLoading(false);
      return ok;
    } catch (e) {
      _setLoading(false, error: 'فشل تغيير حالة التوفر');
      return false;
    }
  }

  Future<void> fetchAvailableRides() async {
    _setLoading(true, error: null);
    try {
      _availableRides = await _rideRepository.fetchAvailableRides();
      _setLoading(false);
    } catch (e) {
      _setLoading(false, error: 'فشل جلب الرحلات المتاحة');
    }
  }

  Future<void> fetchEarningsSummary() async {
    try {
      // Earnings summary fetched via earnings repository; kept here for home screen aggregation.
    } catch (e) {
      // non-fatal
    }
  }

  Future<void> updateLocation(double latitude, double longitude) async {
    try {
      await _rideRepository.updateLocation(latitude: latitude, longitude: longitude);
      _lastLocationUpdate = DateTime.now();
      notifyListeners();
    } catch (e) {
      // non-fatal
    }
  }

  void _setLoading(bool loading, {String? error}) {
    _isLoading = loading;
    if (error != null) _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

final homeViewModelProvider = ChangeNotifierProvider(
  (ref) => HomeViewModel(
    rideRepository: ref.read(rideRepositoryProvider),
    connectivityService: ref.read(connectivityServiceProvider),
  ),
);
