
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/ride_repository.dart';
import '../../../../domain/models/ride.dart';

class RideRequestState {
  const RideRequestState({
    this.status = RideRequestStatus.idle,
    this.rideId,
    this.driverName,
    this.isLoading = false,
    this.error,
  });

  final RideRequestStatus status;
  final String? rideId;
  final String? driverName;
  final bool isLoading;
  final String? error;

  RideRequestState copyWith({
    RideRequestStatus? status,
    String? rideId,
    String? driverName,
    bool? isLoading,
    String? error,
    bool clearRideId = false,
    bool clearDriverName = false,
    bool clearError = false,
  }) {
    return RideRequestState(
      status: status ?? this.status,
      rideId: clearRideId ? null : (rideId ?? this.rideId),
      driverName: clearDriverName ? null : (driverName ?? this.driverName),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RideRequestState &&
      other.status == status &&
      other.rideId == rideId &&
      other.driverName == driverName &&
      other.isLoading == isLoading &&
      other.error == error;

  @override
  int get hashCode => Object.hash(status, rideId, driverName, isLoading, error);
}

/// Notifier for creating and cancelling a ride request.
class RideRequestNotifier extends Notifier<RideRequestState> {
  @override
  RideRequestState build() => const RideRequestState();

  RideRepository get _rideRepository => ref.read(rideRepositoryProvider);

  Future<bool> createRide({
    required String pickup,
    required String destination,
    required String quoteId,
  }) async {
    state = const RideRequestState(status: RideRequestStatus.searching, isLoading: true);
    try {
      final rideId = await _rideRepository.createRide(
        pickup: pickup,
        destination: destination,
        quoteId: quoteId,
      );
      state = state.copyWith(rideId: rideId, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: RideRequestStatus.error,
        isLoading: false,
        error: 'فشل إنشاء الرحلة',
      );
      return false;
    }
  }

  Future<bool> cancelRide() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ok = await _rideRepository.cancelRide(state.rideId ?? '');
      if (!ok) {
        state = state.copyWith(isLoading: false, error: 'فشل إلغاء الرحلة');
        return false;
      }
      state = state.copyWith(status: RideRequestStatus.cancelled, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل إلغاء الرحلة');
      return false;
    }
  }

  void setDriverFound(String driverName) {
    state = state.copyWith(
      status: RideRequestStatus.driverFound,
      driverName: driverName,
      isLoading: false,
    );
  }
}

final rideRequestViewModelProvider =
    NotifierProvider<RideRequestNotifier, RideRequestState>(RideRequestNotifier.new);
