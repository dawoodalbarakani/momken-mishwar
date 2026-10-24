library rider_app.features.home.home_provider;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/map_provider.dart';
import '../../core/connectivity.dart';

class SavedPlace {
  const SavedPlace({required this.id, required this.name, required this.latLng});
  final String id;
  final String name;
  final LatLng latLng;
}

class HomeState {
  const HomeState({
    this.currentLocation,
    this.pickup,
    this.destination,
    this.savedPlaces = const [],
    this.connectionStatus = ConnectionStatus.unknown,
    this.isLoading = false,
    this.error,
  });
  final LatLng? currentLocation;
  final LatLng? pickup;
  final LatLng? destination;
  final List<SavedPlace> savedPlaces;
  final ConnectionStatus connectionStatus;
  final bool isLoading;
  final String? error;

  HomeState copyWith({
    LatLng? currentLocation,
    bool clearCurrentLocation = false,
    LatLng? pickup,
    LatLng? destination,
    List<SavedPlace>? savedPlaces,
    ConnectionStatus? connectionStatus,
    bool? isLoading,
    String? error,
  }) {
    return HomeState(
      currentLocation: clearCurrentLocation ? null : (currentLocation ?? this.currentLocation),
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      savedPlaces: savedPlaces ?? this.savedPlaces,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier(this._mapProvider) : super(const HomeState()) {
    _listenConnectivity();
  }

  final MapProvider _mapProvider;
  StreamSubscription? _connectivitySubscription;

  void _listenConnectivity() {
    _connectivitySubscription = ConnectivityService.watch().listen((status) {
      state = state.copyWith(connectionStatus: status);
    });
  }

  Future<List<PlaceResult>> searchPlaces(String query) async => _mapProvider.searchPlaces(query);

  Future<void> locateMe() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // TODO: integrate geolocator package for current location once added to pubspec.
      final picked = await _mapProvider.pickLocation();
      state = state.copyWith(isLoading: false, currentLocation: picked);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'تعذر تحديد الموقع الحالي');
    }
  }

  void setPickup(LatLng point) => state = state.copyWith(pickup: point);
  void setDestination(LatLng point) => state = state.copyWith(destination: point);
  void clearSelection() => state = state.copyWith(pickup: null, destination: null);
  void setError(String? error) => state = state.copyWith(error: error);

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(StubMapProvider()); // TODO: replace with real MapProvider implementation
});
