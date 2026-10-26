import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../domain/models/available_ride.dart';
import '../../domain/models/auth_user.dart';
import '../../domain/models/document.dart';
import '../../domain/models/earnings.dart';
import '../../domain/models/offer.dart';
import '../../domain/models/ride.dart';
import '../repositories/auth_repository.dart';
import '../repositories/documents_repository.dart';
import '../repositories/earnings_repository.dart';
import '../repositories/map_repository.dart';
import '../repositories/offers_repository.dart';
import '../repositories/ride_repository.dart';
import '../services/connectivity_service.dart';
import '../services/dio_client.dart';
import '../services/map_service.dart';
import 'demo_data.dart';

/// In-memory fake of [AuthRepository].
///
/// Accepts only [DemoData.demoOtp]; any other code throws the same
/// [ApiException] shape the real server returns. Pass [approve] false to
/// demo the un-approved → /documents guard path.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository({this.approve = true});

  final bool approve;
  AuthUser get _user => approve ? DemoData.driver : DemoData.pendingDriver;
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
    return AuthResult(
      accessToken: DemoData.accessToken,
      refreshToken: DemoData.refreshToken,
      user: _user,
    );
  }

  @override
  Future<bool> registerDriver({
    required String name,
    required String phone,
    required String vehicleType,
    required String plateNumber,
    required String nationalId,
    required String licenseNumber,
  }) async =>
      true;

  @override
  Future<AuthUser?> loadMe() async {
    if (_token == null) return null;
    return _user;
  }

  @override
  Future<String?> get accessToken async => _token;

  @override
  Future<void> logout() async {
    _token = null;
  }
}

/// In-memory fake of [RideRepository] implementing the full driver-side ride
/// state machine: assigned → (verify) → in-progress → completed / cancelled.
/// `startRide` only accepts [DemoData.startCode], and cancelling a finished
/// ride returns false, so every guard in RideTrackingNotifier is reachable.
class DemoRideRepository implements RideRepository {
  final Map<String, Ride> _rides = {DemoData.rideId: DemoData.assignedRide()};
  bool _available = false;

  @override
  Future<List<AvailableRide>> fetchAvailableRides() async => DemoData.availableRides();

  @override
  Future<bool> toggleAvailability({required bool available}) async {
    _available = available;
    return true;
  }

  /// The current availability, exposed for tests/inspection.
  bool get isAvailable => _available;

  @override
  Future<void> updateLocation({required double latitude, required double longitude}) async {}

  @override
  Future<Ride> getRide(String rideId) async {
    final ride = _rides[rideId];
    if (ride == null) throw Exception('demo: unknown ride id "$rideId"');
    return ride;
  }

  @override
  Future<bool> verifyAssignment(String rideId) async {
    final ride = _rides[rideId];
    if (ride == null) return false;
    _rides[rideId] = _copy(ride, verifiedAssignment: true);
    return true;
  }

  @override
  Future<bool> startRide(String rideId, {required String startCode}) async {
    final ride = _rides[rideId];
    if (ride == null || !ride.verifiedAssignment || startCode != DemoData.startCode) {
      return false;
    }
    _rides[rideId] = _copy(ride, status: RideStatus.inProgress, started: true);
    return true;
  }

  @override
  Future<bool> completeRide(String rideId) async {
    final ride = _rides[rideId];
    if (ride == null || !ride.canComplete) return false;
    _rides[rideId] = _copy(ride, status: RideStatus.completed, completed: true);
    return true;
  }

  @override
  Future<bool> cancelRide(String rideId, {required String reason, required String actor}) async {
    final ride = _rides[rideId];
    if (ride == null ||
        ride.status == RideStatus.completed ||
        ride.status == RideStatus.cancelled) {
      return false;
    }
    _rides[rideId] = _copy(
      ride,
      status: RideStatus.cancelled,
      cancellation: RideCancellation(reason: reason, actor: actor, cancelledAt: DateTime.now()),
    );
    return true;
  }

