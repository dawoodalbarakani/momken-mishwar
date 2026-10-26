
import 'package:driver_app/data/repositories/ride_repository.dart';
import 'package:driver_app/data/services/connectivity_service.dart';
import 'package:driver_app/domain/models/available_ride.dart';
import 'package:driver_app/ui/features/home/view_models/home_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockRideRepository extends Mock implements RideRepository {}

class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  late MockRideRepository rideRepo;
  late MockConnectivityService connectivity;
  late ProviderContainer container;

  setUp(() {
    rideRepo = MockRideRepository();
    connectivity = MockConnectivityService();
    when(connectivity.watch())
        .thenAnswer((_) => Stream<ConnectionStatus>.value(ConnectionStatus.online));
    container = ProviderContainer(
      overrides: [
        rideRepositoryProvider.overrideWithValue(rideRepo),
        connectivityServiceProvider.overrideWithValue(connectivity),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('initial state is offline with online connectivity detected', () async {
    container.read(homeViewModelProvider);
    await Future<void>(() {});

    final state = container.read(homeViewModelProvider);
    expect(state.availability, AvailabilityStatus.offline);
    expect(state.connectionStatus, ConnectionStatus.online);
  });

  test('toggleAvailability goes online on success', () async {
    when(rideRepo.toggleAvailability(available: any))
        .thenAnswer((_) async => true);

    final ok = await container
        .read(homeViewModelProvider.notifier)
        .toggleAvailability();

    expect(ok, isTrue);
    final state = container.read(homeViewModelProvider);
    expect(state.availability, AvailabilityStatus.online);
    expect(state.isLoading, isFalse);
  });

  test('toggleAvailability failure keeps status and records error', () async {
    when(rideRepo.toggleAvailability(available: any))
        .thenThrow(Exception('network'));

    final ok = await container
        .read(homeViewModelProvider.notifier)
        .toggleAvailability();

    expect(ok, isFalse);
    final state = container.read(homeViewModelProvider);
    expect(state.availability, AvailabilityStatus.offline);
    expect(state.error, 'فشل تغيير حالة التوفر');
  });

  test('fetchAvailableRides populates the ride list', () async {
    final rides = [
      AvailableRide(
        rideId: 'r1',
        pickup: 'التحرير',
        destination: 'الدائري',
        fare: 80,
        distanceMeters: 4200,
        expiresAt: DateTime.now().add(const Duration(minutes: 3)),
      ),
    ];
    when(rideRepo.fetchAvailableRides()).thenAnswer((_) async => rides);

    await container.read(homeViewModelProvider.notifier).fetchAvailableRides();

    final state = container.read(homeViewModelProvider);
    expect(state.availableRides, hasLength(1));
    expect(state.isLoading, isFalse);
  });
}
