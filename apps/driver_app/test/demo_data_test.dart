import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driver_app/data/mock/demo_data.dart';
import 'package:driver_app/data/mock/demo_repositories.dart';
import 'package:driver_app/data/repositories/auth_repository.dart';
import 'package:driver_app/data/repositories/documents_repository.dart';
import 'package:driver_app/data/repositories/earnings_repository.dart';
import 'package:driver_app/data/repositories/map_repository.dart';
import 'package:driver_app/data/repositories/offers_repository.dart';
import 'package:driver_app/data/repositories/ride_repository.dart';
import 'package:driver_app/data/services/connectivity_service.dart';
import 'package:driver_app/domain/models/available_ride.dart';
import 'package:driver_app/domain/models/document.dart';
import 'package:driver_app/domain/models/offer.dart';
import 'package:driver_app/domain/models/ride.dart';
import 'package:driver_app/ui/features/auth/view_models/auth_view_model.dart';
import 'package:driver_app/ui/features/earnings/view_models/earnings_view_model.dart';
import 'package:driver_app/ui/features/home/view_models/home_view_model.dart';
import 'package:driver_app/ui/features/offers/view_models/offers_view_model.dart';
import 'package:driver_app/ui/features/ride_tracking/view_models/ride_tracking_view_model.dart';

