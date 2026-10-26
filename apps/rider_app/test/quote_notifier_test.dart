import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:rider_app/data/repositories/ride_repository.dart';
import 'package:rider_app/domain/models/quote.dart';
import 'package:rider_app/domain/models/ride.dart';
import 'package:rider_app/ui/features/quote/view_models/quote_view_model.dart';

/// Hand-written, generated-style mock shared by the quote/ride flows.
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

  const dummyQuote = Quote(
    id: 'q1',
    estimatedAmount: '1500',
    currency: 'YER',
    ruleVersion: 'v1',
    distanceMeters: 5200,
    durationSeconds: 900,
    extraFees: '0',
  );

  setUp(() {
    repo = MockRideRepository();
    container = ProviderContainer(overrides: [rideRepositoryProvider.overrideWithValue(repo)]);
  });

  tearDown(() => container.dispose());

  QuoteState state() => container.read(quoteViewModelProvider);
  QuoteNotifier notifier() => container.read(quoteViewModelProvider.notifier);

  group('initial', () {
    test('starts idle with no quote', () {
      expect(state().quote, isNull);
      expect(state().isLoading, isFalse);
      expect(state().error, isNull);
    });
  });

  group('fetchQuote', () {
    test('success stores the server quote', () async {
      when(repo.fetchQuote(pickup: anyNamed('pickup'), destination: anyNamed('destination')))
          .thenAnswer((_) async => dummyQuote);
      expect(await notifier().fetchQuote(pickup: 'p', destination: 'd'), isTrue);
      expect(state().quote, same(dummyQuote));
      expect(state().isLoading, isFalse);
      expect(state().error, isNull);
    });

    test('failure records an error and keeps no quote', () async {
      when(repo.fetchQuote(pickup: anyNamed('pickup'), destination: anyNamed('destination')))
          .thenAnswer((_) async => throw Exception('network'));
      expect(await notifier().fetchQuote(pickup: 'p', destination: 'd'), isFalse);
      expect(state().quote, isNull);
      expect(state().error, 'فشل جلب تقدير الأجرة');
      expect(state().isLoading, isFalse);
    });

    test('is loading while the request is in flight', () async {
      final completer = Completer<Quote>();
      when(repo.fetchQuote(pickup: anyNamed('pickup'), destination: anyNamed('destination')))
          .thenAnswer((_) => completer.future);
      final future = notifier().fetchQuote(pickup: 'p', destination: 'd');
      await Future<void>.delayed(Duration.zero);
      expect(state().isLoading, isTrue);
      completer.complete(dummyQuote);
      await future;
      expect(state().isLoading, isFalse);
    });

    test('a new fetch clears the previous error', () async {
      when(repo.fetchQuote(pickup: anyNamed('pickup'), destination: anyNamed('destination')))
          .thenAnswer((_) async => throw Exception('network'));
      await notifier().fetchQuote(pickup: 'p', destination: 'd');
      expect(state().error, isNotNull);

      when(repo.fetchQuote(pickup: anyNamed('pickup'), destination: anyNamed('destination')))
          .thenAnswer((_) async => dummyQuote);
      await notifier().fetchQuote(pickup: 'p', destination: 'd');
      expect(state().error, isNull);
    });
  });

  group('product tiers', () {
    Future<void> loadQuote() async {
      when(repo.fetchQuote(pickup: anyNamed('pickup'), destination: anyNamed('destination')))
          .thenAnswer((_) async => dummyQuote); // estimatedAmount '1500'
      await notifier().fetchQuote(pickup: 'p', destination: 'd');
    }

    test('lands on the default tier with a price equal to the base estimate', () async {
      await loadQuote();
      expect(state().selectedTierId, kDefaultTierId);
      expect(state().selectedOption?.id, kDefaultTierId);
      // mishwar multiplier is 1.0, so the shown price equals the server quote.
      expect(state().selectedPrice, 1500);
    });

    test('selecting a tier rescales the displayed price', () async {
      await loadQuote();
      notifier().selectTier('xl'); // multiplier 1.6
      expect(state().selectedTierId, 'xl');
      expect(state().selectedPrice, 2400);

      notifier().selectTier('economy'); // multiplier 0.85
      expect(state().selectedPrice, 1275);
    });

    test('unknown tier ids are ignored', () async {
      await loadQuote();
      notifier().selectTier('does-not-exist');
      expect(state().selectedTierId, kDefaultTierId);
    });
  });
}
