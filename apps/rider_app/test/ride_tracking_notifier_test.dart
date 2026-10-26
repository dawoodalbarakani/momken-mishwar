import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:rider_app/data/repositories/ride_repository.dart';
import 'package:rider_app/domain/models/quote.dart';
import 'package:rider_app/domain/models/ride.dart';
import 'package:rider_app/ui/features/ride_tracking/view_models/ride_tracking_view_model.dart';

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
  late StreamController<dynamic> rideEvents;
  late ProviderContainer container;

  setUp(() {
    repo = MockRideRepository();
    // Broadcast so multiple family instances (one per ride id) can listen.
    rideEvents = StreamController<dynamic>.broadcast();
    container = ProviderContainer(overrides: [
      rideRepositoryProvider.overrideWithValue(repo),
      rideEventSourceProvider.overrideWithValue((rideId) => rideEvents.stream),
    ]);
  });

  tearDown(() async {
    container.dispose();
    if (!rideEvents.isClosed) await rideEvents.close();
  });

  RideTrackingState state() => container.read(rideTrackingViewModelProvider('r1'));
  RideTrackingNotifier notifier() =>
      container.read(rideTrackingViewModelProvider('r1').notifier);

  group('build', () {
    test('starts optimistically connected while restoring', () async {
      expect(state().isConnected, isTrue);
      expect(state().isLoading, isTrue);
      // Let the async restore settle before the container is disposed.
      await Future<void>.delayed(Duration.zero);
    });

    test('restore fills driver, vehicle and start code', () async {
      when(repo.getRide('r1')).thenAnswer((_) async => const Ride(
            id: 'r1',
            driverName: 'خالد',
            vehiclePlate: 'أب-1234',
            startCode: '4321',
          ));
      expect(state().isConnected, isTrue); // triggers build
      await Future<void>.delayed(Duration.zero);
      expect(state().driverName, 'خالد');
      expect(state().vehiclePlate, 'أب-1234');
      expect(state().startCode, '4321');
      expect(state().isLoading, isFalse);
      expect(state().error, isNull);
    });

    test('restore failure records an error and stops loading', () async {
      when(repo.getRide('r1')).thenAnswer((_) async => throw Exception('network'));
      expect(state().isLoading, isTrue); // triggers build
      await Future<void>.delayed(Duration.zero);
      expect(state().isLoading, isFalse);
      expect(state().error, 'فشل استعادة حالة الرحلة');
    });

    test('the family arg is captured for later repository calls', () async {
      container.read(rideTrackingViewModelProvider('r2'));
      await Future<void>.delayed(Duration.zero);
      verify(repo.getRide('r2')).called(1);
    });
  });

  group('socket events', () {
    test('stream error marks the connection down with an error', () async {
      expect(state().isConnected, isTrue); // triggers build
      rideEvents.addError(Exception('socket'));
      await Future<void>.delayed(Duration.zero);
      expect(state().isConnected, isFalse);
      expect(state().error, 'خطأ في اتصال الركوب');
    });

    test('stream completion marks the connection down', () async {
      expect(state().isConnected, isTrue); // triggers build
      await rideEvents.close();
      await Future<void>.delayed(Duration.zero);
      expect(state().isConnected, isFalse);
    });
  });

  group('cancelRide', () {
    test('passes the repository success through', () async {
      when(repo.cancelRide('r1')).thenAnswer((_) async => true);
      expect(await notifier().cancelRide(), isTrue);
      verify(repo.cancelRide('r1')).called(1);
    });

    test('passes the repository failure through', () async {
      when(repo.cancelRide('r1')).thenAnswer((_) async => false);
      expect(await notifier().cancelRide(), isFalse);
    });

    test('an unexpected throw is reported as failure', () async {
      when(repo.cancelRide('r1')).thenAnswer((_) async => throw Exception('boom'));
      expect(await notifier().cancelRide(), isFalse);
    });
  });

  group('RideTrackingState', () {
    test('isLocationFresh requires an age below 30 seconds', () {
      expect(const RideTrackingState(locationAgeSeconds: 10).isLocationFresh, isTrue);
      expect(const RideTrackingState(locationAgeSeconds: 30).isLocationFresh, isFalse);
      expect(const RideTrackingState().isLocationFresh, isFalse);
    });

    test('clearError drops a recorded error', () {
      const withError = RideTrackingState(error: 'x');
      expect(withError.copyWith(clearError: true).error, isNull);
    });
  });
}
