import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../domain/models/available_ride.dart';
import '../../domain/models/auth_user.dart';
import '../../domain/models/earnings.dart';
import '../../domain/models/offer.dart';
import '../../domain/models/ride.dart';
import '../services/map_service.dart';

/// Static demo fixtures for running and testing the driver app without the
/// live backend. Values are deterministic; anything time-relative (offer /
/// available-ride expiry) is produced by the factory functions so each call
/// gets a fresh window like the real server does.
class DemoData {
  DemoData._();

  // --- Auth ---------------------------------------------------------------
  static const String demoPhone = '+967770000001';
  static const String demoOtp = '123456';
  static const String accessToken = 'demo-driver-access-token';
  static const String refreshToken = 'demo-driver-refresh-token';

  /// The happy-path driver: already approved, so the router guard lands on
  /// /home directly. Use [pendingDriver] to explore the documents flow.
  static const AuthUser driver = AuthUser(
    id: 'demo-driver-1',
    phone: demoPhone,
    name: 'فهد المطري',
    verificationStatus: VerificationStatus.approved,
  );

  static const AuthUser pendingDriver = AuthUser(
    id: 'demo-driver-2',
    phone: demoPhone,
    name: 'فهد المطري',
    verificationStatus: VerificationStatus.pending,
  );

  // --- Places (Sana'a) ------------------------------------------------------
  static const List<PlaceResult> places = [
    PlaceResult(
      placeId: 'place-tahrir',
      name: 'ميدان التحرير',
      address: 'شارع الزبيري، وسط المدينة',
      latLng: LatLng(15.3543, 44.2113),
    ),
    PlaceResult(
      placeId: 'place-old-city',
      name: 'صنعاء القديمة',
      address: 'باب السلام',
      latLng: LatLng(15.3533, 44.2067),
    ),
    PlaceResult(
      placeId: 'place-60meters',
      name: 'شارع الستين',
      address: 'شمال المدينة',
      latLng: LatLng(15.3753, 44.2161),
    ),
    PlaceResult(
      placeId: 'place-hadda',
      name: 'حي حدة',
      address: 'جنوب المدينة',
      latLng: LatLng(15.3289, 44.2447),
    ),
    PlaceResult(
      placeId: 'place-husba',
      name: 'حي الحصبة',
      address: 'شمال غرب المدينة',
      latLng: LatLng(15.3731, 44.1946),
    ),
  ];

  static const LatLng pickedLocation = LatLng(15.3543, 44.2113);

  // --- Ride request data ----------------------------------------------------
  static const String rideId = 'demo-ride-1';
  static const String pickup = 'ميدان التحرير';
  static const String destination = 'حي حدة';
  static const String customerName = 'أحمد الصليحي';
  static const String customerPhone = '+967771234567';
  static const String startCode = '4821';

  /// Fresh assigned ride for the store (verifiedAssignment starts false, so
  /// the whole verify → start → complete flow can be demoed).
  static Ride assignedRide({String id = rideId}) => Ride(
        id: id,
        status: RideStatus.assigned,
        pickup: pickup,
        destination: destination,
        customerName: customerName,
        customerPhone: customerPhone,
        startCode: startCode,
      );

  // --- Available rides & offers ----------------------------------------------
  /// Pending offers with a fresh 5-minute expiry window, like the real API.
  static List<Offer> offers({Duration validity = const Duration(minutes: 5)}) {
    final expiresAt = DateTime.now().add(validity);
    return [
      Offer(
        offerId: 'demo-offer-1',
        rideId: 'demo-ride-101',
        pickup: pickup,
        destination: destination,
        fare: 2000,
        distanceMeters: 7400,
        expiresAt: expiresAt,
      ),
      Offer(
        offerId: 'demo-offer-2',
        rideId: 'demo-ride-102',
        pickup: 'شارع الستين',
        destination: 'مطار صنعاء الدولي',
        fare: 3500,
        distanceMeters: 14500,
        expiresAt: expiresAt,
      ),
    ];
  }

  static List<AvailableRide> availableRides(
      {Duration validity = const Duration(minutes: 10)}) {
    final expiresAt = DateTime.now().add(validity);
    return [
      AvailableRide(
        rideId: 'demo-ride-201',
        pickup: 'صنعاء القديمة',
        destination: 'حي الحصبة',
        fare: 1500,
        distanceMeters: 5200,
        expiresAt: expiresAt,
      ),
      AvailableRide(
        rideId: 'demo-ride-202',
        pickup: 'ميدان التحرير',
        destination: 'حي حدة',
        fare: 2500,
        distanceMeters: 9100,
        expiresAt: expiresAt,
      ),
    ];
  }

  // --- Earnings ---------------------------------------------------------------
  // DateTime constructors are not const, so these are final (computed once).
  static final List<CompletedRide> completedRides = [
    CompletedRide(
      rideId: 'demo-ride-901',
      fare: 2000,
      platformCommission: 200,
      netToDriver: 1800,
      cashCollected: 2000,
      completedAt: DateTime(2026, 10, 20, 9, 30),
    ),
    CompletedRide(
      rideId: 'demo-ride-902',
      fare: 3500,
      platformCommission: 350,
      netToDriver: 3150,
      cashCollected: 3500,
      completedAt: DateTime(2026, 10, 21, 14, 5),
    ),
    CompletedRide(
      rideId: 'demo-ride-903',
      fare: 1500,
      platformCommission: 150,
      netToDriver: 1350,
      cashCollected: 1500,
      completedAt: DateTime(2026, 10, 22, 18, 45),
    ),
  ];

  /// Totals derived from [completedRides] (10% commission) so the figures can
  /// never drift apart.
  static final EarningsState earnings = EarningsState(
    completedRides: completedRides,
    totalFare: 7000,
    platformCommission: 700,
    netPayable: 6300,
    cashCollected: 7000,
    platformReceivables: 700,
  );

  /// A synthetic straight-line route between two points, good enough to draw
  /// a polyline in demo mode.
  static RouteResult syntheticRoute(LatLng origin, LatLng destination) {
    const steps = 5;
    final points = <LatLng>[
      for (var i = 0; i <= steps; i++)
        LatLng(
          origin.latitude + (destination.latitude - origin.latitude) * i / steps,
          origin.longitude + (destination.longitude - origin.longitude) * i / steps,
        ),
    ];
    return RouteResult(points: points, distanceMeters: 7400, durationSeconds: 1200);
  }
}
