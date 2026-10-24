
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/available_ride.dart';
import '../../domain/models/ride.dart';
import '../services/dio_client.dart';
import '../services/ride_service.dart';

class RideRepository {
  RideRepository({required RideService rideService}) : _rideService = rideService;

  final RideService _rideService;

  Future<List<AvailableRide>> fetchAvailableRides() async {
    final list = await _rideService.getAvailableRides();
    return list
        .map((e) => AvailableRide(
              rideId: e['ride_id']?.toString() ?? '',
              pickup: e['pickup']?.toString() ?? '',
              destination: e['destination']?.toString() ?? '',
              fare: (e['fare'] as num?)?.toDouble() ?? 0,
              distanceMeters: (e['distance_meters'] as num?)?.toDouble() ?? 0,
              expiresAt: e['expires_at'] != null
                  ? DateTime.tryParse(e['expires_at'].toString()) ?? DateTime.now().add(const Duration(minutes: 5))
                  : DateTime.now().add(const Duration(minutes: 5)),
            ))
        .where((r) => !r.isExpired)
        .toList();
  }

  Future<bool> toggleAvailability({required bool available}) async {
    try {
      await _rideService.toggleAvailability(available: available);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateLocation({required double latitude, required double longitude}) async {
    await _rideService.updateLocation(latitude: latitude, longitude: longitude);
  }

  Future<Ride> getRide(String rideId) async {
    final data = await _rideService.getRide(rideId);
    return _rideToDomain(data);
  }

  Ride _rideToDomain(Map<String, dynamic> data) {
    return Ride(
      id: data['id']?.toString() ?? '',
      status: _parseStatus(data['status']),
      pickup: data['pickup'] as String?,
      destination: data['destination'] as String?,
      customerName: data['customer_name'] as String?,
      customerPhone: data['customer_phone'] as String?,
      startCode: data['start_code'] as String?,
      verifiedAssignment: data['driver_assigned'] == true,
    );
  }

  Future<bool> verifyAssignment(String rideId) async {
    try {
      final data = await _rideService.verifyAssignment(rideId);
      return data['verified'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startRide(String rideId, {required String startCode}) async {
    try {
      await _rideService.startRide(rideId, startCode: startCode);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> completeRide(String rideId) async {
    try {
      await _rideService.completeRide(rideId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancelRide(String rideId, {required String reason, required String actor}) async {
    try {
      await _rideService.cancelRide(rideId, reason: reason, actor: actor);
      return true;
    } catch (_) {
      return false;
    }
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

final rideRepositoryProvider = Provider(
  (ref) => RideRepository(rideService: RideService(ref.read(dioClientProvider))),
);
