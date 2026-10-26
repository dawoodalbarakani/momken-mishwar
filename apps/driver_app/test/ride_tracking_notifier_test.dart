
import 'package:driver_app/data/repositories/ride_repository.dart';
import 'package:driver_app/domain/models/ride.dart';
import 'package:driver_app/ui/features/ride_tracking/view_models/ride_tracking_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// Hand-written, generated-style overrides (nullable params) so mockito's `any`
// matcher is valid at non-nullable call sites.
class MockRideRepository extends Mock implements RideRepository {
  @override
  Future<Ride> getRide(String? rideId) => (super.noSuchMethod(
        Invocation.method(#getRide, [rideId]),
        returnValue: Future<Ride>.value(const Ride(id: '')),
      ) as Future<Ride>);

  @override
  Future<bool> startRide(String? rideId, {String? startCode}) => (super.noSuchMethod(
        Invocation.method(#startRide, [rideId], {#startCode: startCode}),
        returnValue: Future<bool>.value(false),
      ) as Future<bool>);

  @override
  Future<bool> cancelRide(String? rideId, {String? reason, String? actor}) =>
      (super.noSuchMethod(
        Invocation.method(#cancelRide, [rideId], {#reason: reason, #actor: actor}),
        returnValue: Future<bool>.value(false),
      ) as Future<bool>);
}

void main() {
  late MockRideRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = MockRideRepository();
    container = ProviderContainer(
      overrides: [rideRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() => container.dispose());

  /// Reads the family notifier (triggering `_restore`) and lets the
  /// event loop drain so the restored state has been written.
  Future<RideTrackingNotifier> pumpNotifier(String rideId) async {
    final notifier = container.read(rideTrackingViewModelProvider(rideId).notifier);
    await Future<void>(() {});
    await Future<void>(() {});
    return notifier;
  }

  test('startRide requires a verified assignment', () async {
    when(repo.getRide(any)).thenAnswer(
      (_) async => const Ride(id: 'r1', startCode: '1234'),
    );
    final notifier = await pumpNotifier('r1');

    final ok = await notifier.startRide('1234');

    expect(ok, isFalse);
    expect(container.read(rideTrackingViewModelProvider('r1')).error,
        contains('التحقق'));
  });

  test('startRide rejects a wrong start code', () async {
    when(repo.getRide(any)).thenAnswer(
      (_) async => const Ride(id: 'r1', startCode: '1234', verifiedAssignment: true),
    );
    final notifier = await pumpNotifier('r1');

    final ok = await notifier.startRide('9999');

    expect(ok, isFalse);
    expect(container.read(rideTrackingViewModelProvider('r1')).error,
        contains('غير صحيح'));
  });

  test('startRide with correct code moves ride to in-progress', () async {
    when(repo.getRide(any)).thenAnswer(
      (_) async => const Ride(id: 'r1', startCode: '1234', verifiedAssignment: true),
    );
    when(repo.startRide(any, startCode: anyNamed('startCode'))).thenAnswer((_) async => true);
    final notifier = await pumpNotifier('r1');

    final ok = await notifier.startRide('1234');

    expect(ok, isTrue);
    final state = container.read(rideTrackingViewModelProvider('r1'));
    expect(state.started, isTrue);
    expect(state.status, RideStatus.inProgress);
    expect(state.canComplete, isTrue);
  });

  test('completeRide is refused before the ride has started', () async {
    when(repo.getRide(any)).thenAnswer((_) async => const Ride(id: 'r1'));
    final notifier = await pumpNotifier('r1');

    final ok = await notifier.completeRide();

    expect(ok, isFalse);
    expect(container.read(rideTrackingViewModelProvider('r1')).error,
        'لا يمكن إنهاء الرحلة في الحالة الحالية');
  });

  test('cancelRide records cancellation details', () async {
    when(repo.getRide(any)).thenAnswer((_) async => const Ride(id: 'r1'));
    when(repo.cancelRide(any, reason: anyNamed('reason'), actor: anyNamed('actor')))
        .thenAnswer((_) async => true);
    final notifier = await pumpNotifier('r1');

    final ok = await notifier.cancelRide(reason: 'تغيرت الخطط', actor: 'driver');

    expect(ok, isTrue);
    final state = container.read(rideTrackingViewModelProvider('r1'));
    expect(state.status, RideStatus.cancelled);
    expect(state.cancellation?.actor, 'driver');
  });

  test('restore failure surfaces an error', () async {
    // Throw asynchronously (like a real network failure): a synchronous throw
    // would write state during build(), which Riverpod forbids.
    when(repo.getRide(any))
        .thenAnswer((_) async => throw Exception('network'));
    await pumpNotifier('r1');

    final state = container.read(rideTrackingViewModelProvider('r1'));
    expect(state.isLoading, isFalse);
    expect(state.error, 'فشل استعادة حالة الرحلة');
  });
}
