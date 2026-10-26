
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/ride_repository.dart';
import '../../../../domain/models/ride.dart';

class RideTrackingState {
  const RideTrackingState({
    this.status = RideStatus.assigned,
    this.pickup,
    this.destination,
    this.customerName,
    this.customerPhone,
    this.startCode,
    this.verifiedAssignment = false,
    this.started = false,
    this.completed = false,
    this.cancellation,
    this.isConnected = false,
    this.isLoading = true,
    this.error,
  });

  final RideStatus status;
  final String? pickup;
  final String? destination;
  final String? customerName;
  final String? customerPhone;
  final String? startCode;
  final bool verifiedAssignment;
  final bool started;
  final bool completed;
  final RideCancellation? cancellation;
  final bool isConnected;
  final bool isLoading;
  final String? error;

  bool get canStart => verifiedAssignment && !started && status == RideStatus.assigned;
  bool get canComplete => started && status == RideStatus.inProgress && !completed;

  RideTrackingState copyWith({
    RideStatus? status,
    String? pickup,
    String? destination,
    String? customerName,
    String? customerPhone,
    String? startCode,
    bool? verifiedAssignment,
    bool? started,
    bool? completed,
    RideCancellation? cancellation,
    bool? isConnected,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return RideTrackingState(
      status: status ?? this.status,
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      startCode: startCode ?? this.startCode,
      verifiedAssignment: verifiedAssignment ?? this.verifiedAssignment,
      started: started ?? this.started,
      completed: completed ?? this.completed,
      cancellation: cancellation ?? this.cancellation,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RideTrackingNotifier extends FamilyNotifier<RideTrackingState, String> {
  /// The family argument (ride id), captured in [build].
  late final String _rideId;

  @override
  RideTrackingState build(String rideId) {
    _rideId = rideId;
    // First state write happens after an await, so this is safe to fire here.
    _restore();
    return const RideTrackingState();
  }

  RideRepository get _rideRepository => ref.read(rideRepositoryProvider);

  Future<void> _restore() async {
    try {
      final ride = await _rideRepository.getRide(_rideId);
      state = state.copyWith(
        status: ride.status,
        pickup: ride.pickup,
        destination: ride.destination,
        customerName: ride.customerName,
        customerPhone: ride.customerPhone,
        startCode: ride.startCode,
        verifiedAssignment: ride.verifiedAssignment,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل استعادة حالة الرحلة');
    }
  }

  Future<bool> verifyAssignment() async {
    try {
      final ok = await _rideRepository.verifyAssignment(_rideId);
      state = state.copyWith(verifiedAssignment: ok);
      return ok;
    } catch (e) {
      state = state.copyWith(error: 'فشل التحقق من الإسناد');
      return false;
    }
  }

  Future<bool> startRide(String enteredStartCode) async {
    if (!state.verifiedAssignment) {
      state = state.copyWith(error: 'يجب التحقق من إسناد الرحلة أولاً');
      return false;
    }
    if (state.startCode == null) {
      state = state.copyWith(error: 'رمز بدء الرحلة غير متوفر من الخادم');
      return false;
    }
    if (enteredStartCode.trim() != state.startCode) {
      state = state.copyWith(error: 'رمز بدء الرحلة غير صحيح');
      return false;
    }
    try {
      final ok = await _rideRepository.startRide(_rideId, startCode: enteredStartCode.trim());
      if (ok) {
        state = state.copyWith(started: true, status: RideStatus.inProgress);
      }
      return ok;
    } catch (e) {
      state = state.copyWith(error: 'فشل بدء الرحلة');
      return false;
    }
  }

  Future<bool> completeRide() async {
    if (!state.canComplete) {
      state = state.copyWith(error: 'لا يمكن إنهاء الرحلة في الحالة الحالية');
      return false;
    }
    try {
      final ok = await _rideRepository.completeRide(_rideId);
      if (ok) {
        state = state.copyWith(status: RideStatus.completed, completed: true);
      }
      return ok;
    } catch (e) {
      state = state.copyWith(error: 'فشل إنهاء الرحلة');
      return false;
    }
  }

  Future<bool> cancelRide({required String reason, required String actor}) async {
    if (state.status == RideStatus.completed || state.status == RideStatus.cancelled) {
      state = state.copyWith(error: 'الرحلة مكتملة أو ملغاة مسبقاً');
      return false;
    }
    try {
      final ok = await _rideRepository.cancelRide(_rideId, reason: reason, actor: actor);
      if (ok) {
        state = state.copyWith(
          status: RideStatus.cancelled,
          cancellation: RideCancellation(reason: reason, actor: actor, cancelledAt: DateTime.now()),
        );
      }
      return ok;
    } catch (e) {
      state = state.copyWith(error: 'فشل إلغاء الرحلة');
      return false;
    }
  }
}

final rideTrackingViewModelProvider =
    NotifierProvider.family<RideTrackingNotifier, RideTrackingState, String>(
  RideTrackingNotifier.new,
);
