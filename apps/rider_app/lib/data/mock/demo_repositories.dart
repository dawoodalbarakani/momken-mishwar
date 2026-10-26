import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/demo_mode.dart';
import '../../domain/models/auth_user.dart';
import '../../domain/models/quote.dart';
import '../../domain/models/ride.dart';
import '../../ui/features/ride_tracking/view_models/ride_tracking_view_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/map_repository.dart';
import '../repositories/ride_repository.dart';
import '../services/connectivity_service.dart';
import '../services/dio_client.dart';
import '../services/map_service.dart';
import 'demo_data.dart';

/// In-memory fake of [AuthRepository].
///
/// Accepts only [DemoData.demoOtp]; any other code throws the same
/// [ApiException] shape the real server returns, so the Arabic error path in
/// AuthNotifier is exercised in demo mode too.
class DemoAuthRepository implements AuthRepository {
  String? _token;

  @override
  Future<bool> requestOtp(String phone) async => true;

  @override
  Future<AuthResult> verifyOtp(String phone, String otp) async {
    if (otp != DemoData.demoOtp) {
      throw ApiException(
        code: 'invalid_otp',
        messageAr: 'رمز التحقق غير صحيح',
        messageEn: 'Invalid OTP',
      );
    }
    _token = DemoData.accessToken;
    return const AuthResult(
      accessToken: DemoData.accessToken,
      user: DemoData.rider,
    );
  }

  @override
  Future<String?> get accessToken async => _token;

  @override
  Future<void> logout() async {
    _token = null;
  }
}

/// In-memory fake of [RideRepository] with a small mutable ride store.
///
/// Created rides are remembered (with driver info) so the tracking screen's
/// restore path works end to end. Cancelling an unknown or already-cancelled
/// ride returns `false`, matching how the real repository swallows errors.
class DemoRideRepository implements RideRepository {
  final Map<String, Ride> _rides = {DemoData.preexistingRideId: DemoData.preexistingRide};
  final Set<String> _cancelled = {};
  int _sequence = 100;

  @override
  Future<Quote> fetchQuote({required String pickup, required String destination}) async =>
      DemoData.quote;

  @override
  Future<String> createRide({
    required String pickup,
    required String destination,
    required String quoteId,
  }) async {
    final rideId = 'demo-ride-${++_sequence}';
    _rides[rideId] = Ride(
      id: rideId,
      driverName: DemoData.driverName,
      vehiclePlate: DemoData.vehiclePlate,
      startCode: DemoData.startCode,
    );
    return rideId;
  }

  @override
  Future<bool> cancelRide(String rideId) async {
    if (!_rides.containsKey(rideId) || _cancelled.contains(rideId)) return false;
    _cancelled.add(rideId);
    return true;
  }

  @override
  Future<Ride> getRide(String rideId) async {
    final ride = _rides[rideId];
    if (ride == null) throw Exception('demo: unknown ride id "$rideId"');
    return ride;
  }
}

/// In-memory fake of [MapRepository] serving the static Sana'a place list.
class DemoMapRepository implements MapRepository {
  @override
  Future<List<PlaceResult>> searchPlaces(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return DemoData.places;
    return DemoData.places
        .where((p) => p.name.toLowerCase().contains(q) || p.address.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<LatLng> pickLocation() async => DemoData.pickedLocation;

  @override
  Future<RouteResult> getRoute(LatLng origin, LatLng destination) async =>
      DemoData.syntheticRoute(origin, destination);

  @override
  Stream<DriverLocation> watchDriverLocation(String rideId) async* {
    const totalTicks = 10;
    const pickup = DemoData.pickedLocation;
    const destination = LatLng(15.3289, 44.2447); // حي حدة
    for (var tick = 0; tick < totalTicks; tick++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      yield DriverLocation(
        latLng: DemoData.driverLocationAt(tick, totalTicks, pickup, destination),
        recordedAt: DateTime(2026, 1, 1).add(Duration(seconds: 2 * tick)),
        ageSeconds: 0,
      );
    }
  }
}

/// Fake [ConnectivityService] that reports a stable online connection. Each
/// [watch] subscriber receives `online` immediately, so the home notifier
/// always settles on a connected state in demo mode.
class DemoConnectivityService implements ConnectivityService {
  @override
  Stream<ConnectionStatus> watch() => Stream<ConnectionStatus>.value(ConnectionStatus.online);

  @override
  Future<ConnectionStatus> check() async => ConnectionStatus.online;
}

/// Demo replacement for `rideEventSourceProvider`: emits deterministic
/// location ticks every 2s for a ride and then completes, instead of opening
/// a live WebSocket.
Stream<dynamic> demoRideEventSource(String rideId) {
  const totalTicks = 10;
  const pickup = DemoData.pickedLocation;
  const destination = LatLng(15.3289, 44.2447); // حي حدة
  return Stream.periodic(const Duration(seconds: 2), (tick) {
    final latLng = DemoData.driverLocationAt(tick, totalTicks, pickup, destination);
    return <String, dynamic>{
      'type': 'driver_location',
      'ride_id': rideId,
      'latitude': latLng.latitude,
      'longitude': latLng.longitude,
      'age_seconds': 0,
    };
  }).take(totalTicks);
}

/// Provider overrides that switch the whole app to the demo back end.
/// Use with `ProviderScope(overrides: demoOverrides, ...)` (see main_demo.dart)
/// or build a `ProviderContainer` with them in tests.
List<Override> get demoOverrides => [
      demoModeProvider.overrideWithValue(true),
      authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
      rideRepositoryProvider.overrideWithValue(DemoRideRepository()),
      mapRepositoryProvider.overrideWithValue(DemoMapRepository()),
      connectivityServiceProvider.overrideWithValue(DemoConnectivityService()),
      rideEventSourceProvider.overrideWithValue(demoRideEventSource),
    ];
