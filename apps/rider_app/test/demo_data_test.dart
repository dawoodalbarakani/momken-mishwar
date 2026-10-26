import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rider_app/data/mock/demo_data.dart';
import 'package:rider_app/data/mock/demo_repositories.dart';
import 'package:rider_app/data/repositories/auth_repository.dart';
import 'package:rider_app/data/repositories/map_repository.dart';
import 'package:rider_app/data/repositories/ride_repository.dart';
import 'package:rider_app/data/services/connectivity_service.dart';
import 'package:rider_app/domain/models/ride.dart';
import 'package:rider_app/ui/features/auth/view_models/auth_view_model.dart';
import 'package:rider_app/ui/features/home/view_models/home_view_model.dart';
import 'package:rider_app/ui/features/quote/view_models/quote_view_model.dart';
import 'package:rider_app/ui/features/ride_request/view_models/ride_request_view_model.dart';
import 'package:rider_app/ui/features/ride_tracking/view_models/ride_tracking_view_model.dart';

/// Contract tests for the demo back end: they drive the real notifiers
/// against fresh demo repositories, proving the demo data is consistent with
/// every state transition the app makes (and giving integration tests a
/// ready-made offline app to pump).
void main() {
  late DemoAuthRepository authRepo;
  late DemoRideRepository rideRepo;
  late DemoMapRepository mapRepo;
  late ProviderContainer container;

  setUp(() {
    authRepo = DemoAuthRepository();
    rideRepo = DemoRideRepository();
    mapRepo = DemoMapRepository();
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      rideRepositoryProvider.overrideWithValue(rideRepo),
      mapRepositoryProvider.overrideWithValue(mapRepo),
      connectivityServiceProvider.overrideWithValue(DemoConnectivityService()),
      // Empty event stream: the tracking notifier must work with zero events.
      rideEventSourceProvider.overrideWithValue((rideId) => const Stream<dynamic>.empty()),
    ]);
  });

  tearDown(() => container.dispose());

  group('demo auth flow (through AuthNotifier)', () {
    test('OTP request always succeeds in demo mode', () async {
      expect(
        await container.read(authViewModelProvider.notifier).requestOtp(DemoData.demoPhone),
        isTrue,
      );
    });

    test('the demo OTP logs the rider in', () async {
      final notifier = container.read(authViewModelProvider.notifier);
      expect(await notifier.verifyOtp(DemoData.demoPhone, DemoData.demoOtp), isTrue);
      final state = container.read(authViewModelProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.token, DemoData.accessToken);
      expect(state.user?.name, 'سالم');
    });

    test('a wrong OTP shows the server Arabic error', () async {
      final notifier = container.read(authViewModelProvider.notifier);
      expect(await notifier.verifyOtp(DemoData.demoPhone, '000000'), isFalse);
      expect(container.read(authViewModelProvider).error, 'رمز التحقق غير صحيح');
    });
  });

  group('demo quote + ride lifecycle', () {
    test('fetchQuote returns the demo fare', () async {
      final ok = await container
          .read(quoteViewModelProvider.notifier)
          .fetchQuote(pickup: 'place-tahrir', destination: 'place-hadda');
      expect(ok, isTrue);
      expect(container.read(quoteViewModelProvider).quote, same(DemoData.quote));
    });

    test('create → cancel → re-cancel runs the whole state machine', () async {
      final notifier = container.read(rideRequestViewModelProvider.notifier);
      expect(
        await notifier.createRide(pickup: 'p', destination: 'd', quoteId: DemoData.quote.id),
        isTrue,
      );
      final rideId = container.read(rideRequestViewModelProvider).rideId;
      expect(rideId, 'demo-ride-101');

      expect(await notifier.cancelRide(), isTrue);
      expect(container.read(rideRequestViewModelProvider).status, RideRequestStatus.cancelled);

      // Second cancel hits the repository's false branch → error, not cancelled.
      expect(await notifier.cancelRide(), isFalse);
      expect(container.read(rideRequestViewModelProvider).error, 'فشل إلغاء الرحلة');
    });
  });

  group('demo ride tracking', () {
    test('the preexisting ride restores driver info', () async {
      container.read(rideTrackingViewModelProvider(DemoData.preexistingRideId));
      await Future<void>.delayed(Duration.zero);
      final state = container.read(rideTrackingViewModelProvider(DemoData.preexistingRideId));
      expect(state.driverName, DemoData.driverName);
      expect(state.vehiclePlate, DemoData.vehiclePlate);
      expect(state.startCode, DemoData.startCode);
      expect(state.isLoading, isFalse);
    });

    test('a freshly created ride is restorable on the tracking screen', () async {
      await container
          .read(rideRequestViewModelProvider.notifier)
          .createRide(pickup: 'p', destination: 'd', quoteId: 'q');
      final rideId = container.read(rideRequestViewModelProvider).rideId!;
      container.read(rideTrackingViewModelProvider(rideId));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(rideTrackingViewModelProvider(rideId)).driverName,
          DemoData.driverName);
    });
  });

  group('demo map data', () {
    test('search filters by Arabic name and matches everything when empty', () async {
      final notifier = container.read(homeViewModelProvider.notifier);
      expect(await notifier.searchPlaces('تحرير'), hasLength(1));
      expect(await notifier.searchPlaces(''), hasLength(DemoData.places.length));
      expect(await notifier.searchPlaces('لا شيء'), isEmpty);
    });

    test('locateMe lands on the demo pickup point', () async {
      final notifier = container.read(homeViewModelProvider.notifier);
      await notifier.locateMe();
      expect(container.read(homeViewModelProvider).currentLocation, DemoData.pickedLocation);
    });

    test('getRoute returns an interpolated polyline', () async {
      final route = await mapRepo.getRoute(
        const LatLng(15.35, 44.20),
        const LatLng(15.33, 44.24),
      );
      expect(route.points, hasLength(6));
      expect(route.points.first.latitude, closeTo(15.35, 1e-9));
      expect(route.points.last.longitude, closeTo(44.24, 1e-9));
    });
  });

  group('demo connectivity', () {
    test('home notifier settles on online', () async {
      container.read(homeViewModelProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(homeViewModelProvider).connectionStatus, ConnectionStatus.online);
    });
  });

  group('demo event source', () {
    test('emits deterministic driver_location maps', () async {
      final events = await demoRideEventSource('r1').take(2).toList();
      expect(events, hasLength(2));
      final first = events.first as Map<String, dynamic>;
      expect(first['type'], 'driver_location');
      expect(first['ride_id'], 'r1');
      expect(first['latitude'], isA<double>());
    });
  });
}
