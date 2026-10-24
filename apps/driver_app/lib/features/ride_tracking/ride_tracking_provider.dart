library driver_app.features.ride_tracking.ride_tracking_provider;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api_client.dart';
import '../../core/secure_storage.dart';
import '../../core/constants.dart';

enum RideStatus { assigned, arriving, arrived, inProgress, completed, cancelled }

class RideCancellation {
  const RideCancellation({required this.reason, required this.actor, required this.cancelledAt});
  final String reason;
  final String actor; // 'driver' | 'rider' | 'system'
  final DateTime cancelledAt;
}

class RideTrackingState {
  const RideTrackingState({
    this.rideId,
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
    this.driverLocation,
    this.locationAgeSeconds,
    this.isConnected = false,
    this.isLoading = true,
    this.error,
  });
  final String? rideId;
  final RideStatus status;
  final String? pickup;
  final String? destination;
  final String? customerName;
  final String? customerPhone;
  final String? startCode; // رمز بدء الرحلة من الخادم
  final bool verifiedAssignment; // تم التحقق من أن السائق هو المسند إليه الرحلة
  final bool started; // بدأت الرحلة بعد التحقق من الرمز
  final bool completed;
  final RideCancellation? cancellation;
  final double? driverLocationLatitude;
  final double? driverLocationLongitude;
  final int? locationAgeSeconds;
  final bool isConnected;
  final bool isLoading;
  final String? error;

  RideTrackingState copyWith({
    String? rideId,
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
    double? driverLocationLatitude,
    double? driverLocationLongitude,
    int? locationAgeSeconds,
    bool clearLocation = false,
    bool? isConnected,
    bool? isLoading,
    String? error,
  }) {
    return RideTrackingState(
      rideId: rideId ?? this.rideId,
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
      driverLocationLatitude: clearLocation ? null : (driverLocationLatitude ?? this.driverLocationLatitude),
      driverLocationLongitude: clearLocation ? null : (driverLocationLongitude ?? this.driverLocationLongitude),
      locationAgeSeconds: locationAgeSeconds ?? this.locationAgeSeconds,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get canStart => verifiedAssignment && started == false && status == RideStatus.assigned;
  bool get canComplete => started && status == RideStatus.inProgress && completed == false;
}

class RideTrackingNotifier extends StateNotifier<RideTrackingState> {
  RideTrackingNotifier(this._client, this.rideId) : super(const RideTrackingState(rideId: '')) {
    _rideId = rideId;
    _restore();
    _connectWebSocket();
  }

  final DioClient _client;
  String _rideId;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;

  Future<void> _restore() async {
    try {
      final data = await _client.get<Map<String, dynamic>>('/rides/$_rideId');
      state = state.copyWith(
        status: _parseStatus(data?['status']),
        pickup: data?['pickup']?.toString(),
        destination: data?['destination']?.toString(),
        customerName: data?['customer_name']?.toString(),
        customerPhone: data?['customer_phone']?.toString(),
        startCode: data?['start_code']?.toString(),
        verifiedAssignment: data?['driver_assigned'] == true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل استعادة حالة الرحلة');
    }
  }

  /// التحقق من أن السائق المسجل الدخول هو السائق المسند إلى هذه الرحلة.
  Future<bool> verifyAssignment() async {
    try {
      final data = await _client.get<Map<String, dynamic>>('/rides/$_rideId/verify');
      final ok = data?['verified'] == true;
      state = state.copyWith(verifiedAssignment: ok);
      return ok;
    } catch (e) {
      state = state.copyWith(error: 'فشل التحقق من الإسناد');
      return false;
    }
  }

  /// بدء الرحلة بعد التحقق من الإسناد ورمز بدء الرحلة الذي يحدده السائق/الخادم.
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
      await _client.post('/rides/$_rideId/start', data: {'start_code': enteredStartCode.trim()});
      state = state.copyWith(started: true, status: RideStatus.inProgress);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.messageAr);
      return false;
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
      await _client.post('/rides/$_rideId/complete', data: {});
      state = state.copyWith(status: RideStatus.completed, completed: true);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.messageAr);
      return false;
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
      await _client.post('/rides/$_rideId/cancel', data: {'reason': reason, 'actor': actor});
      state = state.copyWith(
        status: RideStatus.cancelled,
        cancellation: RideCancellation(reason: reason, actor: actor, cancelledAt: DateTime.now()),
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.messageAr);
      return false;
    } catch (e) {
      state = state.copyWith(error: 'فشل إلغاء الرحلة');
      return false;
    }
  }

  void _connectWebSocket() {
    _channel = WebSocketChannel.connect(Uri.parse('${AppConstants.wsBaseUrl}/ws/rides/$_rideId'));
    _wsSubscription = _channel!.stream.listen(
      (message) {
        try {
          final data = _decode(message);
          if (data == null) return;
          final type = data['type']?.toString();
          if (type == 'ride.updated') {
            state = state.copyWith(
              status: _parseStatus(data['status']),
              customerName: data['customer_name']?.toString(),
            );
          } else if (type == 'driver.location') {
            state = state.copyWith(
              driverLocationLatitude: data['latitude'] as double?,
              driverLocationLongitude: data['longitude'] as double?,
              locationAgeSeconds: data['age_s'] as int?,
            );
          } else if (type == 'ride.cancelled') {
            state = state.copyWith(
              status: RideStatus.cancelled,
              cancellation: RideCancellation(reason: data['reason']?.toString() ?? '', actor: data['actor']?.toString() ?? 'system', cancelledAt: DateTime.now()),
            );
          }
        } catch (_) {
          // ignore malformed messages
        }
      },
      onError: (_) => state = state.copyWith(isConnected: false),
      onDone: () => state = state.copyWith(isConnected: false),
    );
    state = state.copyWith(isConnected: true);
  }

  dynamic _decode(dynamic message) {
    return null; // minimal stub: real implementation parses JSON via dart:convert
  }

  bool get isLocationFresh {
    final age = state.locationAgeSeconds;
    return age != null && age < 30;
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  RideStatus _parseStatus(dynamic v) {
    switch (v?.toString().toLowerCase()) {
      case 'arriving':
        return RideStatus.arriving;
      case 'arrived':
        return RideStatus.arrived;
      case 'in_progress':
        return RideStatus.inProgress;
      case 'completed':
        return RideStatus.completed;
      case 'cancelled':
        return RideStatus.cancelled;
      default:
        return RideStatus.assigned;
    }
  }
}

final rideTrackingProvider = StateNotifierProvider.family<RideTrackingNotifier, RideTrackingState, String>((ref, rideId) {
  return RideTrackingNotifier(DioClient(SecureStorage.instance), rideId);
});
