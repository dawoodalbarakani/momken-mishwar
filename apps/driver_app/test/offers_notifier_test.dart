
import 'package:driver_app/data/repositories/offers_repository.dart';
import 'package:driver_app/domain/models/offer.dart';
import 'package:driver_app/ui/features/offers/view_models/offers_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockOffersRepository extends Mock implements OffersRepository {}

void main() {
  late MockOffersRepository repo;
  late ProviderContainer container;

  final now = DateTime.now();
  Offer buildOffer(String id, {OfferStatus status = OfferStatus.pending}) => Offer(
        offerId: id,
        rideId: 'ride-$id',
        pickup: 'التحرير',
        destination: 'الصافية',
        fare: 100,
        distanceMeters: 5000,
        expiresAt: now.add(const Duration(minutes: 5)),
        status: status,
      );

  setUp(() {
    repo = MockOffersRepository();
    container = ProviderContainer(
      overrides: [offersRepositoryProvider.overrideWithValue(repo)],
    );
  });

  // Disposing the container cancels pending offer-expiry timers registered
  // through ref.onDispose, keeping tests free of leaked timers.
  tearDown(() => container.dispose());

  test('fetchOffers loads offers and clears loading', () async {
    when(repo.fetchOffers()).thenAnswer((_) async => [buildOffer('o1')]);

    await container.read(offersViewModelProvider.notifier).fetchOffers();

    final state = container.read(offersViewModelProvider);
    expect(state.offers, hasLength(1));
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
  });

  test('fetchOffers failure records error', () async {
    when(repo.fetchOffers()).thenThrow(Exception('network'));

    await container.read(offersViewModelProvider.notifier).fetchOffers();

    final state = container.read(offersViewModelProvider);
    expect(state.error, 'فشل جلب العروض');
    expect(state.isLoading, isFalse);
  });

  test('acceptOffer is blocked while another ride is active', () async {
    when(repo.fetchOffers()).thenAnswer((_) async => [buildOffer('o1')]);
    final notifier = container.read(offersViewModelProvider.notifier);
    await notifier.fetchOffers();
    notifier.setActiveRideId('other-ride');

    final ok = await notifier.acceptOffer('o1');

    expect(ok, isFalse);
    expect(container.read(offersViewModelProvider).error, contains('رحلة نشطة'));
  });

  test('acceptOffer marks offer accepted and sets active ride', () async {
    when(repo.fetchOffers()).thenAnswer((_) async => [buildOffer('o1')]);
    when(repo.acceptOffer(any, rideId: any, idempotencyKey: any))
        .thenAnswer((_) async => true);

    final notifier = container.read(offersViewModelProvider.notifier);
    await notifier.fetchOffers();
    final ok = await notifier.acceptOffer('o1');

    expect(ok, isTrue);
    final state = container.read(offersViewModelProvider);
    expect(state.hasActiveRide, isTrue);
    expect(state.activeRideId, 'ride-o1');
    expect(state.offers.single.status, OfferStatus.accepted);
  });

  test('acceptOffer rejects expired offers', () async {
    final expired = Offer(
      offerId: 'o1',
      rideId: 'ride-o1',
      pickup: 'a',
      destination: 'b',
      fare: 100,
      distanceMeters: 5000,
      expiresAt: now.subtract(const Duration(minutes: 1)),
    );
    when(repo.fetchOffers()).thenAnswer((_) async => [expired]);

    final notifier = container.read(offersViewModelProvider.notifier);
    await notifier.fetchOffers();
    final ok = await notifier.acceptOffer('o1');

    expect(ok, isFalse);
    expect(container.read(offersViewModelProvider).error, 'العرض غير متاح للقبول');
  });

  test('rejectOffer marks offer rejected', () async {
    when(repo.fetchOffers()).thenAnswer((_) async => [buildOffer('o1')]);
    when(repo.rejectOffer(any)).thenAnswer((_) async => true);

    final notifier = container.read(offersViewModelProvider.notifier);
    await notifier.fetchOffers();
    final ok = await notifier.rejectOffer('o1');

    expect(ok, isTrue);
    expect(container.read(offersViewModelProvider).offers.single.status,
        OfferStatus.rejected);
  });

  test('endActiveRide clears the active ride id', () async {
    final notifier = container.read(offersViewModelProvider.notifier);
    notifier.setActiveRideId('r1');
    expect(container.read(offersViewModelProvider).hasActiveRide, isTrue);

    notifier.endActiveRide();

    final state = container.read(offersViewModelProvider);
    expect(state.hasActiveRide, isFalse);
    expect(state.activeRideId, isNull);
  });
}
