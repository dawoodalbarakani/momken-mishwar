
import 'package:driver_app/data/repositories/earnings_repository.dart';
import 'package:driver_app/domain/models/earnings.dart';
import 'package:driver_app/ui/features/earnings/view_models/earnings_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockEarningsRepository extends Mock implements EarningsRepository {}

void main() {
  late MockEarningsRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = MockEarningsRepository();
    container = ProviderContainer(
      overrides: [earningsRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() => container.dispose());

  test('build starts loading and initial fetch fills the summary', () async {
    final fetched = EarningsState(
      completedRides: [
        CompletedRide(
          rideId: 'r1',
          fare: 100,
          platformCommission: 15,
          netToDriver: 85,
          cashCollected: 100,
          completedAt: DateTime(2026, 10, 1),
        ),
      ],
      totalFare: 100,
      netPayable: 85,
    );
    when(repo.fetchEarnings()).thenAnswer((_) async => fetched);

    // Reading the provider triggers build(), which defers the fetch to the
    // event loop; drain the loop so the result has landed.
    container.read(earningsViewModelProvider);
    await Future<void>(() {});
    await Future<void>(() {});

    final state = container.read(earningsViewModelProvider);
    expect(state.isLoading, isFalse);
    expect(state.totalFare, 100);
    expect(state.netPayable, 85);
    expect(state.completedRides, hasLength(1));
  });

  test('fetch failure records a localized error', () async {
    when(repo.fetchEarnings()).thenThrow(Exception('network'));

    container.read(earningsViewModelProvider);
    await Future<void>(() {});
    await Future<void>(() {});

    final state = container.read(earningsViewModelProvider);
    expect(state.error, 'فشل جلب الأرباح');
    expect(state.isLoading, isFalse);
  });

  /// Reads the notifier and drains the event loop so build()'s deferred
  /// initial fetch has completed before the test acts on the notifier.
  Future<EarningsNotifier> settledNotifier() async {
    final notifier = container.read(earningsViewModelProvider.notifier);
    await Future<void>(() {});
    await Future<void>(() {});
    return notifier;
  }

  test('requestPayout failure records a localized error', () async {
    when(repo.fetchEarnings()).thenAnswer((_) async => const EarningsState());
    when(repo.requestPayout(any)).thenThrow(Exception('network'));
    final notifier = await settledNotifier();

    final ok = await notifier.requestPayout(50);

    expect(ok, isFalse);
    expect(container.read(earningsViewModelProvider).error,
        'فشل إرسال طلب التسوية');
  });

  test('requestPayout success clears loading', () async {
    when(repo.fetchEarnings()).thenAnswer((_) async => const EarningsState());
    when(repo.requestPayout(any)).thenAnswer((_) async => true);
    final notifier = await settledNotifier();

    final ok = await notifier.requestPayout(50);

    expect(ok, isTrue);
    expect(container.read(earningsViewModelProvider).isLoading, isFalse);
  });
}
