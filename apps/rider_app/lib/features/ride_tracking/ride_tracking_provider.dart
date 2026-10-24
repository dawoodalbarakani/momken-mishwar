library rider_app.features.ride_tracking.ride_tracking_provider;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../core/map_provider.dart';

class RideEvent {
  const RideEvent({required this.type, required this.data});
  final String type;
  final Map<String, dynamic> data;
}

class RideTrackingState {
  const RideTrackingState({
    this.driverName,
    this.vehiclePlate,
    this.driverLocation,
    this.locationAgeSeconds,
    this.startCode,
    this.isConnected = false,
    this.isLoading = true,
    this.error,
  });
  final String? driverName;
  final String? vehiclePlate;
  final LatLng? driverLocation;
  final int? locationAgeSeconds;
  final String? startCode;
  final bool isConnected;
  final bool isLoading;
  final String? error;
}

class RideTrackingNotifier extends StateNotifier<RideTrackingState> {
  RideTrackingNotifier(this._client, this.rideId) : super(const RideTrackingState()) {
    _restore();
    _connectWebSocket();
  }

  final DioClient _client;
  final String rideId;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;

  Future<void> _restore() async {
    try {
      final data = await _client.get<Map<String, dynamic>>('/rides/$rideId');
      state = state.copyWith(
        driverName: data?['driver_name']?.toString(),
        vehiclePlate: data?['vehicle_plate']?.toString(),
        startCode: data?['start_code']?.toString(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل استعادة حالة الرحلة');
    }
  }

  void _connectWebSocket() {
    final token = ''; // TODO: inject access token from auth provider
    _channel = WebSocketChannel.connect(Uri.parse('${AppConstants.wsBaseUrl}/ws/rides/$rideId?token=$token'));
    _wsSubscription = _channel!.stream.listen(
      (message) {
        // TODO: parse JSON message into RideEvent and update state (offer.created, ride.updated, driver.location)
        final event = RideEvent(type: 'raw', data: {});
        _handleEvent(event);
      },
      onError: (e) => state = state.copyWith(isConnected: false, error: 'خطأ في اتصال الركوب'),
      onDone: () => state = state.copyWith(isConnected: false),
    );
    state = state.copyWith(isConnected: true);
  }

  void _handleEvent(RideEvent event) {
    switch (event.type) {
      case 'driver.location':
        final lat = event.data['latitude'] as double?;
        final lng = event.data['longitude'] as double?;
        final age = event.data['age_s'] as int?;
        if (lat != null && lng != null) {
          state = state.copyWith(
            driverLocation: LatLng(lat, lng),
            locationAgeSeconds: age,
          );
        }
        break;
      case 'ride.updated':
        state = state.copyWith(
          driverName: event.data['driver_name']?.toString(),
          vehiclePlate: event.data['vehicle_plate']?.toString(),
        );
        break;
      default:
        break;
    }
  }

  /// Returns true if the driver location is fresh enough to be shown as live.
  bool get isLocationFresh {
    final age = state.locationAgeSeconds;
    return age != null && age < 30;
  }

  Future<bool> cancelRide() async {
    try {
      await _client.post('/rides/$rideId/cancel', data: {});
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}

final rideTrackingProvider = StateNotifierProvider.family<RideTrackingNotifier, RideTrackingState, String>((ref, rideId) {
  return RideTrackingNotifier(DioClient(SecureStorage.instance), rideId); // TODO: inject shared DioClient + token
});
