import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:rider_app/data/repositories/map_repository.dart';
import 'package:rider_app/data/services/connectivity_service.dart';
import 'package:rider_app/data/services/map_service.dart';
import 'package:rider_app/ui/features/home/view_models/home_view_model.dart';

/// Hand-written, generated-style mock: every when-stubbed member overrides with
/// nullable-widened params delegating to noSuchMethod with a typed returnValue.
class MockMapRepository extends Mock implements MapRepository {
  @override
  Future<List<PlaceResult>> searchPlaces(String? query) => (super.noSuchMethod(
        Invocation.method(#searchPlaces, [query]),
        returnValue: Future<List<PlaceResult>>.value(const []),
        returnValueForMissingStub: Future<List<PlaceResult>>.value(const []),
      ) as Future<List<PlaceResult>>);

  @override
  Future<LatLng> pickLocation() => (super.noSuchMethod(
        Invocation.method(#pickLocation, []),
        returnValue: Future<LatLng>.value(const LatLng(15.5, 44.2)),
      ) as Future<LatLng>);
}

class MockConnectivityService extends Mock implements ConnectivityService {
  @override
  Stream<ConnectionStatus> watch() => (super.noSuchMethod(
        Invocation.method(#watch, []),
        returnValue: const Stream<ConnectionStatus>.empty(),
        returnValueForMissingStub: const Stream<ConnectionStatus>.empty(),
      ) as Stream<ConnectionStatus>);
}

void main() {
  late MockMapRepository mapRepo;
  late MockConnectivityService connectivity;
  late StreamController<ConnectionStatus> connectivityController;
  late ProviderContainer container;

  setUp(() {
    mapRepo = MockMapRepository();
    connectivity = MockConnectivityService();
    connectivityController = StreamController<ConnectionStatus>.broadcast();
    when(connectivity.watch()).thenAnswer((_) => connectivityController.stream);
    container = ProviderContainer(overrides: [
      mapRepositoryProvider.overrideWithValue(mapRepo),
      connectivityServiceProvider.overrideWithValue(connectivity),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await connectivityController.close();
  });

  HomeState state() => container.read(homeViewModelProvider);
  HomeNotifier notifier() => container.read(homeViewModelProvider.notifier);

  group('initial', () {
    test('starts empty and subscribes to connectivity', () {
      expect(state().connectionStatus, ConnectionStatus.unknown);
      expect(state().pickup, isNull);
      expect(state().currentLocation, isNull);
      verify(connectivity.watch()).called(1);
    });
  });

  group('connectivity stream', () {
    test('events update connection status', () async {
      expect(state().connectionStatus, ConnectionStatus.unknown);
      connectivityController.add(ConnectionStatus.online);
      await Future<void>.delayed(Duration.zero);
      expect(state().connectionStatus, ConnectionStatus.online);
      connectivityController.add(ConnectionStatus.offline);
      await Future<void>.delayed(Duration.zero);
      expect(state().connectionStatus, ConnectionStatus.offline);
    });
  });

  group('locateMe', () {
    test('success stores the picked location', () async {
      const picked = LatLng(15.3, 44.2);
      when(mapRepo.pickLocation()).thenAnswer((_) async => picked);
      await notifier().locateMe();
      expect(state().currentLocation, picked);
      expect(state().isLoading, isFalse);
      expect(state().error, isNull);
    });

    test('failure records an error', () async {
      when(mapRepo.pickLocation()).thenAnswer((_) async => throw Exception('gps'));
      await notifier().locateMe();
      expect(state().error, 'تعذر تحديد الموقع الحالي');
      expect(state().isLoading, isFalse);
      expect(state().currentLocation, isNull);
    });
  });

  group('pickup / destination', () {
    test('setting a null pickup clears the previous one', () {
      final vm = notifier();
      const point = LatLng(15.1, 44.1);
      vm.setPickup(point);
      expect(state().pickup, point);
      vm.setPickup(null);
      expect(state().pickup, isNull);
    });

    test('setting a null destination clears the previous one', () {
      final vm = notifier();
      const point = LatLng(15.2, 44.3);
      vm.setDestination(point);
      expect(state().destination, point);
      vm.setDestination(null);
      expect(state().destination, isNull);
    });

    test('clearSelection removes both endpoints', () {
      final vm = notifier();
      vm.setPickup(const LatLng(15.1, 44.1));
      vm.setDestination(const LatLng(15.2, 44.3));
      vm.clearSelection();
      expect(state().pickup, isNull);
      expect(state().destination, isNull);
    });
  });

  group('setError', () {
    test('sets and clears the error message', () {
      notifier().setError('boom');
      expect(state().error, 'boom');
      notifier().setError(null);
      expect(state().error, isNull);
    });
  });

  group('searchPlaces', () {
    test('passes through repository results', () async {
      const results = [
        PlaceResult(
          placeId: 'p1',
          name: 'صنعاء',
          address: 'Old City',
          latLng: LatLng(15.35, 44.2),
        ),
      ];
      when(mapRepo.searchPlaces('صنعاء')).thenAnswer((_) async => results);
      expect(await notifier().searchPlaces('صنعاء'), results);
    });
  });
}
