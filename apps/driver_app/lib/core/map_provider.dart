library driver_app.core.map_provider;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'constants.dart';

class PlaceResult {
  const PlaceResult({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latLng,
  });
  final String placeId;
  final String name;
  final String address;
  final LatLng latLng;
}

class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
  final List<LatLng> points;
  final double distanceMeters;
  final int durationSeconds;
}

class DriverLocation {
  const DriverLocation({
    required this.latLng,
    required this.recordedAt,
    required this.ageSeconds,
  });
  final LatLng latLng;
  final DateTime recordedAt;
  final int ageSeconds;
}

abstract class MapProvider {
  Future<LatLng> pickLocation();
  Future<List<PlaceResult>> searchPlaces(String query);
  Future<RouteResult> getRoute(LatLng origin, LatLng destination);
  Stream<DriverLocation> watchDriverLocation(String rideId);
}

class StubMapProvider implements MapProvider {
  @override
  Future<LatLng> pickLocation() =>
      throw UnimplementedError('StubMapProvider.pickLocation: replace with a real map provider (Google Maps / Mapbox). See README-SETUP.md.');

  @override
  Future<List<PlaceResult>> searchPlaces(String query) =>
      throw UnimplementedError('StubMapProvider.searchPlaces: replace with a real map provider. See README-SETUP.md.');

  @override
  Future<RouteResult> getRoute(LatLng origin, LatLng destination) =>
      throw UnimplementedError('StubMapProvider.getRoute: replace with a real map provider. See README-SETUP.md.');

  @override
  Stream<DriverLocation> watchDriverLocation(String rideId) async* {
    throw UnimplementedError('StubMapProvider.watchDriverLocation: replace with a real map provider. See README-SETUP.md.');
  }
}
