
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../data/repositories/map_repository.dart';
import '../../../../data/services/connectivity_service.dart';
import '../../../../domain/models/saved_place.dart';
import '../../../../data/services/map_service.dart';

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
    LatLng? pickup,
    LatLng? destination,
    List<SavedPlace>? savedPlaces,
    ConnectionStatus? connectionStatus,
    bool? isLoading,
    String? error,
    bool clearPickup = false,
    bool clearDestination = false,
    bool clearError = false,
  }) {
    return HomeState(
      currentLocation: currentLocation ?? this.currentLocation,
      pickup: clearPickup ? null : (pickup ?? this.pickup),
      destination: clearDestination ? null : (destination ?? this.destination),
      savedPlaces: savedPlaces ?? this.savedPlaces,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HomeState &&
      other.currentLocation == currentLocation &&
      other.pickup == pickup &&
      other.destination == destination &&
      other.savedPlaces == savedPlaces &&
      other.connectionStatus == connectionStatus &&
      other.isLoading == isLoading &&
      other.error == error;

  @override
  int get hashCode => Object.hash(
      currentLocation, pickup, destination, savedPlaces, connectionStatus, isLoading, error);
}

/// Notifier for the home screen: location picking, saved places, connectivity.
class HomeNotifier extends Notifier<HomeState> {
  @override
  HomeState build() {
    final subscription = ref.read(connectivityServiceProvider).watch().listen((status) {
      state = state.copyWith(connectionStatus: status);
    });
    ref.onDispose(subscription.cancel);
    return const HomeState();
  }

  MapRepository get _mapRepository => ref.read(mapRepositoryProvider);

  Future<List<PlaceResult>> searchPlaces(String query) => _mapRepository.searchPlaces(query);

  Future<void> locateMe() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final picked = await _mapRepository.pickLocation();
      state = state.copyWith(currentLocation: picked, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'تعذر تحديد الموقع الحالي');
    }
  }

  void setPickup(LatLng? point) {
    state = point == null
        ? state.copyWith(clearPickup: true)
        : state.copyWith(pickup: point);
  }

  void setDestination(LatLng? point) {
    state = point == null
        ? state.copyWith(clearDestination: true)
        : state.copyWith(destination: point);
  }

  void clearSelection() {
    state = state.copyWith(clearPickup: true, clearDestination: true);
  }

  void setError(String? error) {
    state = error == null ? state.copyWith(clearError: true) : state.copyWith(error: error);
  }
}

final homeViewModelProvider = NotifierProvider<HomeNotifier, HomeState>(HomeNotifier.new);
