library driver_app.features.home.home_provider;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/secure_storage.dart';
import '../../core/connectivity.dart';
import '../../core/map_provider.dart';

enum AvailabilityStatus { online, offline }

class AvailableRide {
  const AvailableRide({
    required this.rideId,
    required this.pickup,
    required this.destination,
    required this.fare,
    required this.distanceMeters,
    required this.expiresAt,
  });
  final String rideId;
  final String pickup;
  final String destination;
  final double fare;
  final double distanceMeters;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class EarningsSummary {
  const EarningsSummary({required this.totalFare, required this.completedRides, required this.cashCollected});
  final double totalFare;
  final int completedRides;
  final double cashCollected;
}

class HomeState {
  const HomeState({
    this.availability = AvailabilityStatus.offline,
    this.availableRides = const [],
    this.earningsSummary,
    this.lastLocationUpdate,
    this.connectionStatus = ConnectionStatus.unknown,
    this.isLoading = false,
    this.error,
  });
  final AvailabilityStatus availability;
  final List<AvailableRide> availableRides;
  final EarningsSummary? earningsSummary;
  final DateTime? lastLocationUpdate;
  final ConnectionStatus connectionStatus;
  final bool isLoading;
  final String? error;

  HomeState copyWith({
    AvailabilityStatus? availability,
    List<AvailableRide>? availableRides,
    EarningsSummary? earningsSummary,
    DateTime? lastLocationUpdate,
    bool clearLastLocationUpdate = false,
    ConnectionStatus? connectionStatus,
    bool? isLoading,
    String? error,
  }) {
    return HomeState(
      availability: availability ?? this.availability,
      availableRides: availableRides ?? this.availableRides,
      earningsSummary: earningsSummary ?? this.earningsSummary,
      lastLocationUpdate: clearLastLocationUpdate ? null : (lastLocationUpdate ?? this.lastLocationUpdate),
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier(this._client, this._mapProvider) : super(const HomeState()) {
    _listenConnectivity();
  }

  final DioClient _client;
  final MapProvider _mapProvider;
  StreamSubscription? _connectivitySubscription;

  void _listenConnectivity() {
    _connectivitySubscription = ConnectivityService.watch().listen((status) {
      state = state.copyWith(connectionStatus: status);
    });
  }

  Future<bool> toggleAvailability() async {
    final target = state.availability == AvailabilityStatus.offline ? AvailabilityStatus.online : AvailabilityStatus.offline;
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _client.patch('/driver/availability', data: {'available': target == AvailabilityStatus.online});
      state = state.copyWith(availability: target, isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.messageAr);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل تغيير حالة التوفر');
      return false;
    }
  }

  Future<void> fetchAvailableRides() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _client.get<List<dynamic>>('/rides/available');
      final rides = (data ?? [])
          .map((e) => AvailableRide(
                rideId: e['ride_id']?.toString() ?? '',
                pickup: e['pickup']?.toString() ?? '',
                destination: e['destination']?.toString() ?? '',
                fare: (e['fare'] as num?)?.toDouble() ?? 0,
                distanceMeters: (e['distance_meters'] as num?)?.toDouble() ?? 0,
                expiresAt: e['expires_at'] != null ? DateTime.tryParse(e['expires_at'].toString()) ?? DateTime.now().add(const Duration(minutes: 5)) : DateTime.now().add(const Duration(minutes: 5)),
              ))
          .where((r) => !r.isExpired)
          .toList();
      state = state.copyWith(availableRides: rides, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.messageAr);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل جلب الرحلات المتاحة');
    }
  }

  Future<void> fetchEarningsSummary() async {
    try {
      final data = await _client.get<Map<String, dynamic>>('/earnings/summary');
      state = state.copyWith(
        earningsSummary: EarningsSummary(
          totalFare: (data?['total_fare'] as num?)?.toDouble() ?? 0,
          completedRides: (data?['completed_rides'] as int?) ?? 0,
          cashCollected: (data?['cash_collected'] as num?)?.toDouble() ?? 0,
        ),
      );
    } catch (e) {
      // non-fatal
    }
  }

  Future<void> updateLocation(LatLng point) async {
    try {
      await _client.post('/driver/location', data: {'latitude': point.latitude, 'longitude': point.longitude});
      state = state.copyWith(lastLocationUpdate: DateTime.now());
    } catch (e) {
      // non-fatal
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(DioClient(SecureStorage.instance), StubMapProvider());
});
