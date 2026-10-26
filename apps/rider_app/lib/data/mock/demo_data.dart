import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../domain/models/auth_user.dart';
import '../../domain/models/quote.dart';
import '../../domain/models/ride.dart';
import '../services/map_service.dart';

/// Static demo fixtures for running and testing the app without the live
/// backend. Everything here is deterministic so tests can assert on exact
/// values; the fake repositories in `demo_repositories.dart` serve them.
class DemoData {
  DemoData._();

  // --- Auth -------------------------------------------------------------
  static const String demoPhone = '+967771234567';
  static const String demoOtp = '123456';
  static const String accessToken = 'demo-access-token';
  static const AuthUser rider =
      AuthUser(id: 'demo-rider-1', phone: demoPhone, name: 'سالم');

  // --- Places (Sana'a) ---------------------------------------------------
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
    PlaceResult(
      placeId: 'place-airport',
      name: 'مطار صنعاء الدولي',
      address: 'الطريق الصاعد غرب المدينة',
      latLng: LatLng(15.2945, 44.1784),
    ),
  ];

  /// Default "current location" returned by the demo location picker
  /// (Tahrir Square).
  static const LatLng pickedLocation = LatLng(15.3543, 44.2113);

  // --- Quote ---------------------------------------------------------------
  static const Quote quote = Quote(
    id: 'demo-quote-1',
    estimatedAmount: '1800',
    currency: 'YER',
    ruleVersion: 'v1',
    distanceMeters: 7400,
    durationSeconds: 1200,
    extraFees: '0',
  );

  // --- Rides ---------------------------------------------------------------
  static const String preexistingRideId = 'demo-ride-1';
  static const String driverName = 'خالد الأهدل';
  static const String vehiclePlate = 'صنعاء أ 12345';
  static const String startCode = '4821';

  static const Ride preexistingRide = Ride(
    id: preexistingRideId,
    driverName: driverName,
    vehiclePlate: vehiclePlate,
    startCode: startCode,
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
    return RouteResult(
      points: points,
      distanceMeters: quote.distanceMeters,
      durationSeconds: quote.durationSeconds,
    );
  }

  /// Driver position at [tick] of [totalTicks] ticks, interpolated from
  /// pickup to [destination].
  static LatLng driverLocationAt(int tick, int totalTicks, LatLng pickup, LatLng destination) {
    final fraction = (tick + 1) / (totalTicks + 1);
    return LatLng(
      pickup.latitude + (destination.latitude - pickup.latitude) * fraction,
      pickup.longitude + (destination.longitude - pickup.longitude) * fraction,
    );
  }
}