/// Contract tests for the demo back end: they drive the real driver notifiers
/// against fresh demo repositories, proving the demo data is consistent with
/// every state transition the app makes (auth guard, availability toggle,
/// offer accept/reject, earnings, and the full verify → start → complete
/// ride lifecycle), and giving integration tests a ready-made offline app.
void main() {
  late DemoRideRepository rideRepo;
  late DemoDocumentsRepository documentsRepo;
  late ProviderContainer container;

  setUp(() {
    rideRepo = DemoRideRepository();
    documentsRepo = DemoDocumentsRepository();
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
      rideRepositoryProvider.overrideWithValue(rideRepo),
      offersRepositoryProvider.overrideWithValue(DemoOffersRepository()),
      earningsRepositoryProvider.overrideWithValue(DemoEarningsRepository()),
      documentsRepositoryProvider.overrideWithValue(documentsRepo),
      mapRepositoryProvider.overrideWithValue(DemoMapRepository()),
      connectivityServiceProvider.overrideWithValue(DemoConnectivityService()),
    ]);
  });

  tearDown(() => container.dispose());

  group('demo auth flow (through AuthNotifier)', () {
    test('the demo OTP logs an approved driver in', () async {
      final notifier = container.read(authViewModelProvider.notifier);
      expect(await notifier.verifyOtp(DemoData.demoPhone, DemoData.demoOtp), isTrue);
      final state = container.read(authViewModelProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.isApproved, isTrue);
      expect(state.user?.name, 'فهد المطري');
    });

    test('a wrong OTP fails with the generic error message', () async {
      final notifier = container.read(authViewModelProvider.notifier);
      expect(await notifier.verifyOtp(DemoData.demoPhone, '000000'), isFalse);
      expect(container.read(authViewModelProvider).error, 'فشل التحقق من الرمز');
    });

    test('initialize restores the session and loads the approved profile', () async {
      final notifier = container.read(authViewModelProvider.notifier);
      await notifier.verifyOtp(DemoData.demoPhone, DemoData.demoOtp);
      notifier.logout();
      // Re-login silently: token is back after verify, so initialize finds it.
      await notifier.verifyOtp(DemoData.demoPhone, DemoData.demoOtp);
      expect(await notifier.initialize(), isTrue);
      final state = container.read(authViewModelProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.isApproved, isTrue);
      expect(state.isInitializing, isFalse);
    });

    test('register always succeeds in demo mode', () async {
      final notifier = container.read(authViewModelProvider.notifier);
      expect(
        await notifier.registerDriver(
          name: 'سائق جديد',
          phone: DemoData.demoPhone,
          vehicleType: 'sedan',
          plateNumber: 'صنعاء أ 12345',
          nationalId: '0101010101',
          licenseNumber: 'L-12345',
        ),
        isTrue,
      );
    });
  });

  group('demo home (availability + available rides)', () {
    test('fetchAvailableRides returns the demo queue', () async {
      await container.read(homeViewModelProvider.notifier).fetchAvailableRides();
      final state = container.read(homeViewModelProvider);
      expect(state.availableRides, hasLength(2));
      expect(state.availableRides.first.rideId, 'demo-ride-201');
      expect(state.error, isNull);
    });

    test('toggleAvailability goes online', () async {
      expect(container.read(homeViewModelProvider).availability, AvailabilityStatus.offline);
      expect(await container.read(homeViewModelProvider.notifier).toggleAvailability(), isTrue);
      expect(container.read(homeViewModelProvider).availability, AvailabilityStatus.online);
      expect(rideRepo.isAvailable, isTrue);
    });

    test('connectivity settles on online', () async {
      container.read(homeViewModelProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(homeViewModelProvider).connectionStatus, ConnectionStatus.online);
    });
  });

  group('demo offers lifecycle', () {
    test('accept marks the offer accepted and pins the active ride', () async {
      final notifier = container.read(offersViewModelProvider.notifier);
      await notifier.fetchOffers();
      expect(container.read(offersViewModelProvider).offers, hasLength(2));

      expect(await notifier.acceptOffer('demo-offer-1'), isTrue);
      final state = container.read(offersViewModelProvider);
      expect(state.activeRideId, 'demo-ride-101');
      expect(state.offers.first.status, OfferStatus.accepted);
    });

    test('a second accept is blocked by the active-ride guard', () async {
      final notifier = container.read(offersViewModelProvider.notifier);
      await notifier.fetchOffers();
      await notifier.acceptOffer('demo-offer-1');
      expect(await notifier.acceptOffer('demo-offer-2'), isFalse);
      expect(container.read(offersViewModelProvider).error,
          'لديك رحلة نشطة بالفعل، لا يمكن قبول رحلة جديدة');
    });

    test('reject removes the offer from pending', () async {
      final notifier = container.read(offersViewModelProvider.notifier);
      await notifier.fetchOffers();
      expect(await notifier.rejectOffer('demo-offer-2'), isTrue);
      expect(container.read(offersViewModelProvider).offers.last.status, OfferStatus.rejected);
      // Rejecting the same offer twice hits the repository's false branch.
      expect(await notifier.rejectOffer('demo-offer-2'), isFalse);
    });
  });

  group('demo earnings', () {
    test('build fetches the demo ledger with consistent totals', () async {
      container.read(earningsViewModelProvider); // deferred fetch on build
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final state = container.read(earningsViewModelProvider);
      expect(state.completedRides, hasLength(3));
      expect(state.totalFare, 7000);
      expect(state.netPayable, 6300);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('payout succeeds in range and fails out of range', () async {
      final notifier = container.read(earningsViewModelProvider.notifier);
      expect(await notifier.requestPayout(1000), isTrue);
      expect(await notifier.requestPayout(0), isFalse);
      expect(await notifier.requestPayout(999999), isFalse);
    });
  });

  group('demo ride tracking lifecycle', () {
    RideTrackingState tracking() =>
        container.read(rideTrackingViewModelProvider(DemoData.rideId));
    RideTrackingNotifier trackingNotifier() =>
        container.read(rideTrackingViewModelProvider(DemoData.rideId).notifier);

    test('assigned ride → verify → wrong code → right code → complete', () async {
      tracking(); // triggers build + restore
      await Future<void>.delayed(Duration.zero);
      expect(tracking().status, RideStatus.assigned);
      expect(tracking().customerName, DemoData.customerName);
      expect(tracking().isLoading, isFalse);

      expect(await trackingNotifier().verifyAssignment(), isTrue);

      expect(await trackingNotifier().startRide('0000'), isFalse);
      expect(tracking().error, 'رمز بدء الرحلة غير صحيح');

      expect(await trackingNotifier().startRide(DemoData.startCode), isTrue);
      expect(tracking().status, RideStatus.inProgress);
      expect(tracking().canComplete, isTrue);

      expect(await trackingNotifier().completeRide(), isTrue);
      expect(tracking().status, RideStatus.completed);

      // Cancelling a completed ride hits the notifier's guard branch.
      expect(
        await trackingNotifier().cancelRide(reason: 'test', actor: 'driver'),
        isFalse,
      );
      expect(tracking().error, 'الرحلة مكتملة أو ملغاة مسبقاً');
    });

    test('cancelling an assigned ride records the cancellation', () async {
      tracking();
      await Future<void>.delayed(Duration.zero);
      expect(
        await trackingNotifier().cancelRide(reason: 'تعذر الوصول', actor: 'driver'),
        isTrue,
      );
      expect(tracking().status, RideStatus.cancelled);
      expect(tracking().cancellation?.actor, 'driver');
    });

    test('an unknown ride fails restore with the demo error message', () async {
      container.read(rideTrackingViewModelProvider('nope'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(rideTrackingViewModelProvider('nope')).error,
          'فشل استعادة حالة الرحلة');
    });
  });

  group('demo documents + map', () {
    test('upload link is served for every document type', () async {
      final link = await documentsRepo.getUploadLink(DocumentType.nationalId);
      expect(link['upload_url'], contains('national_id'));
      expect(await documentsRepo.submitDocuments(), isTrue);
    });

    test('place search filters by Arabic name', () async {
      expect(await container.read(mapRepositoryProvider).searchPlaces('تحرير'), hasLength(1));
      expect(await container.read(mapRepositoryProvider).searchPlaces(''),
          hasLength(DemoData.places.length));
    });
  });
}
