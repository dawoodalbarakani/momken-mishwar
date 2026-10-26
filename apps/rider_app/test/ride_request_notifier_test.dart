import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:rider_app/data/repositories/ride_repository.dart';
import 'package:rider_app/domain/models/quote.dart';
import 'package:rider_app/domain/models/ride.dart';
import 'package:rider_app/ui/features/ride_request/view_models/ride_request_view_model.dart';

/// Hand-written, generated-style mock: every when-stubbed member overrides with
/// nullable-widened params delegating to noSuchMethod with a typed returnValue.
class MockRideRepository extends Mock implements RideRepository {
  @override
  Future<Quote> fetchQuote({String? pickup, String? destination}) => (super.noSuchMethod(
        Invocation.method(#fetchQuote, [], {#pickup: pickup, #destination: destination}),
        returnValue: Future<Quote>.value(const Quote(
          id: '',
          estimatedAmount: '0',
          currency: 'YER',
          ruleVersion: '',
          distanceMeters: 0,
          durationSeconds: 0,
          extraFees: '0',
        )),
      ) as Future<Quote>);

  @override
  Future<String> createRide({String? pickup, String? destination, String? quoteId}) =>
      (super.noSuchMethod(
        Invocation.method(#createRide, [],
            {#pickup: pickup, #destination: destination, #quoteId: quoteId}),
        returnValue: Future<String>.value(''),
      ) as Future<String>);

  @override
  Future<bool> cancelRide(String? rideId) => (super.noSuchMethod(
        Invocation.method(#cancelRide, [rideId]),
        returnValue: Future<bool>.value(true),
        returnValueForMissingStub: Future<bool>.value(true),
      ) as Future<bool>);

  @override
  Future<Ride> getRide(String? rideId) => (super.noSuchMethod(
        Invocation.method(#getRide, [rideId]),
        returnValue: Future<Ride>.value(const Ride(id: '')),
        returnValueForMissingStub: Future<Ride>.value(const Ride(id: '')),
      ) as Future<Ride>);
}

void main() {
  late MockRideRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = MockRideRepository();
    container =
        ProviderContainer(overrides: [rideRepositoryProvider.overrideWithValue(repo)]);
  });

  tearDown(() => container.dispose());

  RideRequestState state() => container.read(rideRequestViewModelProvider);
  RideRequestNotifier notifier() => container.read(rideRequestViewModelProvider.notifier);

  Future<void> createRideOk() async {
    when(repo.createRide(
      pickup: anyNamed('pickup'),
      destination: anyNamed('destination'),
      quoteId: anyNamed('quoteId'),
    )).thenAnswer((_) async => 'ride-1');
    await notifier().createRide(pickup: 'p', destination: 'd', quoteId: 'q1');
  }

  group('initial', () {
    test('starts idle', () {
      expect(state().status, RideRequestStatus.idle);
      expect(state().rideId, isNull);
      expect(state().isLoading, isFalse);
    });
  });

  group('createRide', () {
    test('success stores the ride id and searches', () async {
      await createRideOk();
      expect(state().status, RideRequestStatus.searching);
      expect(state().rideId, 'ride-1');
      expect(state().isLoading, isFalse);
      expect(state().error, isNull);
    });

    test('failure moves to error status', () async {
      when(repo.createRide(
        pickup: anyNamed('pickup'),
        destination: anyNamed('destination'),
        quoteId: anyNamed('quoteId'),
      )).thenAnswer((_) async => throw Exception('network'));
      expect(await notifier().createRide(pickup: 'p', destination: 'd', quoteId: 'q1'), isFalse);
      expect(state().status, RideRequestStatus.error);
      expect(state().error, 'فشل إنشاء الرحلة');
      expect(state().isLoading, isFalse);
    });

    test('a new request starts from a fresh state (old error cleared)', () async {
      when(repo.createRide(
        pickup: anyNamed('pickup'),
        destination: anyNamed('destination'),
        quoteId: anyNamed('quoteId'),
      )).thenAnswer((_) async => throw Exception('network'));
      await notifier().createRide(pickup: 'p', destination: 'd', quoteId: 'q1');
      expect(state().error, isNotNull);

      await createRideOk();
      expect(state().error, isNull);
      expect(state().status, RideRequestStatus.searching);
    });
  });

  group('cancelRide', () {
    test('repository success moves to cancelled', () async {
      await createRideOk();
      when(repo.cancelRide('ride-1')).thenAnswer((_) async => true);
      expect(await notifier().cancelRide(), isTrue);
      expect(state().status, RideRequestStatus.cancelled);
      expect(state().isLoading, isFalse);
    });

    test('repository false is surfaced as an error, not cancelled', () async {
      await createRideOk();
      when(repo.cancelRide('ride-1')).thenAnswer((_) async => false);
      expect(await notifier().cancelRide(), isFalse);
      expect(state().status, isNot(RideRequestStatus.cancelled));
      expect(state().error, 'فشل إلغاء الرحلة');
      expect(state().isLoading, isFalse);
    });

    test('unexpected throw is handled as failure', () async {
      await createRideOk();
      when(repo.cancelRide('ride-1')).thenAnswer((_) async => throw Exception('boom'));
      expect(await notifier().cancelRide(), isFalse);
      expect(state().error, 'فشل إلغاء الرحلة');
    });

    test('cancels the ride returned by the last createRide', () async {
      await createRideOk();
      await notifier().cancelRide();
      verify(repo.cancelRide('ride-1')).called(1);
    });
  });

  group('setDriverFound', () {
    test('updates status and driver name', () async {
      await createRideOk();
      notifier().setDriverFound('خالد');
      expect(state().status, RideRequestStatus.driverFound);
      expect(state().driverName, 'خالد');
      expect(state().isLoading, isFalse);
    });
  });
}
