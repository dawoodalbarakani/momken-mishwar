
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/app_constants.dart';
import '../../../../data/repositories/ride_repository.dart';

/// Source of raw ride events for a given ride id. Wrapped in a provider so the
/// live socket can be replaced by a deterministic stream in tests.
final rideEventSourceProvider = Provider<Stream<dynamic> Function(String rideId)>((ref) {
  // TODO: send the real session token once the WS auth contract is settled.
  return (rideId) {
    final channel = WebSocketChannel.connect(
      Uri.parse('${AppConstants.wsBaseUrl}/ws/rides/$rideId?token='),
    );
    ref.onDispose(() => channel.sink.close());
    return channel.stream;
  };
});

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

  /// True if the driver location is fresh enough to be shown as live.
  bool get isLocationFresh {
    final age = locationAgeSeconds;
    return age != null && age < 30;
  }

  RideTrackingState copyWith({
    String? driverName,
    String? vehiclePlate,
    LatLng? driverLocation,
    int? locationAgeSeconds,
    String? startCode,
    bool? isConnected,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return RideTrackingState(
      driverName: driverName ?? this.driverName,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      driverLocation: driverLocation ?? this.driverLocation,
      locationAgeSeconds: locationAgeSeconds ?? this.locationAgeSeconds,
      startCode: startCode ?? this.startCode,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RideTrackingState &&
      other.driverName == driverName &&
      other.vehiclePlate == vehiclePlate &&
      other.driverLocation == driverLocation &&
      other.locationAgeSeconds == locationAgeSeconds &&
      other.startCode == startCode &&
      other.isConnected == isConnected &&
      other.isLoading == isLoading &&
      other.error == error;

  @override
  int get hashCode => Object.hash(driverName, vehiclePlate, driverLocation,
      locationAgeSeconds, startCode, isConnected, isLoading, error);
}

/// Notifier for live ride tracking: driver location, vehicle info, socket events.
class RideTrackingNotifier extends FamilyNotifier<RideTrackingState, String> {
  /// The family argument (ride id), captured in [build].
  late final String _rideId;

  @override
  RideTrackingState build(String rideId) {
    _rideId = rideId;
    final subscription = ref.read(rideEventSourceProvider)(rideId).listen(
      (message) {
        // TODO: parse JSON message into a domain event and update state.
        _handleEvent(<String, dynamic>{});
      },
      onError: (e) =>
          state = state.copyWith(isConnected: false, error: 'خطأ في اتصال الركوب'),
      onDone: () => state = state.copyWith(isConnected: false),
    );
    ref.onDispose(subscription.cancel);
    unawaited(_restore());
    // The original view model reported connected=true optimistically right
    // after opening the socket; onError/onDone correct it afterwards.
    return const RideTrackingState(isConnected: true);
  }

  RideRepository get _rideRepository => ref.read(rideRepositoryProvider);

  Future<void> _restore() async {
    try {
      final ride = await _rideRepository.getRide(_rideId);
      state = state.copyWith(
        driverName: ride.driverName,
        vehiclePlate: ride.vehiclePlate,
        startCode: ride.startCode,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل استعادة حالة الرحلة');
    }
  }

  void _handleEvent(Map<String, dynamic> data) {
    // TODO: parse RideEvent and update driver location / ride updated fields.
  }

  Future<bool> cancelRide() async {
    try {
      return await _rideRepository.cancelRide(_rideId);
    } catch (e) {
      return false;
    }
  }
}

final rideTrackingViewModelProvider =
    NotifierProvider.family<RideTrackingNotifier, RideTrackingState, String>(
        RideTrackingNotifier.new);
