
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/app_constants.dart';
import '../../../../data/repositories/ride_repository.dart';

/// ViewModel for live ride tracking: driver location, vehicle info, WebSocket events.
class RideTrackingViewModel extends ChangeNotifier {
  RideTrackingViewModel({
    required RideRepository rideRepository,
    required this.rideId,
  })  : _rideRepository = rideRepository {
    _restore();
    _connectWebSocket('');
  }

  final RideRepository _rideRepository;
  final String rideId;

  String? _driverName;
  String? get driverName => _driverName;

  String? _vehiclePlate;
  String? get vehiclePlate => _vehiclePlate;

  LatLng? _driverLocation;
  LatLng? get driverLocation => _driverLocation;

  int? _locationAgeSeconds;
  int? get locationAgeSeconds => _locationAgeSeconds;

  String? _startCode;
  String? get startCode => _startCode;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;

  /// Returns true if the driver location is fresh enough to be shown as live.
  bool get isLocationFresh {
    final age = _locationAgeSeconds;
    return age != null && age < 30;
  }

  Future<void> _restore() async {
    try {
      final ride = await _rideRepository.getRide(rideId);
      _driverName = ride.driverName;
      _vehiclePlate = ride.vehiclePlate;
      _startCode = ride.startCode;
    } catch (e) {
      _error = 'فشل استعادة حالة الرحلة';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _connectWebSocket(String token) {
    _channel = WebSocketChannel.connect(Uri.parse('${AppConstants.wsBaseUrl}/ws/rides/$rideId?token=$token'));
    _wsSubscription = _channel!.stream.listen(
      (message) {
        // TODO: parse JSON message into a domain event and update state.
        _handleEvent(<String, dynamic>{});
      },
      onError: (e) => _setConnected(false, error: 'خطأ في اتصال الركوب'),
      onDone: () => _setConnected(false),
    );
    _setConnected(true);
  }

  void _handleEvent(Map<String, dynamic> data) {
    // TODO: parse RideEvent and update driver location / ride updated fields.
  }

  Future<bool> cancelRide() async {
    try {
      await _rideRepository.cancelRide(rideId);
      return true;
    } catch (e) {
      return false;
    }
  }

  void _setConnected(bool connected, {String? error}) {
    _isConnected = connected;
    if (error != null) _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _channel?.sink.close();
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
