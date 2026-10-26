
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/services/connectivity_service.dart';
import '../../../../data/repositories/ride_repository.dart';
import '../../../../domain/models/available_ride.dart';

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
    ConnectionStatus? connectionStatus,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return HomeState(
      availability: availability ?? this.availability,
      availableRides: availableRides ?? this.availableRides,
      earningsSummary: earningsSummary ?? this.earningsSummary,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class HomeNotifier extends Notifier<HomeState> {
  @override
  HomeState build() {
    final subscription = ref.read(connectivityServiceProvider).watch().listen((status) {
      state = state.copyWith(connectionStatus: status);
    });
    ref.onDispose(subscription.cancel);
    return const HomeState();
  }

  Future<bool> toggleAvailability() async {
    final target = state.availability == AvailabilityStatus.offline
        ? AvailabilityStatus.online
        : AvailabilityStatus.offline;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ok = await ref.read(rideRepositoryProvider)
          .toggleAvailability(available: target == AvailabilityStatus.online);
      if (ok) {
        state = state.copyWith(availability: target, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
      return ok;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل تغيير حالة التوفر');
      return false;
    }
  }

  Future<void> fetchAvailableRides() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final rides = await ref.read(rideRepositoryProvider).fetchAvailableRides();
      state = state.copyWith(availableRides: rides, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل جلب الرحلات المتاحة');
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
      await ref.read(rideRepositoryProvider)
          .updateLocation(latitude: latitude, longitude: longitude);
      state = state.copyWith(lastLocationUpdate: DateTime.now());
    } catch (e) {
      // non-fatal
    }
  }
}

final homeViewModelProvider = NotifierProvider<HomeNotifier, HomeState>(HomeNotifier.new);
