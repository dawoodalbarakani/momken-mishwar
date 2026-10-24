library rider_app.features.ride_request.ride_request_provider;

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';

enum RideRequestStatus { idle, searching, driverFound, cancelled, error }

class RideRequestState {
  const RideRequestState({
    this.status = RideRequestStatus.idle,
    this.rideId,
    this.driverName,
    this.error,
    this.isLoading = false,
  });
  final RideRequestStatus status;
  final String? rideId;
  final String? driverName;
  final String? error;
  final bool isLoading;

  RideRequestState copyWith({
    RideRequestStatus? status,
    String? rideId,
    String? driverName,
    String? error,
    bool? isLoading,
  }) {
    return RideRequestState(
      status: status ?? this.status,
      rideId: rideId ?? this.rideId,
      driverName: driverName ?? this.driverName,
      error: error ?? this.error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class RideRequestNotifier extends StateNotifier<RideRequestState> {
  RideRequestNotifier(this._client) : super(const RideRequestState());
  final DioClient _client;

  String _generateIdempotencyKey() {
    final ms = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random.secure().nextInt(900000) + 100000;
    return 'ride_${ms}_$random';
  }

  Future<bool> createRide({required String pickup, required String destination, required String quoteId}) async {
    state = state.copyWith(status: RideRequestStatus.searching, isLoading: true, error: null, rideId: null, driverName: null);
    try {
      final idempotencyKey = _generateIdempotencyKey();
      final data = await _client.post<Map<String, dynamic>>(
        '/rides',
        data: {'pickup': pickup, 'destination': destination, 'quote_id': quoteId},
        idempotencyKey: idempotencyKey,
      );
      final rideId = data?['id']?.toString();
      if (rideId == null || rideId.isEmpty) {
        throw ApiException(code: 'NO_RIDE_ID', messageAr: 'لم يُرجَع معرف الرحلة', messageEn: 'No ride id returned');
      }
      state = state.copyWith(status: RideRequestStatus.searching, rideId: rideId, isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(status: RideRequestStatus.error, isLoading: false, error: e.messageAr);
      return false;
    } catch (e) {
      state = state.copyWith(status: RideRequestStatus.error, isLoading: false, error: 'فشل إنشاء الرحلة');
      return false;
    }
  }

  Future<bool> cancelRide(String rideId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _client.post('/rides/$rideId/cancel', data: {}, idempotencyKey: _generateIdempotencyKey());
      state = state.copyWith(status: RideRequestStatus.cancelled, isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.messageAr);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل إلغاء الرحلة');
      return false;
    }
  }

  void setDriverFound(String driverName) {
    state = state.copyWith(status: RideRequestStatus.driverFound, driverName: driverName, isLoading: false);
  }
}

final rideRequestProvider = StateNotifierProvider<RideRequestNotifier, RideRequestState>((ref) {
  return RideRequestNotifier(DioClient(SecureStorage.instance)); // TODO: inject shared DioClient
});