  /// The domain [Ride] is immutable without a copyWith, so rebuild it with the
  /// few fields the state machine ever changes.
  static Ride _copy(
    Ride ride, {
    RideStatus? status,
    bool? verifiedAssignment,
    bool? started,
    bool? completed,
    RideCancellation? cancellation,
  }) {
    return Ride(
      id: ride.id,
      status: status ?? ride.status,
      pickup: ride.pickup,
      destination: ride.destination,
      customerName: ride.customerName,
      customerPhone: ride.customerPhone,
      startCode: ride.startCode,
      verifiedAssignment: verifiedAssignment ?? ride.verifiedAssignment,
      started: started ?? ride.started,
      completed: completed ?? ride.completed,
      cancellation: cancellation ?? ride.cancellation,
    );
  }
}

/// In-memory fake of [OffersRepository]. Offers carry a fresh expiry window on
/// every fetch (like the real filtered API); accept/reject flip the stored
/// status and only succeed once per offer.
class DemoOffersRepository implements OffersRepository {
  List<Offer> _offers = DemoData.offers();

  @override
  Future<List<Offer>> fetchOffers() async {
    _offers = DemoData.offers();
    return _offers.where((o) => !o.isExpired).toList();
  }

  @override
  Future<bool> acceptOffer(String offerId,
      {required String rideId, required String idempotencyKey}) async {
    final index = _offers.indexWhere((o) => o.offerId == offerId);
    if (index == -1 || _offers[index].status != OfferStatus.pending || _offers[index].isExpired) {
      return false;
    }
    _offers[index] = _offers[index].copyWith(status: OfferStatus.accepted);
    return true;
  }

  @override
  Future<bool> rejectOffer(String offerId) async {
    final index = _offers.indexWhere((o) => o.offerId == offerId);
    if (index == -1 || _offers[index].status != OfferStatus.pending) {
      return false;
    }
    _offers[index] = _offers[index].copyWith(status: OfferStatus.rejected);
    return true;
  }
}

/// In-memory fake of [EarningsRepository]. Payout succeeds only for a positive
/// amount that does not exceed [DemoData.earnings]'s net payable.
class DemoEarningsRepository implements EarningsRepository {
  @override
  Future<EarningsState> fetchEarnings() async => DemoData.earnings;

  @override
  Future<bool> requestPayout(double amount) async =>
      amount > 0 && amount <= DemoData.earnings.netPayable;
}

/// In-memory fake of [DocumentsRepository] returning a fake presigned link.
class DemoDocumentsRepository implements DocumentsRepository {
  @override
  Future<Map<String, dynamic>> getUploadLink(DocumentType type) async {
    return {
      'upload_url': 'https://demo.invalid/uploads/${_slug(type)}',
      'method': 'PUT',
      'expires_in': 900,
    };
  }

  /// Wire-format (snake_case) names, matching the API contract style.
  static String _slug(DocumentType type) {
    switch (type) {
      case DocumentType.nationalId:
        return 'national_id';
      case DocumentType.license:
        return 'license';
      case DocumentType.vehicleRegistration:
        return 'vehicle_registration';
      case DocumentType.plate:
        return 'plate';
      case DocumentType.insurance:
        return 'insurance';
    }
  }

  @override
  Future<bool> submitDocuments() async => true;
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
      final fraction = (tick + 1) / (totalTicks + 1);
      yield DriverLocation(
        latLng: LatLng(
          pickup.latitude + (destination.latitude - pickup.latitude) * fraction,
          pickup.longitude + (destination.longitude - pickup.longitude) * fraction,
        ),
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

/// Provider overrides that switch the whole driver app to the demo back end.
/// Use with `ProviderScope(overrides: demoOverrides, ...)` (see main_demo.dart)
/// or build a `ProviderContainer` with them in tests.
List<Override> get demoOverrides => [
      authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
      rideRepositoryProvider.overrideWithValue(DemoRideRepository()),
      offersRepositoryProvider.overrideWithValue(DemoOffersRepository()),
      earningsRepositoryProvider.overrideWithValue(DemoEarningsRepository()),
      documentsRepositoryProvider.overrideWithValue(DemoDocumentsRepository()),
      mapRepositoryProvider.overrideWithValue(DemoMapRepository()),
      connectivityServiceProvider.overrideWithValue(DemoConnectivityService()),
    ];
